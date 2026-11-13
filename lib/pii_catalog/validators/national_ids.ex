defmodule PiiCatalog.Validators.NationalIds do
  @moduledoc """
  National identity, tax and social security numbers: the checks for
  `:pesel_pl`, `:rrn_be`, `:ppsn_ie`, `:nif_pt`, `:ahv_ch`, `:svnr_at`,
  `:isikukood_ee` and `:nhs_gb`.

  Each is written from what its issuer, or the issuer's government,
  publishes, except the isikukood's check digit:

    * `:pesel_pl` – Ustawa o ewidencji ludności, art. 15, and the
      Rozporządzenie MSW z dnia 4 stycznia 2012 r. w sprawie nadania lub
      zmiany numeru PESEL, § 7.
    * `:rrn_be` – Registre national, "T.I. 000 – Le numéro
      d'identification" (2016), and the Banque Carrefour de la sécurité
      sociale, "Registres: concepts et règles".
    * `:ppsn_ie` – Department of Social Protection, "Extension of the
      Personal Public Service Number Range", for the structure and the
      ninth character. It does not give the weights or the letter for each
      remainder. Those are taken from the Irish VAT number rules
      Ireland published through the Austrian Ministry of Finance (see
      `PiiCatalog.Validators.VatEu`), and they reproduce both of the
      department's examples.
    * `:nif_pt` – Decreto-Lei n.º 14/2013, art. 4 (nine digits, the last a
      check digit), and the Portuguese VAT rules published through the
      Austrian Ministry of Finance, whose number is the NIF.
    * `:ahv_ch` – the Central Compensation Office (ZAS), "AHV-Nummer", and
      the Federal Social Insurance Office's Wegleitung über
      Versicherungsausweis und individuelles Konto, annex 7.
    * `:svnr_at` – Anfragebeantwortung 4690/AB XXIII. GP (Federal Ministry
      of Health, 2008), and the Dachverband der Sozialversicherungsträger's
      description of the number.
    * `:isikukood_ee` – Siseministri määrus "Isikukoodide moodustamise ja
      andmise kord", § 4, for the structure. The check digit is defined in
      the standard EVS 585, which is sold, not published. The rule checked
      is the one the Estonian Wikipedia article "Isikukood" gives, which
      the Information System Authority's eID overview cites on the
      formula's origin and its weakness.
    * `:nhs_gb` – the NHS Data Dictionary, "NHS NUMBER".

  Two checks also compare the date of birth with today's date
  (`Date.utc_today/0`): `:pesel_pl` and `:isikukood_ee` refuse a date after
  today. `:rrn_be` tries the reading for people born from 2000 only for a
  year that has begun.

  `SOURCES.md` in the repository gives each source's address.
  """

  alias PiiCatalog.Validators

  @ie_letters ~c"WABCDEFGHIJKLMNOPQRSTUV"

  @doc """
  Runs the check for one of the identifiers above on a matched value.
  Separators the pattern allows are dropped first.

      iex> PiiCatalog.Validators.NationalIds.valid?(:nhs_gb, "943 476 5919")
      true
      iex> PiiCatalog.Validators.NationalIds.valid?(:nhs_gb, "943 476 5918")
      false
  """
  @spec valid?(
          :pesel_pl
          | :rrn_be
          | :ppsn_ie
          | :nif_pt
          | :ahv_ch
          | :svnr_at
          | :isikukood_ee
          | :nhs_gb,
          binary()
        ) :: boolean()
  def valid?(:pesel_pl, value), do: pesel_pl?(Validators.digits(value))
  def valid?(:rrn_be, value), do: rrn_be?(Validators.digits(value))
  def valid?(:ppsn_ie, value), do: ppsn_ie?(value)
  def valid?(:nif_pt, value), do: nif_pt?(Validators.digits(value))
  def valid?(:ahv_ch, value), do: ahv_ch?(Validators.digits(value))
  def valid?(:svnr_at, value), do: svnr_at?(Validators.digits(value))
  def valid?(:isikukood_ee, value), do: isikukood_ee?(Validators.digits(value))
  def valid?(:nhs_gb, value), do: nhs_gb?(Validators.digits(value))

  # PESEL: YYMMDD with the century in the month (+80 for 1800-1899, +0 for
  # 1900-1999, +20 for 2000-2099), a four-digit serial and a check digit:
  # 10 minus the last digit of the 1, 3, 7, 9, 1, 3, 7, 9, 1, 3 weighted
  # sum, or 0 when that digit is 0. The 1800s are refused: no holder is
  # alive. A date after today is refused too.
  defp pesel_pl?([y1, y2, m1, m2, d1, d2, _, _, _, _, check] = digits) do
    month = m1 * 10 + m2

    century =
      cond do
        month in 1..12 -> 1900
        month in 21..32 -> 2000
        true -> nil
      end

    century != nil and
      past_date?(century + y1 * 10 + y2, rem(month, 20), d1 * 10 + d2) and
      rem(10 - rem(weighted(Enum.take(digits, 10), [1, 3, 7, 9, 1, 3, 7, 9, 1, 3]), 10), 10) ==
        check
  end

  defp pesel_pl?(_digits), do: false

  # Belgian national register number: YYMMDD (month and day 00 when
  # unknown), a serial from 001 to 998 and two check digits: 97 minus the
  # nine digits mod 97, or, for people born from 2000, 97 minus 2 followed
  # by the nine digits mod 97.
  defp rrn_be?([y1, y2, m1, m2, d1, d2, s1, s2, s3, c1, c2] = digits) do
    nine = digits |> Enum.take(9) |> Integer.undigits()
    check = c1 * 10 + c2
    serial = Integer.undigits([s1, s2, s3])
    born_2000 = 2000 + y1 * 10 + y2

    (m1 * 10 + m2) in 0..12 and (d1 * 10 + d2) in 0..31 and serial in 1..998 and
      (check == 97 - rem(nine, 97) or
         (born_2000 <= Date.utc_today().year and check == 97 - rem(2_000_000_000 + nine, 97)))
  end

  defp rrn_be?(_digits), do: false

  # PPS number: seven digits, a check letter and, optionally, a ninth
  # character. The check letter is the 8, 7, ..., 2 weighted sum of the
  # digits, plus 9 times the value of the ninth character (W or none 0, A 1,
  # B 2 and so on), mod 23, where 0 is W and 1 to 22 are A to V. A ninth
  # character H marks a Local Property Tax number, which Revenue says is not
  # a PPS number.
  defp ppsn_ie?(<<body::binary-size(7), check>>), do: ppsn_check?(body, 0, check)
  defp ppsn_ie?(<<body::binary-size(7), check, ?W>>), do: ppsn_check?(body, 0, check)
  defp ppsn_ie?(<<_::binary-size(7), _check, ?H>>), do: false

  defp ppsn_ie?(<<body::binary-size(7), check, ninth>>) when ninth in ?A..?Z,
    do: ppsn_check?(body, ninth - ?A + 1, check)

  defp ppsn_ie?(_value), do: false

  defp ppsn_check?(body, ninth, check) do
    case Validators.digits(body) do
      digits when length(digits) == 7 ->
        rem(weighted(digits, [8, 7, 6, 5, 4, 3, 2]) + 9 * ninth, 23) ==
          Enum.find_index(@ie_letters, &(&1 == check))

      _ ->
        false
    end
  end

  # Portuguese NIF: nine digits, the first not 0. The last is 11 minus the
  # 9, 8, ..., 2 weighted sum mod 11, where 10 and 11 give 0.
  defp nif_pt?([first | _] = digits) when length(digits) == 9 and first != 0 do
    {body, [check]} = Enum.split(digits, 8)

    case 11 - rem(weighted(body, [9, 8, 7, 6, 5, 4, 3, 2]), 11) do
      r when r in [10, 11] -> check == 0
      r -> check == r
    end
  end

  defp nif_pt?(_digits), do: false

  # AHV number: 756, nine digits and an EAN-13 check digit. From the right,
  # starting with the second to last digit, the digits are weighted 3 and 1
  # in turn; the check digit brings the sum to the next multiple of 10.
  defp ahv_ch?([7, 5, 6 | _] = digits) when length(digits) == 13 do
    {body, [check]} = Enum.split(digits, 12)
    sum = body |> Enum.reverse() |> weighted(Stream.cycle([3, 1]))
    rem(10 - rem(sum, 10), 10) == check
  end

  defp ahv_ch?(_digits), do: false

  # Austrian social security number: a serial from 100 (LLL), the check
  # digit P and the date of birth DDMMYY. P is the 3, 7, 9 (LLL) and 5, 8,
  # 4, 2, 1, 6 (DDMMYY) weighted sum mod 11; a remainder of 10 is never
  # issued. The day is 01 to 31; a month from 13 stands for an unknown or
  # unusable date, so the date is not checked against the calendar.
  defp svnr_at?([l1, _, _, p, d1, d2, m1, m2, _, _] = digits) when l1 > 0 do
    sum = weighted(List.delete_at(digits, 3), [3, 7, 9, 5, 8, 4, 2, 1, 6])
    (d1 * 10 + d2) in 1..31 and m1 * 10 + m2 >= 1 and rem(sum, 11) == p
  end

  defp svnr_at?(_digits), do: false

  # Estonian isikukood: century and sex (3 and 4 for 1900-1999, 5 and 6 for
  # 2000-2099), YYMMDD, a serial and a check digit. 1 and 2 (1800-1899) are
  # refused: no holder is alive. A date after today is refused too.
  defp isikukood_ee?([c, y1, y2, m1, m2, d1, d2, _, _, _, check] = digits) when c in 3..6 do
    century = if c in 3..4, do: 1900, else: 2000

    isikukood_check_digit(Enum.take(digits, 10)) == check and
      past_date?(century + y1 * 10 + y2, m1 * 10 + m2, d1 * 10 + d2)
  end

  defp isikukood_ee?(_digits), do: false

  # The first ten digits weighted 1 to 9 and 1, mod 11. A remainder of 10 is
  # retried with the weights 3 to 9 and 1 to 3, and a second 10 gives 0.
  defp isikukood_check_digit(body) do
    case rem(weighted(body, [1, 2, 3, 4, 5, 6, 7, 8, 9, 1]), 11) do
      10 -> rem(rem(weighted(body, [3, 4, 5, 6, 7, 8, 9, 1, 2, 3]), 11), 10)
      remainder -> remainder
    end
  end

  # NHS number: ten digits. The first nine are weighted 10 down to 2; 11
  # minus the sum mod 11 is the check digit, where 11 gives 0 and 10 is
  # never issued.
  defp nhs_gb?(digits) when length(digits) == 10 do
    {body, [check]} = Enum.split(digits, 9)

    case 11 - rem(weighted(body, [10, 9, 8, 7, 6, 5, 4, 3, 2]), 11) do
      10 -> false
      11 -> check == 0
      r -> check == r
    end
  end

  defp nhs_gb?(_digits), do: false

  defp past_date?(year, month, day) do
    case Date.new(year, month, day) do
      {:ok, date} -> Date.compare(date, Date.utc_today()) != :gt
      {:error, _} -> false
    end
  end

  defp weighted(digits, weights) do
    digits |> Enum.zip(weights) |> Enum.reduce(0, fn {d, w}, acc -> acc + d * w end)
  end
end
