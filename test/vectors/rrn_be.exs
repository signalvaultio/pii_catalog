# Belgian national register numbers, dotted and compact: most generated on
# 2026-10-19 by running python-stdnum (see SOURCES.md, "Test values"), and
# all checked against the rule in the Registre national's "T.I. 000 – Le
# numéro d'identification" and the Banque Carrefour de la sécurité sociale's
# "Registres: concepts et règles" (see SOURCES.md). 17070526025 passes only
# with the 2 used for people born from 2000. Not real people.
%{
  valid: ["79.11.04-215.43", "79110421543", "57080287428", "16020945740", "17070526025"],
  # Check digits changed, and a month of 13.
  invalid: ["79.11.04-215.44", "57080287421", "16020945741", "85130103367"],
  look_alikes: [
    "Version 12.11.04-215.43.1 released",
    "Phone +32 471 23 45 67"
  ]
}
