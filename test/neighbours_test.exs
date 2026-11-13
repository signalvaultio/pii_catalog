defmodule PiiCatalog.NeighboursTest do
  @moduledoc """
  Patterns match bytewise, without the `u` flag, and their boundaries ask
  only about ASCII word characters. A character outside ASCII next to a
  value must neither hide it nor cut it short.
  """
  use ExUnit.Case, async: true

  @scanner PiiCatalog.compile()

  @not_letters [
    {"€", "€"},
    {"«", "»"},
    {"“", "”"},
    {"\u00A0", "\u00A0"},
    {"\u202F", "\u202F"},
    {"№", "."},
    {"日", "日"},
    {<<0xFF>>, <<0xFE>>}
  ]
  @letters [{"ö", "ö"}, {"Ж", "Ж"}, {"ÄÖ", "ÅÆ"}, {"é", "é"}]

  defp found(name, text) do
    for %{name: ^name, value: value} <- PiiCatalog.find(@scanner, text), do: value
  end

  for %PiiCatalog.Pattern{name: name, example: example} <- PiiCatalog.patterns() do
    @name name
    @example example

    test "#{name}: found exactly between symbols, punctuation and other scripts" do
      expected = found(@name, "Reference: #{@example}.")
      assert expected != []

      for {left, right} <- @not_letters do
        text = "Reference: " <> left <> @example <> right <> " end"
        assert found(@name, text) == expected, "#{@name} in #{inspect(text)}"
      end
    end

    if name != :email do
      test "#{name}: found exactly between letters outside ASCII" do
        expected = found(@name, "Reference: #{@example}.")

        for {left, right} <- @letters do
          text = "Reference: " <> left <> @example <> right <> " end"
          assert found(@name, text) == expected, "#{@name} in #{inspect(text)}"
        end
      end
    end
  end

  test "email: letters outside ASCII before and after the @" do
    assert found(:email, "Mail anna.björk@exempel.se today") == ["anna.björk@exempel.se"]
    assert found(:email, "Från Östen@firma.example.") == ["Östen@firma.example"]
    assert found(:email, "Пишите dmitri@почта.рф") == ["dmitri@почта.рф"]
  end

  test "email: a letter touching the address is part of it" do
    for {left, right} <- @letters do
      text = "Write to " <> left <> "anna.berg@example.com" <> right <> " today"
      assert found(:email, text) == [left <> "anna.berg@example.com" <> right]
    end
  end

  test "email: scripts written without spaces between words are not taken in" do
    assert found(:email, "メールはanna@example.comです") == ["anna@example.com"]
    assert found(:email, "邮箱：wei@example.cn。") == ["wei@example.cn"]
  end
end
