defmodule PiiCatalog.VectorsTest do
  @moduledoc """
  Every pattern carries a vector file in `test/vectors/<name>.exs`: values
  it must find, values of the right shape it must not (where it has a
  check), and look-alikes. `noise.exs` is text no pattern may match.

  A valid value is a string that must be found whole, or `{text, value}`
  where only `value` is found: a pattern that requires a word before the
  identifier matches the identifier alone.
  """
  use ExUnit.Case, async: true

  import PiiCatalog.Test.Vectors, only: [load: 1, found: 2, with_found: 1]

  alias PiiCatalog.Pattern
  alias PiiCatalog.Test.Vectors

  test "there is one vector file per pattern, and noise" do
    files =
      Vectors.dir()
      |> Path.join("*.exs")
      |> Path.wildcard()
      |> Enum.map(&Path.basename(&1, ".exs"))
      |> Enum.sort()

    expected = ["noise" | Enum.map(PiiCatalog.names(), &Atom.to_string/1)] |> Enum.sort()
    assert files == expected
  end

  for %Pattern{name: name, confidence: confidence} <- PiiCatalog.patterns() do
    @name name
    @confidence confidence

    test "#{name}: every valid value is found, exactly" do
      %{valid: valid} = load(@name)
      assert length(valid) >= 3, "#{@name} needs at least 3 valid values"

      for entry <- valid do
        {text, value} = with_found(entry)

        assert found(@name, "Reference: #{text}.") == [value],
               "#{@name} did not find exactly #{inspect(value)} in #{inspect(text)}"
      end
    end

    test "#{name}: values that fail its check are not found" do
      %{invalid: invalid} = load(@name)

      if @confidence == :checksum do
        assert length(invalid) >= 3, "#{@name} needs at least 3 values that fail its check"
      end

      for value <- invalid do
        assert found(@name, "Reference: #{value}.") == [],
               "#{@name} found #{inspect(value)}, which fails its check"
      end
    end

    test "#{name}: look-alikes are not found" do
      %{look_alikes: look_alikes} = load(@name)
      assert length(look_alikes) >= 2, "#{@name} needs at least 2 look-alikes"

      for text <- look_alikes do
        assert found(@name, text) == [], "#{@name} matched in #{inspect(text)}"
      end
    end
  end

  test "no pattern matches ordinary text" do
    scanner = PiiCatalog.compile()

    for text <- load(:noise) do
      assert PiiCatalog.find(scanner, text) == [], "a pattern matched in #{inspect(text)}"
    end
  end
end
