defmodule PiiCatalog.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/signalvaultio/pii_catalog"

  def project do
    [
      app: :pii_catalog,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: false,
      deps: deps(),
      description:
        "Regexes and validators for 29 personal identifiers (email, phone, payment card, " <>
          "IBAN, EU VAT and European national ID numbers): check-digit and structure " <>
          "checks, and a scanner that finds them in text, most of them in one shared regex pass.",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts",
        plt_add_apps: [:mix]
      ]
    ]
  end

  def application do
    [extra_applications: []]
  end

  # `dev/` holds the README generator and its Mix task. It is not compiled
  # when the package is used as a dependency, and it is not shipped.
  defp elixirc_paths(:test), do: ["lib", "dev", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:stream_data, "~> 1.1", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/v#{@version}/CHANGELOG.md"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md SECURITY.md SOURCES.md LICENSE NOTICE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "SECURITY.md", "SOURCES.md"],
      groups_for_modules: [
        Catalog: [PiiCatalog, PiiCatalog.Pattern, PiiCatalog.Patterns],
        Scanning: [PiiCatalog.Scanner, PiiCatalog.Match, PiiCatalog.ScanError],
        Validators: [
          PiiCatalog.Validators,
          PiiCatalog.Validators.NationalIds,
          PiiCatalog.Validators.VatEu
        ]
      ],
      filter_modules: fn module, _metadata ->
        not String.starts_with?(inspect(module), ["Mix.Tasks.", "PiiCatalog.Dev"])
      end
    ]
  end
end
