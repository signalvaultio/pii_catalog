# US social security numbers and ITINs.
%{
  valid: ["123-45-6789", "078-05-1120", "912-70-1234"],
  # Area 000 or 666, group 00, serial 0000: never issued. Area 9xx with a
  # group outside the ITIN ranges.
  invalid: ["000-12-3456", "666-12-3456", "123-00-4567", "123-45-0000", "900-12-3456"],
  look_alikes: ["Code: 12-34-567", "Part 1234-56-789", "Released 2026-10-18"]
}
