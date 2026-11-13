defmodule PiiCatalog.Pattern do
  @moduledoc """
  One identifier in the catalog: a regex that finds values of its shape, and
  the check a value must pass before it counts.

  ## Fields

    * `name` – the stable identifier, an atom such as `:iban` or
      `:personnummer_se`. Once a pattern is released its name never changes,
      so it can be stored.
    * `label`, `short_label`, `plural` – how to name it in a full sentence
      ("US Social Security number"), in a compact list ("SSN") and in running
      text ("US social security numbers").
    * `regex` – finds candidate values. Compiled without the `u` flag, so it
      matches bytewise; see `PiiCatalog.Patterns` for the boundaries this
      implies.
    * `regions` – where the identifier is used, as region atoms
      (`PiiCatalog.regions/0`). The first is the region it is listed under.
    * `confidence` – how a match is confirmed:
      * `:checksum` – a validator confirms the value (a check digit or a
        structure the regex cannot express);
      * `:format` – the regex alone decides;
      * `:format_with_context` – the identifier has no check digit, or one
        too weak on its own, so the regex also requires a word naming it
        directly before the value, and starts the match after that word with
        `\\K`. The validator still runs on the value.
    * `check` – what the validator checks: `:check_digit` (a check digit,
      letter or character computed from the rest of the value),
      `:structure` (a structure only, such as a date of birth or ranges that
      are never issued, with no check digit), `:mixed` (a check digit for
      some values and a structure only for others, as for EU VAT numbers,
      where some member states' numbers have no check), or `nil` (no
      validator).
    * `keyword_required` – `true` when the regex matches only directly
      after a word naming the identifier. That is every
      `:format_with_context` pattern, where the word is not part of the
      match, and `:date_of_birth`, where it is.
    * `validator` – the name of the check in `PiiCatalog.Validators`, or
      `nil` when the format alone decides.
    * `requires` – what a text must contain for the pattern to be scanned at
      all: a literal every match contains (`"@"`), or a list of regexes, one
      of which every text holding a match also matches. `nil` means always
      scan.
    * `example` – a test or invented value, never a real person's. For a
      `:format_with_context` pattern it includes the keyword.
    * `notes` – what the regex accepts, in a sentence or two.
  """

  @enforce_keys [:name, :label, :short_label, :plural, :regex, :regions, :confidence, :example]
  defstruct [
    :name,
    :label,
    :short_label,
    :plural,
    :regex,
    :regions,
    :confidence,
    :example,
    :notes,
    check: nil,
    keyword_required: false,
    validator: nil,
    requires: nil
  ]

  @type confidence :: :checksum | :format | :format_with_context
  @type check :: :check_digit | :mixed | :structure | nil

  @type t :: %__MODULE__{
          name: atom(),
          label: String.t(),
          short_label: String.t(),
          plural: String.t(),
          regex: Regex.t(),
          regions: [atom(), ...],
          confidence: confidence(),
          check: check(),
          keyword_required: boolean(),
          example: String.t(),
          notes: String.t() | nil,
          validator: atom() | nil,
          requires: String.t() | [Regex.t()] | nil
        }
end
