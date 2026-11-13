# Danish CPR numbers: valid dates after the word CPR. Only the number is
# matched.
%{
  valid: [
    {"CPR: 070761-4285", "070761-4285"},
    {"CPR-nr. 0101901234", "0101901234"},
    {"cpr nummer 311299-1234", "311299-1234"},
    {"CPR-nummer: 290204-1234", "290204-1234"},
    {"Patient CPR no. 150372-1111", "150372-1111"}
  ],
  # A day or month that does not exist, and 29 February in a year that is
  # not a leap year.
  invalid: ["CPR: 320190-1234", "CPR 011390-1234", "CPR-nr. 290201-1234"],
  look_alikes: [
    "Order 070761-4285 shipped",
    "CPR\n070761-4285",
    "Reference 0101901234",
    "CPRS 070761-4285"
  ]
}
