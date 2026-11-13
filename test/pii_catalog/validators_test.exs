defmodule PiiCatalog.ValidatorsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PiiCatalog.Test.Vectors
  alias PiiCatalog.Validators
  alias PiiCatalog.Validators.{NationalIds, VatEu}

  doctest VatEu
  doctest NationalIds

  # The digit that makes `digits` pass Luhn when appended.
  defp luhn_check_digit(digits) do
    Enum.find(0..9, &Validators.luhn?(digits ++ [&1]))
  end

  describe "luhn?/1" do
    test "accepts the networks' test card numbers" do
      for number <- ["4111111111111111", "5500000000000004", "378282246310005"] do
        assert Validators.valid?(:luhn, number)
      end
    end

    test "ignores separators" do
      assert Validators.valid?(:luhn, "4111 1111 1111 1111")
      assert Validators.valid?(:luhn, "5500-0000-0000-0004")
    end

    test "refuses a wrong check digit, and nothing at all" do
      refute Validators.valid?(:luhn, "4111111111111112")
      refute Validators.valid?(:luhn, "")
    end

    property "catches every single-digit error" do
      check all(
              body <- list_of(integer(0..9), min_length: 12, max_length: 18),
              position <- integer(0..(length(body) - 1)),
              shift <- integer(1..9)
            ) do
        number = body ++ [luhn_check_digit(body)]
        assert Validators.luhn?(number)

        changed = List.update_at(number, position, &rem(&1 + shift, 10))
        refute Validators.luhn?(changed)
      end
    end
  end

  describe "ip_octets" do
    test "accepts 0 to 255 in each place" do
      for ip <- ["0.0.0.0", "255.255.255.255", "192.0.2.10", "010.001.002.003"] do
        assert Validators.valid?(:ip_octets, ip)
      end
    end

    test "refuses an octet over 255" do
      for ip <- ["256.1.1.1", "1.1.1.256", "999.999.999.999"] do
        refute Validators.valid?(:ip_octets, ip)
      end
    end
  end

  describe "nanp_phone" do
    test "accepts an area code and exchange that start with 2-9" do
      for phone <- ["212-555-0123", "2125550123", "555.234.5678", "900 200 0000"] do
        assert Validators.valid?(:nanp_phone, phone)
      end
    end

    test "refuses an area code or exchange that starts with 0 or 1" do
      for phone <- ["012-555-0123", "112-555-0123", "212-055-0123", "212-155-0123", "1760781234"] do
        refute Validators.valid?(:nanp_phone, phone)
      end
    end
  end

  describe "ssn_structure" do
    test "accepts issued SSNs and ITINs" do
      for ssn <- ["123-45-6789", "078-05-1120", "912-70-1234"] do
        assert Validators.valid?(:ssn_structure, ssn)
      end
    end

    test "accepts area 9xx only with an ITIN group" do
      assert Validators.valid?(:ssn_structure, "987-94-4320")
      refute Validators.valid?(:ssn_structure, "987-93-4320")
      refute Validators.valid?(:ssn_structure, "900-12-3456")
    end

    test "refuses numbers that are never issued" do
      for ssn <- ["000-12-3456", "666-12-3456", "123-00-4567", "123-45-0000"] do
        refute Validators.valid?(:ssn_structure, ssn)
      end
    end
  end

  describe "date?/3" do
    test "accepts real dates and 29 February in a leap year" do
      assert Validators.date?(1985, 5, 1)
      assert Validators.date?(4, 2, 29)
      assert Validators.date?(2000, 2, 29)
    end

    test "refuses dates that do not exist" do
      refute Validators.date?(1985, 13, 1)
      refute Validators.date?(1985, 4, 31)
      refute Validators.date?(1, 2, 29)
      refute Validators.date?(1985, 0, 10)
    end
  end

  describe "mod11_check_digit/2" do
    test "maps 11 to 0 and 10 to no digit" do
      # 1*3 + 1*2 = 5, 11 - 5 = 6
      assert Validators.mod11_check_digit([1, 1], [3, 2]) == 6
      # 11 - 0 = 11 -> 0
      assert Validators.mod11_check_digit([0, 0], [3, 2]) == 0
      # 1*1 = 1, 11 - 1 = 10 -> none
      assert Validators.mod11_check_digit([1], [1]) == nil
    end
  end

  describe "iban" do
    test "accepts published examples, spaced or compact" do
      for iban <- ["DE89 3704 0044 0532 0130 00", "GB82WEST12345698765432", "NO9386011117947"] do
        assert Validators.valid?(:iban, iban)
      end
    end

    test "refuses wrong check digits, a wrong length and a country outside SEPA" do
      for iban <- [
            "DE88 3704 0044 0532 0130 00",
            "DE89 3704 0044 0532 0130",
            "US64SVBKUS6S3300967386",
            # The Faroe Islands and Greenland are not in the EPC's SEPA list.
            "FO6264600001631634",
            "GL8964710001000206"
          ] do
        refute Validators.valid?(:iban, iban)
      end
    end

    property "catches every single-digit change in the account number" do
      check all(position <- integer(4..21), shift <- integer(1..9)) do
        iban = "DE89370400440532013000"
        <<head::binary-size(position), d, tail::binary>> = iban
        changed = <<head::binary, ?0 + rem(d - ?0 + shift, 10), tail::binary>>
        refute Validators.valid?(:iban, changed)
      end
    end
  end

  describe "personnummer_se" do
    test "accepts the short and long forms and samordningsnummer" do
      for pnr <- ["811218-9876", "19811218-9876", "198112189876", "640823+3234", "811278-9873"] do
        assert Validators.valid?(:personnummer_se, pnr)
      end
    end

    test "refuses a wrong check digit, an impossible date or century" do
      for pnr <- ["811218-9875", "811318-9876", "811292-9876", "18811218-9876", "811218-0008"] do
        refute Validators.valid?(:personnummer_se, pnr)
      end
    end
  end

  describe "fodselsnummer_no" do
    test "accepts fødselsnummer and D-nummer" do
      for fnr <- ["01058512326", "15076500565", "41058512581"] do
        assert Validators.valid?(:fodselsnummer_no, fnr)
      end
    end

    test "refuses the month plus 40, an H-nummer" do
      refute Validators.valid?(:fodselsnummer_no, "01458510055")
    end

    test "takes 40 off the day only for a D-nummer, whose first digit is 4 to 7" do
      # Day 81 with valid check digits: 41 would be a D-nummer for day 1.
      refute Validators.valid?(:fodselsnummer_no, "81018500027")
      assert Validators.valid?(:fodselsnummer_no, "41058512581")
    end

    property "catches every single-digit change" do
      check all(position <- integer(0..10), shift <- integer(1..9)) do
        digits = Validators.digits("15076500565")
        changed = List.update_at(digits, position, &rem(&1 + shift, 10))
        refute Validators.valid?(:fodselsnummer_no, Enum.join(changed))
      end
    end
  end

  describe "hetu_fi" do
    test "accepts each century sign" do
      for hetu <- ["131052-308T", "010594Y803U", "010105A123P"] do
        assert Validators.valid?(:hetu_fi, hetu)
      end
    end

    test "refuses a wrong check character, an unknown sign and individual numbers outside 002-899" do
      for hetu <- ["131052-308K", "131052G308T", "131052-001W", "131052-9085", "010594Y9032"] do
        refute Validators.valid?(:hetu_fi, hetu)
      end
    end
  end

  describe "cpr_dk" do
    test "checks the date only" do
      assert Validators.valid?(:cpr_dk, "070761-4285")
      assert Validators.valid?(:cpr_dk, "070761-0000")
      refute Validators.valid?(:cpr_dk, "320190-1234")
    end
  end

  describe "kennitala_is" do
    test "accepts each century digit" do
      for kt <- ["150385-2029", "021104-2050", "120160-3389"] do
        assert Validators.valid?(:kennitala_is, kt)
      end
    end

    test "does not check the ninth digit: numbers issued since 18 February 2026 have no check digit" do
      # Þjóðskrá's test numbers for numbers without a check digit.
      for kt <- ["281191-3049", "020980-4299", "040404-4400", "100514-8220"] do
        assert Validators.valid?(:kennitala_is, kt)
      end
    end

    test "refuses an unknown century and a company number" do
      for kt <- ["150385-2027", "550385-2019", "320385-2029"] do
        refute Validators.valid?(:kennitala_is, kt)
      end
    end
  end

  describe "steuer_id_de" do
    test "accepts published test numbers and a digit three times apart" do
      for id <- ["86095742719", "47036892816", "57549285017", "11213456783"] do
        assert Validators.valid?(:steuer_id_de, id)
      end
    end

    test "refuses a leading 0, every digit once, and a digit three times in a row" do
      for id <- ["06095742719", "12345678903", "47770382916"] do
        refute Validators.valid?(:steuer_id_de, id)
      end
    end

    property "the check digit catches every single-digit change" do
      check all(position <- integer(0..10), shift <- integer(1..9)) do
        digits = Validators.digits("86095742719")
        changed = List.update_at(digits, position, &rem(&1 + shift, 10))
        refute Validators.valid?(:steuer_id_de, Enum.join(changed))
      end
    end
  end

  describe "bsn_nl" do
    test "applies the 11-proef" do
      assert Validators.valid?(:bsn_nl, "111222333")
      assert Validators.valid?(:bsn_nl, "1234.56.782")
      refute Validators.valid?(:bsn_nl, "111222334")
      refute Validators.valid?(:bsn_nl, "000000000")
    end
  end

  describe "nir_fr" do
    test "accepts valid keys, Corsican departments and spacing" do
      for nir <- [
            "284127645108993",
            "2 84 12 76 451 089 93",
            "290062A12345645",
            "169032B12300403"
          ] do
        assert Validators.valid?(:nir_fr, nir)
      end
    end

    test "refuses a wrong key, an impossible month, commune or order number 000 and sex 7" do
      for nir <- [
            "284127645108994",
            "284137645108912",
            "284127645100085",
            "284127600008943",
            "784127645108937"
          ] do
        refute Validators.valid?(:nir_fr, nir)
      end
    end
  end

  describe "dni_es and nie_es" do
    test "check the letter" do
      assert Validators.valid?(:dni_es, "12345678Z")
      assert Validators.valid?(:dni_es, "12345678-Z")
      refute Validators.valid?(:dni_es, "12345678A")
      assert Validators.valid?(:nie_es, "X1234567L")
      assert Validators.valid?(:nie_es, "Z1234567R")
      refute Validators.valid?(:nie_es, "Y1234567L")
    end

    property "the DNI letter catches every single-digit change" do
      check all(position <- integer(0..7), shift <- integer(1..9)) do
        digits = Validators.digits("12345678")
        changed = digits |> List.update_at(position, &rem(&1 + shift, 10)) |> Enum.join()
        refute Validators.valid?(:dni_es, changed <> "Z")
      end
    end
  end

  describe "codice_fiscale_it" do
    test "accepts men's and women's codes and omocodia" do
      for cf <- ["RSSMRA85T10A562S", "RSSMRA85T50A562W", "RSSMRA85T10A56NH"] do
        assert Validators.valid?(:codice_fiscale_it, cf)
      end
    end

    test "refuses a wrong check character and impossible days" do
      # 30 February, 35, and 81 and 99, past the women's range (41-71).
      for cf <- [
            "RSSMRA85T10A562T",
            "RSSMRA85B30A562G",
            "RSSMRA85T35A562G",
            "RSSMRA85T81A562Y",
            "RSSMRA85T99A562U"
          ] do
        refute Validators.valid?(:codice_fiscale_it, cf)
      end
    end
  end

  describe "nino_gb" do
    test "refuses prefixes that are never issued and a suffix after D" do
      assert Validators.valid?(:nino_gb, "AB 12 34 56 C")
      assert Validators.valid?(:nino_gb, "JG103759A")

      for nino <- ["QQ123456C", "AO123456B", "GB123456A", "AB123456E"] do
        refute Validators.valid?(:nino_gb, nino)
      end
    end
  end

  describe "vat_eu" do
    @member_states ~w(AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV MT NL PL PT RO SE SI SK)
    # Member states with no check here (SOURCES.md says why for each): their
    # numbers are checked for their format only.
    @format_only ~w(BG CY EL LV MT RO)

    test "the corpus has a valid number for every member state, and a near miss for each with a check" do
      {%{valid: valid, invalid: invalid}, _} =
        Code.eval_file(Path.expand("../vectors/vat_eu.exs", __DIR__))

      prefixes = fn values ->
        values |> Enum.map(&binary_part(&1, 0, 2)) |> Enum.uniq() |> Enum.sort()
      end

      assert VatEu.member_states() == @member_states
      assert prefixes.(valid) == @member_states
      assert prefixes.(invalid) == @member_states -- @format_only

      for vat <- valid, do: assert(Validators.valid?(:vat_eu, vat), vat)
      for vat <- invalid, do: refute(Validators.valid?(:vat_eu, vat), vat)
    end

    test "the sample numbers in each country's published rules pass" do
      # The Austrian Ministry of Finance's Konstruktionsregeln (one sample
      # per country), REGOS for the Croatian OIB, the Czech Statistical
      # Office for the IČO, Poland's TIN sheet and Skatteverket's SKV 704
      # personnummer with the 01 suffix.
      for vat <- ~w(ATU10223006 BE0776091951 DE111111125 DK88146328 EE100207415 FI09853608
                    HU21376414 HU10597190 IE8Z49289F IE3628739L IE3628739UA IT00000010215
                    LT213179412 LT290061371314 LU10000356 NL010000446B01 NL123456789B13
                    PL5260001246 PT502757191 SE556188840401 SI15012557 SK4030000007
                    HR69435151530 CZ47117061 PL2234567895 SE640823323401) do
        assert Validators.valid?(:vat_eu, vat), vat
      end

      # The BMF's own counter-example: the third digit is 0.
      refute Validators.valid?(:vat_eu, "SK5407062531")
    end

    test "accepts the people's numbers some countries issue as VAT numbers" do
      # A Czech birth number, a Bulgarian EGN, a Latvian personal code and a
      # Swedish personnummer.
      for vat <- ["CZ7103192745", "BG7501020018", "LV16117519997", "SE640823323401"] do
        assert Validators.valid?(:vat_eu, vat), vat
      end
    end

    test "a Czech nine-digit birth number is checked by its date only" do
      # Born before 1954: no check digit. 13 is not a month, and 57 is too
      # late for a nine-digit number.
      assert Validators.valid?(:vat_eu, "CZ370206443")
      assert Validators.valid?(:vat_eu, "CZ375206440")
      refute Validators.valid?(:vat_eu, "CZ371306443")
      refute Validators.valid?(:vat_eu, "CZ570206443")
    end

    test "member states without a published check accept any number of their format" do
      for vat <- ~w(BG000000000 BG9999999999 CY00000000A EL000000000 LV00000000000
                    MT00000000 RO10 RO9999999999) do
        assert Validators.valid?(:vat_eu, vat), vat
      end

      refute Validators.valid?(:vat_eu, "RO0123456")
    end

    test "Spanish legal entities and the French key are checked for their format only" do
      assert Validators.valid?(:vat_eu, "ESH11562854")
      assert Validators.valid?(:vat_eu, "ESK1234567A")
      refute Validators.valid?(:vat_eu, "ESI1234567A")
      # Any key, but the SIREN must pass Luhn.
      assert Validators.valid?(:vat_eu, "FR00000666255")
      assert Validators.valid?(:vat_eu, "FRZZ000666255")
      refute Validators.valid?(:vat_eu, "FR00000666256")
    end

    test "refuses an unknown prefix, GB, and the wrong shape for the country" do
      for vat <- ["XX123456789", "GB123456789", "DE12345678", "ATU1234567", "NL123456789X01"] do
        refute Validators.valid?(:vat_eu, vat), vat
      end
    end
  end

  describe "national identity numbers" do
    test "PESEL reads the century from the month, and refuses years no holder has" do
      # 2005-07-30 (month 27); 1885-07-30 (month 87) passes the check digit.
      assert Validators.valid?(:pesel_pl, "05273012345")
      refute Validators.valid?(:pesel_pl, "85873012345")
      # 07700 900126, a UK mobile, reads as 2207-10-09.
      refute Validators.valid?(:pesel_pl, "07700900126")
    end

    test "isikukood refuses a birth date after today" do
      refute Validators.valid?(:isikukood_ee, "63811163647")
    end

    test "a Belgian number born from 2000 is checked with a 2 in front" do
      assert Validators.valid?(:rrn_be, "17070526025")
      refute Validators.valid?(:rrn_be, "17070526026")
    end

    test "a PPS number's ninth character counts A = 1, B = 2 and so on, W as 0" do
      # The Department of Social Protection's examples: 1234567T, 1234567FA.
      assert Validators.valid?(:ppsn_ie, "1234567T")
      assert Validators.valid?(:ppsn_ie, "1234567FA")
      # A generated number: W counts as 0, the same as no ninth character.
      assert Validators.valid?(:ppsn_ie, "5820317V")
      assert Validators.valid?(:ppsn_ie, "5820317VW")
      refute Validators.valid?(:ppsn_ie, "5820317VA")
      refute Validators.valid?(:ppsn_ie, "1234567TA")
      # H marks a Local Property Tax number, not a PPS number: refused
      # even with the check letter it would have if H counted as 8.
      refute Validators.valid?(:ppsn_ie, "5820317BH")
    end

    test "the Austrian check digit is the fourth; the day is 01 to 31, the month any from 01" do
      assert Validators.valid?(:svnr_at, "2748 140379")
      # The Dachverband's example.
      assert Validators.valid?(:svnr_at, "1680250250")
      # 30 February: issued when the real date of birth is unknown.
      assert Validators.valid?(:svnr_at, "1232300285")
      # A month from 13 stands for an unknown date.
      assert Validators.valid?(:svnr_at, "9865242720")
      refute Validators.valid?(:svnr_at, "4123881811")
    end

    test "the AHV number must start with 756" do
      # The Federal Social Insurance Office's worked example.
      assert Validators.valid?(:ahv_ch, "7561234567897")
      refute Validators.valid?(:ahv_ch, "7571234567896")
    end

    test "a Belgian number has a month from 00 to 12 and a serial from 001 to 998" do
      # The Registre national's examples, 42.01.22-051.81 and 40.00.01-001.33.
      assert Validators.valid?(:rrn_be, "42012205181")
      assert Validators.valid?(:rrn_be, "40000100133")
      refute Validators.valid?(:rrn_be, "42212205181")
      refute Validators.valid?(:rrn_be, "42012200002")
    end

    test "the isikukood's check digit: the first weights, then the second, then 0" do
      # 48809166445: the weights 1 to 9 and 1 give 5. 38507300124: they give
      # 10, and 3 to 9 and 1 to 3 give 4. 36001111750: both give 10.
      for {valid, changed} <- [
            {"48809166445", "48809166446"},
            {"38507300124", "38507300125"},
            {"36001111750", "36001111751"}
          ] do
        assert Validators.valid?(:isikukood_ee, valid)
        refute Validators.valid?(:isikukood_ee, changed)
      end

      # 30 February, with its check digit right.
      refute Validators.valid?(:isikukood_ee, "38502300127")
    end
  end

  test "no validator accepts everything" do
    assert Validators.valid?(nil, "anything")
  end

  test "an unknown check raises ArgumentError" do
    assert_raise ArgumentError, ~r/unknown check :nope/, fn -> Validators.valid?(:nope, "1") end
  end

  describe "bytes a check does not allow" do
    test "give false" do
      for {name, value} <- [
            iban: "DE89370400440532013a00",
            iban: "DE89-3704-0044-0532-01",
            codice_fiscale_it: "rssmra85T10A562S",
            codice_fiscale_it: "RSSMRA85T10A562s",
            hetu_fi: "131052-+08T",
            hetu_fi: "131052--08T",
            ip_address: "+1.2.3.4",
            ip_address: "1.-0.3.4",
            dni_es: "+1234567Z",
            nie_es: "X-123456L",
            nir_fr: "1+1 12 76 451 089 93",
            nir_fr: "2 84 12 76 451 089 +3",
            nino_gb: "AB+12345C",
            nino_gb: "a b123456C"
          ] do
        refute PiiCatalog.valid?(name, value), "#{name}: #{inspect(value)}"
      end
    end

    # Values of the right length with one byte replaced are where a check
    # that reads fixed positions would meet a byte it does not expect.
    defp near_valid do
      values =
        for name <- PiiCatalog.names(),
            entry <- Vectors.load(name).valid,
            do: elem(Vectors.with_found(entry), 1)

      gen all(
            value <- member_of(values),
            position <- integer(0..(byte_size(value) - 1)),
            byte <- integer(0..255)
          ) do
        <<head::binary-size(position), _, tail::binary>> = value
        <<head::binary, byte, tail::binary>>
      end
    end

    property "valid?/2 returns a boolean for any binary, and does not raise" do
      value_gen =
        one_of([
          string(:printable, max_length: 40),
          string(Enum.concat([?0..?9, ~c" -.+/"]), max_length: 40),
          string(Enum.concat([?0..?9, ?A..?Z, ?a..?z, ~c" -.+*"]), max_length: 40),
          binary(max_length: 40),
          near_valid()
        ])

      check all(name <- member_of(PiiCatalog.names()), value <- value_gen, max_runs: 3_000) do
        assert is_boolean(PiiCatalog.valid?(name, value))
      end
    end
  end
end
