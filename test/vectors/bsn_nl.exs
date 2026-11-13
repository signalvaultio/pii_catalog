# Dutch BSN: the 11-proef test numbers, after the word that names them.
# Only the number is matched.
%{
  valid: [
    {"BSN 111222333", "111222333"},
    {"BSN-nummer: 123456782", "123456782"},
    {"burgerservicenummer 1234.56.782", "1234.56.782"},
    {"bsn: 111 222 333", "111 222 333"}
  ],
  # Fails the 11-proef, and all zeros.
  invalid: ["BSN 111222334", "BSN 123456789", "BSN 000000000"],
  look_alikes: ["Order 111222333 shipped", "BSN\n111222333", "BSNX 111222333"]
}
