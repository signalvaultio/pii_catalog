defmodule PiiCatalog.Validators.VatEu do
  @moduledoc """
  EU VAT identification numbers, for the 27 member states.

  The prefix is the country code, `EL` for Greece. The national number
  follows in its compact form, after an optional space.

  Each country's check is written from what its issuer, or the issuer's
  government, publishes. Most come from one source: the Austrian Federal
  Ministry of Finance's *Information über die Konstruktionsregeln der
  Umsatzsteuer-Identifikationsnummern (UID)*, Stand November 2020. Member
  states released the rules in it for publication. That covers AT, BE, DE,
  DK, EE, FI, HU, IE, IT, LT, LU, NL, PL, PT, SE, SI and SK. The others come
  from national law:

    * CZ – zákon č. 280/2009 Sb. § 130 (the number is the IČO of a legal
      entity or the birth number of a person), the Czech Statistical
      Office's description of the IČO check, and zákon č. 133/2000 Sb. § 13
      on birth numbers.
    * ES – Real Decreto 1065/2007 and Orden EHA/451/2008 on the NIF, and the
      Ministerio del Interior's DNI and NIE letter table.
    * FR – INSEE's description of the SIREN, which carries a Luhn check
      digit.
    * HR – Zakon o osobnom identifikacijskom broju (NN 60/2008) and its
      Pravilnik (NN 1/2009): the number is the OIB, with an ISO 7064
      MOD 11,10 check digit.

  Only the structure is checked where no official source publishes a
  check, or where a number with a published check cannot be told from one
  without. That applies to all of a country's numbers for BG, CY, EL, LV, MT
  and RO. It also applies to some numbers in three more countries:

    * ES – legal entities, and the K, L and M forms. Each is a letter,
      seven characters and a control character.
    * FR – the two-character key. The SIREN after it is still checked.
    * CZ – nine-digit birth numbers, which people born before 1954 hold.
      These have no check digit, so only their date is checked.

  `SOURCES.md` in the repository lists the source for each country.
  """

  alias PiiCatalog.Validators

  @member_states ~w(AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV MT NL PL PT RO SE SI SK)

  # Orden EHA/451/2008, arts. 3 to 5: the letters a legal entity's NIF
  # starts with.
  @es_entity_letters ~c"ABCDEFGHJNPQRSUVW"

  # Ireland (BMF): the check letter for a remainder mod 23, 0 to 22.
  @ie_letters ~c"WABCDEFGHIJKLMNOPQRSTUV"

  @doc """
  Whether a VAT number, with its two-letter prefix, passes its country's
  check. A space between the prefix and the number is allowed.

      iex> PiiCatalog.Validators.VatEu.valid?("DE 111111125")
      true
      iex> PiiCatalog.Validators.VatEu.valid?("DE111111126")
      false
  """
  @spec valid?(binary()) :: boolean()
  def valid?(<<country::binary-size(2), " ", number::binary>>), do: valid?(country, number)
  def valid?(<<country::binary-size(2), number::binary>>), do: valid?(country, number)
  def valid?(_value), do: false

  @doc "The prefixes `valid?/1` knows, `EL` for Greece."
  @spec member_states() :: [String.t(), ...]
  def member_states, do: @member_states

  defp valid?(country, number) when country in @member_states, do: country?(country, number)
  defp valid?(_country, _number), do: false

  # Austria (BMF): U and eight digits C2 to C9.
  # C9 = (10 - (R + C2 + C4 + C6 + C8 + 4) mod 10) mod 10, R = S3 + S5 + S7.
  defp country?("AT", <<"U", rest::binary-size(8)>>) do
    case numeric(rest) do
      [c2, c3, c4, c5, c6, c7, c8, c9] ->
        r = s(c3) + s(c5) + s(c7)
        rem(10 - rem(r + c2 + c4 + c6 + c8 + 4, 10), 10) == c9

      nil ->
        false
    end
  end

  # Belgium (BMF): ten digits, the first 0, or 0 or 1 since 2020. The last
  # two are 97 minus the first eight mod 97.
  defp country?("BE", <<first, _::binary-size(9)>> = number) when first in ~c"01" do
    on_digits(number, fn digits ->
      {body, check} = Enum.split(digits, 8)
      97 - rem(Integer.undigits(body), 97) == Integer.undigits(check)
    end)
  end

  # Germany (BMF): nine digits, the first not 0. C9 comes from C1 to C8 by
  # the iterative procedure the BMF gives (P = 10; S = C + P; M = S mod 10,
  # 0 read as 10; P = 2M mod 11; C9 = 11 - P, 10 read as 0), which is
  # `Validators.iso7064_mod11_10/1`.
  defp country?("DE", <<first, _::binary-size(8)>> = number) when first != ?0 do
    on_digits(number, fn digits ->
      {body, [check]} = Enum.split(digits, 8)
      Validators.iso7064_mod11_10(body) == check
    end)
  end

  # Denmark (BMF): eight digits, the first not 0, with
  # 2*C1 + 7*C2 + 6*C3 + 5*C4 + 4*C5 + 3*C6 + 2*C7 + C8 divisible by 11.
  defp country?("DK", <<first, _::binary-size(7)>> = number) when first != ?0 do
    on_digits(number, &(rem(weighted(&1, [2, 7, 6, 5, 4, 3, 2, 1]), 11) == 0))
  end

  # Estonia (BMF): nine digits starting 10. C9 is the 3, 7, 1, 3, 7, 1, 3, 7
  # weighted sum subtracted from the next multiple of ten.
  defp country?("EE", <<"10", _::binary-size(7)>> = number) do
    on_digits(number, fn digits ->
      {body, [check]} = Enum.split(digits, 8)
      rem(10 - rem(weighted(body, [3, 7, 1, 3, 7, 1, 3, 7]), 10), 10) == check
    end)
  end

  # Finland (BMF, and Valtioneuvoston asetus 288/2001 § 3): eight digits.
  # R = 11 - (7, 9, 10, 5, 8, 4, 2 weighted sum mod 11). R = 10 is never
  # issued and R = 11 gives 0.
  defp country?("FI", <<_::binary-size(8)>> = number) do
    on_digits(number, fn digits ->
      {body, [check]} = Enum.split(digits, 7)

      case 11 - rem(weighted(body, [7, 9, 10, 5, 8, 4, 2]), 11) do
        10 -> false
        11 -> check == 0
        r -> check == r
      end
    end)
  end

  # Hungary (BMF, and NAV's recommendation for invoicing software): eight
  # digits. C8 is 10 minus the last digit of the 9, 7, 3, 1, 9, 7, 3
  # weighted sum, or 0 when that digit is 0.
  defp country?("HU", <<_::binary-size(8)>> = number) do
    on_digits(number, fn digits ->
      {body, [check]} = Enum.split(digits, 7)
      rem(10 - rem(weighted(body, [9, 7, 3, 1, 9, 7, 3]), 10), 10) == check
    end)
  end

  # Ireland (BMF), version 1: a digit, a letter, + or *, five digits and the
  # check letter. The sum runs over 0, the five digits and the first digit.
  defp country?("IE", <<first, second, five::binary-size(5), check>>)
       when first in ?0..?9 and (second in ?A..?Z or second in ~c"+*") do
    on_digits(five, &ie_check?([0 | &1] ++ [first - ?0], 0, check))
  end

  # Version 2: seven digits and the check letter.
  defp country?("IE", <<body::binary-size(7), check>>) do
    on_digits(body, &ie_check?(&1, 0, check))
  end

  # Version 3: seven digits, the check letter and a letter from A to I,
  # counted 1 to 9 with weight 9.
  defp country?("IE", <<body::binary-size(7), check, extra>>) when extra in ?A..?I do
    on_digits(body, &ie_check?(&1, (extra - ?A + 1) * 9, check))
  end

  # Italy (BMF, and DM 23 dicembre 1976 art. 8 and 9): eleven digits; C8 to
  # C10 are the office code. The BMF's rule allows 001 to 100, 120, 121, 888
  # and 999, its worked example 001 to 150; 001 to 150, 888 and 999 pass.
  # C11 is the units digit of 10 minus the sum of the odd-position digits
  # and of the doubled even-position ones, each reduced to one digit.
  defp country?("IT", <<_::binary-size(11)>> = number) do
    case numeric(number) do
      [c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11] ->
        office = Integer.undigits([c8, c9, c10])
        sum = c1 + c3 + c5 + c7 + c9 + s(c2) + s(c4) + s(c6) + s(c8) + s(c10)
        (office in 1..150 or office in [888, 999]) and rem(10 - rem(sum, 10), 10) == c11

      nil ->
        false
    end
  end

  # Lithuania (BMF): nine digits with C8 = 1 (legal persons), or twelve with
  # C11 = 1 (temporarily registered taxpayers).
  defp country?("LT", <<_::binary-size(7), "1", _>> = number) do
    on_digits(number, &lt_check?/1)
  end

  defp country?("LT", <<_::binary-size(10), "1", _>> = number) do
    on_digits(number, &lt_check?/1)
  end

  # Luxembourg (BMF): eight digits, the last two the first six mod 89.
  defp country?("LU", <<_::binary-size(8)>> = number) do
    on_digits(number, fn digits ->
      {body, check} = Enum.split(digits, 6)
      rem(Integer.undigits(body), 89) == Integer.undigits(check)
    end)
  end

  # Netherlands (BMF): nine digits, B and two digits. Valid when it passes
  # the modulo 11 check, or else the modulo 97 one used since 2020.
  defp country?("NL", <<body::binary-size(9), "B", suffix::binary-size(2)>> = number) do
    with [_ | _] = digits <- numeric(body),
         [_ | _] = suffix_digits <- numeric(suffix) do
      suffix = Integer.undigits(suffix_digits)
      nl_mod11?(digits, suffix) or nl_mod97?(number, suffix)
    else
      _ -> false
    end
  end

  # Poland (BMF, and the Ministry of Finance's TIN sheet): ten digits. C10
  # is the 6, 5, 7, 2, 3, 4, 5, 6, 7 weighted sum mod 11; 10 is never
  # issued. The Ministry's XML type for the NIP (TNrNIP) also requires a
  # first digit other than 0 and second and third digits other than 00.
  defp country?("PL", <<first, second, third, _::binary-size(7)>> = number)
       when first != ?0 and <<second, third>> != "00" do
    on_digits(number, fn digits ->
      {body, [check]} = Enum.split(digits, 9)
      rem(weighted(body, [6, 5, 7, 2, 3, 4, 5, 6, 7]), 11) == check
    end)
  end

  # Portugal (BMF): nine digits, the first not 0.
  # C9 = 11 - (9, 8, ..., 2 weighted sum mod 11), where 10 and 11 give 0.
  defp country?("PT", <<first, _::binary-size(8)>> = number) when first != ?0 do
    on_digits(number, &pt_check?/1)
  end

  # Sweden (BMF): twelve digits, the last two from 01 to 94.
  # C10 = (10 - (R + C2 + C4 + C6 + C8) mod 10) mod 10, R = S1 + S3 + ... + S9.
  # The ten digits are an organisationsnummer, whose third digit is at
  # least 2 (Skatteverket, SKV 709), or a sole trader's personnummer, whose
  # first six are a date of birth (Skatteverket).
  defp country?("SE", <<_::binary-size(12)>> = number) do
    case numeric(number) do
      [c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12] ->
        r = s(c1) + s(c3) + s(c5) + s(c7) + s(c9)

        (c11 * 10 + c12) in 1..94 and (c3 >= 2 or se_birth_date?(c1, c2, c3, c4, c5, c6)) and
          rem(10 - rem(r + c2 + c4 + c6 + c8, 10), 10) == c10

      nil ->
        false
    end
  end

  # Slovenia (BMF): eight digits, the first seven from 1000000.
  # R = 11 - (8, 7, ..., 2 weighted sum mod 11); R = 10 gives 0, R = 11 is
  # never issued.
  defp country?("SI", <<first, _::binary-size(7)>> = number) when first != ?0 do
    on_digits(number, fn digits ->
      {body, [check]} = Enum.split(digits, 7)

      case 11 - rem(weighted(body, [8, 7, 6, 5, 4, 3, 2]), 11) do
        11 -> false
        10 -> check == 0
        r -> check == r
      end
    end)
  end

  # Slovakia (BMF): ten digits, the first not 0 and the third one of 2, 3,
  # 4, 7, 8 or 9; the number is divisible by 11.
  defp country?("SK", <<first, _, third, _::binary-size(7)>> = number)
       when first != ?0 and third in ~c"234789" do
    on_digits(number, &(rem(Integer.undigits(&1), 11) == 0))
  end

  # Croatia: the OIB, eleven digits, the last an ISO 7064 MOD 11,10 check
  # digit (Pravilnik o osobnom identifikacijskom broju, NN 1/2009, art. 3).
  defp country?("HR", <<_::binary-size(11)>> = number) do
    on_digits(number, fn digits ->
      {body, [check]} = Enum.split(digits, 10)
      Validators.iso7064_mod11_10(body) == check
    end)
  end

  # Czech Republic (zákon č. 280/2009 Sb. § 130): the IČO of a legal entity,
  # eight digits, or the birth number of a person, nine or ten.
  defp country?("CZ", <<_::binary-size(8)>> = number), do: on_digits(number, &ico_check?/1)

  defp country?("CZ", number) when byte_size(number) in 9..10,
    do: on_digits(number, &birth_number_cz?/1)

  # Spain: a person's NIF is the DNI number and its letter
  # (RD 1065/2007 art. 19.1); a foreigner's is the NIE. Legal entities, and
  # the K, L and M forms, are checked for their structure only.
  defp country?("ES", <<first, middle::binary-size(7), last>> = number) do
    cond do
      first in ?0..?9 -> Validators.valid?(:dni_es, number)
      first in ~c"XYZ" -> Validators.valid?(:nie_es, number)
      first in @es_entity_letters -> numeric(middle) != nil and alphanumeric?(<<last>>)
      first in ~c"KLM" -> alphanumeric?(middle) and last in ?A..?Z
      true -> false
    end
  end

  # France: a two-character key, whose computation is not published, and
  # the SIREN, nine digits with a Luhn check digit (INSEE).
  defp country?("FR", <<k1, k2, siren::binary-size(9)>>) do
    alphanumeric?(<<k1, k2>>) and on_digits(siren, &Validators.luhn?/1)
  end

  # Structure only: no check is published for these.
  # Bulgaria: nine digits (an EIK) or ten (a person's number).
  defp country?("BG", number) when byte_size(number) in 9..10, do: numeric(number) != nil

  # Cyprus: eight digits and a letter.
  defp country?("CY", <<body::binary-size(8), letter>>) when letter in ?A..?Z,
    do: numeric(body) != nil

  # Greece: nine digits.
  defp country?("EL", <<_::binary-size(9)>> = number), do: numeric(number) != nil

  # Latvia: eleven digits.
  defp country?("LV", <<_::binary-size(11)>> = number), do: numeric(number) != nil

  # Malta: eight digits.
  defp country?("MT", <<_::binary-size(8)>> = number), do: numeric(number) != nil

  # Romania: two to ten digits, no leading zero.
  defp country?("RO", <<first, _::binary>> = number)
       when first != ?0 and byte_size(number) in 2..10,
       do: numeric(number) != nil

  defp country?(_country, _number), do: false

  # A personnummer's date (SKV 704): YYMMDD, the day plus 60 for a
  # samordningsnummer.
  defp se_birth_date?(y1, y2, m1, m2, d1, d2) do
    day = d1 * 10 + d2
    day = if day > 60, do: day - 60, else: day
    Validators.date?(y1 * 10 + y2, m1 * 10 + m2, day)
  end

  # Si = INT(Ci / 5) + (Ci * 2) mod 10: the doubled digit, its two digits
  # added.
  defp s(c), do: div(c, 5) + rem(c * 2, 10)

  # Ireland: the 8, 7, ..., 2 weighted sum of seven digits, plus the extra
  # letter's value, mod 23 gives the check letter.
  defp ie_check?(digits, extra, check) do
    rem(weighted(digits, [8, 7, 6, 5, 4, 3, 2]) + extra, 23) ==
      Enum.find_index(@ie_letters, &(&1 == check))
  end

  # Lithuania: the 1, 2, ..., 9, 1, 2 weighted sum mod 11; when that is 10,
  # the 3, 4, ..., 9, 1, 2, 3, 4 weighted sum mod 11, where 10 gives 0.
  defp lt_check?(digits) do
    {body, [check]} = Enum.split(digits, -1)
    first = [1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2]
    second = [3, 4, 5, 6, 7, 8, 9, 1, 2, 3, 4]

    case rem(weighted(body, first), 11) do
      10 -> rem(rem(weighted(body, second), 11), 10) == check
      r -> r == check
    end
  end

  # Netherlands, modulo 11: C9 is the 9, 8, ..., 2 weighted sum of C1 to C8
  # mod 11, where 10 is never issued; the last two digits are above 00.
  defp nl_mod11?(digits, suffix) do
    {body, [check]} = Enum.split(digits, 8)
    suffix > 0 and rem(weighted(body, [9, 8, 7, 6, 5, 4, 3, 2]), 11) == check
  end

  # Netherlands, modulo 97: NL and the twelve characters, each letter read
  # as 10 to 35, leave 1 mod 97; the last two digits are 02 to 98.
  defp nl_mod97?(number, suffix) do
    value = for <<c <- "NL" <> number>>, into: "", do: nl_char(c)
    suffix in 2..98 and rem(String.to_integer(value), 97) == 1
  end

  defp nl_char(c) when c in ?A..?Z, do: Integer.to_string(c - ?A + 10)
  defp nl_char(c), do: <<c>>

  defp pt_check?(digits) do
    {body, [check]} = Enum.split(digits, 8)

    case 11 - rem(weighted(body, [9, 8, 7, 6, 5, 4, 3, 2]), 11) do
      r when r in [10, 11] -> check == 0
      r -> check == r
    end
  end

  # IČO (Czech Statistical Office, "Připojení AIS editorů ROS k systému
  # základních registrů", 2.1.5): the seven digits weighted 8 down to 2, the
  # sum subtracted from the next higher multiple of 11. A difference of 11
  # gives 1, of 10 gives 0.
  defp ico_check?(digits) do
    {body, [check]} = Enum.split(digits, 7)

    case 11 - rem(weighted(body, [8, 7, 6, 5, 4, 3, 2]), 11) do
      11 -> check == 1
      10 -> check == 0
      r -> check == r
    end
  end

  # Birth number (zákon č. 133/2000 Sb. § 13): YYMMDD and an ending, the
  # month plus 50 for women. Nine digits were issued to people born before
  # 1954 and are not divisible by 11, so only the date is checked. Ten
  # digits are divisible by 11; since 2004 the month can also be plus 20 for
  # men and plus 70 for women.
  defp birth_number_cz?([y1, y2, m1, m2, d1, d2, _, _, _]) do
    year = y1 * 10 + y2
    month = m1 * 10 + m2
    month = if month > 50, do: month - 50, else: month
    year <= 53 and Validators.date?(1900 + year, month, d1 * 10 + d2)
  end

  defp birth_number_cz?([y1, y2, m1, m2, d1, d2, _, _, _, _] = digits) do
    year = y1 * 10 + y2
    century = if year >= 54, do: 1900, else: 2000

    rem(Integer.undigits(digits), 11) == 0 and
      Validators.date?(century + year, cz_month(m1 * 10 + m2), d1 * 10 + d2)
  end

  defp cz_month(month) when month in 21..32, do: month - 20
  defp cz_month(month) when month in 51..62, do: month - 50
  defp cz_month(month) when month in 71..82, do: month - 70
  defp cz_month(month), do: month

  defp alphanumeric?(binary) do
    binary |> :binary.bin_to_list() |> Enum.all?(&(&1 in ?0..?9 or &1 in ?A..?Z))
  end

  # Runs `fun` on the digits of a binary that holds only digits; false
  # otherwise.
  defp on_digits(binary, fun) do
    case numeric(binary) do
      nil -> false
      digits -> fun.(digits)
    end
  end

  defp numeric(binary) do
    digits = Validators.digits(binary)
    if length(digits) == byte_size(binary), do: digits
  end

  defp weighted(digits, weights) do
    digits |> Enum.zip(weights) |> Enum.reduce(0, fn {d, w}, acc -> acc + d * w end)
  end
end
