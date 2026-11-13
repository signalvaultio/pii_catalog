# Estonian isikukood, after the word that names it: most generated on
# 2026-10-19 by running python-stdnum (see SOURCES.md, "Test values"), and
# all checked against the structure in Siseministri määrus "Isikukoodide
# moodustamise ja andmise kord", § 4, and the check digit's rule (see
# SOURCES.md). Not real people.
%{
  # The check digit from the first weights (48809166445, 61110261904,
  # 36402153101), from the second (38507300124), and 0 when both give 10
  # (36001111750).
  valid: [
    {"Isikukood 38507300124", "38507300124"},
    {"isikukood: 48809166445", "48809166445"},
    {"Isikukoodiga 61110261904", "61110261904"},
    {"ISIKUKOODI 36402153101", "36402153101"},
    {"Isikukood 36001111750", "36001111750"}
  ],
  # The three valid values above with their check digit changed; then,
  # each with its check digit right, 30 February, a birth date after today
  # (2038) and the 1800s.
  invalid: [
    "Isikukood 48809166446",
    "Isikukood 38507300125",
    "Isikukood 36001111751",
    "Isikukood 38502300127",
    "Isikukood 63811163647",
    "Isikukood 11607142683"
  ],
  look_alikes: [
    "Order 98507300124 shipped",
    "Invoice 385073001245 paid",
    "Reference 38507300124",
    "Isikukood\n38507300124"
  ]
}
