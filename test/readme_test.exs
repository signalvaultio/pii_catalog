defmodule PiiCatalog.ReadmeTest do
  use ExUnit.Case, async: true

  alias PiiCatalog.Dev.Readme

  @readme Path.expand("../README.md", __DIR__)

  test "README.md's table and lists match the catalog (run mix pii_catalog.readme)" do
    readme = File.read!(@readme)
    assert readme == Readme.render(readme)
  end

  test "the README table has a row per pattern, linking its vector file" do
    readme = File.read!(@readme)

    for name <- PiiCatalog.names() do
      assert readme =~ "| `#{name}` |"
      assert readme =~ "test/vectors/#{name}.exs)"
      assert File.exists?(Path.expand("vectors/#{name}.exs", __DIR__))
    end
  end

  test "the README intro counts the identifiers and countries in the catalog" do
    readme = File.read!(@readme)
    countries = Keyword.keys(PiiCatalog.regions()) -- [:global, :eu, :nordics, :us]

    assert readme =~ "for #{length(PiiCatalog.names())} personal identifiers"
    assert readme =~ "from #{length(countries)} European countries and the US"
  end

  test "the README usage example gives what it shows" do
    scanner = PiiCatalog.compile()

    assert [%PiiCatalog.Match{name: :iban, value: "DE89 3704 0044 0532 0130 00", offset: 7}] =
             PiiCatalog.find(scanner, "Pay to DE89 3704 0044 0532 0130 00 by Friday")
  end
end
