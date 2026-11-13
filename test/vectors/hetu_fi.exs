# Finnish henkilötunnus: the Digital and Population Data Services Agency's
# examples and generated codes, including the century signs added in 2023.
%{
  valid: ["131052-308T", "010594Y803U", "010594Y802T", "010105A123P", "150399-215K"],
  # Wrong check character, a day that does not exist, an individual number
  # below 002, and one from 900, kept for testing (the agency's own example
  # for the Y sign).
  invalid: ["131052-308K", "131052-308S", "311152-308T", "131052-001W", "010594Y9032"],
  look_alikes: [
    "Model 123456-789X is discontinued",
    "lowercase 131052-308t is not matched",
    "Serial 131052G308T"
  ]
}
