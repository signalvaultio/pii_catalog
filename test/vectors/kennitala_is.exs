# Icelandic kennitala, after the word that names it: generated with valid
# dates and century digits, and 281191-3049, one of the test numbers
# Þjóðskrá published for numbers without a check digit (issued since
# 18 February 2026). Only the number is matched.
%{
  valid: [
    {"Kennitala 150385-2029", "150385-2029"},
    {"kt. 1503852109", "1503852109"},
    {"kennitölu 021104-2050", "021104-2050"},
    {"Kt: 120160-3389", "120160-3389"},
    {"Kennitala: 281191-3049", "281191-3049"}
  ],
  # A century digit that is not 8, 9 or 0, a day that does not exist, and a
  # company number (day + 40).
  invalid: ["Kennitala 150385-2027", "Kennitala 320385-2029", "Kennitala 550385-2019"],
  look_alikes: [
    "Ticket 1098765432 was reassigned",
    "Order 12345-67890 shipped",
    "Reference 150385-2029",
    "Kennitala\n150385-2029"
  ]
}
