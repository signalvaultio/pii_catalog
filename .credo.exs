%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "dev/", "test/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      strict: true,
      checks: %{
        extra: [
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 20]}
        ]
      }
    }
  ]
}
