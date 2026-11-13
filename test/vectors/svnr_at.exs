# Austrian social security numbers, after the word that names it. Checked
# against the rule in Anfragebeantwortung 4690/AB XXIII. GP (Federal
# Minister of Health, 2008) and the Dachverband's "Organisationsbeschreibung
# Datenaustausch mit Öffentlichen Apotheken (DOA)" (see SOURCES.md): serial
# 100 to 999, the check digit, and a day of 01 to 31. 1680250250 is the
# Dachverband's example; most of the rest were generated on 2026-10-19 by
# running python-stdnum (see SOURCES.md, "Test values"). Not real people.
%{
  valid: [
    {"SVNR 2748 140379", "2748 140379"},
    {"SV-Nr.: 1231300785", "1231300785"},
    {"Sozialversicherungsnummer 4120081181", "4120081181"},
    {"VSNR 9865242720", "9865242720"},
    {"Versicherungsnummer 1680250250", "1680250250"}
  ],
  # The check digit (the fourth) changed, and a day of 88 with a valid
  # check digit.
  invalid: ["SVNR 4122881811", "SVNR 9867242720", "SVNR 8298955450", "SVNR 4123881811"],
  look_alikes: [
    "Phone 0664 1234567",
    "SVNR\n2748 140379"
  ]
}
