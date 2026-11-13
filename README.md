# PiiCatalog

Regexes and validators for 29 personal identifiers: email addresses, phone numbers, payment cards, IBANs, IP addresses, dates of birth, EU VAT numbers, and national identity, tax and social security numbers from 18 European countries and the US.
Each value a regex finds is confirmed by a check digit or structure check where the identifier has one, and a scanner finds them in a text, most of them in one shared regex pass.
No processes, no state and no runtime dependencies: nothing is started, cached or logged.

```elixir
Mix.install([{:pii_catalog, "~> 0.1"}])

scanner = PiiCatalog.compile()
PiiCatalog.find(scanner, "Pay to DE89 3704 0044 0532 0130 00 by Friday")
#=> [%PiiCatalog.Match{name: :iban, value: "DE89 3704 0044 0532 0130 00", offset: 7, length: 27}]
```

## Identifiers

"Checked" is what a candidate must pass after the regex finds it. "Keyword" says whether the regex matches only directly after a word naming the identifier. Each vector file holds values that must be found, values of the right shape that fail the check, and look-alikes that must not be found.

<!-- generated:identifiers -->
| Name | Identifier | Regions | Checked | Keyword | Vectors |
| --- | --- | --- | --- | --- | --- |
| `email` | Email address | Global | Format only | no | [email.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/email.exs) |
| `phone_us` | US phone number | United States | Structure only: Area code and exchange that can exist | no | [phone_us.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/phone_us.exs) |
| `phone_intl` | International phone number | Global | Format only | no | [phone_intl.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/phone_intl.exs) |
| `ssn` | US Social Security number | United States | Structure only: Excludes numbers never issued | no | [ssn.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/ssn.exs) |
| `credit_card` | Payment card number | Global | Check digit: Luhn check digit | no | [credit_card.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/credit_card.exs) |
| `iban` | IBAN (bank account number) | Global, European Union | Check digit: Length for the country and mod-97 check digits | no | [iban.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/iban.exs) |
| `ip_address` | IPv4 address | Global | Structure only: Each part 0–255 | no | [ip_address.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/ip_address.exs) |
| `date_of_birth` | Date of birth | Global | Format only | required, part of the match | [date_of_birth.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/date_of_birth.exs) |
| `cpr_dk` | Danish CPR number | Nordics, European Union, Denmark | Structure only: Date of birth, after the word CPR | required | [cpr_dk.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/cpr_dk.exs) |
| `hetu_fi` | Finnish personal identity code (henkilötunnus) | Nordics, European Union, Finland | Check digit: Date of birth and check character | no | [hetu_fi.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/hetu_fi.exs) |
| `kennitala_is` | Icelandic kennitala | Nordics, Iceland | Structure only: Date of birth and century digit, after the word kennitala | required | [kennitala_is.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/kennitala_is.exs) |
| `fodselsnummer_no` | Norwegian national identity number (fødselsnummer) | Nordics, Norway | Check digit: Date of birth and two mod-11 check digits | no | [fodselsnummer_no.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/fodselsnummer_no.exs) |
| `personnummer_se` | Swedish personal identity number (personnummer) | Nordics, European Union, Sweden | Check digit: Date of birth and Luhn check digit | no | [personnummer_se.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/personnummer_se.exs) |
| `svnr_at` | Austrian social security number (SVNR) | European Union, Austria | Check digit: Check digit, after the word SVNR | required | [svnr_at.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/svnr_at.exs) |
| `rrn_be` | Belgian national register number | European Union, Belgium | Check digit: Month of birth and mod-97 check digits | no | [rrn_be.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/rrn_be.exs) |
| `steuer_id_de` | German tax ID (Steuer-ID) | European Union, Germany | Check digit: ISO 7064 check digit and digit pattern | no | [steuer_id_de.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/steuer_id_de.exs) |
| `isikukood_ee` | Estonian personal identification code (isikukood) | European Union, Estonia | Check digit: Date of birth and check digit, after the word isikukood | required | [isikukood_ee.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/isikukood_ee.exs) |
| `dni_es` | Spanish national identity number (DNI) | European Union, Spain | Check digit: Check letter (mod 23) | no | [dni_es.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/dni_es.exs) |
| `nie_es` | Spanish foreigner identity number (NIE) | European Union, Spain | Check digit: Check letter (mod 23) | no | [nie_es.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/nie_es.exs) |
| `nir_fr` | French social security number (NIR) | European Union, France | Check digit: Sex, month and mod-97 key | no | [nir_fr.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/nir_fr.exs) |
| `ppsn_ie` | Irish PPS number | European Union, Ireland | Check digit: Check letter (mod 23) | no | [ppsn_ie.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/ppsn_ie.exs) |
| `codice_fiscale_it` | Italian tax code (codice fiscale) | European Union, Italy | Check digit: Date of birth and check character | no | [codice_fiscale_it.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/codice_fiscale_it.exs) |
| `bsn_nl` | Dutch citizen service number (BSN) | European Union, Netherlands | Check digit: 11-check, after the word BSN | required | [bsn_nl.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/bsn_nl.exs) |
| `pesel_pl` | Polish PESEL number | European Union, Poland | Check digit: Date of birth and check digit | no | [pesel_pl.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/pesel_pl.exs) |
| `nif_pt` | Portuguese tax number (NIF) | European Union, Portugal | Check digit: Mod-11 check digit, after the word NIF | required | [nif_pt.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/nif_pt.exs) |
| `vat_eu` | EU VAT number | European Union | Partly check digit: Check digits in 21 member states; format only in BG, CY, EL, LV, MT and RO, for Spanish legal entities and for the French key; date only for Czech nine-digit numbers | no | [vat_eu.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/vat_eu.exs) |
| `ahv_ch` | Swiss social security number (AHV/AVS) | Switzerland | Check digit: 756 prefix and EAN-13 check digit | no | [ahv_ch.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/ahv_ch.exs) |
| `nino_gb` | UK National Insurance number | United Kingdom | Structure only: Issued prefix, after the words National Insurance | required | [nino_gb.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/nino_gb.exs) |
| `nhs_gb` | UK NHS number | United Kingdom | Check digit: Mod-11 check digit, after the word NHS | required | [nhs_gb.exs](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/vectors/nhs_gb.exs) |

<!-- /generated:identifiers -->

The table is generated from `PiiCatalog.patterns/0` by this repository's `pii_catalog.readme` Mix task; a test fails when it drifts.

## Usage

Add it to your dependencies:

```elixir
def deps do
  [{:pii_catalog, "~> 0.1"}]
end
```

Compile a scanner once and keep it. Compiling one with every pattern takes about as long as scanning a few kilobytes of text, a cost worth paying once rather than on every call; a scanner is an immutable value you can store in a process, an ETS table or `:persistent_term`.

```elixir
scanner = PiiCatalog.compile([:email, :iban, :personnummer_se])
nordics = PiiCatalog.compile(PiiCatalog.in_region(:nordics))

PiiCatalog.scan(scanner, text)  # every value of the right shape
PiiCatalog.find(scanner, text)  # only those that pass their check
PiiCatalog.valid?(:iban, "DE89 3704 0044 0532 0130 00")  #=> true
```

| Function | Returns |
| --- | --- |
| `PiiCatalog.patterns/0` | Every `%PiiCatalog.Pattern{}`, in catalog order. |
| `PiiCatalog.names/0` | Every pattern name, such as `:iban`. Names never change once released. |
| `PiiCatalog.get/1`, `fetch!/1` | One pattern by name (atom or string). |
| `PiiCatalog.regions/0`, `region_label/1` | The regions patterns are tagged with, with display names. |
| `PiiCatalog.in_region/1`, `groups/0` | The patterns tagged with a region; the patterns grouped by the region they are listed under. |
| `PiiCatalog.compile/1` | An opaque `%PiiCatalog.Scanner{}` for some or all patterns. |
| `PiiCatalog.scan/2` | Candidate matches, before validation, as `%PiiCatalog.Match{}`. |
| `PiiCatalog.find/2` | The candidates that pass their pattern's validator. |
| `PiiCatalog.valid?/2` | Whether a value passes a pattern's validator. It does not check the format. |
| `PiiCatalog.Validators` | The checks themselves: Luhn, mod 11, mod 97, ISO 7064 and the rest. |
| `PiiCatalog.ScanError` | Raised by `scan/2` and `find/2` when a text could not be scanned to the end. |

A `%PiiCatalog.Match{}` has the pattern `name`, the matched `value`, and its `offset` and `length` in bytes. `scan/2` and `find/2` report matches grouped by pattern in the order the scanner was compiled with, left to right within each pattern, with no match starting inside the previous match of the same pattern. Matches of different patterns can overlap.

`scan/2` and `find/2` raise `PiiCatalog.ScanError` when the regex engine gives up on a pattern before the end of the text: when it reaches its match limit or its recursion limit. The exception has two fields: `patterns`, the names of the patterns being scanned (for the shared pass, every pattern in it), and `reason`, the engine's error, such as `:match_limit`. The results are never silently partial: either the whole text was scanned and every match is returned, or the call raises and returns nothing. Catch the error and decide what to do with the text, such as refusing it or redacting it whole. The catalog's tests run its patterns on crafted inputs that make regexes backtrack, such as a keyword followed by thousands of spaces; a pattern of your own can still reach the limit.

## Precision

A match means a value has the shape of an identifier and passes its check. It does not mean the value was issued, belongs to anyone, or is personal data where it appears. This package makes no claim of precision or recall on real text. What follows is derived from the code; each claim has a test in [`test/limits_test.exs`](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/test/limits_test.exs).

### What a check digit proves

A check digit is computed from the rest of the value. When it matches, the value is well-formed: it was not mistyped in the ways the check catches. It does not prove that the number was issued, that it is still in use, or that it belongs to the person named next to it. Anyone can compute a valid check digit for an invented number.

Luhn, used by payment cards and the Swedish personnummer, catches every single-digit error and every swap of two adjacent digits except 09 and 90. For any body exactly one of the ten possible last digits passes, so 1 in 10 random digit strings of the right length and prefix passes. Checks with more possible check values, such as two digits mod 97 or a check letter, pass fewer random values, and several identifiers also check a date of birth, but none tells a real value from a well-formed invented one.

These identifiers have a check digit, letter or character:

<!-- generated:check_digit -->
- `credit_card`, Payment card number: Luhn check digit.
- `iban`, IBAN (bank account number): Length for the country and mod-97 check digits.
- `hetu_fi`, Finnish personal identity code (henkilötunnus): Date of birth and check character.
- `fodselsnummer_no`, Norwegian national identity number (fødselsnummer): Date of birth and two mod-11 check digits.
- `personnummer_se`, Swedish personal identity number (personnummer): Date of birth and Luhn check digit.
- `svnr_at`, Austrian social security number (SVNR): Check digit, after the word SVNR.
- `rrn_be`, Belgian national register number: Month of birth and mod-97 check digits.
- `steuer_id_de`, German tax ID (Steuer-ID): ISO 7064 check digit and digit pattern.
- `isikukood_ee`, Estonian personal identification code (isikukood): Date of birth and check digit, after the word isikukood.
- `dni_es`, Spanish national identity number (DNI): Check letter (mod 23).
- `nie_es`, Spanish foreigner identity number (NIE): Check letter (mod 23).
- `nir_fr`, French social security number (NIR): Sex, month and mod-97 key.
- `ppsn_ie`, Irish PPS number: Check letter (mod 23).
- `codice_fiscale_it`, Italian tax code (codice fiscale): Date of birth and check character.
- `bsn_nl`, Dutch citizen service number (BSN): 11-check, after the word BSN.
- `pesel_pl`, Polish PESEL number: Date of birth and check digit.
- `nif_pt`, Portuguese tax number (NIF): Mod-11 check digit, after the word NIF.
- `ahv_ch`, Swiss social security number (AHV/AVS): 756 prefix and EAN-13 check digit.
- `nhs_gb`, UK NHS number: Mod-11 check digit, after the word NHS.

<!-- /generated:check_digit -->

### Check digits for some values, structure for others

EU VAT numbers are checked by the rules each member state publishes. Six have no check here (Bulgaria, Cyprus, Greece, Latvia, Malta and Romania), so any number of their format passes, and so does any Spanish legal entity's number and any French key in front of a SIREN that passes Luhn. Czech numbers of nine digits are the birth numbers of people born before 1954, which have no check digit: only their date is checked. [SOURCES.md](SOURCES.md) lists the source for each country, and says for each of the six why it has no check.

<!-- generated:mixed -->
- `vat_eu`, EU VAT number: Check digits in 21 member states; format only in BG, CY, EL, LV, MT and RO, for Spanish legal entities and for the French key; date only for Czech nine-digit numbers.

<!-- /generated:mixed -->

### Structure only, no check digit

These are confirmed by a structure check only: a date that exists, or ranges that are never issued.

<!-- generated:structure_only -->
- `phone_us`, US phone number: Area code and exchange that can exist.
- `ssn`, US Social Security number: Excludes numbers never issued.
- `ip_address`, IPv4 address: Each part 0–255.
- `cpr_dk`, Danish CPR number: Date of birth, after the word CPR.
- `kennitala_is`, Icelandic kennitala: Date of birth and century digit, after the word kennitala.
- `nino_gb`, UK National Insurance number: Issued prefix, after the words National Insurance.

<!-- /generated:structure_only -->

A US phone number is any ten digits whose first and fourth digits are 2 to 9, which 64 in 100 ten-digit numbers are. The SSN check only refuses area 000 and 666, group 00 and serial 0000, and area 900 to 999 outside the ITIN groups. A Danish CPR number is not guaranteed to pass the modulus-11 check since 2007, and an Icelandic kennitala issued since 18 February 2026 has no check digit, so only their date is checked. These two are matched only after a word naming them.

### Format only, no validator

<!-- generated:format_only -->
- `email`, Email address: Format only.
- `phone_intl`, International phone number: E.164: + and 7 to 15 digits, without spaces.
- `date_of_birth`, Date of birth: A date written after "DOB", "date of birth", "born on" or "birthday".

<!-- /generated:format_only -->

### A context keyword is required

These match only directly after a word naming the identifier, in one of the forms listed. Between the word and the value there may be only spaces and tabs and at most one `:` or `#`; for `bsn_nl` and `nif_pt` that one character may also be a `.`. A `.` that ends an abbreviation is part of the word (`kt.`, `CPR-nr.`, `NI no.`, `SV-Nr.`, `N.I.F.`), and so is one after `Kennitala` and `kennitölu`; `NINO.` and `SVNR.` are read as `NI no.` and `SV-Nr.`. For `date_of_birth` there may be one or more spaces, tabs or colons. A keyword in another language, in another form, with other text before the value or on the line before is not seen. The keyword is not part of the match, except for `date_of_birth`.

<!-- generated:keyword -->
- `date_of_birth`, Date of birth: A date written after "DOB", "date of birth", "born on" or "birthday".
- `cpr_dk`, Danish CPR number: DDMMYY-NNNN after CPR, CPR-nr. or CPR-nummer on the same line. Since 2007 a Danish number is not guaranteed to pass the modulus-11 check, so a number on its own is not matched.
- `kennitala_is`, Icelandic kennitala: DDMMYY-NNNN or ten digits after kennitala, kennitölu or kt. on the same line, ending in a century digit (8, 9 or 0). Numbers issued since 18 February 2026 have no check digit, so none is checked. A person's number only: company numbers are not matched.
- `svnr_at`, Austrian social security number (SVNR): Four digits and the date of birth after SVNR, VSNR, SV-Nr., SV-Nummer or (Sozial)versicherungsnummer on the same line, with its check digit.
- `isikukood_ee`, Estonian personal identification code (isikukood): Eleven digits after isikukood, isikukoodi or isikukoodiga on the same line: century and sex (3 to 6), a date of birth no later than today, a serial of three digits and a check digit.
- `bsn_nl`, Dutch citizen service number (BSN): Nine digits after BSN, BSN-nummer or burgerservicenummer on the same line, passing the 11-proef.
- `nif_pt`, Portuguese tax number (NIF): Nine digits after NIF, NIPC or contribuinte (optionally followed by n.º) on the same line, with the mod-11 check digit.
- `nino_gb`, UK National Insurance number: Two letters, six digits and A to D after National Insurance, NI number, NI no. or NINO on the same line. Prefixes that are never issued are ignored.
- `nhs_gb`, UK NHS number: Ten digits, optionally 3-3-4, after NHS, NHS number or NHS no. on the same line, with the mod-11 check digit.

<!-- /generated:keyword -->

### Known false positives

- **Numbers that pass Luhn.** A number of 13 to 16 digits starting with 4, 51 to 55, 34, 37, 6011 or 65 that passes Luhn is reported as a card number, as 1 in 10 such numbers do: order and reference numbers among them.
- **Ten-digit numbers as US phone numbers.** 64 in 100 ten-digit numbers pass, so order, ticket and account numbers are matched. Runs starting with 0 or 1, including Unix timestamps in seconds until May 2033, are not.
- **Eleven-digit numbers.** `pesel_pl`, `rrn_be`, `steuer_id_de` and `fodselsnummer_no` are matched on the digits alone, without a keyword. About 1 in 110 uniformly random eleven-digit numbers passes at least one of them (measured on 50,000 random strings with a fixed seed).
- **One value, several names.** Each pattern is checked on its own, so a span can be reported under more than one name: `811218-9876` is a Swedish personnummer and a US phone number, and in `NHS number 943 476 5919` the number is an NHS number and a US phone number.
- **Dates of birth.** Any date-shaped value after the keyword is a date of birth: the date is not checked against the calendar, so `DOB: 99/99/9999` and dates in the future are matched.
- **Version numbers and OIDs as IP addresses.** Four numbers from 0 to 255 separated by dots are an IPv4 address, so `version 1.2.3.4` is matched (`v1.2.3.4` is not: the address must not follow a letter), and so are the first four parts of an OID: in `1.3.6.1.4.1.311`, `1.3.6.1`.
- **Format-only patterns.** `email` and `phone_intl` have no check: `Score +1234567` is an international phone number.

### Known false negatives

- **Card numbers outside the known ranges.** Mastercard's 2-series (2221 to 2720), JCB, Diners Club, UnionPay and Discover numbers outside 6011 and 65 are not matched, nor are American Express numbers written 4-6-5, numbers separated by dots, or numbers longer than 16 digits.
- **Separators the regexes do not allow.** For example a US area code in parentheses (`(212) 555-0123`), spaces inside an E.164 number (`+46 70 174 06 05`) or `00` instead of `+`, an SSN without dashes, an IBAN with dashes, a DNI with dots (`12.345.678-Z`), an AHV number with spaces, a Steuer-ID with slashes, a BSN with dashes. The `notes` of each pattern describe the forms it accepts. A value split across lines is not found.
- **Lowercase.** Identifiers written in capitals (IBAN, HETU, codice fiscale, the DNI letter, VAT numbers) are not found in lowercase.
- **Next to an ASCII letter, digit or underscore.** `SSN123-45-6789` is not found; `SSN 123-45-6789` is.
- **Dates of birth in other forms.** Month names, `1985-04-12`, keywords in other languages (`Geburtsdatum`) and `D.O.B.` are not matched.
- **Ten-digit personnummer.** `8112189876` is not a personnummer without its `-` or `+`; the twelve-digit form is matched without one.
- **Everything outside the catalog's scope.** IPv6 addresses, IBANs from countries outside the SEPA list, and digits outside ASCII (such as full-width digits) are not matched.
- **Long email addresses.** The email pattern keeps to RFC 5321's limits: an address with more than 64 characters before the `@`, or more than 250 between the `@` and the domain's last dot, is not found whole.
- **Email addresses with `/`, `?`, `=` or `&` before the `@`.** RFC 5322 allows them, but they also join an address to a URL or a query string, so the pattern leaves them out: in `https://example.com/u/anna@example.com` and `?token=x&email=anna@example.com` the match is `anna@example.com` alone. An address that has one of them before the `@` is matched from after the last one, so `a/b@example.com` is found as `b@example.com` and `a/` is left in the text.
- **Email addresses in scripts written in three bytes of UTF-8.** Letters written in two bytes are read as part of an address, before and after the `@`: accented Latin letters, Greek, Cyrillic, Hebrew and Arabic (`anna.björk@exempel.se`, `dmitri@почта.рф`). Letters written in three bytes, such as Chinese, Japanese, Thai and Devanagari, are not. They are left out as a group because Chinese and Japanese put no space between words: in `田中taro@example.jp` the match is `taro@example.jp`, and an address with a domain in such a script is not found.
- **A no-break space.** A no-break space (U+00A0) or a narrow one (U+202F) between a keyword and its value, or between the groups of a value, is not read as a space: `NHS number 943 476 5919` and `4111 1111 1111 1111` written with them are not found. Next to a value, they do not hide it.

### When a scan raises

`scan/2` and `find/2` raise `PiiCatalog.ScanError`, with the `patterns` being scanned and the engine's `reason`, when the regex engine gives up before the end of the text (its match or recursion limit). They never return the matches found before that point as if they were all of them. See [Usage](#usage).

## How matching works

Patterns are compiled without the `u` flag, so they match bytewise and hold on text that is not valid UTF-8. Their boundaries ask only about ASCII word characters, so a value next to the bytes of a non-ASCII letter is found. Offsets and lengths are in bytes.

Most patterns start the same way, with no ASCII word character before and then a digit or a capital letter. `PiiCatalog.Scanner` scans all of those in one pass, trying each as a lookahead at every position where such a match can start. A pattern led by a literal or a keyword is scanned on its own, and skipped when the text lacks what its `requires` field names. A pattern of your own is always scanned on its own, so it cannot change what the catalog patterns find, and a `PiiCatalog.ScanError` raised on it names it alone. For each pattern the result is the same as `Regex.scan/3` on its own regex; a property test checks this on generated text.

Three validators compare a date of birth with today's date (`pesel_pl`, `isikukood_ee`, `rrn_be`), so their answer for a given value can change over time.

## Test vectors

`test/vectors/<name>.exs` holds, for each identifier:

- `valid`: values that must be found. A string is found whole; `{text, value}` is found as `value` alone, for an identifier that needs a keyword before it.
- `invalid`: values of the right shape that fail the check (a changed check digit, a date that does not exist, a range that is never issued).
- `look_alikes`: texts in which nothing may be found, such as order numbers, dates, product codes and the same value on the line after its keyword.

`test/vectors/noise.exs` is ordinary log and prompt text in which no pattern may match. The values are published test numbers, numbers generated to pass or fail a check, or invented. None was taken from a real person, but a generated value that passes its check may still have been issued to someone. [SOURCES.md](SOURCES.md#test-values), under "Test values", says how most values for EU VAT numbers and eight national identifiers were generated.

## Reporting a missed or false identifier

See [SECURITY.md](SECURITY.md). Never include real personal data in a report: use an invented value that is found, or missed, the same way.

## License

Apache License 2.0. See [LICENSE](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/LICENSE) and [NOTICE](https://github.com/signalvaultio/pii_catalog/blob/v0.1.0/NOTICE).
