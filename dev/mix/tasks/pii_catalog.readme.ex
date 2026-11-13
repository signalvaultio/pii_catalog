defmodule Mix.Tasks.PiiCatalog.Readme do
  @shortdoc "Regenerates the identifier table and lists in README.md"
  @moduledoc """
  Regenerates the parts of `README.md` that are read from the catalog.

      mix pii_catalog.readme          # rewrite README.md
      mix pii_catalog.readme --check  # exit non-zero if README.md is out of date

  Only for working on this repository: not shipped with the package.
  """
  use Mix.Task

  alias PiiCatalog.Dev.Readme

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    Mix.Task.run("compile")
    current = File.read!("README.md")
    rendered = Readme.render(current)

    cond do
      rendered == current ->
        Mix.shell().info("README.md is up to date")

      "--check" in args ->
        Mix.raise("README.md is out of date: run mix pii_catalog.readme")

      true ->
        File.write!("README.md", rendered)
        Mix.shell().info("README.md regenerated")
    end
  end
end
