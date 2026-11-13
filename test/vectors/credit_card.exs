# Payment cards: the networks' published test numbers.
%{
  valid: [
    "4111 1111 1111 1111",
    "5500-0000-0000-0004",
    "378282246310005",
    "6011111111111117",
    "5555555555554444"
  ],
  # Right prefix and length, wrong Luhn check digit.
  invalid: ["4111 1111 1111 1112", "5500-0000-0000-0005", "378282246310006", "4532015112830367"],
  look_alikes: ["Reference 4000123456789010", "Order 1234 5678 9012 3456"]
}
