# IPv4 addresses, from the documentation ranges where possible.
%{
  valid: ["192.0.2.10", "203.0.113.255", "10.0.0.1", "198.51.100.0"],
  # Dotted quads with an octet over 255.
  invalid: ["999.999.999.999", "256.1.1.1", "192.168.1.300"],
  look_alikes: ["Upgrade to v1.2.3.4", "Version 1.2.3", "Build 2026.10.18"]
}
