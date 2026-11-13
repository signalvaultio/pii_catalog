# EU VAT numbers. The first block is generated values, one or more per
# member state, most of them on 2026-10-19 by running python-stdnum (see
# SOURCES.md, "Test values"), as are most near misses below. Each value is
# checked against the country's published rules as cited in SOURCES.md (for
# most states the Austrian Ministry of Finance's Konstruktionsregeln, and
# the format alone where there is no check); not real registrations. The
# second block is the sample numbers printed in those rules: the Austrian
# Ministry of Finance's Konstruktionsregeln, REGOS for the Croatian OIB and
# the Czech Statistical Office for the IČO.
%{
  valid: [
    "ATU10575894",
    "BE0515010414",
    "BG572063078",
    "BG4071169406",
    "CY39834757W",
    "CZ25596641",
    "CZ370206443",
    "DE452325818",
    "DE 411798307",
    "DK93778065",
    "EE100425446",
    "EL056204372",
    "ESH11562857",
    "ESX1234567L",
    "FI48185649",
    "FRA6000666255",
    "FR5Z000655548",
    "HR83479281234",
    "HU51064264",
    "IE9479607R",
    "IE5S64768U",
    "IT56206350177",
    "LT283203112",
    "LT840504762819",
    "LU62717985",
    "LV28097712279",
    "MT29366618",
    "NL599794331B54",
    "PL9881006443",
    "PT819788520",
    "RO426953",
    "SE362156517901",
    # The same organisationsnummer with another suffix from 01 to 94.
    "SE362156517902",
    "SE362156517994",
    "SI11130229",
    "SK2020000004",
    # Published samples.
    "ATU10223006",
    "BE0776091951",
    "CZ47117061",
    "DE111111125",
    "DK88146328",
    "EE100207415",
    "FI09853608",
    "HR69435151530",
    "HU21376414",
    "HU10597190",
    "IE8Z49289F",
    "IE3628739L",
    "IE3628739UA",
    "IT00000010215",
    "LT213179412",
    "LT290061371314",
    "LU10000356",
    "NL010000446B01",
    "NL123456789B13",
    "PL5260001246",
    "PT502757191",
    "SE556188840401",
    "SI15012557",
    "SK4030000007"
  ],
  # The same numbers with the check digit or letter changed, and other
  # shapes the country's rules refuse. BG, CY, EL, LV, MT and RO have no
  # check here (SOURCES.md says why for each), so they have none: every
  # value of their shape passes.
  invalid: [
    "ATU10575891",
    "BE1395340544",
    "CZ25596640",
    "CZ371306443",
    "CZ570206443",
    "DE452325819",
    "DK93778064",
    "EE100425447",
    "ES12345678A",
    "ESI1234567A",
    "ESX1234567Z",
    "FI48185646",
    "FRA6000666253",
    "FRA6000666251",
    "HR83479281231",
    "HU51064268",
    "IE9479607W",
    "IT56206350178",
    "LT283203110",
    "LU62717982",
    "NL599794332B54",
    "PL9881006447",
    "PT819788522",
    "SE362156517801",
    # Suffixes outside 01 to 94.
    "SE362156517900",
    "SE362156517995",
    "SI11130227",
    "SK0060129432",
    "SK5407062531"
  ],
  look_alikes: [
    "Order DE1234567890 shipped",
    "Code ATU1234567 expired",
    "Part RO12345 in stock",
    "Shipment SE1234567890 to Malmö",
    "lowercase de452325818 is not matched",
    "Ref NL123456789C01 noted",
    "Template value PL0000000000 and SE000000000001"
  ]
}
