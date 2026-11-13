# Norwegian fødselsnummer and D-nummer: generated with valid dates and both
# mod-11 check digits.
%{
  valid: ["01058512326", "010585 12326", "15076500565", "41058512581", "01058512407"],
  # Wrong first or second check digit, a day that does not exist, and the
  # month plus 40 (an H-nummer, a help number internal to one health
  # organisation, not a fødselsnummer) with valid check digits.
  invalid: ["01058512327", "01058512336", "32058512326", "01458510055"],
  look_alikes: [
    "Account 12345678901 was closed",
    "Invoice 20261018001 is due",
    "Tracking 010585123260 delivered"
  ]
}
