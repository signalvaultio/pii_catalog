# US phone numbers. 555-01xx are reserved for fiction.
%{
  valid: ["212-555-0123", "212.555.0123", "212 555 0123", "2125550123", "555-234-5678"],
  # Area code or exchange starting with 0 or 1: never assigned.
  invalid: ["012-555-0123", "112-555-0123", "212-055-0123", "212-155-0123"],
  look_alikes: [
    "Unix time 1760781234",
    "Order 1234567890 shipped",
    "Tracking 0987654321",
    "Ticket 1098765432 closed"
  ]
}
