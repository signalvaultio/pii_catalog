defmodule PiiCatalog.Test.Vectors do
  @moduledoc false
  # Reads the test vectors in test/vectors/. Each pattern's file is a map:
  #
  #   * valid: values it must find. A string is found whole; `{text, value}`
  #     is found as `value` alone, for a pattern that requires a word before
  #     the identifier.
  #   * invalid: values of the right shape that fail its check.
  #   * look_alikes: texts in which it must find nothing.
  #
  # noise.exs is a list of texts no pattern may match.

  @dir Path.expand("../vectors", __DIR__)

  @doc "The directory holding the vector files."
  @spec dir() :: String.t()
  def dir, do: @dir

  @doc "The vectors of one pattern, or the noise list for `:noise`."
  @spec load(atom()) :: map() | [String.t()]
  def load(name) do
    path = Path.join(@dir, "#{name}.exs")

    if not File.exists?(path) do
      raise ArgumentError, "#{name} has no vector file at #{path}"
    end

    {vectors, _binding} = Code.eval_file(path)
    vectors
  end

  @doc "A valid entry as `{text, value}`."
  @spec with_found(String.t() | {String.t(), String.t()}) :: {String.t(), String.t()}
  def with_found({text, value}), do: {text, value}
  def with_found(value), do: {value, value}

  @doc "The values one pattern finds in a text, after validation."
  @spec found(atom(), binary()) :: [binary()]
  def found(name, text) do
    [name] |> PiiCatalog.compile() |> PiiCatalog.find(text) |> Enum.map(& &1.value)
  end

  @doc "Every string in every vector file, as it appears in text."
  @spec snippets() :: [String.t()]
  def snippets do
    for path <- Path.wildcard(Path.join(@dir, "*.exs")),
        {vectors, _} = Code.eval_file(path),
        entry <-
          if(is_list(vectors), do: vectors, else: Enum.flat_map(Map.values(vectors), & &1)) do
      case entry do
        {text, _value} -> text
        text -> text
      end
    end
  end
end
