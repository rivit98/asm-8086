program Z ; uses Crt ;
type T1 = array [0..7] of byte ;
var A : array [#0..#127] of T1 absolute $F000:$FA6E ;
B : T1 ;
C, D, E : byte ; F : char ;
const X : array [boolean] of char = ' *' ;

BEGIN ;
repeat Write('Character (<End> to stop)? ') ; F := ReadKey ;
  if F=#0 then begin F := ReadKey ; HALT end ;
  B := A[F] ; Writeln ;
  for C := 0 to 7 do begin D := B[C] ; Write(D:5, '':2) ;
    for E := 0 to 7 do
      begin Write(X[D>127]) ; D := (D and $7F) shl 1 end ;
    Writeln end ;
  until false ;
END.