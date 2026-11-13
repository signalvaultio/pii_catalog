# German Steuer-ID: published test numbers and generated ones.
%{
  valid: [
    "86095742719",
    "86 095 742 719",
    "47036892816",
    "65929970489",
    "57549285017",
    # One digit three times, not in a row.
    "11213456783"
  ],
  # Wrong check digit; a correct check digit but every digit once; and one
  # digit three times in a row.
  invalid: ["86095742718", "12345678903", "47770382916"],
  look_alikes: ["Order 12 345 678 901 shipped", "Tracking 00340434161094 delivered"]
}
