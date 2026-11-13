defmodule PiiCatalog.ScannerTest do
  @moduledoc """
  The scanner scans most patterns in one shared pass. For every pattern it
  must give exactly what `Regex.scan/3` gives on that pattern's own regex.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PiiCatalog.{Match, Pattern, Scanner}

  # Every string in the vector files, as found in real text.
  @snippets PiiCatalog.Test.Vectors.snippets()

  defp one_by_one(patterns, text) do
    Enum.flat_map(patterns, fn %Pattern{name: name, regex: regex} ->
      for [{s, len} | _] <- Regex.scan(regex, text, return: :index),
          do: %Match{name: name, value: binary_part(text, s, len), offset: s, length: len}
    end)
  end

  defp scan(patterns, text), do: patterns |> PiiCatalog.compile() |> PiiCatalog.scan(text)

  defp emails(text),
    do: [:email] |> PiiCatalog.compile() |> PiiCatalog.find(text) |> Enum.map(& &1.value)

  @crafted_shapes [
    :after_at,
    :before_at,
    :many_ats,
    :two_byte_domain,
    :atext_before_at,
    :atext_ats
  ]

  # Text of about 2n bytes that made the old email regex backtrack.
  defp crafted(:after_at, n), do: "@" <> String.duplicate("a.", n)
  defp crafted(:before_at, n), do: String.duplicate("a.", n) <> "@"
  defp crafted(:many_ats, n), do: String.duplicate(String.duplicate("a.", 50) <> "@", div(n, 50))
  defp crafted(:two_byte_domain, n), do: "x@" <> String.duplicate("é.", div(n * 2, 3))
  defp crafted(:atext_before_at, n), do: String.duplicate("a'=&", div(n, 2)) <> "@"

  defp crafted(:atext_ats, n),
    do: String.duplicate(String.duplicate("a!{/", 25) <> "@", div(n, 50))

  # The fastest of three scans for email, in microseconds.
  defp min_time(text) do
    scanner = PiiCatalog.compile([:email])

    1..3
    |> Enum.map(fn _ -> elem(:timer.tc(fn -> PiiCatalog.find(scanner, text) end), 0) end)
    |> Enum.min()
  end

  defp custom(regex) do
    %Pattern{
      name: :custom,
      label: "Custom",
      short_label: "Custom",
      plural: "customs",
      regex: regex,
      regions: [:global],
      confidence: :format,
      example: "12"
    }
  end

  # A keyword each keyword pattern accepts on its own, as in its example.
  @keywords %{
    date_of_birth: "DOB",
    cpr_dk: "CPR",
    kennitala_is: "Kennitala",
    svnr_at: "SVNR",
    isikukood_ee: "Isikukood",
    bsn_nl: "BSN",
    nif_pt: "NIF",
    nino_gb: "NINO",
    nhs_gb: "NHS"
  }

  defp keyword_patterns, do: Enum.filter(PiiCatalog.patterns(), & &1.keyword_required)

  # The regex as it was before its runs of blanks were made possessive.
  defp backtracking(%Regex{} = regex) do
    regex
    |> Regex.source()
    |> String.replace(["[ \\t]*+", "[ \\t]++"], &String.slice(&1, 0..-2//1))
    |> Regex.compile!(Regex.opts(regex))
  end

  # The fastest of three runs of fun, in microseconds.
  defp min_time_of(fun) do
    1..3 |> Enum.map(fn _ -> elem(:timer.tc(fun), 0) end) |> Enum.min()
  end

  # For each keyword pattern, forms of its keywords and of its values.
  @keyword_forms [
    {~w(DOB birthday) ++ ["date of birth", "born on"], ["12/04/1985", "1.2.85"]},
    {["CPR", "cpr", "CPR-nr.", "CPR nummer", "CPR - no", "cpr.nr"],
     ["070761-4285", "0707614285"]},
    {["Kennitala", "kt.", "kennitölu", "KT"], ["150385-2029", "1503852029"]},
    {[
       "SVNR",
       "VSNR",
       "SV-Nr.",
       "SV - Nummer",
       "sv nr",
       "Versicherungsnummer",
       "Sozialversicherungsnummer"
     ], ["2748 140379", "2748140379"]},
    {["Isikukood", "isikukoodi", "isikukoodiga"], ["38507300124"]},
    {["BSN", "BSN-nummer", "bsn - nummer", "burgerservicenummer"],
     ["111222333", "1112.22.333", "111 222 333"]},
    {["NIF", "N.I.F.", "NIPC", "contribuinte", "Contribuinte n.º", "NIF n o", "nif N°"],
     ["123456789", "362 345 767"]},
    {["National Insurance", "national insurance number", "NI number", "NI no.", "NINO", "ni no"],
     ["AB 12 34 56 C", "AB123456C"]},
    {["NHS", "NHS number", "nhs no.", "NHS No"], ["943 476 5919", "9434765919", "943-476-5919"]}
  ]

  # Text with one to three keywords, each followed by blanks, separators
  # and a value: a keyword's words joined by runs of blanks, then runs of
  # blanks and separators, then a value of one of the keyword patterns.
  defp keyword_text_gen do
    blanks = string([?\s, ?\t], max_length: 3)
    noise = string(~c" \t:#.-\nABx", max_length: 3)

    between =
      frequency([
        {4, string([?\s, ?\t], min_length: 1, max_length: 3)},
        {2, member_of([":", "#", "."])},
        {1, member_of(["-", "\n", "x"])}
      ])
      |> list_of(max_length: 4)
      |> map(&Enum.join/1)

    keyword =
      fn words ->
        words = String.split(words, " ")

        map(list_of(blanks, length: length(words) - 1), fn gaps ->
          words |> Enum.zip_with(gaps ++ [""], &(&1 <> &2)) |> Enum.join()
        end)
      end

    one =
      bind(member_of(@keyword_forms), fn {keywords, values} ->
        {noise, bind(member_of(keywords), keyword), between, member_of(values), noise}
        |> map(fn {a, k, b, v, c} -> a <> k <> b <> v <> c end)
      end)

    gen(all(pieces <- list_of(one, min_length: 1, max_length: 3), do: Enum.join(pieces)))
  end

  # Text built from vector values and the characters patterns care about.
  defp text_gen do
    piece =
      one_of([
        member_of(@snippets),
        string(Enum.concat([?0..?9, ?A..?Z, ~c" -.+/:,\n\t"]), max_length: 12),
        string(:alphanumeric, max_length: 8),
        # Runs where matches of one pattern can overlap: 1.2.3.4.5
        string(Enum.concat(?0..?9, ~c".- "), min_length: 5, max_length: 24)
      ])

    gen(all(pieces <- list_of(piece, max_length: 12), do: Enum.join(pieces)))
  end

  # As text_gen/0, with bytes that are not valid UTF-8 and the bytes of
  # non-ASCII letters between the pieces.
  defp bytes_gen do
    piece =
      one_of([
        text_gen(),
        member_of([<<0xFF>>, <<0xC3>>, <<0xA9>>, <<0x80>>, "é", "ê", "Ö", "Ъ", "邮", " "])
      ])

    gen(all(pieces <- list_of(piece, max_length: 8), do: Enum.join(pieces)))
  end

  describe "the shared pass" do
    test "includes the digit- and capital-led patterns, not literals, keywords or flags" do
      shared = for p <- PiiCatalog.patterns(), Scanner.shared?(p), do: p.name

      assert :ssn in shared and :iban in shared and :personnummer_se in shared
      refute :email in shared or :phone_intl in shared or :date_of_birth in shared
      refute :cpr_dk in shared
    end

    test "every shared pattern starts with a digit or capital letter, without backreferences or named groups" do
      shared = Enum.filter(PiiCatalog.patterns(), &Scanner.shared?/1)
      assert length(shared) <= 1000, "capture names are padded to three digits"
      text = Enum.join(@snippets, " \n ")

      for %Pattern{} = p <- shared do
        refute p.regex.source =~ ~r/\\[1-9]|\\k</, "#{p.name} uses a backreference"
        # A named group would shift the :all_names columns the scan reads.
        refute p.regex.source =~ ~r/\(\?P?<[A-Za-z_]|\(\?'/, "#{p.name} has a named group"

        for [{s, len} | _] <- Regex.scan(p.regex, text, return: :index) do
          first = binary_part(text, s, min(len, 1))
          assert first =~ ~r/\A[0-9A-Z]/, "#{p.name} matched starting with #{inspect(first)}"
        end
      end
    end

    property "gives each pattern exactly what its own regex gives" do
      patterns = PiiCatalog.patterns()

      check all(text <- text_gen(), max_runs: 500) do
        assert scan(patterns, text) == one_by_one(patterns, text)
      end
    end

    property "holds for any subset of the patterns" do
      check all(
              patterns <-
                PiiCatalog.patterns()
                |> member_of()
                |> list_of(min_length: 1)
                |> map(&Enum.uniq/1),
              text <- text_gen(),
              max_runs: 300
            ) do
        assert scan(patterns, text) == one_by_one(patterns, text)
      end
    end

    property "holds on text that is not valid UTF-8" do
      patterns = PiiCatalog.patterns()

      check all(text <- bytes_gen(), max_runs: 300) do
        assert scan(patterns, text) == one_by_one(patterns, text)
      end
    end

    test "a match does not start inside the previous one of the same pattern" do
      # 2.3.4.5 is also an address, but starts inside 1.2.3.4.
      text = "hosts 1.2.3.4.5 and 10.0.0.1"

      assert [%Match{offset: 6, length: 7}, %Match{offset: 20}] = scan([:ip_address], text)
      assert scan([:ip_address], text) == one_by_one([PiiCatalog.fetch!(:ip_address)], text)
    end

    test "the same set of patterns in any order compiles to the same shared regex" do
      patterns = Enum.filter(PiiCatalog.patterns(), &Scanner.shared?/1)
      a = PiiCatalog.compile(patterns)
      b = PiiCatalog.compile(Enum.reverse(patterns))

      assert a.shared.source == b.shared.source
      assert a.shared_names == b.shared_names
    end

    test "a scanner with no shared pattern scans each on its own" do
      scanner = PiiCatalog.compile([:email, :phone_intl])
      assert scanner.shared == nil

      assert [%Match{name: :email}, %Match{name: :phone_intl}] =
               PiiCatalog.scan(scanner, "anna.berg@example.com or +46701740605")
    end

    test "a pattern is skipped on text without what it requires" do
      # The email regex cannot match without @, so the scan does not run it.
      assert scan([:email], "no address here") == []
      assert scan([:svnr_at], "Number 2748 140379") == []
      assert [%Match{value: "2748 140379"}] = scan([:svnr_at], "SVNR 2748 140379")
    end
  end

  describe "patterns of your own" do
    test "are never in the shared pass, even when their regex could be" do
      refute Scanner.shared?(custom(~r/(?<![A-Za-z0-9_])\d{4}/))

      # A catalog name with another regex is a pattern of your own too.
      ssn = PiiCatalog.get(:ssn)
      assert Scanner.shared?(ssn)
      refute Scanner.shared?(%{ssn | regex: ~r/(?<![A-Za-z0-9_])\d{3}-\d{2}-\d{4}/})

      scanner = PiiCatalog.compile([custom(~r/(?<![A-Za-z0-9_])\d{4}/), :ssn, :ip_address])
      assert scanner.shared_names == [:ip_address, :ssn]
    end

    test "a regex that is slow only inside the shared pass leaves the catalog patterns alone" do
      # On its own the engine sees that no C follows and stops at once; in
      # the shared pass it tried every way of splitting the Bs, reached its
      # match limit and raised for the catalog patterns too.
      pattern = custom(~r/(?<![A-Za-z0-9_])A(?:B|BB)*C/)
      text = "A" <> String.duplicate("B", 40) <> " and 123-45-6789"

      assert [%Match{name: :ssn, value: "123-45-6789"}] =
               [pattern, :ssn, :ip_address] |> PiiCatalog.compile() |> PiiCatalog.find(text)
    end

    test "an engine error on a pattern of your own names that pattern alone" do
      pattern = custom(~r/(\w+\s?)+$/)
      text = "SSN 123-45-6789 " <> String.duplicate("a", 40) <> "!"

      error =
        assert_raise PiiCatalog.ScanError, fn ->
          [pattern, :ssn, :ip_address] |> PiiCatalog.compile() |> PiiCatalog.find(text)
        end

      assert error.patterns == [:custom]

      # The catalog patterns scan the same text without it.
      assert [%Match{name: :ssn}] =
               [:ssn, :ip_address] |> PiiCatalog.compile() |> PiiCatalog.find(text)
    end
  end

  describe "patterns scanned on their own" do
    test "a regex with a backtracking verb, a named group or a backreference is not shared" do
      for source <- [
            "(?<![A-Za-z0-9_])\\d{4}(*SKIP)(*FAIL)|\\d{3}",
            "(?<![A-Za-z0-9_])(?<year>\\d{4})",
            "(?<![A-Za-z0-9_])(\\d)\\1",
            "(?<![A-Za-z0-9_])(\\d)\\g{1}",
            "(?<![A-Za-z0-9_])(?<d>\\d)\\k<d>"
          ] do
        pattern = custom(Regex.compile!(source))
        refute Scanner.shareable?(pattern), source
      end

      assert Scanner.shareable?(custom(~r/(?<![A-Za-z0-9_])\d{4}/))
    end

    test "a regex with | outside parentheses is not shared" do
      for source <- [
            "(?<![A-Za-z0-9_])ORD\\d{4}|INV\\d{4}",
            "(?<![A-Za-z0-9_])\\d{4}|"
          ] do
        refute Scanner.shareable?(custom(Regex.compile!(source))), source
      end

      # | inside a group, a class, an escape, \\Q...\\E or a comment.
      for source <- [
            "(?<![A-Za-z0-9_])(?:ORD|INV)\\d{4}",
            "(?<![A-Za-z0-9_])[|]\\d{4}",
            "(?<![A-Za-z0-9_])[]|]\\d{4}",
            "(?<![A-Za-z0-9_])[^]|]\\d{4}",
            "(?<![A-Za-z0-9_])[[:digit:]|]\\d{4}",
            "(?<![A-Za-z0-9_])[\\]|]\\d{4}",
            "(?<![A-Za-z0-9_])\\|\\d{4}",
            "(?<![A-Za-z0-9_])\\Q|)\\E\\d{4}",
            "(?<![A-Za-z0-9_])(?#a|b)\\d{4}",
            "(?<![A-Za-z0-9_])\\((?:A|B)\\d{4}"
          ] do
        assert Scanner.shareable?(custom(Regex.compile!(source))), source
      end
    end

    test "a pattern of your own with | outside parentheses gives what its own regex gives" do
      pattern = custom(~r/(?<![A-Za-z0-9_])ORD\d{4}|INV\d{4}/)
      text = "xINV1234 and ORD1234"

      assert [%Match{value: "INV1234"}, %Match{value: "ORD1234"}] = scan([pattern, :ssn], text)
      assert scan([pattern], text) == one_by_one([pattern], text)
    end

    test "a regex that calls a group or has a condition on one is not shared" do
      # Group numbers count from the start of the whole regex, so in the
      # shared pass they would point at other patterns' groups.
      for source <- [
            "(?<![A-Za-z0-9_])(\\d{2})-(?1)",
            "(?<![A-Za-z0-9_])(\\d{2})-(?+1)(\\d)",
            "(?<![A-Za-z0-9_])(\\d{2})-(?-1)",
            "(?<![A-Za-z0-9_])(\\d|-(?R))",
            "(?<![A-Za-z0-9_])(A)?(?(1)B|C)\\d",
            "(?<![A-Za-z0-9_])(A)?(?(+1)B|C)(\\d)",
            "(?<![A-Za-z0-9_])(A)?(?(-1)B|C)\\d",
            "(?<![A-Za-z0-9_])(?(R)A|B)\\d",
            "(?<![A-Za-z0-9_])(?(DEFINE)(\\d{2}))(?1)"
          ] do
        refute Scanner.shareable?(custom(Regex.compile!(source))), source
      end

      # The same characters escaped, in a class, in a comment, inline flags
      # and a condition on an assertion.
      for source <- [
            "(?<![A-Za-z0-9_])\\(?1\\)\\d{4}",
            "(?<![A-Za-z0-9_])[(?1)]\\d{4}",
            "(?<![A-Za-z0-9_])(?#calls (?1 here)\\d{4}",
            "(?<![A-Za-z0-9_])\\Q(?R)\\E\\d{4}",
            "(?<![A-Za-z0-9_])(?-i:A)\\d{4}",
            "(?<![A-Za-z0-9_])(?(?=A)A\\d|\\d{2})"
          ] do
        assert Scanner.shareable?(custom(Regex.compile!(source))), source
      end
    end

    test "a pattern of your own that calls a group gives what its own regex gives" do
      for {regex, text} <- [
            {~r/(?<![A-Za-z0-9_])(\d{2})-(?1)/, "ID 12-34 and 56-78"},
            {~r/(?<![A-Za-z0-9_])(A)?(?(1)B|C)\d/, "AB1 C2"}
          ] do
        pattern = custom(regex)
        expected = regex |> Regex.scan(text) |> Enum.map(&hd/1)

        assert [pattern, :ssn, :ip_address]
               |> PiiCatalog.compile()
               |> PiiCatalog.scan(text)
               |> Enum.map(& &1.value) == expected
      end
    end

    test "a pattern of your own with a verb is scanned on its own, as its own regex gives" do
      pattern = custom(~r/(?<![A-Za-z0-9_])(?:\d{3}(*SKIP)(*FAIL)|\d{2})(?![0-9])/)
      text = "12 345 6789 01"
      scanner = PiiCatalog.compile([pattern, :ssn])

      assert PiiCatalog.scan(scanner, text) == one_by_one([pattern], text)
    end
  end

  describe "keyword patterns and runs of blanks" do
    test "the keyword list covers every keyword pattern" do
      assert Enum.sort(Map.keys(@keywords)) == Enum.sort(Enum.map(keyword_patterns(), & &1.name))
    end

    test "every keyword pattern's runs of blanks are possessive" do
      for %Pattern{name: name, regex: regex} <- keyword_patterns(), name != :date_of_birth do
        refute Regex.source(regex) =~ ~r/\[ \\t\][*+](?![+])/, "#{name} has a backtracking run"
      end

      for probe <- PiiCatalog.fetch!(:svnr_at).requires do
        refute Regex.source(probe) =~ ~r/\[ \\t\][*+](?![+])/
      end
    end

    property "possessive runs of blanks match exactly what backtracking ones did" do
      regexes =
        Enum.map(keyword_patterns(), & &1.regex) ++ PiiCatalog.fetch!(:svnr_at).requires

      check all(text <- keyword_text_gen(), max_runs: 1000) do
        for regex <- regexes do
          assert Regex.scan(regex, text, return: :index) ==
                   Regex.scan(backtracking(regex), text, return: :index),
                 "#{Regex.source(regex)} on #{inspect(text)}"
        end
      end
    end

    test "a value after a keyword followed by thousands of blanks is found" do
      for %Pattern{name: name, regex: regex, example: example} <- keyword_patterns() do
        keyword = Map.fetch!(@keywords, name)
        [%Match{value: value}] = [name] |> PiiCatalog.compile() |> PiiCatalog.find(example)
        text = keyword <> String.duplicate(" ", 5000) <> "x\n" <> example

        assert {:match, _} = :re.run(text, regex.re_pattern, [:global, :report_errors]), "#{name}"

        for scanner <- [PiiCatalog.compile([name]), PiiCatalog.compile()] do
          assert Enum.any?(
                   PiiCatalog.find(scanner, text),
                   &(&1.name == name and &1.value == value)
                 ),
                 "#{name} lost #{inspect(value)}"
        end
      end

      for probe <- PiiCatalog.fetch!(:svnr_at).requires do
        text = "SV" <> String.duplicate(" ", 5000) <> "x"
        assert :re.run(text, probe.re_pattern, [:report_errors]) in [:match, :nomatch]
      end
    end

    # A backtracking run of blanks after a keyword took time quadratic in
    # the number of blanks. The bounds are relative, as for email.
    for {name, keyword} <- [
          date_of_birth: "DOB",
          cpr_dk: "CPR",
          kennitala_is: "Kennitala",
          svnr_at: "SV",
          isikukood_ee: "Isikukood",
          bsn_nl: "BSN",
          nif_pt: "NIF",
          nino_gb: "National Insurance",
          nhs_gb: "NHS"
        ],
        {shape, blanks} <- [spaces: " ", tabs: " \t"] do
      test "scans a keyword and a long run of blanks in linear time: #{name}, #{shape}" do
        keyword = unquote(keyword)
        blanks = unquote(blanks)
        text = fn kb -> keyword <> String.duplicate(blanks, div(kb * 1024, byte_size(blanks))) end
        scanner = PiiCatalog.compile([unquote(name)])

        small = min_time_of(fn -> PiiCatalog.find(scanner, text.(16)) end)
        big = min_time_of(fn -> PiiCatalog.find(scanner, text.(64)) end)

        assert big < 2_000_000, "64 KB took #{big} µs"
        assert big < 10 * small + 20_000, "16 KB took #{small} µs, 64 KB #{big} µs"
      end
    end

    test "every pattern together scans keywords and long runs of blanks in linear time" do
      scanner = PiiCatalog.compile()

      text = fn kb ->
        chunk =
          Enum.map_join(@keywords, fn {_, keyword} -> keyword <> String.duplicate(" ", 200) end)

        String.duplicate(chunk, div(kb * 1024, byte_size(chunk)) + 1)
      end

      small = min_time_of(fn -> PiiCatalog.find(scanner, text.(16)) end)
      big = min_time_of(fn -> PiiCatalog.find(scanner, text.(64)) end)

      assert big < 2_000_000, "64 KB took #{big} µs"
      assert big < 10 * small + 20_000, "16 KB took #{small} µs, 64 KB #{big} µs"
    end
  end

  describe "when the regex engine stops" do
    # The runs of blanks here backtrack, as the catalog's did before.
    @limited ~r/(?<![A-Za-z0-9_])NHS[ \t]*[:#]?[ \t]*\K\d{10}/
    @limited_text "NHS" <> String.duplicate(" ", 5000) <> "x\nNHS 9434765919"

    test "a pattern that reaches the match limit raises ScanError" do
      assert {:error, :match_limit} =
               :re.run(@limited_text, @limited.re_pattern, [:global, :report_errors])

      # Regex.scan/3 reads the error as no match.
      assert Regex.scan(@limited, @limited_text) == []

      scanner = PiiCatalog.compile([custom(@limited), :ssn])

      error = assert_raise PiiCatalog.ScanError, fn -> PiiCatalog.find(scanner, @limited_text) end
      assert error.patterns == [:custom]
      assert error.reason == :match_limit
      assert Exception.message(error) =~ ":custom"
      assert_raise PiiCatalog.ScanError, fn -> PiiCatalog.scan(scanner, @limited_text) end
    end

    test "the same pattern on text that does not reach the limit gives what Regex.scan gives" do
      text = "NHS" <> String.duplicate(" ", 200) <> "x\nNHS 9434765919"
      pattern = custom(@limited)

      assert [%Match{value: "9434765919"}] = scan([pattern], text)
      assert scan([pattern], text) == one_by_one([pattern], text)
    end

    test "a requires regex that reaches the match limit counts as present" do
      pattern = %{custom(~r/ID\d{4}/) | requires: [@limited]}
      text = @limited_text <> " ID1234"
      assert {:error, :match_limit} = :re.run(text, @limited.re_pattern, [:report_errors])

      assert [%Match{value: "ID1234"}] = scan([pattern], text)
    end

    if :erlang.system_info(:otp_release) >= ~c"28" do
      test "a regex exported with the E flag is scanned as Regex.scan scans it" do
        pattern = custom(Regex.compile!("(?<![A-Za-z0-9_])ID\\d{4}", [:export]))
        assert {:re_exported_pattern, _, _, _, _} = pattern.regex.re_pattern
        text = "ID1234 and xID5678 and ID9012"

        assert [%Match{value: "ID1234"}, %Match{value: "ID9012"}] = scan([pattern], text)
        assert scan([pattern], text) == one_by_one([pattern], text)
      end
    end

    test "the shared pass reads its captures in pattern order" do
      scanner = PiiCatalog.compile()
      assert Regex.names(scanner.shared) == scanner.shared_columns
      assert length(scanner.shared_columns) == length(scanner.shared_names)
    end
  end

  describe "email" do
    # Each shape took from seconds to minutes at 128 KB with an unbounded,
    # backtracking local part. A linear scan grows about 4 times from 16 KB
    # to 64 KB, a quadratic one about 16 times. The bounds are relative, so
    # that a slow machine does not fail them.
    for shape <- @crafted_shapes do
      test "scans crafted input in linear time: #{shape}" do
        small = min_time(crafted(unquote(shape), 16 * 512))
        big = min_time(crafted(unquote(shape), 64 * 512))

        assert big < 2_000_000, "64 KB took #{big} µs"
        assert big < 10 * small + 20_000, "16 KB took #{small} µs, 64 KB #{big} µs"
      end
    end

    for char <- ~w(! # $ % ' * + - ^ _ ` { | } ~) do
      test "a local part with #{char} inside is found whole" do
        address = "a#{unquote(char)}b@example.com"
        assert emails("Write to #{address} today.") == [address]
      end
    end

    test "names with an apostrophe are found whole" do
      for address <- [
            "o'brien@example.ie",
            "jean-luc.d'arc@example.fr",
            "x{y}z|w~v@example.org"
          ] do
        assert emails("Contact #{address}, please.") == [address]
      end
    end

    test "quotes and brackets around an address stay outside the match" do
      for text <- ["'anna@example.com'", "`anna@example.com`", "{anna@example.com}"] do
        assert emails(text) == ["anna@example.com"]
      end
    end

    test "an address in a URL path, a query string or a mailto: link is matched alone" do
      for text <- [
            "https://example.com/u/anna@example.com",
            "https://example.com/?token=x&email=anna@example.com",
            "mailto:anna@example.com"
          ] do
        assert emails(text) == ["anna@example.com"]
      end
    end

    test "/ ? = & before the @ are left out: the match starts after the last one" do
      for address <- ["a/b@example.com", "a?b@example.com", "a=b@example.com", "a&b@example.com"] do
        assert emails(address) == ["b@example.com"]
      end
    end

    test "an address after a failed one is found from its own start" do
      text = "x@nodot then a.b@c@example.com and 1.2.3@ok.io"

      assert [:email] |> PiiCatalog.compile() |> PiiCatalog.find(text) |> Enum.map(& &1.value) ==
               ["c@example.com", "1.2.3@ok.io"]
    end
  end

  describe "memory on text dense with matches" do
    # The shared pass used to read every match position with a capture for
    # every pattern in it: 1 MB of IP addresses held about 1 GB. Matched one
    # at a time it holds about 56 MB, most of it the matches returned. The
    # scan runs under a 128 MB heap limit, which kills the process if it
    # goes over.
    @heap_limit_words div(128 * 1024 * 1024, :erlang.system_info(:wordsize))

    for {label, unit} <- [{"IP addresses", "1.2.3.4."}, {"an IP log", "10.0.0.1,"}] do
      test "1 MB of #{label} is scanned with every pattern within 128 MB" do
        unit = unquote(unit)
        text = String.duplicate(unit, div(1_048_576, byte_size(unit)))
        scanner = PiiCatalog.compile()
        parent = self()

        {pid, ref} =
          spawn_monitor(fn ->
            Process.flag(:max_heap_size, %{
              size: @heap_limit_words,
              kill: true,
              error_logger: false
            })

            send(parent, {:found, length(PiiCatalog.find(scanner, text))})
          end)

        assert_receive {:found, count}, 60_000
        assert count > 100_000
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      end
    end
  end

  describe "bytes" do
    test "patterns match bytewise, so text that is not valid UTF-8 is scanned" do
      text = <<"IBAN ", 0xFF, "DE89 3704 0044 0532 0130 00", 0xC3, " and ", 0x80, "123-45-6789">>
      refute String.valid?(text)

      assert [%Match{name: :iban, offset: 6}, %Match{name: :ssn, value: "123-45-6789"}] =
               [:iban, :ssn] |> PiiCatalog.compile() |> PiiCatalog.find(text)
    end

    test "a value directly after or before a non-ASCII letter is found" do
      # The boundaries ask only about ASCII word characters, so the bytes of
      # é and ê do not hide a value.
      assert [%Match{value: "123-45-6789"}] =
               [:ssn] |> PiiCatalog.compile() |> PiiCatalog.find("né123-45-6789ê")

      assert [%Match{value: "anna@example.com"}] =
               [:email] |> PiiCatalog.compile() |> PiiCatalog.find("«anna@example.com»")
    end
  end
end
