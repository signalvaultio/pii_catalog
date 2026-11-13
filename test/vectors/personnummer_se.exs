# Swedish personnummer and samordningsnummer: test numbers with valid dates
# and Luhn check digits.
%{
  valid: [
    "811218-9876",
    "19811218-9876",
    "198112189876",
    "690407-2383",
    "640823+3234",
    "811278-9873",
    "20010101-1237"
  ],
  # Wrong check digit, a month or day that does not exist, a century other
  # than 19 or 20, and birth number 000.
  invalid: [
    "811218-9875",
    "811318-9876",
    "811232-9876",
    "19811218-9877",
    "18811218-9876",
    "811218-0008"
  ],
  look_alikes: [
    "Ticket 8112189876 was closed",
    "Version 811218-98765 released",
    "Batch 20231018-0041 shipped"
  ]
}
