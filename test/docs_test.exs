defmodule PiiCatalog.DocsTest do
  use ExUnit.Case, async: true

  @modules [
    PiiCatalog,
    PiiCatalog.Match,
    PiiCatalog.Pattern,
    PiiCatalog.Patterns,
    PiiCatalog.ScanError,
    PiiCatalog.Scanner,
    PiiCatalog.Validators,
    PiiCatalog.Validators.NationalIds,
    PiiCatalog.Validators.VatEu
  ]

  test "every shipped module is listed here" do
    {:ok, modules} = :application.get_key(:pii_catalog, :modules)

    shipped =
      Enum.reject(
        modules,
        &String.starts_with?(inspect(&1), ["Mix.", "PiiCatalog.Dev", "PiiCatalog.Test"])
      )

    assert Enum.sort(shipped) == Enum.sort(@modules)
  end

  test "every module and public function has documentation and a spec" do
    for module <- @modules do
      {:docs_v1, _, :elixir, _, moduledoc, _, docs} = Code.fetch_docs(module)
      assert %{"en" => _} = moduledoc, "#{inspect(module)} has no @moduledoc"

      {:ok, specs} = Code.Typespec.fetch_specs(module)
      specced = MapSet.new(specs, fn {{name, arity}, _} -> {name, arity} end)

      # defexception generates exception/1 without documentation. A function
      # with @doc false is not part of the API.
      for {{:function, name, arity}, _, _, doc, _} <- docs,
          name not in [:__struct__, :exception],
          doc != :hidden do
        assert %{"en" => _} = doc, "#{inspect(module)}.#{name}/#{arity} has no @doc"

        # A function with default arguments has a spec for its full arity.
        assert Enum.any?(arity..(arity + 2), &({name, &1} in specced)),
               "#{inspect(module)}.#{name}/#{arity} has no @spec"
      end
    end
  end
end
