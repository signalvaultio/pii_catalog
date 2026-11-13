# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Pattern names are part of the public API: renaming or removing one is a
breaking change.

## [0.1.0] - 2026-11-13

### Added

- 29 identifiers, each a regex and, where the identifier has one, a check
  digit or structure validator: `email`, `phone_us`, `phone_intl`, `ssn`,
  `credit_card`, `iban`, `ip_address`, `date_of_birth`, `cpr_dk`, `hetu_fi`,
  `kennitala_is`, `fodselsnummer_no`, `personnummer_se`, `svnr_at`,
  `rrn_be`, `steuer_id_de`, `isikukood_ee`, `dni_es`, `nie_es`, `nir_fr`,
  `ppsn_ie`, `codice_fiscale_it`, `bsn_nl`, `pesel_pl`, `nif_pt`, `vat_eu`
  (all 27 member states), `ahv_ch`, `nino_gb` and `nhs_gb`.
- Validators written from, or checked against, the issuers' published
  rules. `SOURCES.md` lists the source of each, with what it checks; the
  README's "Precision" section lists, per identifier, what a check proves
  and what is matched.
- Check digits where the issuer publishes them, and a structure check
  (a date of birth, ranges that are never issued) where it does not. EU
  VAT numbers are checked by check digit in 21 member states and by format
  in the other six, a `:mixed` check kind. The Danish CPR number and the
  Icelandic kennitala are checked by their date (and the kennitala's
  century digit), not by a check digit. The Estonian isikukood's check
  digit is defined in a standard that is sold; it is checked by the rule
  described in public, which `SOURCES.md` cites.
- Nine patterns that match only after a word naming the identifier, on
  the same line: `date_of_birth`, `cpr_dk`, `kennitala_is`, `svnr_at`,
  `isikukood_ee`, `bsn_nl`, `nif_pt`, `nino_gb` and `nhs_gb`. What may come
  between the word and the value is set out in the README, under "A
  context keyword is required".
- `PiiCatalog.patterns/0`, `names/0`, `get/1`, `fetch!/1`, `regions/0`,
  `region_label/1`, `in_region/1` and `groups/0` to read the catalog.
- `PiiCatalog.compile/1`, `scan/2` and `find/2`: a scanner that finds most
  patterns, those that start with a digit or a capital letter, in one
  shared regex pass, and the rest each in a pass of their own. On crafted
  input, the tests check that scan time grows linearly with the text for
  `email` and the keyword patterns, whose regexes could otherwise
  backtrack. `compile/1` raises `ArgumentError` for an
  unknown name or a pattern whose validator is not a known check.
- `PiiCatalog.ScanError`, raised by `scan/2` and `find/2` when the regex
  engine stops before the end of a text, such as at its match limit, so
  that a text not scanned to the end is never reported as clean.
- `PiiCatalog.valid?/2`, a pattern's check on its own, and
  `PiiCatalog.Validators`, the checks by name. `PiiCatalog.valid?/2`
  raises `ArgumentError` for an unknown pattern name.
- Test vectors for every identifier in `test/vectors/`: valid values,
  values of the right shape that fail the check, and look-alikes.

[0.1.0]: https://github.com/signalvaultio/pii_catalog/releases/tag/v0.1.0
