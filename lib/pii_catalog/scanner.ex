defmodule PiiCatalog.Scanner do
  @moduledoc """
  A compiled set of patterns, ready to scan text. Build one with
  `PiiCatalog.compile/1` and keep it: compiling every pattern takes about
  as long as scanning a few kilobytes of text, which is worth paying once rather
  than per call. A scanner is an immutable value, so it can be kept in a process, an ETS
  table or `:persistent_term`. Build it at runtime rather than in a module
  attribute: from OTP 28 a compiled regex is a reference, which cannot be
  stored at compile time.

  ## How a text is scanned

  The regex engine pays a cost at every position of the text for each pass,
  so scanning patterns one after another costs one such pass each. Most
  catalog patterns start the same way: no ASCII word character before, then
  a digit or a capital letter. Those share one pass. Patterns of your own
  never do: each is scanned in a pass of its own, so it cannot change what
  the catalog patterns find, and an error from the engine on it names it
  alone. At each position where
  such a match can start, each of them is tried as a lookahead with a named
  capture, and the position is reported only if one of them matched.

  For each pattern the result is what `Regex.scan/3` gives on its own
  regex: matches left to right, none starting inside the previous one. A
  pattern scanned in the shared pass matches at a position exactly when its
  own regex does, so the only step left is dropping a match that starts
  inside the previous one.

  A catalog pattern shares the pass when `shared?/1` is true: its regex starts with
  `(?<![A-Za-z0-9_])`, has no flags, has no `|` outside parentheses, and
  uses none of `\\K`, a backtracking verb such as `(*SKIP)` (any `(*` in
  its source), a named group, a backreference (`\\1` to `\\9`, `\\g`,
  `\\k`, `(?P=`), a subroutine call (`(?1)`, `(?+1)`, `(?-1)`, `(?R)`,
  `(?&name)`, `(?P>name)`) or a condition other than an assertion (`(?(1)`,
  `(?(R)`, `(?(DEFINE)`). Inside the shared regex a verb would act on the
  other patterns' positions too, and the others would point at the wrong
  group, as group numbers count from the start of the whole regex. In a regex such as `(?<![A-Za-z0-9_])ORD\\d{4}|INV\\d{4}`
  the lookbehind applies to the first branch only, but in the shared regex
  it would apply to both. The rest are scanned on
  their own: those starting with a literal (`@`, `+`) or a keyword, which
  the engine finds quickly, and those with flags or any of the above. A
  pattern scanned on its own is skipped when the text lacks what its
  `requires` field names: a literal, or a match for one of a list of
  regexes.

  A pattern in the shared pass must also begin every match with a digit or
  a capital letter. The catalog's tests check this for every catalog
  pattern that shares the pass.

  ## When the regex engine stops

  The engine stops a match that takes too many steps and returns an error
  (`:match_limit`). `Regex.scan/3` reads that error as no more matches, so
  the rest of the text would go unscanned without a sign. The scanner reads
  the error and raises `PiiCatalog.ScanError` instead. A pattern skipped
  on a text that lacks its `requires` is still skipped; a `requires` regex
  that stops with an error counts as present, so the pattern is scanned.
  """

  alias PiiCatalog.{Match, Pattern, Patterns, ScanError, Validators}

  @shared_prefix "(?<![A-Za-z0-9_])"

  @enforce_keys [:patterns, :shared, :shared_names, :shared_columns, :validators]
  defstruct [:patterns, :shared, :shared_names, :shared_columns, :validators]

  @opaque t :: %__MODULE__{
            patterns: [Pattern.t()],
            shared: Regex.t() | nil,
            shared_names: [atom()],
            shared_columns: [String.t()],
            validators: %{atom() => atom() | nil}
          }

  @doc """
  Compiles a scanner for the given patterns, scanned in the order given.
  A second pattern with a name already in the list is dropped. Raises
  `ArgumentError` for a pattern whose `validator` is neither `nil` nor one
  of `PiiCatalog.Validators.names/0`.
  """
  @spec new([Pattern.t()]) :: t()
  def new(patterns) when is_list(patterns) do
    patterns = Enum.uniq_by(patterns, & &1.name)
    Enum.each(patterns, &check_validator!/1)
    {shared, names, columns} = patterns |> Enum.filter(&shared?/1) |> shared_regex()

    %__MODULE__{
      patterns: patterns,
      shared: shared,
      shared_names: names,
      shared_columns: columns,
      validators: Map.new(patterns, &{&1.name, &1.validator})
    }
  end

  # The compiled pattern `:re.run/3` takes for a regex, as `Regex.run/3`
  # would run it. A regex compiled for another version of the engine, or
  # exported with the `E` flag, is compiled again from its source. The
  # scanner keeps `Regex` structs rather than these, so that it can be
  # stored where a regex can.
  defp compiled(%Regex{} = regex) do
    %Regex{re_pattern: pattern, source: source, opts: opts} = Regex.recompile!(regex)

    case pattern do
      {:re_exported_pattern, _, _, _, _} ->
        Regex.compile!(source, List.delete(opts, :export)).re_pattern

      {:re_pattern, _, _, _, compiled} when is_binary(compiled) ->
        if :erlang.system_info(:otp_release) >= ~c"28",
          do: Regex.compile!(source, opts).re_pattern,
          else: pattern

      pattern ->
        pattern
    end
  end

  defp check_validator!(%Pattern{validator: nil}), do: :ok

  defp check_validator!(%Pattern{name: name, validator: validator}) do
    if validator not in Validators.names() do
      raise ArgumentError,
            "pattern #{inspect(name)} has validator #{inspect(validator)}, " <>
              "which is not nil or one of PiiCatalog.Validators.names/0"
    end

    :ok
  end

  @doc "The patterns a scanner holds, in the order it reports them."
  @spec patterns(t()) :: [Pattern.t()]
  def patterns(%__MODULE__{patterns: patterns}), do: patterns

  @doc """
  Whether a pattern is scanned in the shared pass. Only catalog patterns
  are: a pattern whose name is not in the catalog, or whose regex is not
  the catalog's (same source and options), is scanned on its own. Of the
  catalog patterns, those whose regex starts with `(?<![A-Za-z0-9_])`,
  has no flags and no `|` outside parentheses, and has no `\\K`,
  backtracking verb, named group, backreference, subroutine call or
  condition other than an assertion share the pass.
  """
  @spec shared?(Pattern.t()) :: boolean()
  def shared?(%Pattern{} = pattern), do: catalog_pattern?(pattern) and shareable?(pattern)

  # A pattern of your own, or a catalog pattern with another regex, never
  # shares the pass: what it finds, how long it takes and any error from
  # the engine stay its own.
  defp catalog_pattern?(%Pattern{name: name, regex: regex}) do
    case Patterns.get(name) do
      %Pattern{regex: catalog} ->
        Regex.source(catalog) == Regex.source(regex) and Regex.opts(catalog) == Regex.opts(regex)

      nil ->
        false
    end
  end

  # Whether a regex could be tried inside the shared regex and match
  # exactly where it matches on its own. The catalog's tests check every
  # catalog pattern that shares the pass against its own regex.
  @doc false
  @spec shareable?(Pattern.t()) :: boolean()
  def shareable?(%Pattern{regex: regex}) do
    source = regex.source

    String.starts_with?(source, @shared_prefix) and no_flags?(regex) and
      not String.contains?(source, ["\\K", "(*"]) and Regex.names(regex) == [] and
      not Regex.match?(~r/\\[1-9gk]/, source) and not top_level_alternation?(source) and
      not group_reference?(source)
  end

  # Whether the source has a `|` outside every group.
  defp top_level_alternation?(source),
    do: any_token?(source, 0, fn at, depth -> depth == 0 and match?("|" <> _, at) end)

  # Whether the source calls a group as a subroutine (`(?1)`, `(?+1)`,
  # `(?-1)`, `(?R)`, `(?&name)`, `(?P>name)`), refers to one by name
  # (`(?P=name)`), or has a condition other than an assertion (`(?(1)`,
  # `(?(R)`, `(?(<name>)`, `(?(DEFINE)`). Group numbers count from the
  # start of the whole regex, so in the shared pass they would point at
  # other patterns' groups.
  defp group_reference?(source),
    do: any_token?(source, 0, fn at, _depth -> group_reference_at?(at) end)

  defp group_reference_at?(<<"(?(?", _::binary>>), do: false
  defp group_reference_at?(<<"(?(", _::binary>>), do: true
  defp group_reference_at?(<<"(?", c, _::binary>>) when c in ?0..?9 or c in [?+, ?R, ?&], do: true
  defp group_reference_at?(<<"(?-", c, _::binary>>) when c in ?0..?9, do: true
  defp group_reference_at?(<<"(?P", c, _::binary>>) when c in [?>, ?=], do: true
  defp group_reference_at?(_at), do: false

  # Calls `test` with the source from each character that is not escaped,
  # inside `\\Q...\\E`, inside a character class or inside a `(?#...)`
  # comment, and the group depth there, until it returns true.
  defp any_token?(<<>>, _depth, _test), do: false

  defp any_token?(<<"\\Q", rest::binary>>, depth, test),
    do: rest |> skip_past("\\E") |> any_token?(depth, test)

  defp any_token?(<<"\\", _, rest::binary>>, depth, test), do: any_token?(rest, depth, test)

  defp any_token?(<<"(?#", rest::binary>>, depth, test),
    do: rest |> skip_past(")") |> any_token?(depth, test)

  # A ] right after [ or [^ is a literal, not the end of the class.
  defp any_token?(<<"[^]", rest::binary>>, depth, test),
    do: rest |> skip_class() |> any_token?(depth, test)

  defp any_token?(<<"[]", rest::binary>>, depth, test),
    do: rest |> skip_class() |> any_token?(depth, test)

  defp any_token?(<<"[^", rest::binary>>, depth, test),
    do: rest |> skip_class() |> any_token?(depth, test)

  defp any_token?(<<"[", rest::binary>>, depth, test),
    do: rest |> skip_class() |> any_token?(depth, test)

  defp any_token?(<<c, rest::binary>> = source, depth, test),
    do: test.(source, depth) or any_token?(rest, depth_after(c, depth), test)

  defp depth_after(?(, depth), do: depth + 1
  defp depth_after(?), depth), do: depth - 1
  defp depth_after(_c, depth), do: depth

  # The rest of a character class after its closing ].
  defp skip_class(<<>>), do: <<>>
  defp skip_class(<<"]", rest::binary>>), do: rest
  defp skip_class(<<"\\", _, rest::binary>>), do: skip_class(rest)

  defp skip_class(<<"[:", rest::binary>> = class) do
    case Regex.run(~r/\A\^?[a-z]+:\]/, rest, return: :index) do
      [{0, length}] -> skip_class(binary_part(rest, length, byte_size(rest) - length))
      nil -> skip_class(binary_part(class, 1, byte_size(class) - 1))
    end
  end

  defp skip_class(<<_, rest::binary>>), do: skip_class(rest)

  defp skip_past(binary, delimiter) do
    case :binary.split(binary, delimiter) do
      [_, rest] -> rest
      [_] -> <<>>
    end
  end

  # Elixir 1.15 returns the flags as a string, later versions as a list.
  defp no_flags?(regex), do: Regex.opts(regex) in [[], ""]

  @doc """
  Every candidate match of every pattern in `text`, before validation.
  Grouped by pattern in the scanner's order, and left to right within each.
  Raises `PiiCatalog.ScanError` when the regex engine stops before the end
  of the text.
  """
  @spec scan(t(), binary()) :: [Match.t()]
  def scan(%__MODULE__{patterns: patterns} = scanner, text) when is_binary(text) do
    shared_spans = shared_spans(scanner, text)

    Enum.flat_map(patterns, fn %Pattern{name: name} = pattern ->
      spans = Map.get_lazy(shared_spans, name, fn -> own_spans(pattern, text) end)

      Enum.map(spans, fn {offset, length} ->
        %Match{
          name: name,
          value: binary_part(text, offset, length),
          offset: offset,
          length: length
        }
      end)
    end)
  end

  @doc """
  The matches of `scan/2` that pass their pattern's validator, in the same
  order. The validator sees the matched bytes alone. Raises
  `PiiCatalog.ScanError` as `scan/2` does.
  """
  @spec find(t(), binary()) :: [Match.t()]
  def find(%__MODULE__{validators: validators} = scanner, text) when is_binary(text) do
    scanner
    |> scan(text)
    |> Enum.filter(&Validators.valid?(Map.fetch!(validators, &1.name), &1.value))
  end

  # As Regex.scan/3 with `return: :index`, first span of each match, but
  # an error from the engine raises rather than reading as no more matches.
  defp own_spans(%Pattern{name: name, regex: regex, requires: required}, text) do
    if present?(required, text) do
      for [span] <- run!(text, regex, :first, [name]), do: span
    else
      []
    end
  end

  defp present?(nil, _text), do: true

  defp present?(literal, text) when is_binary(literal),
    do: :binary.match(text, literal) != :nomatch

  # A probe that stops with an error counts as present, so the pattern is
  # scanned and its own error, if any, is raised.
  defp present?(probes, text) when is_list(probes) do
    Enum.any?(probes, fn probe ->
      :re.run(text, compiled(probe), [:report_errors, {:capture, :none}]) != :nomatch
    end)
  end

  defp run!(text, regex, columns, names) do
    options = [:global, :report_errors, {:capture, columns, :index}]

    case :re.run(text, compiled(regex), options) do
      {:match, rows} -> rows
      :nomatch -> []
      {:error, reason} -> raise ScanError, patterns: names, reason: reason
    end
  end

  defp shared_spans(%__MODULE__{shared: nil}, _text), do: %{}

  defp shared_spans(
         %__MODULE__{shared: regex, shared_names: names, shared_columns: capture},
         text
       ) do
    re = compiled(regex)
    matches = collect_shared(text, re, [0 | capture], names, 0, byte_size(text), [])
    by_group = group_by_capture(matches)

    names
    |> Enum.with_index(1)
    |> Map.new(fn {name, group} -> {name, non_overlapping(Map.get(by_group, group, []))} end)
  end

  # One match at a time, from an offset, keeping only the groups that
  # matched. A global run returns, for every position where any pattern
  # matches, a capture for every pattern in the pass, matched or not: on
  # 1 MB of IP addresses that held hundreds of megabytes at once. The
  # shared regex matches the empty string (its tries are lookaheads), so
  # each search resumes one byte on, as a global run does after an empty
  # match. Returns {group, offset, length} for each matched group, last
  # first.
  defp collect_shared(_text, _re, _capture, _names, offset, size, acc) when offset > size,
    do: acc

  defp collect_shared(text, re, capture, names, offset, size, acc) do
    case :re.run(text, re, [{:offset, offset}, :report_errors, {:capture, capture, :index}]) do
      {:match, [{start, length} | groups]} ->
        acc = matched_groups(groups, 1, acc)
        collect_shared(text, re, capture, names, start + max(length, 1), size, acc)

      :nomatch ->
        acc

      {:error, reason} ->
        raise ScanError, patterns: names, reason: reason
    end
  end

  defp matched_groups([], _group, acc), do: acc

  defp matched_groups([{offset, length} | rest], group, acc) when offset >= 0,
    do: matched_groups(rest, group + 1, [{group, offset, length} | acc])

  defp matched_groups([_unmatched | rest], group, acc),
    do: matched_groups(rest, group + 1, acc)

  # The matches come last first, so prepending puts each group's spans in
  # text order.
  defp group_by_capture(matches) do
    Enum.reduce(matches, %{}, fn {group, offset, length}, acc ->
      Map.update(acc, group, [{offset, length}], &[{offset, length} | &1])
    end)
  end

  # Regex.scan resumes after each match, so a match starting inside the
  # previous one is never reported.
  defp non_overlapping(spans) do
    {_, kept} =
      Enum.reduce(spans, {0, []}, fn {offset, length}, {last_end, kept} ->
        if offset >= last_end,
          do: {offset + length, [{offset, length} | kept]},
          else: {last_end, kept}
      end)

    Enum.reverse(kept)
  end

  # The shared regex for a set of patterns, their names in capture order,
  # and the capture group names to read. Captures are named `p000`,
  # `p001`, … so that their sorted order, which `Regex.names/1` and
  # `capture: :all_names` give, is the pattern order. The patterns are
  # sorted by name, so the same set gives the same regex in any order.
  defp shared_regex([]), do: {nil, [], []}

  defp shared_regex(patterns) do
    patterns = Enum.sort_by(patterns, & &1.name)

    if length(patterns) > 1000 do
      raise ArgumentError, "at most 1000 patterns can share a pass, got #{length(patterns)}"
    end

    groups =
      Enum.with_index(patterns, fn p, i -> {p, "p" <> String.pad_leading("#{i}", 3, "0")} end)

    tries =
      Enum.map_join(groups, fn {p, group} ->
        "(?:(?=(?<#{group}>#{String.replace_prefix(p.regex.source, @shared_prefix, "")}))|)"
      end)

    # Fails unless at least one group matched, so positions where nothing
    # matched return no row.
    any_matched =
      groups
      |> Enum.reverse()
      |> Enum.reduce("(?!)", fn {_p, group}, rest -> "(?(<#{group}>)|#{rest})" end)

    regex = Regex.compile!(@shared_prefix <> "(?=[0-9A-Z])" <> tries <> any_matched)
    {regex, Enum.map(patterns, & &1.name), Enum.map(groups, &elem(&1, 1))}
  end
end
