# UK NHS numbers, checked against the NHS Data Dictionary, "NHS NUMBER" (see
# SOURCES.md). 943 476 5919 is the number NHS documentation uses as an
# example; the rest were generated on 2026-10-19 by running python-stdnum
# (see SOURCES.md, "Test values"). Not real people.
%{
  valid: [
    {"NHS number 943 476 5919", "943 476 5919"},
    {"NHS no. 7812978001", "7812978001"},
    {"NHS: 241-027-5486", "241-027-5486"},
    {"nhs number 1112716718", "1112716718"}
  ],
  # Check digit changed.
  invalid: ["NHS 9434765918", "NHS 7812978009", "NHS 2410275489"],
  look_alikes: [
    "Call 020 7946 0958 today",
    "NHS\n943 476 5919"
  ]
}
