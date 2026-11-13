defmodule PiiCatalog.LimitsTest do
  @moduledoc """
  The claims in the README's "Precision" section, as tests. When one of
  these fails, the README is wrong: fix the README with the code.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PiiCatalog.Validators

  defp found(text),
    do: PiiCatalog.compile() |> PiiCatalog.find(text) |> Enum.map(&{&1.name, &1.value})

  describe "what a check digit proves" do
    property "Luhn: for any body, exactly one of the ten last digits passes" do
      check all(body <- list_of(integer(0..9), min_length: 12, max_length: 18)) do
        assert Enum.count(0..9, &Validators.luhn?(body ++ [&1])) == 1
      end
    end

    property "Luhn: every swap of two adjacent digits is caught, except 09 and 90" do
      check all(
              body <- list_of(integer(0..9), length: 15),
              position <- integer(0..14)
            ) do
        number = body ++ [Enum.find(0..9, &Validators.luhn?(body ++ [&1]))]
        a = Enum.at(number, position)
        b = Enum.at(number, position + 1)
        swapped = number |> List.replace_at(position, b) |> List.replace_at(position + 1, a)

        if a != b and Enum.sort([a, b]) != [0, 9] do
          refute Validators.luhn?(swapped)
        end
      end
    end

    test "Luhn: a swap of 0 and 9 is not caught" do
      assert Validators.luhn?(Validators.digits("101709"))
      assert Validators.luhn?(Validators.digits("101790"))
    end
  end

  describe "check digits for some values, structure for others" do
    test "VAT numbers of the member states with no check here pass on their format" do
      for vat <- ~w(BG000000000 CY00000000A EL000000000 LV00000000000 MT00000000 RO100000) do
        assert found("VAT #{vat}") == [vat_eu: vat], vat
      end

      # A Spanish legal entity's control character and the French key.
      assert found("VAT ESH11562854") == [vat_eu: "ESH11562854"]
      assert found("VAT FRZZ000666255") == [vat_eu: "FRZZ000666255"]
      refute Keyword.has_key?(found("VAT FRZZ000666256"), :vat_eu)
    end

    test "a Czech nine-digit VAT number is checked by its date only" do
      assert found("VAT CZ370206443") == [vat_eu: "CZ370206443"]
      assert found("VAT CZ370206440") == [vat_eu: "CZ370206440"]
      assert found("VAT CZ371306443") == []
    end
  end

  describe "structure only" do
    test "the kennitala's check digit is not checked" do
      # 150385-2039 fails the kennitala check digit used until 2026.
      assert found("Kennitala 150385-2039") == [kennitala_is: "150385-2039"]
    end

    test "CPR, kennitala and isikukood are matched only after a word naming them" do
      refute Keyword.has_key?(found("Reference 070761-4285"), :cpr_dk)
      refute Keyword.has_key?(found("Reference 150385-2029"), :kennitala_is)
      refute Keyword.has_key?(found("Reference 38507300124"), :isikukood_ee)
    end

    test "SSN area 900 to 999 only with an ITIN group" do
      assert found("SSN 912-70-1234") == [ssn: "912-70-1234"]
      assert found("SSN 900-12-3456") == []
    end
  end

  describe "a context keyword is required" do
    @keyword_values [
      cpr_dk: {"CPR", "070761-4285"},
      kennitala_is: {"Kennitala", "150385-2029"},
      svnr_at: {"SVNR", "2748 140379"},
      isikukood_ee: {"Isikukood", "38507300124"},
      bsn_nl: {"BSN", "111222333"},
      nif_pt: {"NIF", "123456789"},
      nino_gb: {"NINO", "AB 12 34 56 C"},
      nhs_gb: {"NHS", "943 476 5919"}
    ]

    test "the keyword patterns are the ones listed here and date_of_birth" do
      keyword_patterns = for p <- PiiCatalog.patterns(), p.keyword_required, do: p.name

      assert Enum.sort(keyword_patterns) ==
               Enum.sort([:date_of_birth | Keyword.keys(@keyword_values)])
    end

    test "between the word and the value: blanks and at most one : or #" do
      for {name, {keyword, value}} <- @keyword_values do
        for between <- [" ", "", " \t ", ":", " : ", "\t#\t", "# "] do
          assert Keyword.get_values(found(keyword <> between <> value), name) == [value],
                 "#{name}: #{inspect(between)}"
        end

        for between <- [" :: ", ": #", " - ", " x ", "\n", " ; ", "\u00A0"] do
          assert Keyword.get_values(found(keyword <> between <> value), name) == [],
                 "#{name}: #{inspect(between)}"
        end
      end
    end

    test "a . for bsn_nl and nif_pt, and as part of the word" do
      for {name, {keyword, value}} <- @keyword_values do
        expected = if name in [:bsn_nl, :nif_pt], do: [value], else: []

        assert Keyword.get_values(found(keyword <> " . " <> value), name) == expected, "#{name}"

        # Kennitala. as kt., and NINO. and SVNR. read as NI no. and SV-Nr.
        expected =
          if name in [:bsn_nl, :nif_pt, :kennitala_is, :nino_gb, :svnr_at], do: [value], else: []

        assert Keyword.get_values(found(keyword <> ". " <> value), name) == expected, "#{name}"
      end
    end

    test "for date_of_birth, any run of spaces, tabs and colons" do
      assert found("DOB :: \t: 12/04/1985") == [date_of_birth: "DOB :: \t: 12/04/1985"]
      assert found("DOB - 12/04/1985") == []
    end
  end

  describe "known false positives" do
    test "a number with a card prefix that passes Luhn is a card number" do
      assert found("Order 4000000000000002") == [credit_card: "4000000000000002"]
    end

    test "a US phone number is any ten digits whose first and fourth digits are 2 to 9" do
      passing =
        for first <- 0..9,
            fourth <- 0..9,
            Validators.valid?(:nanp_phone, "#{first}00#{fourth}000000"),
            do: {first, fourth}

      assert length(passing) == 64

      # Unix timestamps in seconds start with 1 until May 2033.
      refute Validators.valid?(:nanp_phone, "1999999999")
      assert %DateTime{year: 2033, month: 5} = DateTime.from_unix!(2_000_000_000)
      assert found("Order 4155550123 shipped") == [phone_us: "4155550123"]
    end

    test "one value can match several patterns" do
      assert found("NHS number 943 476 5919") == [
               phone_us: "943 476 5919",
               nhs_gb: "943 476 5919"
             ]

      assert [phone_us: "811218-9876", personnummer_se: "811218-9876"] =
               found("811218-9876")
    end

    test "a date of birth is any date-shaped value after its keyword" do
      assert found("DOB: 99/99/9999") == [date_of_birth: "DOB: 99/99/9999"]
      assert found("Born on 01/01/2090") == [date_of_birth: "Born on 01/01/2090"]
    end

    test "four numbers from 0 to 255 are an IP address, a version number too" do
      assert found("version 1.2.3.4") == [ip_address: "1.2.3.4"]
    end

    test "the first four parts of an OID are an IP address" do
      assert found("OID 1.3.6.1.4.1.311") == [ip_address: "1.3.6.1"]
    end

    test "a + and seven to fifteen digits is an international phone number" do
      assert found("Score +1234567") == [phone_intl: "+1234567"]
    end

    test "about 1 in 110 random eleven-digit numbers passes an eleven-digit national ID check" do
      :rand.seed(:exsss, {1, 2, 3})

      scanner = PiiCatalog.compile([:pesel_pl, :rrn_be, :steuer_id_de, :fodselsnummer_no])

      runs = 50_000

      passed =
        Enum.count(1..runs, fn _ ->
          number = for _ <- 1..11, into: "", do: <<?0 + :rand.uniform(10) - 1>>
          PiiCatalog.find(scanner, number) != []
        end)

      assert passed / runs > 0.0075 and passed / runs < 0.011, "#{passed} of #{runs}"
    end
  end

  describe "known false negatives" do
    test "card numbers outside the ranges and groupings the regex knows" do
      for text <- [
            # American Express written 4-6-5.
            "3782 822463 10005",
            # Mastercard's 2-series, JCB, Diners Club, UnionPay.
            "2221000000000009",
            "3530111333300000",
            "30569309025904",
            "6200000000000005",
            # Discover outside 6011 and 65.
            "6445644564456445",
            # Dots as separators, and 19 digits.
            "4111.1111.1111.1111",
            "4111111111111111110"
          ] do
        assert found("Card #{text}") == [], text
      end
    end

    test "values written with separators the regexes do not allow" do
      for text <- [
            "Phone (212) 555-0123",
            "Phone +46 70 174 06 05",
            "Phone 0046701740605",
            "SSN 123 45 6789",
            "SSN 123456789",
            "IBAN DE89-3704-0044-0532-0130-00",
            "DNI 12.345.678-Z",
            "AHV 756 1234 5678 97",
            "Steuer-ID 86/095/742/719",
            "BSN: 111-222-333"
          ] do
        assert found(text) == [], text
      end
    end

    test "a value split across lines, and a ten-digit personnummer without - or +" do
      assert found("Card 4111 1111\n1111 1111") == []
      assert found("Call\n212\n555\n0123") == []
      assert found("DOB:\n12/04/1985") == []
      refute Enum.any?(found("Personnummer 8112189876"), &match?({:personnummer_se, _}, &1))
      assert found("Personnummer 198112189876") == [personnummer_se: "198112189876"]
    end

    test "lowercase where the identifier is written in capitals" do
      for text <- ["de89370400440532013000", "131052-308t", "rssmra85t10a562s", "12345678z"] do
        assert found("Value #{text}") == [], text
      end
    end

    test "a value directly after an ASCII letter, digit or underscore" do
      assert found("SSN123-45-6789") == []
      assert found("SSN 123-45-6789") == [ssn: "123-45-6789"]
      assert found("id+12345678") == []
      assert found("id +12345678") == [phone_intl: "+12345678"]
    end

    test "dates of birth not written as digits with / - or ." do
      for text <- [
            "DOB: 12 April 1985",
            "DOB: 1985-04-12",
            "Geburtsdatum: 12.04.1985",
            "D.O.B. 12/04/1985"
          ] do
        assert found(text) == [], text
      end
    end

    test "keyword patterns with the keyword on another line" do
      assert found("NHS\n943 476 5919") == [phone_us: "943 476 5919"]
      assert found("BSN\n111222333") == []
    end

    test "IPv6, IBANs outside SEPA and digits outside ASCII" do
      assert found("Host 2001:db8::1") == []
      assert found("IBAN SA0380000000608010167519") == []
      assert found("Card ４１１１１１１１１１１１１１１１") == []
    end

    test "an email address longer than RFC 5321 allows is not found whole" do
      assert found("Mail #{String.duplicate("a", 64)}@example.com") ==
               [email: String.duplicate("a", 64) <> "@example.com"]

      assert found("Mail #{String.duplicate("a", 65)}@example.com") == []
      assert found("Mail x@#{String.duplicate("a", 251)}.com") == []
    end

    test "an email address in a script written in three bytes of UTF-8" do
      # The match starts at the ASCII part: 田中 is not taken into it.
      assert found("Mail 田中taro@example.jp") == [email: "taro@example.jp"]
      assert found("Mail taro@例え.jp") == []
    end

    test "a no-break space between a keyword or the groups of a value" do
      refute Keyword.has_key?(found("NHS number\u00A0943 476 5919"), :nhs_gb)
      assert found("Card 4111\u00A01111\u00A01111\u00A01111") == []
      assert found("Steuer-ID 86\u202F095\u202F742\u202F719") == []
    end
  end
end
