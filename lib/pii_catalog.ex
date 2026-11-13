defmodule PiiCatalog do
  @moduledoc """
  A catalog of personal identifiers, each a regex plus, where the
  identifier has one, a check-digit or structure validator, and a scanner
  that finds them in a text, most of them in one shared regex pass.

      iex> scanner = PiiCatalog.compile()
      iex> PiiCatalog.find(scanner, "Pay to DE89 3704 0044 0532 0130 00 by Friday")
      [%PiiCatalog.Match{name: :iban, value: "DE89 3704 0044 0532 0130 00", offset: 7, length: 27}]

  No processes, no state and no runtime dependencies: nothing is started,
  cached or logged. Three validators read today's date (see
  `PiiCatalog.Validators`), so their answer for a value can change over
  time. Compile a scanner once with `compile/1` and keep it; `scan/2` and
  `find/2` take it as their first argument.

  Pattern names are atoms (`:iban`, `:personnummer_se`) and never change
  once released. Every function that takes a name also takes it as a
  string, without creating atoms.
  """

  alias PiiCatalog.{Match, Pattern, Patterns, Scanner, Validators}

  # Region names, in display order. Countries come after the region they
  # are grouped under.
  @regions [
    global: "Global",
    eu: "European Union",
    at: "Austria",
    be: "Belgium",
    de: "Germany",
    ee: "Estonia",
    es: "Spain",
    fr: "France",
    ie: "Ireland",
    it: "Italy",
    nl: "Netherlands",
    pl: "Poland",
    pt: "Portugal",
    nordics: "Nordics",
    dk: "Denmark",
    fi: "Finland",
    is: "Iceland",
    no: "Norway",
    se: "Sweden",
    ch: "Switzerland",
    gb: "United Kingdom",
    us: "United States"
  ]

  # Built at compile time from the catalog: the names in catalog order and
  # each pattern's validator, so that a lookup by name does not compile 29
  # regexes.
  @names Patterns.names()
  @validators Map.new(Patterns.all(), &{&1.name, &1.validator})
  @names_by_string Map.new(@names, &{Atom.to_string(&1), &1})

  @typedoc "A pattern name, as an atom or a string."
  @type name :: atom() | String.t()

  @doc """
  Every pattern, in catalog order, with its regex compiled.

  Builds the list on each call: compile a scanner once rather than calling
  this for every scan. From OTP 28 a compiled regex is a reference, so
  patterns from two calls are not `==`; compare them by `name`.
  """
  @spec patterns() :: [Pattern.t()]
  defdelegate patterns, to: Patterns, as: :all

  @doc "Every pattern name, in catalog order."
  @spec names() :: [atom(), ...]
  def names, do: @names

  @doc "The pattern with this name, or `nil`. Builds only that pattern."
  @spec get(name()) :: Pattern.t() | nil
  def get(name) do
    case to_name(name) do
      nil -> nil
      name -> Patterns.get(name)
    end
  end

  @doc "The pattern with this name. Raises `ArgumentError` for an unknown name."
  @spec fetch!(name()) :: Pattern.t()
  def fetch!(name) do
    case get(name) do
      nil -> raise ArgumentError, "unknown pattern #{inspect(name)}"
      pattern -> pattern
    end
  end

  @doc """
  Every region a pattern is tagged with, in display order, as
  `[{region, label}]`: `[global: "Global", eu: "European Union", ...]`.
  """
  @spec regions() :: [{atom(), String.t()}, ...]
  def regions, do: @regions

  @doc """
  A region's display name: `region_label(:se)` is `"Sweden"`. Raises
  `ArgumentError` for a region not in `regions/0`.
  """
  @spec region_label(atom()) :: String.t()
  def region_label(region) do
    case List.keyfind(@regions, region, 0) do
      {^region, label} -> label
      nil -> raise ArgumentError, "unknown region #{inspect(region)}"
    end
  end

  @doc """
  The patterns tagged with a region, in catalog order. `:eu` includes the
  identifiers listed under another group that are used in the EU, such as
  `:iban` (listed under `:global`) and `:personnummer_se` (under
  `:nordics`). Raises `ArgumentError` for a region not in `regions/0`.
  """
  @spec in_region(atom()) :: [Pattern.t()]
  def in_region(region) do
    _label = region_label(region)
    Enum.filter(patterns(), &(region in &1.regions))
  end

  @doc """
  The patterns grouped by the region they are listed under (the first of
  their `regions`), in display order: `[{region, label, [pattern]}]`. Each
  pattern appears once.
  """
  @spec groups() :: [{atom(), String.t(), [Pattern.t(), ...]}]
  def groups do
    by_group = Enum.group_by(patterns(), &hd(&1.regions))

    for {region, label} <- @regions,
        patterns = Map.get(by_group, region),
        do: {region, label, patterns}
  end

  @doc """
  Compiles a scanner. Takes pattern names, `PiiCatalog.Pattern` structs or
  a mix; with no argument, every pattern. Matches are reported grouped by
  pattern in the order given. Raises `ArgumentError` for an unknown name.

      PiiCatalog.compile([:email, :iban, :phone_intl])
      PiiCatalog.compile(PiiCatalog.in_region(:nordics))

  A struct is taken as it is, so a pattern of your own can be scanned too;
  its `validator` must be `nil` or one of `PiiCatalog.Validators.names/0`
  (`ArgumentError` otherwise), and see `PiiCatalog.Scanner` for what a regex in the shared pass must
  meet.
  """
  @spec compile([name() | Pattern.t()]) :: Scanner.t()
  def compile(patterns_or_names \\ names()) when is_list(patterns_or_names) do
    patterns_or_names
    |> Enum.map(fn
      %Pattern{} = pattern -> pattern
      name -> Patterns.get(fetch_name!(name))
    end)
    |> Scanner.new()
  end

  @doc """
  Every candidate match in `text`: values of the right shape, before any
  validator runs. Grouped by pattern in the scanner's order, and left to
  right within each pattern, with no match starting inside the previous
  match of the same pattern. Matches of different patterns may overlap.

  Each pattern gives what `Regex.scan/3` on its own regex gives, though
  most patterns share one pass over the text, except that an error from
  the regex engine raises `PiiCatalog.ScanError` (see `find/2`) where
  `Regex.scan/3` would return the matches before it as if the text ended
  there.
  """
  @spec scan(Scanner.t(), binary()) :: [Match.t()]
  defdelegate scan(scanner, text), to: Scanner

  @doc """
  The matches in `text` that pass their pattern's validator, in the order
  of `scan/2`. A pattern without a validator keeps every match.

  Raises `PiiCatalog.ScanError`, with the `patterns` being scanned and the
  engine's `reason`, when the regex engine gives up before the end of the
  text: at its match or recursion limit. The result is never partial: the
  whole text was scanned and every match is returned, or the call raises.
  The caller decides what to do with a text that raised, such as refusing
  it or redacting it whole. `scan/2` raises the same way.

      iex> scanner = PiiCatalog.compile([:credit_card])
      iex> PiiCatalog.find(scanner, "Card 4111 1111 1111 1111, not 4111 1111 1111 1112")
      [%PiiCatalog.Match{name: :credit_card, value: "4111 1111 1111 1111", offset: 5, length: 19}]
  """
  @spec find(Scanner.t(), binary()) :: [Match.t()]
  defdelegate find(scanner, text), to: Scanner

  @doc """
  Whether a value passes the validator of the named pattern, taken as the
  whole of a match. It does not check the format: that is the regex's job,
  and a pattern without a validator (`:email`, `:phone_intl`,
  `:date_of_birth`) accepts every value. To check text, use `find/2`.

      iex> PiiCatalog.valid?(:iban, "DE89 3704 0044 0532 0130 00")
      true
      iex> PiiCatalog.valid?(:iban, "DE88 3704 0044 0532 0130 00")
      false

  Raises `ArgumentError` for an unknown name.
  """
  @spec valid?(name(), binary()) :: boolean()
  def valid?(name, value) when is_binary(value) do
    Validators.valid?(Map.fetch!(@validators, fetch_name!(name)), value)
  end

  defp fetch_name!(name) do
    case to_name(name) do
      nil -> raise ArgumentError, "unknown pattern #{inspect(name)}"
      name -> name
    end
  end

  defp to_name(name) when is_atom(name), do: if(name in @names, do: name)
  defp to_name(name) when is_binary(name), do: Map.get(@names_by_string, name)
  defp to_name(_name), do: nil
end
