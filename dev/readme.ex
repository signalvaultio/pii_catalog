defmodule PiiCatalog.Dev.Readme do
  @moduledoc false
  # Generates the parts of README.md that are read from the catalog: the
  # identifier table and the lists in the precision section. Each sits
  # between `<!-- generated:NAME -->` and `<!-- /generated:NAME -->`.
  # `mix pii_catalog.readme` rewrites them; test/readme_test.exs fails when
  # README.md differs from what this module renders.

  alias PiiCatalog.{Pattern, Validators}

  # The tag of the version being published, so that the links in the
  # README on Hex point at the vectors of that version.
  @vectors_url "https://github.com/signalvaultio/pii_catalog/blob/v#{Mix.Project.config()[:version]}/test/vectors"
  @blocks ~w(identifiers check_digit mixed structure_only format_only keyword)

  @doc "README.md with every generated block rendered from the catalog."
  @spec render(String.t()) :: String.t()
  def render(readme) do
    Enum.reduce(@blocks, readme, fn block, acc ->
      open = "<!-- generated:#{block} -->"
      close = "<!-- /generated:#{block} -->"

      case String.split(acc, [open, close]) do
        [before, _old, rest] -> before <> open <> "\n" <> block(block) <> "\n" <> close <> rest
        _ -> raise ArgumentError, "README.md has no single #{open} … #{close} block"
      end
    end)
  end

  defp block("identifiers") do
    header = """
    | Name | Identifier | Regions | Checked | Keyword | Vectors |
    | --- | --- | --- | --- | --- | --- |
    """

    rows =
      Enum.map_join(PiiCatalog.patterns(), fn %Pattern{} = p ->
        cells = [
          "`#{p.name}`",
          p.label,
          Enum.map_join(p.regions, ", ", &PiiCatalog.region_label/1),
          checked(p),
          keyword(p),
          "[#{p.name}.exs](#{@vectors_url}/#{p.name}.exs)"
        ]

        "| " <> Enum.join(cells, " | ") <> " |\n"
      end)

    header <> rows
  end

  defp block("check_digit"), do: list(&(&1.check == :check_digit), &describe/1)
  defp block("mixed"), do: list(&(&1.check == :mixed), &describe/1)
  defp block("structure_only"), do: list(&(&1.check == :structure), &describe/1)
  defp block("format_only"), do: list(&(&1.check == nil), &notes/1)
  defp block("keyword"), do: list(& &1.keyword_required, &notes/1)

  defp list(filter, detail) do
    for %Pattern{} = p <- PiiCatalog.patterns(), filter.(p), into: "" do
      "- `#{p.name}`, #{p.label}: #{detail.(p)}\n"
    end
  end

  defp checked(%Pattern{check: :check_digit, validator: v}),
    do: "Check digit: " <> Validators.describe(v)

  defp checked(%Pattern{check: :mixed, validator: v}),
    do: "Partly check digit: " <> Validators.describe(v)

  defp checked(%Pattern{check: :structure, validator: v}),
    do: "Structure only: " <> Validators.describe(v)

  defp checked(%Pattern{check: nil}), do: "Format only"

  defp keyword(%Pattern{keyword_required: false}), do: "no"
  defp keyword(%Pattern{confidence: :format_with_context}), do: "required"
  defp keyword(%Pattern{}), do: "required, part of the match"

  defp describe(%Pattern{validator: validator}), do: Validators.describe(validator) <> "."

  defp notes(%Pattern{notes: nil}), do: "Format only."
  defp notes(%Pattern{notes: notes}), do: notes
end
