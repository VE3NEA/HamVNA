unit ComplMath;

interface

uses
  Math;


type
  PComplex = ^TComplex;
  TComplex = record
  public
    class operator Implicit(const D: Single): TComplex;
    class operator Negative(const C: TComplex): TComplex;
    class operator Equal(const C1, C2: TComplex): Boolean;
    class operator NotEqual(const C1, C2: TComplex): Boolean;
    class operator Add(const C1, C2: TComplex): TComplex;
    class operator Add(const C: TComplex; const D: Single): TComplex;
    class operator Add(const D: Single; const C: TComplex): TComplex;
    class operator Subtract(const C1, C2: TComplex): TComplex;
    class operator Subtract(const C: TComplex; const D: Single): TComplex;
    class operator Subtract(const D: Single; const C: TComplex): TComplex;
    class operator Multiply(const C1, C2: TComplex): TComplex;
    class operator Multiply(const C: TComplex; const D: Single): TComplex;
    class operator Multiply(const D: Single; const C: TComplex): TComplex;
    class operator Divide(const C1, C2: TComplex): TComplex;
    class operator Divide(const C: TComplex; const D: Single): TComplex;
    class operator Divide(const D: Single; const C: TComplex): TComplex;
    function IsZero: Boolean;
    function IsNonZero: Boolean;
    function Conj: TComplex;
    function Sqr: TComplex;
    function Sqrt: TComplex;
    function Arg: Single;
    function Mag: Single;
    function SqrMag: Single;
  public
    Re, Im: Single;
  end;


  //TSingleArray = array of Single;

  TComplexArray = array of TComplex;
  TComplexMatrix = array of TComplexArray;

  PComplexArray = ^TComplArray;
  TComplArray = array[0..(MAXINT div SizeOf(TComplex))-1] of TComplex;

function COMPL(Re, Im: Single): TComplex;
function POLAR_COMPL(Mag, Arg: Single): TComplex;

const
  ZeroComplex: TComplex = ();//initialize to zero;


implementation

class operator TComplex.Implicit(const D: Single): TComplex;
begin
  Result.Re := D;
  Result.Im := 0.0;
end;

class operator TComplex.Negative(const C: TComplex): TComplex;
begin
  Result.Re := -C.Re;
  Result.Im := -C.Im;
end;

class operator TComplex.Equal(const C1, C2: TComplex): Boolean;
begin
  Result := (C1.Re=C2.Re) and (C1.Im=C2.Im);
end;

class operator TComplex.NotEqual(const C1, C2: TComplex): Boolean;
begin
  Result := not (C1=C2);
end;

class operator TComplex.Add(const C1, C2: TComplex): TComplex;
begin
  Result.Re := C1.Re + C2.Re;
  Result.Im := C1.Im + C2.Im;
end;

class operator TComplex.Add(const C: TComplex; const D: Single): TComplex;
begin
  Result.Re := C.Re + D;
  Result.Im := C.Im;
end;

class operator TComplex.Add(const D: Single; const C: TComplex): TComplex;
begin
  Result.Re := D + C.Re;
  Result.Im := C.Im;
end;

function TComplex.Arg: Single;
begin
  Result := ArcTan2(Im, Re);
end;

class operator TComplex.Subtract(const C1, C2: TComplex): TComplex;
begin
  Result.Re := C1.Re - C2.Re;
  Result.Im := C1.Im - C2.Im;
end;

class operator TComplex.Subtract(const C: TComplex; const D: Single): TComplex;
begin
  Result.Re := C.Re - D;
  Result.Im := C.Im;
end;

class operator TComplex.Subtract(const D: Single; const C: TComplex): TComplex;
begin
  Result.Re := D - C.Re;
  Result.Im := -C.Im;
end;

class operator TComplex.Multiply(const C1, C2: TComplex): TComplex;
begin
  Result.Re := C1.Re*C2.Re - C1.Im*C2.Im;
  Result.Im := C1.Re*C2.Im + C1.Im*C2.Re;
end;

class operator TComplex.Multiply(const C: TComplex; const D: Single): TComplex;
begin
  Result.Re := C.Re*D;
  Result.Im := C.Im*D;
end;

class operator TComplex.Multiply(const D: Single; const C: TComplex): TComplex;
begin
  Result.Re := D*C.Re;
  Result.Im := D*C.Im;
end;

class operator TComplex.Divide(const C1, C2: TComplex): TComplex;
var
  R, Denominator: Single;
begin
  if abs(C2.Re)>=abs(C2.Im) then
    begin
    R := C2.Im/C2.Re;
    Denominator := C2.Re+R*C2.Im;
    Result.Re := (C1.Re+R*C1.Im)/Denominator;
    Result.Im := (C1.Im-R*C1.Re)/Denominator;
    end
  else
    begin
    R := C2.Re/C2.Im;
    Denominator := C2.Im+R*C2.Re;
    Result.Re := (C1.Re*R+C1.Im)/Denominator;
    Result.Im := (C1.Im*R-C1.Re)/Denominator;
    end;
end;

class operator TComplex.Divide(const C: TComplex; const D: Single): TComplex;
begin
  Result := C*(1.0/D);
end;

class operator TComplex.Divide(const D: Single; const C: TComplex): TComplex;
var
  R, Denominator: Single;
begin
  if abs(C.Re)>=abs(C.Im) then
    begin
    R := C.Im/C.Re;
    Denominator := C.Re+R*C.Im;
    Result.Re := D/Denominator;
    Result.Im := -R*Result.Re;
    end
  else
    begin
    R := C.Re/C.Im;
    Denominator := C.Im+R*C.Re;
    Result.Im := -D/Denominator;
    Result.Re := -R*Result.Im;
    end;
end;

function TComplex.IsZero: Boolean;
begin
  Result := Self = ZeroComplex;
end;

function TComplex.IsNonZero: Boolean;
begin
  Result := Self <> ZeroComplex;
end;

function TComplex.Conj: TComplex;
begin
  Result.Re := Re;
  Result.Im := -Im;
end;

function TComplex.Sqr: TComplex;
begin
  Result := Self*Self;
end;

function TComplex.Sqrt: TComplex;
var
  x, y, v, w: Single;
begin
  if IsZero then begin
    Result := ZeroComplex;
  end else begin
    x := abs(Re);
    y := abs(Im);
    if x>=y then begin
      v := y/x;
      w := System.Sqrt(x)*System.Sqrt(0.5*(1.0+System.Sqrt(1.0+v*v)));
    end else begin
      v := x/y;
      w := System.Sqrt(y)*System.Sqrt(0.5*(v+System.Sqrt(1.0+v*v)));
    end;
    if Re>=0.0 then begin
      Result.Re := w;
      Result.Im := Im/(2.0*w);
    end else begin
      if Im>=0.0 then begin
        Result.Im := w;
      end else begin
        Result.Im := -w;
      end;
      Result.Re := Im/(2.0*Result.Im);
    end;
  end;
end;

function TComplex.Mag: Single;
var
  x, y, Temp: Single;
begin
  x := abs(Re);
  y := abs(Im);
  if x=0.0 then begin
    Result := y;
  end else if y=0.0 then begin
    Result := x;
  end else if x>y then begin
    Temp := y/x;
    Result := x*System.Sqrt(1.0+Temp*Temp);
  end else begin
    Temp := x/y;
    Result := y*System.Sqrt(1.0+Temp*Temp);
  end;
end;

function TComplex.SqrMag: Single;
begin
  Result := System.Sqr(Re) + System.Sqr(Im);
end;


function COMPL(Re, Im: Single): TComplex;
begin
  Result.Re := Re;
  Result.Im := Im;
end;


function POLAR_COMPL(Mag, Arg: Single): TComplex;
begin
  Result.Re := Mag * Cos(Arg);
  Result.Im := Mag * Sin(Arg);
end;


end.

