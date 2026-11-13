# Polish PESEL: generated on 2026-10-19 by running python-stdnum (see
# SOURCES.md, "Test values"), and checked against the rule in the Ustawa z
# dnia 24 września 2010 r. o ewidencji ludności, art. 15, and the
# Rozporządzenie MSW z dnia 4 stycznia 2012 r. w sprawie nadania lub zmiany
# numeru PESEL, § 7 (see SOURCES.md). Not real people.
%{
  valid: ["85073012341", "92082891715", "03281583204", "71100730254"],
  # The check digit changed; 31 June; and a valid check in the 1880s (month
  # +80), which no holder can have.
  invalid: ["92082891716", "03281583205", "71100730253", "85063112347", "85873012345"],
  look_alikes: [
    "Order 12345678901 shipped",
    "Timestamp 20261019123 logged",
    "Tracking 1Z999AA10123456784",
    "Call 07700900126 for the demo"
  ]
}
