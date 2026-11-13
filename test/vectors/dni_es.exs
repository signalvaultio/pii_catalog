# Spanish DNI: eight digits and the check letter.
%{
  valid: ["12345678Z", "12345678-Z", "00000000T", "87654321X"],
  invalid: ["12345678A", "00000000R", "87654321A"],
  look_alikes: ["Model 12345678Z9 discontinued", "lowercase 12345678z is not matched"]
}
