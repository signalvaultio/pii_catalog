# Spanish NIE: X, Y or Z, seven digits and the check letter.
%{
  valid: ["X1234567L", "Y1234567X", "Z1234567R", "X-1234567-L"],
  invalid: ["X1234567M", "Y1234567L", "Z1234567T"],
  look_alikes: ["Part X1234567 in stock", "SKU XA1234567L restocked"]
}
