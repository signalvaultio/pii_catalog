defmodule PiiCatalog.ScanError do
  @moduledoc """
  Raised by `PiiCatalog.scan/2` and `PiiCatalog.find/2` when the regex
  engine stops before it has scanned the whole text, for example when a
  pattern reaches the engine's match limit (`:match_limit`) on a crafted
  input.

  The scan reports no result for that text rather than the matches found
  before the engine stopped: a text that was not fully scanned is not
  reported as holding no identifier. What to do with the text, such as
  refusing it or redacting it whole, is the caller's choice.

  The catalog's tests run its patterns on crafted inputs that make regexes
  backtrack, such as a keyword followed by thousands of spaces; a pattern
  of your own can still reach the limit.

    * `patterns` – the names of the patterns that were being scanned. For
      the shared pass (see `PiiCatalog.Scanner`) these are all the patterns
      in it.
    * `reason` – the error the regex engine returned, such as
      `:match_limit` or `:match_limit_recursion`.
  """

  defexception [:patterns, :reason]

  @type t :: %__MODULE__{patterns: [atom()], reason: term()}

  @doc "The error as a sentence, naming the patterns and the engine's reason."
  @spec message(t()) :: String.t()
  @impl Exception
  def message(%__MODULE__{patterns: patterns, reason: reason}) do
    "the regex engine stopped with #{inspect(reason)} while scanning for " <>
      Enum.map_join(patterns, ", ", &inspect/1) <> ", so the text was not fully scanned"
  end
end
