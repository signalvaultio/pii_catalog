# Email addresses. Format only: there is no check to fail.
%{
  valid: [
    "anna.berg@example.com",
    "first+tag@mail.example.co.uk",
    "x_y-z@sub.example.org",
    # Letters outside ASCII, before and after the @.
    "anna.björk@exempel.se",
    "Östen.Ågren@firma.example",
    "dmitri@почта.рф"
  ],
  invalid: [],
  look_alikes: [
    "Hey @anna, check this",
    "Mail user@localhost",
    "Pinned to docs@v2",
    "Write to name@example",
    "a @ b.com"
  ]
}
