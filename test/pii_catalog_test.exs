defmodule PiiCatalogTest do
  use ExUnit.Case, async: true

  import PiiCatalog.Test.Vectors, only: [load: 1, found: 2, with_found: 1]

  alias PiiCatalog.{Match, Pattern, Validators}

  doctest PiiCatalog

  # Names already released. Callers store them, so none may be renamed or
  # removed.
  @released ~w(email phone_us phone_intl ssn credit_card iban ip_address date_of_birth cpr_dk
               hetu_fi kennitala_is fodselsnummer_no personnummer_se svnr_at rrn_be steuer_id_de
               isikukood_ee dni_es nie_es nir_fr ppsn_ie codice_fiscale_it bsn_nl pesel_pl nif_pt
               vat_eu ahv_ch nino_gb nhs_gb)a

  describe "the catalog" do
    test "has 29 patterns" do
      assert length(PiiCatalog.patterns()) == 29
    end

    test "names are unique and lowercase ASCII" do
      names = PiiCatalog.names()

      assert names == Enum.map(PiiCatalog.patterns(), & &1.name)
      assert names == Enum.uniq(names)

      for name <- names do
        assert Atom.to_string(name) =~ ~r/\A[a-z][a-z0-9_]*\z/, "#{name} is not lowercase ASCII"
      end
    end

    test "every released name is still there" do
      for name <- @released, do: assert(name in PiiCatalog.names(), "#{name} was removed")
    end

    test "a pattern with a check names a validator, and one without has none" do
      for %Pattern{} = p <- PiiCatalog.patterns() do
        case p.confidence do
          :checksum -> assert p.validator, "#{p.name} is :checksum without a validator"
          :format_with_context -> assert p.validator, "#{p.name} has no validator"
          :format -> assert p.validator == nil, "#{p.name} is :format with a validator"
        end
      end
    end

    test "check is nil exactly when there is no validator, and every validator exists" do
      for %Pattern{} = p <- PiiCatalog.patterns() do
        if p.validator do
          assert p.validator in Validators.names(), "#{p.name}: unknown #{p.validator}"
          assert p.check in [:check_digit, :mixed, :structure], "#{p.name} has no check kind"
        else
          assert p.check == nil, "#{p.name} has a check kind and no validator"
        end
      end
    end

    test "every region is a known one, and the first is the group it is listed under" do
      known = Keyword.keys(PiiCatalog.regions())

      for %Pattern{regions: regions} = p <- PiiCatalog.patterns() do
        assert regions != [] and Enum.all?(regions, &(&1 in known)),
               "#{p.name}: #{inspect(regions)}"
      end

      grouped = for {_region, _label, patterns} <- PiiCatalog.groups(), p <- patterns, do: p.name
      assert Enum.sort(grouped) == Enum.sort(PiiCatalog.names())
    end

    test "no regex has the u flag, so every one matches bytewise" do
      for %Pattern{regex: regex} = p <- PiiCatalog.patterns() do
        # Elixir 1.15 gives the flags as a string, later versions as a list.
        unicode? =
          case Regex.opts(regex) do
            opts when is_list(opts) -> :unicode in opts
            opts -> String.contains?(opts, "u")
          end

        refute unicode?, "#{p.name} is compiled with the u flag"
      end
    end

    test "every example is found: whole, or after the word a pattern requires" do
      for %Pattern{} = p <- PiiCatalog.patterns() do
        assert [match] = found(p.name, "Example: #{p.example}."),
               "#{p.name} does not find its own example #{inspect(p.example)}"

        if p.confidence == :format_with_context do
          assert String.ends_with?(p.example, match) and match != p.example
        else
          assert match == p.example
        end
      end
    end

    test "a pattern's required literal is in every value it finds" do
      for %Pattern{requires: literal} = p <- PiiCatalog.patterns(), is_binary(literal) do
        %{valid: valid} = load(p.name)

        for entry <- [p.example | valid] do
          {_text, value} = with_found(entry)

          assert String.contains?(value, literal),
                 "#{p.name} finds #{inspect(value)} without #{literal}"
        end
      end
    end

    test "a pattern's required regexes find every text it matches in" do
      for %Pattern{requires: [_ | _] = probes} = p <- PiiCatalog.patterns() do
        %{valid: valid} = load(p.name)

        for entry <- [p.example | valid] do
          {text, _value} = with_found(entry)
          assert Enum.any?(probes, &Regex.match?(&1, text)), "#{p.name} skips #{inspect(text)}"
        end

        # Caseless and led by one letter, so each probe is a fast scan.
        for probe <- probes,
            do: assert(probe.source =~ ~r/\A\(\?i:[a-z]/, "#{p.name}: #{probe.source}")
      end
    end

    test "a pattern that requires a word does not match the identifier without it" do
      for %Pattern{confidence: :format_with_context} = p <- PiiCatalog.patterns() do
        [value] = found(p.name, p.example)
        word = String.replace_suffix(p.example, value, "")

        assert found(p.name, "Reference: #{value}.") == [], "#{p.name} matched without its word"

        assert found(p.name, "#{word}\n#{value}") == [],
               "#{p.name} matched with its word on the line before"
      end
    end

    test "keyword_required is set exactly where the value alone is not found" do
      for %Pattern{} = p <- PiiCatalog.patterns() do
        %{valid: valid} = load(p.name)

        for entry <- valid do
          {text, value} = with_found(entry)

          if p.keyword_required do
            # Where the keyword is part of the match, the value starts at
            # the first digit.
            value =
              if p.confidence == :format_with_context,
                do: value,
                else: String.replace(text, ~r/\A\D*/, "")

            assert found(p.name, "Reference: #{value}.") == [],
                   "#{p.name} found #{inspect(value)} without a keyword"
          else
            assert found(p.name, "Reference: #{text}.") == [value]
          end
        end
      end
    end
  end

  describe "lookup" do
    test "get/1 builds the same pattern as patterns/0" do
      for %Pattern{name: name} = pattern <- PiiCatalog.patterns() do
        got = PiiCatalog.get(name)
        assert got.name == name
        assert comparable(got) == comparable(pattern)
      end

      assert Enum.map(PiiCatalog.Patterns.all(), & &1.name) == PiiCatalog.Patterns.names()
    end

    test "get/1 and fetch!/1 take an atom or a string" do
      assert %Pattern{name: :iban} = PiiCatalog.get(:iban)
      assert %Pattern{name: :iban} = PiiCatalog.get("iban")
      assert %Pattern{name: :nhs_gb} = PiiCatalog.fetch!("nhs_gb")
      assert PiiCatalog.get(:nope) == nil
      assert PiiCatalog.get("nope") == nil
      assert_raise ArgumentError, fn -> PiiCatalog.fetch!(:nope) end
    end

    test "valid?/2 runs the pattern's validator on the value" do
      assert PiiCatalog.valid?(:credit_card, "4111 1111 1111 1111")
      refute PiiCatalog.valid?("credit_card", "4111 1111 1111 1112")
      assert PiiCatalog.valid?(:nhs_gb, "943 476 5919")
      # No validator: every value is accepted.
      assert PiiCatalog.valid?(:email, "not an email")
      assert_raise ArgumentError, fn -> PiiCatalog.valid?(:nope, "1") end
    end

    test "valid?/2 agrees with find/2 on every valid and invalid vector" do
      for name <- PiiCatalog.names() do
        %{valid: valid, invalid: invalid} = load(name)

        for entry <- valid do
          {_text, value} = with_found(entry)
          assert PiiCatalog.valid?(name, value), "#{name}: #{inspect(value)}"
        end

        for text <- invalid,
            %Match{value: value} <- PiiCatalog.scan(PiiCatalog.compile([name]), text) do
          refute PiiCatalog.valid?(name, value), "#{name}: #{inspect(value)}"
        end
      end
    end
  end

  describe "compile/1, scan/2 and find/2" do
    test "compile/1 takes names, strings and structs, and refuses unknown names" do
      scanner = PiiCatalog.compile([:email, "iban", PiiCatalog.fetch!(:ssn)])

      assert Enum.map(PiiCatalog.Scanner.patterns(scanner), & &1.name) == [:email, :iban, :ssn]
      assert_raise ArgumentError, fn -> PiiCatalog.compile([:email, :emial]) end
    end

    test "compile/1 refuses a pattern whose validator is not a known check" do
      pattern = %{PiiCatalog.fetch!(:ssn) | name: :my_ssn, validator: :ssn_structur}

      assert_raise ArgumentError, ~r/:my_ssn has validator :ssn_structur/, fn ->
        PiiCatalog.compile([pattern])
      end

      assert %PiiCatalog.Scanner{} =
               PiiCatalog.compile([
                 %{pattern | validator: :ssn_structure},
                 %{pattern | name: :x, validator: nil}
               ])
    end

    test "compile/0 holds every pattern, in catalog order" do
      assert Enum.map(PiiCatalog.Scanner.patterns(PiiCatalog.compile()), & &1.name) ==
               PiiCatalog.names()
    end

    test "a repeated pattern is scanned once" do
      scanner = PiiCatalog.compile([:ssn, :ssn])
      assert [%Match{name: :ssn}] = PiiCatalog.find(scanner, "SSN 123-45-6789")
    end

    test "scan/2 reports candidates that find/2 drops" do
      scanner = PiiCatalog.compile([:credit_card])
      text = "4111 1111 1111 1112"

      assert [%Match{name: :credit_card, value: ^text, offset: 0, length: 19}] =
               PiiCatalog.scan(scanner, text)

      assert PiiCatalog.find(scanner, text) == []
    end

    test "a match's value is the bytes at its offset" do
      scanner = PiiCatalog.compile()

      text =
        "Kontakt: anna.berg@example.com, personnummer 811218-9876, IBAN SE45 5000 0000 0583 9825 7466"

      matches = PiiCatalog.find(scanner, text)

      # 811218-9876 is also a valid US phone number: 811 218 9876.
      assert Enum.map(matches, & &1.name) == [:email, :phone_us, :iban, :personnummer_se]

      for %Match{} = m <- matches do
        assert binary_part(text, m.offset, m.length) == m.value
      end
    end

    test "matches are grouped by pattern in the order given" do
      text = "SSN 123-45-6789, mail anna.berg@example.com"

      assert [:ssn, :email] ==
               [:ssn, :email]
               |> PiiCatalog.compile()
               |> PiiCatalog.find(text)
               |> Enum.map(& &1.name)

      assert [:email, :ssn] ==
               [:email, :ssn]
               |> PiiCatalog.compile()
               |> PiiCatalog.find(text)
               |> Enum.map(& &1.name)
    end
  end

  describe "regions" do
    test "every region has a label" do
      for {region, label} <- PiiCatalog.regions() do
        assert PiiCatalog.region_label(region) == label
      end

      assert PiiCatalog.region_label(:se) == "Sweden"
    end

    test "in_region/1 includes every pattern listed under the region" do
      # By name: from OTP 28 a compiled regex is a reference, so two calls
      # give patterns that are not ==.
      for {region, _label, patterns} <- PiiCatalog.groups(), pattern <- patterns do
        assert pattern.name in Enum.map(PiiCatalog.in_region(region), & &1.name)
      end
    end

    test "in_region/1 refuses an unknown region" do
      assert_raise ArgumentError, "unknown region :europe", fn ->
        PiiCatalog.in_region(:europe)
      end

      assert_raise ArgumentError, fn -> PiiCatalog.region_label(:europe) end
    end

    test "eu covers its own countries and the EU identifiers listed elsewhere" do
      eu = PiiCatalog.in_region(:eu)
      outside = for %Pattern{regions: [group | _]} = p <- eu, group != :eu, do: p.name

      assert outside == [:iban, :cpr_dk, :hetu_fi, :personnummer_se]

      scanner = PiiCatalog.compile(eu)

      assert [%Match{name: :personnummer_se}] =
               PiiCatalog.find(scanner, "Personnummer 811218-9876")

      assert [%Match{name: :iban}] =
               PiiCatalog.find(scanner, "IBAN DE89 3704 0044 0532 0130 00")

      assert PiiCatalog.find(scanner, "Fødselsnummer 01058512326") == []
    end

    test "EU VAT numbers, short Romanian ones aside" do
      assert found(:vat_eu, "Invoice to DE452325818") == ["DE452325818"]
      assert found(:vat_eu, "VAT: DE 452325818.") == ["DE 452325818"]

      # RO12307 passes the Romanian check, but RO and five digits is too
      # common in other codes.
      assert found(:vat_eu, "Supplier RO12307") == []
    end

    test "gb is a group of its own" do
      assert {:gb, "United Kingdom", [%Pattern{name: :nino_gb}, %Pattern{name: :nhs_gb}]} =
               List.keyfind(PiiCatalog.groups(), :gb, 0)
    end

    test "ch is a group of its own, outside eu" do
      assert {:ch, "Switzerland", [%Pattern{name: :ahv_ch}]} =
               List.keyfind(PiiCatalog.groups(), :ch, 0)

      refute :ahv_ch in Enum.map(PiiCatalog.in_region(:eu), & &1.name)
    end

    test "a country holds that country's identifiers only" do
      assert Enum.map(PiiCatalog.in_region(:se), & &1.name) == [:personnummer_se]
      assert :hetu_fi in Enum.map(PiiCatalog.in_region(:nordics), & &1.name)
    end
  end

  # A compiled regex holds a reference on OTP 28, so two compilations of the
  # same source are never ==. Compare regexes by source and options.
  defp comparable(%Pattern{} = pattern) do
    %{pattern | regex: source(pattern.regex), requires: requires(pattern.requires)}
  end

  defp requires(probes) when is_list(probes), do: Enum.map(probes, &source/1)
  defp requires(other), do: other

  defp source(%Regex{} = regex), do: {Regex.source(regex), Regex.opts(regex)}
end
