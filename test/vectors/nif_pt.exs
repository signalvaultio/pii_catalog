# Portuguese NIF, after the word that names it: generated on 2026-10-19 by
# running python-stdnum (see SOURCES.md, "Test values"), and checked against
# Decreto-Lei n.º 14/2013, art. 4, and the check digit in the BMF
# Konstruktionsregeln, "PT – Portugiesische UID" (see SOURCES.md). Not real
# taxpayers.
%{
  valid: [
    {"NIF 123456789", "123456789"},
    {"NIF: 362 345 767", "362 345 767"},
    {"número de contribuinte 881763756", "881763756"},
    {"NIPC 818191368", "818191368"},
    {"Contribuinte n.º 642582424", "642582424"},
    {"N.I.F.: 123456789", "123456789"}
  ],
  # Check digit changed, and a number starting with 0.
  invalid: ["NIF 362345768", "NIF 881763751", "NIF 012345679"],
  look_alikes: [
    "Order 123456789 shipped",
    "NIF\n123456789"
  ]
}
