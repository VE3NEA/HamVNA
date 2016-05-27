//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2014 Alex Shovkoplyas VE3NEA
unit VectFitt;

interface


uses
  SysUtils, SndTypes0, ComplMath, LapackWrap;


type
  TPoleType = (ptReal, ptComplex, ptConjugate);

  TVectorFitter = class
  private
    Dk: TComplexMatrix;
    FSampleCount: integer;
    Gamma: TComplexArray;
    Gamma0: Single;

    procedure ComputeFittedZ;
    function S(Idx: integer): TComplex;
    function RealToComplex(X: TSingleArray): TComplexArray;
    procedure ComputeResidues;
    procedure ComputeDk;
    procedure GenerateEx1Data;
    procedure DeterminePoleTypes;
    function ComputeRms: Single;
    function ResiduesToZeros: TComplexArray;
    procedure ComputeSigmaResidues;
    function BuildInequalities(Escale: TVector): TMatrix;

    procedure Test_ResiduesToZeros;
    procedure Test_ComputeResidues;
    procedure Test_ComputeSigmaResidues;
    procedure Test_all;
  public
    Freq, Weights: TSingleArray;
    MeasuredZ, FittedZ: TComplexArray;
    Poles, Zeros, Residues: TComplexArray;
    D, E: Single;
    PoleCount: integer;
    PoleTypes: array of TPoleType;
    Rms: Single;

    procedure Iterate;
    procedure InitializePoles(APoleCount: integer);
  end;



implementation

{ TVectorFitter }

procedure TVectorFitter.InitializePoles(APoleCount: integer);
var
  Wmin, Wmax, dW: Single;
  p: integer;
begin
  //frequency range
  FSampleCount := Length(MeasuredZ);
  PoleCount := APoleCount;

  Wmin := 2 * Pi * Freq[0];
  Wmax := 2 * Pi * Freq[FSampleCount-1];
  if PoleCount > 1 then dW := (Wmax - Wmin) / (PoleCount div 2);

  //initial poles
  SetLength(Poles, PoleCount);
  for p:=0 to (PoleCount div 2)-1 do
    begin
    Poles[2*p].Im := Wmin + (0.5 + p) * dW;
    Poles[2*p].Re := -0.01 * Poles[2*p].Im;
    Poles[2*p+1] := Poles[2*p].Conj;
    end;

  if Odd(PoleCount) then
    Poles[High(Poles)] := -0.005 * (Wmin + Wmax);
end;


procedure TVectorFitter.Iterate;
var
  p: integer;
  X: TSingleArray;
begin
  FSampleCount := Length(Freq);
  PoleCount := Length(Poles);
  DeterminePoleTypes;

  //find residues of sigma function given original poles
  ComputeSigmaResidues;

  //zeros of sigma function become new poles of fitted function
  Poles := ResiduesToZeros;
  for p:=0 to PoleCount-1 do if Poles[p].Re > 0 then Poles[p].Re := -Poles[p].Re;
  DeterminePoleTypes;

  //compute residues for new poles
  ComputeResidues;
  //DeterminePoleTypes;

  //populate array with values of fitted function
  ComputeFittedZ;
  Rms := ComputeRms;
end;


function TVectorFitter.S(Idx: integer): TComplex;
begin
  Result := COMPL(0, 2*Pi*Freq[Idx]);
end;


procedure TVectorFitter.ComputeFittedZ;
var
  i, p: integer;
begin
  SetLength(FittedZ, Length(Freq));

  for i:=0 to High(FittedZ) do
    begin
    FittedZ[i] := D + S(i) * E;
    for p:=0 to High(Poles) do
      FittedZ[i] := FittedZ[i] + Residues[p] / (S(i) - Poles[p]);
    end;
end;


function TVectorFitter.RealToComplex(X: TSingleArray): TComplexArray;
var
  p: integer;
begin
  SetLength(Result, PoleCount);
  for p:=0 to PoleCount-1 do
    case PoleTypes[p] of
      ptReal:      Result[p] := X[p];
      ptComplex:   Result[p] := COMPL(X[p], X[p+1]);
      ptConjugate: Result[p] := COMPL(X[p-1], -X[p]);
      end;
end;


procedure TVectorFitter.DeterminePoleTypes;
var
  p: integer;
begin
  SetLength(PoleTypes, PoleCount);
  for p:=0 to PoleCount-1 do
    if Poles[p].Im = 0 then PoleTypes[p] := ptReal
    else if (p > 0) and (PoleTypes[p-1] = ptComplex) then PoleTypes[p] := ptConjugate
    else PoleTypes[p] := ptComplex;
end;

procedure TVectorFitter.ComputeDk;
var
  i, p, W: integer;
begin
  SetLength(Dk, FSampleCount, PoleCount+2);

  for i:=0 to FSampleCount-1 do
    begin
    //C
    for p:=0 to PoleCount-1 do
      case PoleTypes[p] of
        ptComplex:   Dk[i,p] := 1 / (S(i) - Poles[p]) + 1 / (S(i) - Poles[p].Conj);
        ptConjugate: Dk[i,p] := COMPL(0,1) / (S(i) - Poles[p-1]) - COMPL(0,1) / (S(i) - Poles[p-1].Conj);
        else         Dk[i,p] := 1 / (S(i) - Poles[p]);
      end;
    //D
    Dk[i, PoleCount] := 1;
    //E
    Dk[i, PoleCount+1] := S(i);
    end;

  for i:=0 to High(Dk) do
    for p:=0 to High(Dk[0]) do
      Dk[i,p] := Weights[i] * Dk[i,p];
end;


procedure TVectorFitter.ComputeResidues;
var
  i, p: integer;
  A, G: TMatrix;
  b, x: TVector;
  Escale: TVector;
begin
  //left side
  ComputeDk;

  //left side, real
  SetLength(A, 2*FSampleCount, PoleCount+2);
  for i:=0 to FSampleCount-1 do
    for p:=0 to High(A[i]) do
      begin
      A[i, p] := Dk[i, p].Re;
      A[FSampleCount+i, p] := Dk[i, p].Im;
      end;

  //right side, real
  SetLength(B, 2*FSampleCount);
  for i:=0 to FSampleCount-1 do
    begin
    b[i] := Weights[i] * MeasuredZ[i].Re;
    b[FSampleCount+i] := Weights[i] * MeasuredZ[i].Im;
    end;

  //scale
  Escale := nil; SetLength(Escale, Length(A[0]));
  for p:=0 to High(EScale) do
    begin
    for i:=0 to High(A) do EScale[p] := EScale[p] + Sqr(A[i,p]);
    EScale[p] := 1 / Sqrt(EScale[p]);
    end;

  for i:=0 to High(A) do
    for p:=0 to High(A[0]) do
      A[i,p] := A[i,p] * EScale[p];

  //ensure positive RLC values
  G := BuildInequalities(Escale);

  //least squares
  LeastSquaresWithInequalityConstraints(A, G, B, X);

  for p:=0 to High(X) do X[p] := X[p] * Escale[p];

  //real back to complex
  Residues := RealToComplex(X);
  D := X[PoleCount];
  E := X[PoleCount+1];
end;


function TVectorFitter.BuildInequalities(Escale: TVector): TMatrix;
var
  Cnt: integer;
  p, c: integer;
begin
  //count constraints
  Cnt := 2;
  for p:=0 to PoleCount-1 do
    case PoleTypes[p] of
      ptReal: Inc(Cnt);
      ptComplex: Inc(Cnt, 3);
      end;
  SetLength(Result, Cnt, PoleCount+2);

  //D >= 0, E >= 0
  Result[0, PoleCount] := 1;
  Result[1, PoleCount+1] := 1;
  c := 2;

  for p:=0 to PoleCount-1 do
    case PoleTypes[p] of
      ptReal:
        begin
        //C >= 0
        Result[c, p] := 1;
        Inc(c);
        end;

      ptComplex:
        begin
        //C.Re >= 0,
        Result[c, p] := 1;
        //-A.Re*C.Re + A.Im*C*Im >= 0,
        Result[c+1, p] := -Poles[p].Re / Escale[p];
        Result[c+1, p+1] := Poles[p].Im / Escale[p+1];
        //-A.Re*C.Re - A.Im*C*Im >= 0,
        Result[c+2, p] := -Poles[p].Re / Escale[p];
        Result[c+2, p+1] := -Poles[p].Im / Escale[p+1];
        Inc(c,3);
        end;
      end;
end;


function TVectorFitter.ResiduesToZeros: TComplexArray;
var
  A: TMatrix;
  b, c: TVector;
  p, q: integer;
begin
  A := nil; SetLength(A, PoleCount, PoleCount);
  b := nil; SetLength(b, PoleCount);
  c := nil; SetLength(c, PoleCount);

  for p:=0 to PoleCount-1 do
    case PoleTypes[p] of
      ptReal:
        begin
        A[p,p] := Poles[p].Re;
        b[p] := 1;
        c[p] := Gamma[p].Re;
        end;

      ptComplex:
        begin
        A[p,p] := Poles[p].Re;
        A[p,p+1] := Poles[p].Im;
        b[p] := 2;
        c[p] := Gamma[p].Re;
        end;

      ptConjugate:
        begin
        A[p,p] := Poles[p-1].Re;
        A[p,p-1] := -Poles[p-1].Im;
        b[p] := 0;
        c[p] := Gamma[p-1].Im;
        end;
      end;

  //A-b*c'/d
  for p:=0 to PoleCount-1 do
    for q:=0 to PoleCount-1 do
      A[p,q] := A[p,q] - b[p] * c[q] / Gamma0;

  //find eigenvalues, use zeros of Gamma as new poles
  EigenValues(A, Result);
end;


procedure TVectorFitter.ComputeSigmaResidues;
var
  i, p: integer;
  A, Q, R: TMatrix;
  Scale, Sum: Single;
  b, x, Escale: TVector;
begin
  //coeffs for fitting func
  ComputeDk;
  //coeffs for sigma func
  SetLength(Dk, FSampleCount, 2 * PoleCount + 3);
  for i:=0 to FSampleCount-1 do
    for p:=0 to PoleCount do Dk[i, PoleCount+2+p] := -Dk[i, p] * MeasuredZ[i];

  //to real matrix
  SetLength(A, 2 * FSampleCount + 1, Length(Dk[0]));
  for i:=0 to FSampleCount-1 do
    for p:=0 to High(A[i]) do
      begin
      A[i, p] := Dk[i, p].Re;
      A[FSampleCount+i, p] := Dk[i, p].Im;
      end;

  //last row of A, integral criterion for sigma
  Scale := 0;
  for i:=0 to FSampleCount-1 do Scale := Scale + (Weights[i] * MeasuredZ[i]).SqrMag;
  Scale := Sqrt(Scale) / FSampleCount;
  for p:=0 to PoleCount do
    begin
    Sum := 0;
    for i:=0 to FSampleCount-1 do Sum := Sum + Dk[i, p].Re;
    A[High(A), PoleCount+2+p] := Scale * Sum;
    end;

  //A -> Q * R decomposition
  QrDecomposition(A, Q, R);

  //left side for back substitution, R * x = Q' * b
  //extract part of R related to residues of Sigma
  R := Copy(R, PoleCount+2, MAXINT);
  for p:=0 to High(R) do R[p] := Copy(R[p], PoleCount+2, MAXINT);

  //right side: Q' * b
  //since b[i] = 0 for all i except last, Q'*b involves only the last row of Q
  SetLength(b, PoleCount+1);
  for p:=0 to PoleCount do B[p] := Q[High(Q), PoleCount+2+p] * FSampleCount * Scale;

  //escale
  SetLength(Escale, Length(R[0]));
  for p:=0 to High(EScale) do
    begin
    for i:=0 to High(R) do EScale[p] := EScale[p] + Sqr(R[i,p]);
    EScale[p] := 1 / Sqrt(EScale[p]);
    end;
  for i:=0 to High(R) do
    for p:=0 to High(R[0]) do
      R[i,p] := R[i,p] * EScale[p];

  //back substitution
  BackSubstitute(R, B, x);
  for p:=0 to High(x) do x[p] := x[p] * Escale[p];

  //Gamma[], the residues of sigma
  SetLength(Gamma, PoleCount);
  for p:=0 to PoleCount-1 do
    case PoleTypes[p] of
      ptReal: Gamma[p] := X[p];
      ptComplex: Gamma[p] := COMPL(X[p], X[p+1]);
      ptConjugate: Gamma[p] := COMPL(X[p-1], -X[p]);
      end;
  Gamma0 := X[PoleCount];
end;


function TVectorFitter.ComputeRms: Single;
var
  i: integer;
  W: Single;
begin
  W := 0;
  for i:=0 to FSampleCount-1 do W := W + Weights[i];
  Result := 0;
  for i:=0 to FSampleCount-1 do Result := Result + (Weights[i] * (FittedZ[i] - MeasuredZ[i])).SqrMag;
  Result := Sqrt(Result / W);
end;



//------------------------------------------------------------------------------
//                                tests
//------------------------------------------------------------------------------
procedure TVectorFitter.GenerateEx1Data;
var
  i: integer;
begin
  PoleCount := 3;
  SetLength(Poles, PoleCount);
  Poles[0] := -5;
  Poles[1] := COMPL(-100, 500);
  Poles[2] := COMPL(-100, -500);

  SetLength(Residues, PoleCount);
  Residues[0] := 2;
  Residues[1] := COMPL(30, 40);
  Residues[2] := COMPL(30, -40);

  D := 0.5;
  E := 0;

  FSampleCount := 101;
  SetLength(Freq, FSampleCount);
  for i:=0 to High(Freq) do Freq[i] := 1 + 100 * i;

  ComputeFittedZ;
  MeasuredZ := Copy(FittedZ);
  FittedZ := nil;
end;


procedure TVectorFitter.Test_ComputeResidues;
begin
  GenerateEx1Data;
  DeterminePoleTypes;
  ComputeResidues;

  ComputeFittedZ;
  ComputeRms;

  //expected: same Residues, D and E as generated in GenerateEx1Data
end;


//((x-1)*(x-2))/((x-3)*(x-4))   =   -2/(x-3) + 6/(x-4) + 1
procedure TVectorFitter.Test_ResiduesToZeros;
begin
  PoleCount := 2;

  SetLength(Poles, PoleCount);
  Poles[0] := 3;
  Poles[1] := 4;

  SetLength(Gamma, PoleCount);
  Gamma[0] := -2;
  Gamma[1] := 6;

  Gamma0 := 1;

  DeterminePoleTypes;
  ResiduesToZeros;
end;


procedure TVectorFitter.Test_ComputeSigmaResidues;
begin
  GenerateEx1Data;
  DeterminePoleTypes;
  ComputeSigmaResidues;
end;


procedure TVectorFitter.Test_all;
begin
  GenerateEx1Data;
  InitializePoles(4);
  Iterate;
  Iterate;
  Iterate;
  Iterate;
end;



initialization

//  TVectorFitter.Create.Test_all;

end.

