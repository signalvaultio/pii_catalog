# Swiss AHV/AVS numbers, dotted and compact, checked against ZAS,
# "AHV-Nummer", and BSV, "Wegleitung über Versicherungsausweis und
# individuelles Konto (WL VA/IK)" Anhang 7 (see SOURCES.md): the 756 prefix
# and the EAN-13 check digit. 756.1234.5678.97 is the Federal Social
# Insurance Office's worked example; the rest were generated on 2026-10-19
# by running python-stdnum (see SOURCES.md, "Test values"). Not real people.
%{
  valid: ["756.1234.5678.97", "7561234567897", "7567740337269", "756.7390.9902.03"],
  # Check digit changed.
  invalid: ["756.1234.5678.98", "7567740337260", "7567390990206"],
  look_alikes: [
    "EAN 4006381333931 on the box",
    "Order 7561234567 shipped"
  ]
}
