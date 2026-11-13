# Irish PPS numbers, with and without a second letter. Checked against the
# Department of Social Protection's "Extension of the Personal Public
# Service Number Range" (the ninth character: A = 1, B = 2 and so on,
# W = 0), the Irish VAT rules in the BMF Konstruktionsregeln for the weights
# and letters the department does not publish, and Revenue's Tax and Duty
# Manual for H (see SOURCES.md). 1234567T and 1234567FA are the department's
# examples; most of the rest were generated on 2026-10-19 by running
# python-stdnum (see SOURCES.md, "Test values"). Not real people.
%{
  valid: ["1234567T", "1234567FA", "1367256OB", "2272601P", "7445290CT"],
  # Check letter changed; T as the ninth character counted as 0; and H, a
  # Local Property Tax number rather than a PPS number, with the check
  # letter it would have if H counted as 8.
  invalid: ["1234567W", "1234567TA", "2272601E", "7445290QT", "7445290GT", "5820317BH"],
  look_alikes: [
    "Part 1234567 in stock",
    "lowercase 1234567t is not matched",
    "SKU 12345678T is a different length"
  ]
}
