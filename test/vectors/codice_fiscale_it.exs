# Italian codice fiscale: the standard example and generated codes,
# including a woman's (day + 40) and omocodia.
%{
  valid: [
    "RSSMRA85T10A562S",
    "MRTMTT91D08F205J",
    "RSSMRA85T50A562W",
    "RSSMRA85T10A56NH",
    "BNCGVN72L52F205Z"
  ],
  # Wrong check character; 30 February with its correct check character;
  # and a day of 35, between the ranges for men and women.
  invalid: [
    "RSSMRA85T10A562T",
    "RSSMRA85B30A562G",
    "RSSMRA85T35A562G",
    "RSSMRA85T81A562Y",
    "RSSMRA85T99A562U"
  ],
  look_alikes: ["Code ABCDEF12G34H567I", "lowercase rssmra85t10a562s is not matched"]
}
