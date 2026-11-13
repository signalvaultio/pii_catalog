defmodule PiiCatalog.Patterns do
  @moduledoc """
  The catalog itself: every identifier as a `PiiCatalog.Pattern`.

  This module is for maintainers and for readers who want to audit a regex.
  Use `PiiCatalog.patterns/0` and the other functions in `PiiCatalog` to
  read the catalog.

  ## Adding a pattern

  1. An entry below. Its `name` is final once released, as callers store it.
     Use `<identifier>_<country>` in lowercase ASCII, the identifier in its
     local name and the country as its ISO 3166 code (`personnummer_se`,
     `nino_gb`); no country for an identifier used across borders (`iban`).
  2. A validator in `PiiCatalog.Validators` where the identifier has a check
     digit or a structure the regex cannot express, with unit tests.
  3. A vector file in `test/vectors/<name>.exs` with valid values, values
     with the right shape that fail the check, and look-alikes. The catalog
     test fails without one.
  4. A benchmark with every pattern on, on prose and on number-heavy text,
     noted in the pull request. See "Scan cost" below.
  5. A line in `CHANGELOG.md` naming the identifier, and the
     `pii_catalog.readme` Mix task run to regenerate the README table.

  ## Boundaries

  Patterns are compiled without the `u` flag so that they match bytewise and
  hold on text that is not valid UTF-8. `\\b` then reads each byte as
  Latin-1, so the bytes of a non-ASCII character next to a value would count
  as word characters and the boundary would not be seen. The boundary
  fragments below ask only about ASCII word characters (`A-Z`, `a-z`, `0-9`
  and `_`): a value directly after or before any other byte, including the
  bytes of a non-ASCII letter, is found.

  Where the pattern itself begins or ends with a word character, half of the
  boundary is already given and only the other half is asserted. The one
  lookaround keeps the scan several times cheaper than the two-sided form,
  which is needed only where the neighbouring character may be punctuation:
  the start of an email address.

  ## Scan cost

  `PiiCatalog.Scanner` scans every pattern that starts with
  `(?<![A-Za-z0-9_])` and then a digit or a capital letter in one shared
  pass, so such a pattern adds little to the scan. A pattern that cannot
  start that way should start with a literal or a keyword with a single
  first letter (`cpr`, `national`), which the regex engine finds without
  trying every position; a keyword with several first letters, or a leading
  character class, costs a full pass of its own. A literal every match
  contains goes in `requires`, and the pattern is skipped on text without
  it. A keyword-led pattern whose keywords start with different letters
  lists one fast regex per letter in `requires` instead (`svnr_at`,
  `nif_pt`).
  """

  alias PiiCatalog.Pattern

  # A letter written as two bytes of UTF-8 (U+00C0 to U+07FF): the accented
  # Latin letters, Greek, Cyrillic, Hebrew and Arabic, which are written
  # with spaces between words. `\\xC2` (U+0080 to U+00BF) is punctuation
  # and symbols, such as `«` and the no-break space, and is left out.
  # Scripts written in three bytes are left out too: Chinese and Japanese
  # put no space between words, so a letter class with them would take the
  # sentence around an address into it.
  @two_byte_letter "[\\xC3-\\xDF][\\x80-\\xBF]"

  # A word boundary on either side, with a two-byte letter counted as a word
  # character. On ASCII text it is the same boundary as an ASCII `\\b`. It
  # does not start with the shared prefix: email is scanned on its own.
  @email_word "(?:[A-Za-z0-9_]|#{@two_byte_letter})"
  @email_start "(?:(?<!#{@two_byte_letter})(?<![A-Za-z0-9_])(?=#{@email_word})|(?<=[A-Za-z0-9_]|#{@two_byte_letter})(?!#{@email_word}))"
  # The local part takes RFC 5322's atext except / ? = & (letters, digits
  # and ! # $ % ' * + - ^ _ ` { | } ~) and the dot, so `o'brien@` is
  # matched from its first character. / ? = & are left out because they
  # join an address to a URL or a query string: in
  # `https://example.com/u/anna@example.com` and `?token=x&email=anna@…`
  # the match is the address alone. An address with one of them before
  # the @ is matched from after the last one (`a/b@` as `b@`). The match
  # starts at a word boundary, so a run of these symbols before the first
  # letter or digit is left out.
  @email_local "(?:[A-Za-z0-9!#$%'*+^_`{|}~.-]|#{@two_byte_letter})"
  @not_after_ascii_word "(?<![A-Za-z0-9_])"
  @not_before_ascii_word "(?![A-Za-z0-9_])"

  # The pattern names in catalog order. Each pattern is built by its own
  # clause of build/1, so that one pattern can be built without the rest.
  @names [
    :email,
    :phone_us,
    :phone_intl,
    :ssn,
    :credit_card,
    :iban,
    :ip_address,
    :date_of_birth,
    :cpr_dk,
    :hetu_fi,
    :kennitala_is,
    :fodselsnummer_no,
    :personnummer_se,
    :svnr_at,
    :rrn_be,
    :steuer_id_de,
    :isikukood_ee,
    :dni_es,
    :nie_es,
    :nir_fr,
    :ppsn_ie,
    :codice_fiscale_it,
    :bsn_nl,
    :pesel_pl,
    :nif_pt,
    :vat_eu,
    :ahv_ch,
    :nino_gb,
    :nhs_gb
  ]

  @doc """
  Every pattern, in catalog order, with its regex compiled.

  Builds the list on each call. Use `PiiCatalog.compile/1` once and keep
  the scanner rather than calling this on every scan.
  """
  @spec all() :: [Pattern.t()]
  def all, do: Enum.map(@names, &build/1)

  @doc "Every pattern name, in catalog order."
  @spec names() :: [atom(), ...]
  def names, do: @names

  @doc """
  The pattern with this name, with its regex compiled, or `nil`. Builds
  only that pattern.
  """
  @spec get(atom()) :: Pattern.t() | nil
  def get(name) when name in @names, do: build(name)
  def get(_name), do: nil

  defp build(:email) do
    %Pattern{
      name: :email,
      label: "Email address",
      short_label: "Email",
      plural: "email addresses",
      # Bounded by RFC 5321's limits: at most 64 characters before the @,
      # and a domain of at most 253. The local part is possessive: giving
      # characters back never puts an @ after it. Once the local part ends
      # at an @ whose domain fails, or at a character that is neither, every
      # start inside it ends there too and fails the same way, so (*SKIP)
      # resumes the scan after it. That keeps the scan linear in the text.
      # In a shared pass (*SKIP) would also skip the positions where other
      # patterns start, so this pattern must run in its own pass (see
      # PiiCatalog.Scanner).
      regex:
        ~r/#{@email_start}#{@email_local}{1,64}+(?:@(*SKIP)(?:[A-Za-z0-9.-]|#{@two_byte_letter}){1,250}\.(?:[A-Za-z]|#{@two_byte_letter}){2,63}#{@not_before_ascii_word}|(?!#{@email_local})(*SKIP)(*FAIL))/,
      regions: [:global],
      confidence: :format,
      requires: "@",
      example: "anna.berg@example.com"
    }
  end

  defp build(:phone_us) do
    %Pattern{
      name: :phone_us,
      label: "US phone number",
      short_label: "US phone",
      plural: "phone numbers",
      regex: ~r/#{@not_after_ascii_word}\d{3}[-. ]?\d{3}[-. ]?\d{4}#{@not_before_ascii_word}/,
      regions: [:us],
      confidence: :checksum,
      validator: :nanp_phone,
      check: :structure,
      example: "212-555-0123",
      notes:
        "Ten digits, optionally separated by -, . or a space. The area code and exchange cannot start with 0 or 1."
    }
  end

  defp build(:phone_intl) do
    %Pattern{
      name: :phone_intl,
      label: "International phone number",
      short_label: "International phone",
      plural: "phone numbers",
      # The lookbehind after the + keeps the literal first, which the regex
      # engine finds quickly, and refuses an ASCII word character before it.
      regex: ~r/\+(?<![A-Za-z0-9_]\+)[1-9]\d{6,14}#{@not_before_ascii_word}/,
      regions: [:global],
      confidence: :format,
      example: "+46701740605",
      notes: "E.164: + and 7 to 15 digits, without spaces."
    }
  end

  defp build(:ssn) do
    %Pattern{
      name: :ssn,
      label: "US Social Security number",
      short_label: "SSN",
      plural: "US social security numbers",
      regex: ~r/#{@not_after_ascii_word}\d{3}-\d{2}-\d{4}#{@not_before_ascii_word}/,
      regions: [:us],
      confidence: :checksum,
      validator: :ssn_structure,
      check: :structure,
      example: "123-45-6789",
      notes:
        "Written with dashes. Numbers that are never issued (area 000 or 666, group 00, serial 0000) are ignored. ITINs (area 900 to 999 with an ITIN group) are included."
    }
  end

  defp build(:credit_card) do
    %Pattern{
      name: :credit_card,
      label: "Payment card number",
      short_label: "Card number",
      plural: "payment card numbers",
      regex:
        ~r/#{@not_after_ascii_word}(?:4\d{3}|5[1-5]\d{2}|3[47]\d{2}|6(?:011|5\d{2}))[- ]?\d{4}[- ]?\d{4}[- ]?\d{1,4}#{@not_before_ascii_word}/,
      regions: [:global],
      confidence: :checksum,
      validator: :luhn,
      check: :check_digit,
      example: "4111 1111 1111 1111",
      notes:
        "Visa, Mastercard, American Express and Discover numbers, with or without spaces or dashes, confirmed by the Luhn check digit."
    }
  end

  defp build(:iban) do
    %Pattern{
      name: :iban,
      label: "IBAN (bank account number)",
      short_label: "IBAN",
      plural: "bank account numbers (IBAN)",
      # One alternative per IBAN length: see iban_alternatives/0.
      regex:
        ~r/#{@not_after_ascii_word}(?=[A-Z]{2}\d{2})(?:#{iban_alternatives()})#{@not_before_ascii_word}/,
      regions: [:global, :eu],
      confidence: :checksum,
      validator: :iban,
      check: :check_digit,
      example: "DE89 3704 0044 0532 0130 00",
      notes:
        "Account numbers from the SEPA countries, written in capitals, as one run or in groups of four."
    }
  end

  defp build(:ip_address) do
    %Pattern{
      name: :ip_address,
      label: "IPv4 address",
      short_label: "IP address",
      plural: "IP addresses",
      regex: ~r/#{@not_after_ascii_word}(?:\d{1,3}\.){3}\d{1,3}#{@not_before_ascii_word}/,
      regions: [:global],
      confidence: :checksum,
      validator: :ip_octets,
      check: :structure,
      example: "192.0.2.10",
      notes: "Four numbers from 0 to 255."
    }
  end

  defp build(:date_of_birth) do
    %Pattern{
      name: :date_of_birth,
      label: "Date of birth",
      short_label: "Date of birth",
      plural: "dates of birth",
      regex:
        ~r/#{@not_after_ascii_word}(?:dob|date[ \t]+of[ \t]+birth|born[ \t]+on|birthday)[: \t]+\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}#{@not_before_ascii_word}/i,
      regions: [:global],
      confidence: :format,
      keyword_required: true,
      example: "DOB: 12/04/1985",
      notes: "A date written after \"DOB\", \"date of birth\", \"born on\" or \"birthday\"."
    }
  end

  defp build(:cpr_dk) do
    %Pattern{
      name: :cpr_dk,
      label: "Danish CPR number",
      short_label: "Danish CPR",
      plural: "Nordic personal identity numbers",
      # \K starts the match at the number, so only the number is redacted.
      # The word and the number must be on one line.
      #
      # Every run of blanks is possessive (`[ \t]*+`, `[ \t]++`): it takes
      # all the blanks and gives none back. What follows a run is never a
      # blank, or is another run that would take the same blanks, so this
      # matches the same strings. With backtracking runs, a keyword followed
      # by thousands of blanks made the engine try every way of splitting
      # them between the runs, which took time quadratic in their number
      # and, past a few thousand, hit the engine's match limit. The same
      # holds for every keyword pattern below and for svnr_at's `requires`.
      regex:
        ~r/#{@not_after_ascii_word}(?i:cpr)(?:[ \t]*+[.-]?[ \t]*+(?i:nummer|nr|no)\.?)?[ \t]*+[:#]?[ \t]*+\K\d{6}-?\d{4}#{@not_before_ascii_word}/,
      regions: [:nordics, :eu, :dk],
      confidence: :format_with_context,
      keyword_required: true,
      validator: :cpr_dk,
      check: :structure,
      example: "CPR-nr. 070761-4285",
      notes:
        "DDMMYY-NNNN after CPR, CPR-nr. or CPR-nummer on the same line. Since 2007 a Danish number is not guaranteed to pass the modulus-11 check, so a number on its own is not matched."
    }
  end

  defp build(:hetu_fi) do
    %Pattern{
      name: :hetu_fi,
      label: "Finnish personal identity code (henkilötunnus)",
      short_label: "Finnish HETU",
      plural: "Nordic personal identity numbers",
      regex:
        ~r/#{@not_after_ascii_word}\d{6}[-+A-FU-Y]\d{3}[0-9A-FHJ-NPR-Y]#{@not_before_ascii_word}/,
      regions: [:nordics, :eu, :fi],
      confidence: :checksum,
      validator: :hetu_fi,
      check: :check_digit,
      example: "131052-308T",
      notes:
        "DDMMYY, a century sign, three digits and a check character, in capitals. Includes the century signs added in 2023."
    }
  end

  defp build(:kennitala_is) do
    %Pattern{
      name: :kennitala_is,
      label: "Icelandic kennitala",
      short_label: "Icelandic kennitala",
      plural: "Nordic personal identity numbers",
      # Numbers issued since 18 February 2026 have no check digit. The
      # date and century digit alone pass about one ten-digit run in 85,
      # so a word naming it must come first on the same line. See cpr_dk
      # for \K and the possessive runs of blanks.
      regex:
        ~r/#{@not_after_ascii_word}(?i:kennit(?:ala|\xC3[\xB6\x96]lu)|kt)\.?[ \t]*+[:#]?[ \t]*+\K\d{6}-?\d{4}#{@not_before_ascii_word}/,
      regions: [:nordics, :is],
      confidence: :format_with_context,
      keyword_required: true,
      validator: :kennitala_is,
      check: :structure,
      example: "Kennitala 150385-2029",
      notes:
        "DDMMYY-NNNN or ten digits after kennitala, kennitölu or kt. on the same line, ending in a century digit (8, 9 or 0). Numbers issued since 18 February 2026 have no check digit, so none is checked. A person's number only: company numbers are not matched."
    }
  end

  defp build(:fodselsnummer_no) do
    %Pattern{
      name: :fodselsnummer_no,
      label: "Norwegian national identity number (fødselsnummer)",
      short_label: "Norwegian fødselsnummer",
      plural: "Nordic personal identity numbers",
      regex: ~r/#{@not_after_ascii_word}\d{6} ?\d{5}#{@not_before_ascii_word}/,
      regions: [:nordics, :no],
      confidence: :checksum,
      validator: :fodselsnummer_no,
      check: :check_digit,
      example: "01058512326",
      notes: "Eleven digits, optionally with a space after the date. D-nummer included."
    }
  end

  defp build(:personnummer_se) do
    %Pattern{
      name: :personnummer_se,
      label: "Swedish personal identity number (personnummer)",
      short_label: "Swedish personnummer",
      plural: "Nordic personal identity numbers",
      regex:
        ~r/#{@not_after_ascii_word}(?:(?:19|20)\d{6}-?|\d{6}[-+])\d{4}#{@not_before_ascii_word}/,
      regions: [:nordics, :eu, :se],
      confidence: :checksum,
      validator: :personnummer_se,
      check: :check_digit,
      example: "811218-9876",
      notes:
        "YYMMDD-NNNN (+ from age 100) or with the century, YYYYMMDD-NNNN or twelve digits. Samordningsnummer included. Ten digits are matched only with the - or +."
    }
  end

  defp build(:svnr_at) do
    %Pattern{
      name: :svnr_at,
      label: "Austrian social security number (SVNR)",
      short_label: "Austrian SVNR",
      plural: "EU national identity and tax numbers",
      # The check rules out ten numbers in eleven, too few for ten-digit
      # phone and order numbers, so a word naming it must come first on the
      # same line. See cpr_dk for \K and the possessive runs of blanks.
      regex:
        ~r/#{@not_after_ascii_word}(?i:svnr|vsnr|sv[ \t]*+-?[ \t]*+(?:nr\.?|nummer)|(?:sozial)?versicherungsnummer)[ \t]*+[:#]?[ \t]*+\K[1-9]\d{3} ?\d{6}#{@not_before_ascii_word}/,
      regions: [:eu, :at],
      confidence: :format_with_context,
      keyword_required: true,
      validator: :svnr_at,
      check: :check_digit,
      # The keywords start with S or V; one regex each is fast to scan.
      requires: [
        ~r/(?i:s(?:vnr|v[ \t]*+-?[ \t]*+n|ozialversicherungsnummer))/,
        ~r/(?i:v(?:snr|ersicherungsnummer))/
      ],
      example: "SVNR 2748 140379",
      notes:
        "Four digits and the date of birth after SVNR, VSNR, SV-Nr., SV-Nummer or (Sozial)versicherungsnummer on the same line, with its check digit."
    }
  end

  defp build(:rrn_be) do
    %Pattern{
      name: :rrn_be,
      label: "Belgian national register number",
      short_label: "Belgian national number",
      plural: "EU national identity and tax numbers",
      regex:
        ~r/#{@not_after_ascii_word}(?:\d{2}\.\d{2}\.\d{2}-\d{3}\.\d{2}|\d{11})#{@not_before_ascii_word}/,
      regions: [:eu, :be],
      confidence: :checksum,
      validator: :rrn_be,
      check: :check_digit,
      example: "79.11.04-215.43",
      notes:
        "YY.MM.DD-NNN.CC or eleven digits, with a month from 00 (unknown) to 12 and the mod-97 check digits (with a 2 in front for people born from 2000)."
    }
  end

  defp build(:steuer_id_de) do
    %Pattern{
      name: :steuer_id_de,
      label: "German tax ID (Steuer-ID)",
      short_label: "German Steuer-ID",
      plural: "EU national identity and tax numbers",
      regex: ~r/#{@not_after_ascii_word}\d{2} ?\d{3} ?\d{3} ?\d{3}#{@not_before_ascii_word}/,
      regions: [:eu, :de],
      confidence: :checksum,
      validator: :steuer_id_de,
      check: :check_digit,
      example: "86 095 742 719",
      notes:
        "Eleven digits, optionally grouped 2-3-3-3. One digit appears two or three times in the first ten, and the last is a check digit."
    }
  end

  defp build(:isikukood_ee) do
    %Pattern{
      name: :isikukood_ee,
      label: "Estonian personal identification code (isikukood)",
      short_label: "Estonian isikukood",
      plural: "EU national identity and tax numbers",
      # A word naming it must come first on the same line. See cpr_dk for
      # \K and the possessive runs of blanks.
      regex:
        ~r/#{@not_after_ascii_word}(?i:isikukood(?:i(?:ga)?)?)[ \t]*+[:#]?[ \t]*+\K[3-6]\d{10}#{@not_before_ascii_word}/,
      regions: [:eu, :ee],
      confidence: :format_with_context,
      keyword_required: true,
      validator: :isikukood_ee,
      check: :check_digit,
      example: "Isikukood 38507300124",
      notes:
        "Eleven digits after isikukood, isikukoodi or isikukoodiga on the same line: century and sex (3 to 6), a date of birth no later than today, a serial of three digits and a check digit."
    }
  end

  defp build(:dni_es) do
    %Pattern{
      name: :dni_es,
      label: "Spanish national identity number (DNI)",
      short_label: "Spanish DNI",
      plural: "EU national identity and tax numbers",
      regex: ~r/#{@not_after_ascii_word}\d{8}[- ]?[A-Z]#{@not_before_ascii_word}/,
      regions: [:eu, :es],
      confidence: :checksum,
      validator: :dni_es,
      check: :check_digit,
      example: "12345678Z",
      notes:
        "Eight digits and a check letter, in capitals. Also the Spanish tax number (NIF) of a person."
    }
  end

  defp build(:nie_es) do
    %Pattern{
      name: :nie_es,
      label: "Spanish foreigner identity number (NIE)",
      short_label: "Spanish NIE",
      plural: "EU national identity and tax numbers",
      regex: ~r/#{@not_after_ascii_word}[XYZ][- ]?\d{7}[- ]?[A-Z]#{@not_before_ascii_word}/,
      regions: [:eu, :es],
      confidence: :checksum,
      validator: :nie_es,
      check: :check_digit,
      example: "X1234567L",
      notes: "X, Y or Z, seven digits and a check letter, in capitals."
    }
  end

  defp build(:nir_fr) do
    %Pattern{
      name: :nir_fr,
      label: "French social security number (NIR)",
      short_label: "French NIR",
      plural: "EU national identity and tax numbers",
      regex:
        ~r/#{@not_after_ascii_word}[12] ?\d{2} ?\d{2} ?(?:\d{2}|2[AB]) ?\d{3} ?\d{3} ?\d{2}#{@not_before_ascii_word}/,
      regions: [:eu, :fr],
      confidence: :checksum,
      validator: :nir_fr,
      check: :check_digit,
      example: "2 84 12 76 451 089 93",
      notes:
        "Fifteen digits with the key, spaced or not, starting with 1 or 2; 2A and 2B for Corsica."
    }
  end

  defp build(:ppsn_ie) do
    %Pattern{
      name: :ppsn_ie,
      label: "Irish PPS number",
      short_label: "Irish PPSN",
      plural: "EU national identity and tax numbers",
      regex: ~r/#{@not_after_ascii_word}\d{7}[A-W][ABHWTX]?#{@not_before_ascii_word}/,
      regions: [:eu, :ie],
      confidence: :checksum,
      validator: :ppsn_ie,
      check: :check_digit,
      example: "1234567T",
      notes:
        "Seven digits and a check letter, optionally followed by A, B, H, W, T or X, in capitals."
    }
  end

  defp build(:codice_fiscale_it) do
    %Pattern{
      name: :codice_fiscale_it,
      label: "Italian tax code (codice fiscale)",
      short_label: "Italian codice fiscale",
      plural: "EU national identity and tax numbers",
      regex:
        ~r/#{@not_after_ascii_word}[A-Z]{6}[0-9L-NP-V]{2}[ABCDEHLMPRST][0-9L-NP-V]{2}[A-Z][0-9L-NP-V]{3}[A-Z]#{@not_before_ascii_word}/,
      regions: [:eu, :it],
      confidence: :checksum,
      validator: :codice_fiscale_it,
      check: :check_digit,
      example: "RSSMRA85T10A562S",
      notes:
        "Sixteen characters in capitals. Codes where letters stand in for digits (omocodia) included."
    }
  end

  defp build(:bsn_nl) do
    %Pattern{
      name: :bsn_nl,
      label: "Dutch citizen service number (BSN)",
      short_label: "Dutch BSN",
      plural: "EU national identity and tax numbers",
      # The 11-proef passes one nine-digit number in eleven, too many for
      # order and account numbers, so BSN or burgerservicenummer must come
      # first on the same line. See cpr_dk for \K and the possessive runs of
      # blanks.
      regex:
        ~r/#{@not_after_ascii_word}(?i:bsn(?:[ \t]*+-?[ \t]*+nummer)?|burgerservicenummer)[ \t]*+[:#.]?[ \t]*+\K(?:\d{9}|\d{4}\.\d{2}\.\d{3}|\d{3}[ .]\d{3}[ .]\d{3})#{@not_before_ascii_word}/,
      regions: [:eu, :nl],
      confidence: :format_with_context,
      keyword_required: true,
      validator: :bsn_nl,
      check: :check_digit,
      example: "BSN 111222333",
      notes:
        "Nine digits after BSN, BSN-nummer or burgerservicenummer on the same line, passing the 11-proef."
    }
  end

  defp build(:pesel_pl) do
    %Pattern{
      name: :pesel_pl,
      label: "Polish PESEL number",
      short_label: "Polish PESEL",
      plural: "EU national identity and tax numbers",
      regex: ~r/#{@not_after_ascii_word}\d{11}#{@not_before_ascii_word}/,
      regions: [:eu, :pl],
      confidence: :checksum,
      validator: :pesel_pl,
      check: :check_digit,
      example: "85073012341",
      notes:
        "Eleven digits: a date of birth from 1900 to today (the century in the month), a serial and a check digit."
    }
  end

  defp build(:nif_pt) do
    %Pattern{
      name: :nif_pt,
      label: "Portuguese tax number (NIF)",
      short_label: "Portuguese NIF",
      plural: "EU national identity and tax numbers",
      # The mod-11 check digit reads a remainder of 10 as 0, so one
      # nine-digit number in ten passes: a word naming it must come first
      # on the same line. See cpr_dk for \K and the possessive runs of
      # blanks.
      regex:
        ~r/#{@not_after_ascii_word}(?i:n\.?i\.?f\.?|nipc|contribuinte)(?:[ \t]*+(?i:n)\.?[ \t]*+(?:º|°|o)\.?)?[ \t]*+[:#.]?[ \t]*+\K(?:\d{9}|\d{3} \d{3} \d{3})#{@not_before_ascii_word}/,
      regions: [:eu, :pt],
      confidence: :format_with_context,
      keyword_required: true,
      validator: :nif_pt,
      check: :check_digit,
      # The keywords start with N or C; one regex each is fast to scan.
      requires: [~r/(?i:n\.?i(?:\.?f|pc))/, ~r/(?i:contribuinte)/],
      example: "NIF 123456789",
      notes:
        "Nine digits after NIF, NIPC or contribuinte (optionally followed by n.º) on the same line, with the mod-11 check digit."
    }
  end

  defp build(:vat_eu) do
    %Pattern{
      name: :vat_eu,
      label: "EU VAT number",
      short_label: "EU VAT",
      plural: "EU VAT numbers",
      # The country prefix, an optional space and the national number in
      # its compact form. The leading lookahead rejects most positions on
      # their first two letters before the 27 alternatives are tried.
      # Romanian numbers have two to ten digits; fewer than six are left
      # out, as RO and a few digits is common in other codes.
      regex:
        ~r/#{@not_after_ascii_word}(?=[A-IL-PRS][EGIKLORS-VYZ])(?:AT ?U\d{8}|BE ?[01]\d{9}|BG ?\d{9,10}|CY ?\d{8}[A-Z]|CZ ?\d{8,10}|DE ?\d{9}|DK ?\d{8}|EE ?\d{9}|EL ?\d{9}|ES ?[0-9A-Z]\d{7}[0-9A-Z]|FI ?\d{8}|FR ?[0-9A-HJ-NP-Z]{2}\d{9}|HR ?\d{11}|HU ?\d{8}|IE ?(?:\d{7}[A-W][A-W]?|\d[A-Z+*]\d{5}[A-W])|IT ?\d{11}|LT ?(?:\d{9}|\d{12})|LU ?\d{8}|LV ?\d{11}|MT ?\d{8}|NL ?\d{9}B\d{2}|PL ?\d{10}|PT ?\d{9}|RO ?[1-9]\d{5,9}|SE ?\d{12}|SI ?\d{8}|SK ?\d{10})#{@not_before_ascii_word}/,
      regions: [:eu],
      confidence: :checksum,
      validator: :vat_eu,
      check: :mixed,
      example: "DE452325818",
      notes:
        "The 27 member states' VAT numbers with their country prefix (EL for Greece), in capitals, optionally with a space after the prefix. Each is confirmed by the check its country publishes; where none is published, by its format."
    }
  end

  defp build(:ahv_ch) do
    %Pattern{
      name: :ahv_ch,
      label: "Swiss social security number (AHV/AVS)",
      short_label: "Swiss AHV",
      plural: "Swiss social security numbers (AHV)",
      regex:
        ~r/#{@not_after_ascii_word}756(?:\.\d{4}\.\d{4}\.\d{2}|\d{10})#{@not_before_ascii_word}/,
      regions: [:ch],
      confidence: :checksum,
      validator: :ahv_ch,
      check: :check_digit,
      example: "756.1234.5678.97",
      notes: "756 and ten digits, dotted or as one run, with the EAN-13 check digit."
    }
  end

  defp build(:nino_gb) do
    %Pattern{
      name: :nino_gb,
      label: "UK National Insurance number",
      short_label: "UK NINO",
      plural: "UK National Insurance numbers",
      # The format is shared with many product and reference codes, so a
      # word naming it must come first on the same line. See cpr_dk for \K
      # and the possessive runs of blanks.
      regex:
        ~r/#{@not_after_ascii_word}(?i:national[ \t]++insurance(?:[ \t]++(?:number|no\.?))?|ni[ \t]*+(?:number|no\.?)|nino)[ \t]*+[:#]?[ \t]*+\K[A-Z]{2} ?\d{2} ?\d{2} ?\d{2} ?[A-D]#{@not_before_ascii_word}/,
      regions: [:gb],
      confidence: :format_with_context,
      keyword_required: true,
      validator: :nino_gb,
      check: :structure,
      example: "NI number: AB 12 34 56 C",
      notes:
        "Two letters, six digits and A to D after National Insurance, NI number, NI no. or NINO on the same line. Prefixes that are never issued are ignored."
    }
  end

  defp build(:nhs_gb) do
    %Pattern{
      name: :nhs_gb,
      label: "UK NHS number",
      short_label: "UK NHS number",
      plural: "UK NHS numbers",
      # The mod-11 check passes one ten-digit number in eleven, too many for
      # phone numbers, so NHS must come first on the same line. See cpr_dk
      # for \K and the possessive runs of blanks.
      regex:
        ~r/#{@not_after_ascii_word}(?i:nhs)(?:[ \t]++(?i:number|no\.?))?[ \t]*+[:#]?[ \t]*+\K\d{3}[ -]?\d{3}[ -]?\d{4}#{@not_before_ascii_word}/,
      regions: [:gb],
      confidence: :format_with_context,
      keyword_required: true,
      validator: :nhs_gb,
      check: :check_digit,
      example: "NHS number 943 476 5919",
      notes:
        "Ten digits, optionally 3-3-4, after NHS, NHS number or NHS no. on the same line, with the mod-11 check digit."
    }
  end

  # One alternative for each IBAN length in the SEPA countries, with the
  # countries of that length: the country, its check digits, and the rest
  # of the length as one run or in groups of four with a shorter last
  # group (`NO93 8601 1117 947`). With an exact length, a token after the
  # IBAN (`BIC`, `EUR`, a four-letter word) is never taken into the match.
  # A range of lengths would take it, the match would then fail the length
  # check, and the scan does not go back to a shorter match.
  defp iban_alternatives do
    PiiCatalog.Validators.iban_lengths()
    |> Enum.group_by(fn {_country, length} -> length end, fn {country, _} -> country end)
    |> Enum.sort()
    |> Enum.map_join("|", fn {length, countries} ->
      rest = length - 4
      last = if rem(rest, 4) > 0, do: " [A-Z0-9]{#{rem(rest, 4)}}", else: ""
      spaced = "(?: [A-Z0-9]{4}){#{div(rest, 4)}}" <> last
      "(?:#{countries |> Enum.sort() |> Enum.join("|")})\\d{2}(?:[A-Z0-9]{#{rest}}|#{spaced})"
    end)
  end
end
