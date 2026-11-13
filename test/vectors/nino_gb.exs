# UK National Insurance numbers after the words that name them. Only the
# number is matched.
%{
  valid: [
    {"NI number: AB 12 34 56 C", "AB 12 34 56 C"},
    {"National Insurance number AB123456C", "AB123456C"},
    {"NINO: CE123456A", "CE123456A"},
    {"NI no. JG103759A", "JG103759A"}
  ],
  # Prefixes that are never issued: Q first, O second, and GB.
  invalid: ["NI number: QQ123456C", "NI number: AO123456B", "NINO: GB123456A"],
  look_alikes: ["Part AB123456C in stock", "NI number\nAB123456C", "Uni no AB123456C"]
}
