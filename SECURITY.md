# Reporting

There are two kinds of report: a value the catalog gets wrong, and a
security issue in the code. They go to different places.

**Never include real personal data in a report**: not your own, not a
customer's, not one found in a log. Make up a value that is found, or
missed, the same way. For an identifier with a check digit, take a value
from the test vectors or the issuer's published examples and change it, or
compute a valid check digit for invented digits. A report that seems to
contain a real person's identifier may be deleted, and you will be asked to
file it again with an invented value.

Reports are read within a few days.

## A missed or false identifier

A false negative (a value that is personal data and is not found) or a
false positive (a value that is found and is not that identifier) is not a
security issue. Open a public GitHub issue at
https://github.com/signalvaultio/pii_catalog/issues with this template:

```
Pattern:        (the name, e.g. iban, or "none" for an identifier not in the catalog)
Kind:           false negative | false positive
Version:        (mix.lock or `mix deps | grep pii_catalog`)
Elixir / OTP:   (elixir --version)

Text (invented values only):
    Reference: DE89 3704 0044 0532 0130 00

Expected:       (what should be found, or nothing)
Got:            (the output of PiiCatalog.find/2 or scan/2)

How the identifier is written in practice:
    (the separators, case and keywords people use for it, and a source:
    the issuer's documentation, a form, a style guide)
```

For a false negative, say whether the value is missed by the regex
(`PiiCatalog.scan/2` does not return it) or refused by the validator
(`scan/2` returns it and `find/2` does not). For a false positive, say what
the value really is (an order number, a date, a product code): the fix is
usually a look-alike added to `test/vectors/<name>.exs` and a tighter regex
or check.

Some known limits are listed in the README under "Precision". A report of
one of them is still welcome if you can show it is common in real text.

## A security issue in the code

For a vulnerability in the code itself, report it privately through
GitHub's security advisories. That includes:

- a catalog regex that takes time out of proportion to the size of the
  text;
- input that makes a catalog pattern reach the regex engine's match limit,
  so that `PiiCatalog.find/2` raises `PiiCatalog.ScanError` instead of
  scanning the text;
- input that makes the scanner raise any other error.

Report it at
https://github.com/signalvaultio/pii_catalog/security/advisories/new

Please do not open a public issue for these. Include the version, a
minimal input that shows the problem (invented values only, as above) and
what you observed.

## Supported versions

Fixes are released for the latest minor version only.
