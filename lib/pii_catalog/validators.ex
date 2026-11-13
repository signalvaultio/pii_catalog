defmodule PiiCatalog.Validators do
  @moduledoc """
  Checks a candidate match must pass before it counts.

  A regex finds values of the right shape; many of those are order numbers,
  timestamps or version strings. Where an identifier carries a check digit
  or a structure the regex cannot express, it is confirmed here.

  Each check takes only the matched bytes. It does not depend on the text
  around them, so a value gives the same answer wherever it is found.

  `valid?/2` takes the name of a check, which is a pattern's `validator`
  field, not the pattern's name; several patterns could share one check.
  `PiiCatalog.valid?/2` takes a pattern name.

  Three checks compare a date of birth with today's date
  (`Date.utc_today/0`): `:pesel_pl`, `:isikukood_ee` (a date after today is
  refused) and `:rrn_be` (the reading for people born from 2000 is tried
  only for a year that has begun). Their answer for a given value can change
  as time passes.
  """

  import Bitwise

  alias PiiCatalog.Validators.{NationalIds, VatEu}

  @doc """
  Runs the named check on a matched value. `nil` accepts every value.

  The names are those in `names/0`; any other raises `ArgumentError`.
  Separators the pattern allows are dropped by the check itself, so
  `"4111 1111 1111 1111"` and `"4111111111111111"` give the same answer.
  For a binary value it returns a boolean and does not raise.
  """
  @spec valid?(atom() | nil, binary()) :: boolean()
  def valid?(nil, _value), do: true
  def valid?(:luhn, value), do: luhn?(digits(value))
  def valid?(:ip_octets, value), do: ip_octets?(value)
  def valid?(:nanp_phone, value), do: nanp_phone?(digits(value))
  def valid?(:ssn_structure, value), do: ssn_structure?(digits(value))
  def valid?(:iban, value), do: iban?(value)
  def valid?(:personnummer_se, value), do: personnummer_se?(digits(value))
  def valid?(:fodselsnummer_no, value), do: fodselsnummer_no?(digits(value))
  def valid?(:hetu_fi, value), do: hetu_fi?(value)
  def valid?(:cpr_dk, value), do: cpr_dk?(digits(value))
  def valid?(:kennitala_is, value), do: kennitala_is?(digits(value))
  def valid?(:steuer_id_de, value), do: steuer_id_de?(digits(value))
  def valid?(:bsn_nl, value), do: bsn_nl?(digits(value))
  def valid?(:nir_fr, value), do: nir_fr?(String.replace(value, " ", ""))
  def valid?(:dni_es, value), do: dni_es?(String.replace(value, ["-", " "], ""))
  def valid?(:nie_es, value), do: nie_es?(String.replace(value, ["-", " "], ""))
  def valid?(:codice_fiscale_it, value), do: codice_fiscale_it?(value)
  def valid?(:nino_gb, value), do: nino_gb?(String.replace(value, " ", ""))
  def valid?(:vat_eu, value), do: VatEu.valid?(value)

  def valid?(name, value)
      when name in [
             :pesel_pl,
             :rrn_be,
             :ppsn_ie,
             :nif_pt,
             :ahv_ch,
             :svnr_at,
             :isikukood_ee,
             :nhs_gb
           ],
      do: NationalIds.valid?(name, value)

  def valid?(name, value) when is_binary(value),
    do: raise(ArgumentError, "unknown check #{inspect(name)}, expected one of names/0 or nil")

  @names [
    :luhn,
    :ip_octets,
    :nanp_phone,
    :ssn_structure,
    :iban,
    :personnummer_se,
    :fodselsnummer_no,
    :hetu_fi,
    :cpr_dk,
    :kennitala_is,
    :steuer_id_de,
    :bsn_nl,
    :nir_fr,
    :dni_es,
    :nie_es,
    :codice_fiscale_it,
    :nino_gb,
    :vat_eu,
    :pesel_pl,
    :rrn_be,
    :ppsn_ie,
    :nif_pt,
    :ahv_ch,
    :svnr_at,
    :isikukood_ee,
    :nhs_gb
  ]

  @doc "The name of every check `valid?/2` runs."
  @spec names() :: [atom(), ...]
  def names, do: @names

  @doc """
  What a check confirms, in a few words: `"Luhn check digit"`. `nil`, no
  check, is `"Format only"`.
  """
  @spec describe(atom() | nil) :: String.t()
  def describe(nil), do: "Format only"
  def describe(:luhn), do: "Luhn check digit"
  def describe(:ip_octets), do: "Each part 0–255"
  def describe(:nanp_phone), do: "Area code and exchange that can exist"
  def describe(:ssn_structure), do: "Excludes numbers never issued"
  def describe(:iban), do: "Length for the country and mod-97 check digits"
  def describe(:personnummer_se), do: "Date of birth and Luhn check digit"
  def describe(:fodselsnummer_no), do: "Date of birth and two mod-11 check digits"
  def describe(:hetu_fi), do: "Date of birth and check character"
  def describe(:cpr_dk), do: "Date of birth, after the word CPR"
  def describe(:kennitala_is), do: "Date of birth and century digit, after the word kennitala"
  def describe(:steuer_id_de), do: "ISO 7064 check digit and digit pattern"
  def describe(:bsn_nl), do: "11-check, after the word BSN"
  def describe(:nir_fr), do: "Sex, month and mod-97 key"
  def describe(:dni_es), do: "Check letter (mod 23)"
  def describe(:nie_es), do: "Check letter (mod 23)"
  def describe(:codice_fiscale_it), do: "Date of birth and check character"
  def describe(:nino_gb), do: "Issued prefix, after the words National Insurance"

  def describe(:vat_eu),
    do:
      "Check digits in 21 member states; format only in BG, CY, EL, LV, MT and RO, " <>
        "for Spanish legal entities and for the French key; date only for Czech nine-digit numbers"

  def describe(:pesel_pl), do: "Date of birth and check digit"
  def describe(:rrn_be), do: "Month of birth and mod-97 check digits"
  def describe(:ppsn_ie), do: "Check letter (mod 23)"
  def describe(:nif_pt), do: "Mod-11 check digit, after the word NIF"
  def describe(:ahv_ch), do: "756 prefix and EAN-13 check digit"
  def describe(:svnr_at), do: "Check digit, after the word SVNR"
  def describe(:isikukood_ee), do: "Date of birth and check digit, after the word isikukood"
  def describe(:nhs_gb), do: "Mod-11 check digit, after the word NHS"

  @doc """
  The Luhn check (ISO/IEC 7812-1), on a list of digits. Used by payment cards,
  and by Swedish personnummer on the ten-digit form.
  """
  @spec luhn?([0..9]) :: boolean()
  def luhn?([]), do: false

  def luhn?(digits) do
    sum =
      digits
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce(0, fn
        {d, i}, acc when (i &&& 1) == 1 ->
          doubled = d * 2
          acc + if doubled > 9, do: doubled - 9, else: doubled

        {d, _i}, acc ->
          acc + d
      end)

    rem(sum, 10) == 0
  end

  @doc "The decimal digits in a value, in order, with separators dropped."
  @spec digits(binary()) :: [0..9]
  def digits(value) do
    for <<c <- value>>, c in ?0..?9, do: c - ?0
  end

  @doc """
  A weighted mod-11 check digit: 11 minus the weighted sum mod 11, where 11
  gives 0 and 10 gives `nil`, a number that is never issued. Used by the
  Norwegian fødselsnummer.
  """
  @spec mod11_check_digit([0..9], [pos_integer()]) :: 0..9 | nil
  def mod11_check_digit(digits, weights) do
    sum = digits |> Enum.zip(weights) |> Enum.reduce(0, fn {d, w}, acc -> acc + d * w end)

    case 11 - rem(sum, 11) do
      11 -> 0
      10 -> nil
      check -> check
    end
  end

  @doc """
  Whether a day, month and two-digit year can be a date of birth. Without the
  century, 29 February is accepted in every year divisible by four.
  """
  @spec date?(integer(), integer(), integer()) :: boolean()
  def date?(year, month, day) when year < 100, do: date?(2000 + year, month, day)
  def date?(year, month, day), do: Calendar.ISO.valid_date?(year, month, day)

  # IBAN lengths, from the SWIFT IBAN Registry, for the countries in the
  # EPC's list of countries in the SEPA schemes' geographical scope.
  @iban_lengths %{
    "AD" => 24,
    "AL" => 28,
    "AT" => 20,
    "BE" => 16,
    "BG" => 22,
    "CH" => 21,
    "CY" => 28,
    "CZ" => 24,
    "DE" => 22,
    "DK" => 18,
    "EE" => 20,
    "ES" => 24,
    "FI" => 18,
    "FR" => 27,
    "GB" => 22,
    "GI" => 23,
    "GR" => 27,
    "HR" => 21,
    "HU" => 28,
    "IE" => 22,
    "IS" => 26,
    "IT" => 27,
    "LI" => 21,
    "LT" => 20,
    "LU" => 20,
    "LV" => 21,
    "MC" => 27,
    "MD" => 24,
    "ME" => 22,
    "MK" => 19,
    "MT" => 31,
    "NL" => 18,
    "NO" => 15,
    "PL" => 28,
    "PT" => 25,
    "RO" => 24,
    "RS" => 22,
    "SE" => 24,
    "SI" => 19,
    "SK" => 24,
    "SM" => 27,
    "VA" => 22
  }

  @doc """
  The IBAN length of every country in the EPC's list of SEPA countries, as
  a map from the country code to the length: `%{"AD" => 24, ...}`.
  """
  @spec iban_lengths() :: %{String.t() => pos_integer()}
  def iban_lengths, do: @iban_lengths

  @doc "The IBAN length for a country code, or `nil` outside SEPA."
  @spec iban_length(String.t()) :: pos_integer() | nil
  def iban_length(country), do: Map.get(@iban_lengths, country)

  # ISO 13616: the length the country registers, and the number made by
  # moving the first four characters to the end and reading each letter as
  # 10-35 leaves 1 mod 97.
  defp iban?(value) do
    iban = String.replace(value, " ", "")

    case iban do
      <<country::binary-size(2), _::binary>> ->
        byte_size(iban) == iban_length(country) and alphanumeric?(iban) and mod97(iban) == 1

      _ ->
        false
    end
  end

  defp mod97(<<head::binary-size(4), rest::binary>>) do
    for(<<c <- rest <> head>>, into: "", do: iban_char(c))
    |> String.to_integer()
    |> rem(97)
  end

  defp iban_char(c) when c in ?0..?9, do: <<c>>
  defp iban_char(c) when c in ?A..?Z, do: Integer.to_string(c - ?A + 10)

  # Digits and capital letters only.
  defp alphanumeric?(<<c, rest::binary>>) when c in ?0..?9 or c in ?A..?Z,
    do: alphanumeric?(rest)

  defp alphanumeric?(<<>>), do: true
  defp alphanumeric?(_value), do: false

  # Decimal digits only, at least one. Integer.parse/1 would also take a
  # sign.
  defp all_digits?(<<>>), do: false
  defp all_digits?(value), do: only_digits?(value)

  defp only_digits?(<<c, rest::binary>>) when c in ?0..?9, do: only_digits?(rest)
  defp only_digits?(<<>>), do: true
  defp only_digits?(_value), do: false

  # Swedish personnummer (Skatteverket, SKV 704): YYMMDD, a birth number
  # from 001 to 999 and a Luhn check digit over the ten. A
  # samordningsnummer adds 60 to the day. The twelve-digit form starts with
  # the century, which the check leaves out.
  defp personnummer_se?([c1, c2 | rest]) when length(rest) == 10 do
    (c1 * 10 + c2) in 19..20 and personnummer_se?(rest, (c1 * 10 + c2) * 100)
  end

  defp personnummer_se?(digits) when length(digits) == 10, do: personnummer_se?(digits, 0)
  defp personnummer_se?(_digits), do: false

  defp personnummer_se?([y1, y2, m1, m2, d1, d2, n1, n2, n3, _] = digits, century) do
    day = d1 * 10 + d2
    day = if day > 60, do: day - 60, else: day

    date?(century + y1 * 10 + y2, m1 * 10 + m2, day) and [n1, n2, n3] != [0, 0, 0] and
      luhn?(digits)
  end

  # Norwegian fødselsnummer (Skatteetaten): DDMMYY, a three-digit individual
  # number and two mod-11 check digits; a check digit of 10 is never issued.
  # A D-nummer adds 4 to the first digit of the day, so a first digit of 4
  # to 7; any other day must be a date as it stands.
  defp fodselsnummer_no?([d1, d2, m1, m2, y1, y2, _, _, _, k1, k2] = digits) do
    day = if d1 in 4..7, do: (d1 - 4) * 10 + d2, else: d1 * 10 + d2
    first_nine = Enum.take(digits, 9)

    date?(y1 * 10 + y2, m1 * 10 + m2, day) and
      mod11_check_digit(first_nine, [3, 7, 6, 1, 8, 9, 4, 5, 2]) == k1 and
      mod11_check_digit(first_nine ++ [k1], [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]) == k2
  end

  defp fodselsnummer_no?(_digits), do: false

  # Finnish henkilötunnus (Valtioneuvoston asetus 128/2010 § 2, as amended
  # by 690/2022): DDMMYY, a century sign, a three-digit individual number
  # and a check character, the nine digits mod 31. Since 2023 Y, X, W, V and
  # U also mark the 1900s and B to F the 2000s. Individual numbers run from
  # 002 to 899 (Statistics Finland, DVV); Kela issues 900 and up for testing.
  @hetu_check_chars ~c"0123456789ABCDEFHJKLMNPRSTUVWXY"

  defp hetu_fi?(<<date::binary-size(6), sign, individual::binary-size(3), check>>) do
    with {:ok, century} <- hetu_century(sign),
         [d1, d2, m1, m2, y1, y2] <- digits(date),
         true <- all_digits?(individual),
         number when number in 2..899 <- String.to_integer(individual) do
      date?(century + y1 * 10 + y2, m1 * 10 + m2, d1 * 10 + d2) and
        Enum.at(@hetu_check_chars, rem(String.to_integer(date <> individual), 31)) == check
    else
      _ -> false
    end
  end

  defp hetu_fi?(_value), do: false

  defp hetu_century(?+), do: {:ok, 1800}
  defp hetu_century(sign) when sign in ~c"-YXWVU", do: {:ok, 1900}
  defp hetu_century(sign) when sign in ~c"ABCDEF", do: {:ok, 2000}
  defp hetu_century(_sign), do: :error

  # Danish CPR: DDMMYY and four digits. Since 2007 a number is not
  # guaranteed to pass the modulus-11 check (CPR-kontoret, "Personnumre uden
  # kontrolciffer (modulus 11 kontrol)"), so only the date is checked; the
  # pattern requires the word CPR before it.
  defp cpr_dk?([d1, d2, m1, m2, y1, y2, _, _, _, _]) do
    date?(y1 * 10 + y2, m1 * 10 + m2, d1 * 10 + d2)
  end

  defp cpr_dk?(_digits), do: false

  # Icelandic kennitala (Þjóðskrá): DDMMYY, three digits and the century (9
  # for the 1900s, 0 for the 2000s, 8 for the 1800s). The ninth digit was a
  # mod-11 check digit until 18 February 2026; numbers issued since do not
  # pass it, so it is not checked. The pattern requires the word kennitala
  # before the number. A day that is not a date, such as a company's day
  # plus 40, is not matched.
  defp kennitala_is?([d1, d2, m1, m2, y1, y2, _, _, _, c]) do
    century = %{9 => 1900, 0 => 2000, 8 => 1800}

    Map.has_key?(century, c) and
      date?(century[c] + y1 * 10 + y2, m1 * 10 + m2, d1 * 10 + d2)
  end

  defp kennitala_is?(_digits), do: false

  # German Steuerliche Identifikationsnummer: eleven digits, not starting
  # with 0. In the first ten, exactly one digit appears two or three times
  # (three never in a row) and the rest at most once. The last is an
  # ISO 7064 MOD 11,10 check digit.
  defp steuer_id_de?([first | _] = digits) when length(digits) == 11 and first != 0 do
    {first_ten, [check]} = Enum.split(digits, 10)
    steuer_id_digit_pattern?(first_ten) and iso7064_mod11_10(first_ten) == check
  end

  defp steuer_id_de?(_digits), do: false

  defp steuer_id_digit_pattern?(digits) do
    case digits |> Enum.frequencies() |> Map.values() |> Enum.sort(:desc) do
      [2 | rest] -> Enum.all?(rest, &(&1 == 1))
      [3 | rest] -> Enum.all?(rest, &(&1 == 1)) and not three_in_a_row?(digits)
      _ -> false
    end
  end

  defp three_in_a_row?([a, a, a | _]), do: true
  defp three_in_a_row?([_ | rest]), do: three_in_a_row?(rest)
  defp three_in_a_row?([]), do: false

  @doc """
  The ISO 7064 MOD 11,10 check digit for a list of digits. Used by the
  German Steuer-ID and the German and Croatian VAT numbers.
  """
  @spec iso7064_mod11_10([0..9]) :: 0..9
  def iso7064_mod11_10(digits) do
    product =
      Enum.reduce(digits, 10, fn d, product ->
        sum = rem(d + product, 10)
        rem(if(sum == 0, do: 10, else: sum) * 2, 11)
      end)

    case 11 - product do
      10 -> 0
      check -> check
    end
  end

  # Dutch burgerservicenummer: nine digits whose weighted sum, 9 down to 2
  # and -1 for the last, is a multiple of 11 (the 11-proef).
  defp bsn_nl?(digits) when length(digits) == 9 do
    sum =
      digits
      |> Enum.zip([9, 8, 7, 6, 5, 4, 3, 2, -1])
      |> Enum.reduce(0, fn {d, w}, acc -> acc + d * w end)

    sum != 0 and rem(sum, 11) == 0
  end

  defp bsn_nl?(_digits), do: false

  # French NIR (INSEE; DSN cahier technique, rubrique S21.G00.30.001): sex
  # (1 or 2), year, month (01-12, or 20, 30-42 and 50-99 where it is
  # unknown), department (01-99, 2A and 2B for Corsica), commune and order
  # number (each 001-999) and a key: 97 minus the thirteen digits mod 97,
  # with 2A read as 19 and 2B as 18.
  defp nir_fr?(
         <<sex, _yy::binary-size(2), mm::binary-size(2), dept::binary-size(2),
           commune::binary-size(3), order::binary-size(3), key::binary-size(2)>> = value
       )
       when sex in ~c"12" do
    number =
      <<binary_part(value, 0, 5)::binary, nir_department(dept)::binary, commune::binary,
        order::binary>>

    with true <- all_digits?(mm) and all_digits?(number) and all_digits?(key),
         month = String.to_integer(mm),
         true <- month in 1..12 or month == 20 or month in 30..42 or month in 50..99,
         true <- dept != "00" and commune != "000" and order != "000" do
      String.to_integer(key) == 97 - rem(String.to_integer(number), 97)
    else
      _ -> false
    end
  end

  defp nir_fr?(_value), do: false

  defp nir_department("2A"), do: "19"
  defp nir_department("2B"), do: "18"
  defp nir_department(dept), do: dept

  # Spanish DNI: eight digits and the letter for their value mod 23. A NIE
  # starts with X, Y or Z, read as 0, 1 and 2, followed by seven digits.
  @dni_letters ~c"TRWAGMYFPDXBNJZSQVHLCKE"

  defp dni_es?(<<number::binary-size(8), letter>>), do: dni_letter?(number, letter)
  defp dni_es?(_value), do: false

  defp nie_es?(<<prefix, number::binary-size(7), letter>>) when prefix in ~c"XYZ" do
    dni_letter?(<<prefix - ?X + ?0, number::binary>>, letter)
  end

  defp nie_es?(_value), do: false

  defp dni_letter?(number, letter) do
    all_digits?(number) and Enum.at(@dni_letters, rem(String.to_integer(number), 23)) == letter
  end

  # Italian codice fiscale: six letters, year, month letter, day (plus 40
  # for women), the birthplace code and a check character. Where two people
  # would share a code, digits are replaced by letters (omocodia), L to V
  # standing for 0 to 9.
  @cf_months ~c"ABCDEHLMPRST"
  @cf_omocodia ~c"LMNPQRSTUV"
  @cf_odd_values [
    1,
    0,
    5,
    7,
    9,
    13,
    15,
    17,
    19,
    21,
    2,
    4,
    18,
    20,
    11,
    3,
    6,
    8,
    12,
    14,
    16,
    10,
    22,
    25,
    24,
    23
  ]

  # Written in capitals, as the regex matches it: any other byte is refused.
  defp codice_fiscale_it?(<<body::binary-size(15), check>>) when check in ?A..?Z do
    alphanumeric?(body) and codice_fiscale_body?(body, check)
  end

  defp codice_fiscale_it?(_value), do: false

  defp codice_fiscale_body?(body, check) do
    <<_names::binary-size(6), y1, y2, month, d1, d2, _rest::binary>> = body
    month_number = Enum.find_index(@cf_months, &(&1 == month))
    [y1, y2, d1, d2] = Enum.map([y1, y2, d1, d2], &cf_digit/1)
    day = cf_day(d1 * 10 + d2)

    month_number != nil and day != nil and date?(y1 * 10 + y2, month_number + 1, day) and
      cf_check(body) == check
  end

  # Men's codes carry the day of birth, women's the day plus 40.
  defp cf_day(day) when day in 1..31, do: day
  defp cf_day(day) when day in 41..71, do: day - 40
  defp cf_day(_day), do: nil

  defp cf_digit(c) when c in ?0..?9, do: c - ?0
  defp cf_digit(c), do: Enum.find_index(@cf_omocodia, &(&1 == c)) || 99

  defp cf_check(body) do
    sum =
      body
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.reduce(0, fn {c, i}, acc -> acc + cf_value(c, rem(i, 2) == 0) end)

    ?A + rem(sum, 26)
  end

  defp cf_value(c, odd?) do
    index = if c in ?0..?9, do: c - ?0, else: c - ?A
    if odd?, do: Enum.at(@cf_odd_values, index), else: index
  end

  # UK National Insurance number: two letters, six digits and A to D. The
  # first letter is never D, F, I, Q, U or V, the second never those or O,
  # and BG, GB, NK, KN, TN, NT and ZZ are not issued.
  defp nino_gb?(<<p1, p2, digits::binary-size(6), suffix>>)
       when p1 in ?A..?Z and p2 in ?A..?Z do
    p1 not in ~c"DFIQUV" and p2 not in ~c"DFIOQUV" and
      <<p1, p2>> not in ~w(BG GB NK KN TN NT ZZ) and suffix in ?A..?D and
      all_digits?(digits)
  end

  defp nino_gb?(_value), do: false

  # Four dotted decimal octets, each 0-255.
  defp ip_octets?(value) do
    case String.split(value, ".") do
      [_, _, _, _] = parts -> Enum.all?(parts, &octet?/1)
      _ -> false
    end
  end

  defp octet?(part), do: all_digits?(part) and String.to_integer(part) in 0..255

  # North American numbering plan: neither the area code nor the exchange
  # starts with 0 or 1. That rules out 36 in 100 ten-digit runs, including
  # every Unix timestamp in seconds before May 2033; the other 64 pass.
  defp nanp_phone?([a, _, _, e, _, _, _, _, _, _]), do: a >= 2 and e >= 2
  defp nanp_phone?(_digits), do: false

  # US social security numbers are never issued with area 000, 666 or 900 to
  # 999, group 00 or serial 0000 (SSA POMS RM 10201.035). An ITIN, as
  # sensitive, starts with 9 and has a group of 50-65, 70-88, 90-92 or 94-99
  # (IRS, IRM 21.8.1.1.21), and is matched too.
  defp ssn_structure?([9, _, _, g1, g2, s1, s2, s3, s4]) do
    group = g1 * 10 + g2

    (group in 50..65 or group in 70..88 or group in 90..92 or group in 94..99) and
      [s1, s2, s3, s4] != [0, 0, 0, 0]
  end

  defp ssn_structure?([a1, a2, a3, g1, g2, s1, s2, s3, s4]) do
    area = [a1, a2, a3]

    area != [0, 0, 0] and area != [6, 6, 6] and [g1, g2] != [0, 0] and
      [s1, s2, s3, s4] != [0, 0, 0, 0]
  end

  defp ssn_structure?(_digits), do: false
end
