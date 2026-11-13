defmodule PiiCatalog.Match do
  @moduledoc """
  One match in a text.

    * `name` – the pattern that matched, such as `:iban`.
    * `value` – the matched bytes. For a pattern that requires a keyword
      before the value (`:format_with_context`), the keyword is not part of
      it.
    * `offset` – where the match starts, in bytes from the start of the
      text.
    * `length` – its length in bytes.

  Offsets and lengths are in bytes, not characters, because the patterns
  match bytewise. `binary_part(text, match.offset, match.length) ==
  match.value`.
  """

  @enforce_keys [:name, :value, :offset, :length]
  defstruct [:name, :value, :offset, :length]

  @type t :: %__MODULE__{
          name: atom(),
          value: binary(),
          offset: non_neg_integer(),
          length: non_neg_integer()
        }
end
