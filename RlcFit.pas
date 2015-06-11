//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2014 Alex Shovkoplyas VE3NEA
unit RlcFit;

interface

uses
  SysUtils, Classes, Math, ComplMath, VnaCli,  IOUtils, SndTypes0,
  VectFitt, Generics.Collections;


const
  INFINITY: Single = 1e9;
  MIN_R = 0.03;
  MAX_R = 1E5;


type
  TTank = class
    C, G, L, R: Single;

    constructor CreateLR;
    constructor CreateCG;
    constructor CreateOpen;
    constructor CreateShort;
    function IsShortCircuit: boolean;
    function IsOpenCircuit: boolean;
  end;

  TTanks = TObjectList<TTank>;

  TRlcFitter = class
  private
    Ft: TVectorFitter;
    function GetWeight(Freq: Single): Single;
    function ComputeRms(AFittedZ: TScanArray): Single;
    procedure ComputeFittedData;
    procedure ComputeLumpedElements;
  public
  Complexity, IterCount: integer;

  Tanks: TTanks;
  FittedZ: TScanArray;

  constructor Create;
  destructor Destroy; override;
  procedure Fit(AData: TScanArray);
  end;



implementation


{ TRlcFitter }

constructor TRlcFitter.Create;
begin
  Ft := TVectorFitter.Create;
  Tanks := TTanks.Create;
  Complexity := 2;
  IterCount := 6;
end;


destructor TRlcFitter.Destroy;
begin
  Ft.Free;
  Tanks.Free;
  inherited;
end;

procedure TRlcFitter.Fit(AData: TScanArray);
var
  i: integer;
  Sum, Weight, Freq, Err: Double;
  IdxD, IdxF: integer; //index of data point, index of basis fun
  Coeff: TVector;
begin
  try
    FittedZ := nil;
    SetLength(Ft.Freq, Length(AData));
    SetLength(Ft.Weights, Length(AData));
    SetLength(Ft.MeasuredZ, Length(AData));
    for i:=0 to High(AData) do
      begin
      Ft.Freq[i] := AData[i].Freq;
      Ft.MeasuredZ[i] := AData[i].Value;
      Ft.Weights[i] := GetWeight(AData[i].Freq);
      end;

    Ft.InitializePoles(Complexity);
    for i:=1 to IterCount do Ft.Iterate;

    ComputeLumpedElements;
    ComputeFittedData;
  except
    Tanks.Clear;
    FittedZ := nil;
  end;
end;


procedure TRlcFitter.ComputeLumpedElements;
var
  p: integer;
  MinS, MaxS: Single;
  ZMin, ZMax: Single;
  Tank: TTank;
begin
  Tanks.Clear;

  //R0, L0
  Tank := TTank.CreateLR;
  Tank.R := Ft.D;
  Tank.L := Ft.E;
  Tanks.Add(Tank);

  //poles/residues to RLCG
  for p:=0 to High(Ft.Poles) do
    case Ft.PoleTypes[p] of
      ptReal:
        begin
        Tank := TTank.CreateCG;
        if Ft.Residues[p].Re = 0
          then
            begin Tank.C := INFINITY; Tank.G := INFINITY; end
          else
            begin
            Tank.C := 1 / Ft.Residues[p].Re;
            Tank.G := -Ft.Poles[p].Re / Ft.Residues[p].Re;
            end;
        Tanks.Add(Tank);
        end;

      ptComplex:
        begin
        Tank := TTank.Create;

        if Ft.Residues[p].Re = 0
          then
            begin
            Tank.C := INFINITY;
            Tank.G := INFINITY;
            end
          else
            begin
            Tank.C := 1 / (2 * Ft.Residues[p].Re);
            Tank.G := (-Ft.Poles[p].Re * Ft.Residues[p].Re + Ft.Poles[p].Im * Ft.Residues[p].Im)
              / (2 * Sqr(Ft.Residues[p].Re));
            end;

        if Ft.Residues[p].SqrMag * Sqr(Ft.Poles[p].Im) = 0
          then
            begin
            Tank.L := INFINITY;
            Tank.R := INFINITY;
            end
          else
            begin
            Tank.L := 2 * IntPower(Ft.Residues[p].Re, 3)
              / (Ft.Residues[p].SqrMag * Sqr(Ft.Poles[p].Im));

            Tank.R:= -2 * Sqr(Ft.Residues[p].Re)
              * (Ft.Poles[p].Re * Ft.Residues[p].Re + Ft.Poles[p].Im * Ft.Residues[p].Im)
              / (Ft.Residues[p].SqrMag * Sqr(Ft.Poles[p].Im));
            end;
        Tanks.Add(Tank);
        end;
      end;

  //ignore too large and too small values
  MinS := 2*Pi * Ft.Freq[0];
  MaxS := 2*Pi * Ft.Freq[High(Ft.Freq)];

  for p:=0 to Tanks.Count-1 do
    with Tanks[p] do
      begin
      if C <> 0 then
        begin
        ZMax := 1 / (MinS * C); ZMin := 1 / (MaxS * C);
        if Abs(ZMax) < MIN_R then C := INFINITY
        else if Abs(ZMin) > MAX_R then C := 0
        else if C < 0 then C := 0;
        end;

      if G <> 0 then
        begin
        ZMax := 1 / G; ZMin := 1 / G;
        if Abs(ZMax) < MIN_R then G := INFINITY
        else if Abs(ZMin) > MAX_R then G := 0
        else if G < 0 then G := 0;
        end;

      ZMax := MaxS * L; ZMin := MinS * L;
      if Abs(ZMax) < MIN_R then L := 0
      else if Abs(ZMin) > MAX_R then L := INFINITY
      else if L < 0 then L := 0;

      if Abs(R) < MIN_R then R := 0
      else if Abs(R) > MAX_R then R := INFINITY
      else if R < 0 then R := 0;

      //merge R and G
      if (L = 0) and (R <> 0) and (R <> INFINITY) then
        begin
        G := G + 1/R;
        R := INFINITY;
        end
    end;

  //delete short circuit tanks
  for p:=Tanks.Count-1 downto 0 do
    if Tanks[p].IsShortCircuit then Tanks.Delete(p)
    else if Tanks[p].IsOpenCircuit then
      begin Tanks.Clear; Tanks.Add(TTank.CreateOpen); Break; end;
  if Tanks.Count = 0 then Tanks.Add(TTank.CreateShort);
end;


procedure TRlcFitter.ComputeFittedData;
var
  i, p: integer;
  Y, Z: TComplex;
  function s(idx: integer): TComplex;
    begin Result := COMPL(0, 2*Pi* FittedZ[i].Freq); end;
begin
  SetLength(FittedZ, Length(Ft.MeasuredZ));
  for i:=0 to High(Ft.MeasuredZ) do
    begin
    FittedZ[i].Freq := Round(Ft.Freq[i]);

    Z := 0;
    for p:=0 to Tanks.Count-1 do
      with Tanks[p] do
        if not IsShortCircuit then
          begin
          Y := C * s(i) + G + 1 / (L * s(i) + R);
          Z := Z + 1 / Y;
          end;
    FittedZ[i].Value := Z;
    end;
end;


//empirical weight function, reduces the effect of imperfect hardware response
//below 1.5 MHz and above 58.5 MHz
function TRlcFitter.GetWeight(Freq: Single): Single;
var
  x: Single;
begin
  x := Freq * 1e-6;
  if x < 2 then x := 2 - x
  else if x > 58 then x := x - 58
  else Exit(1);
  Result := Exp(-(Sqr(Sqr(x))));
end;


function TRlcFitter.ComputeRms(AFittedZ: TScanArray): Single;
var
  i: integer;
  W: Single;
begin
  Result := 0; W := 0;

  for i:=0 to High(AFittedZ) do
    begin
    Result := Result + (Ft.Weights[i] * (AFittedZ[i].Value - Ft.MeasuredZ[i])).SqrMag;
    W := W + Ft.Weights[i];
    end;

  Result := Sqrt(Result / W);
end;






//------------------------------------------------------------------------------
//                                TTank
//------------------------------------------------------------------------------
constructor TTank.CreateLR;
begin
  C := 0;
  G := 0;
end;


constructor TTank.CreateCG;
begin
  L := INFINITY;
  R := INFINITY;
end;


constructor TTank.CreateShort;
begin
  L := 0;
  R := 0;
  C := INFINITY;
  G := INFINITY;
end;


constructor TTank.CreateOpen;
begin
  L := INFINITY;
  R := INFINITY;
  C := 0;
  G := 0;
end;


function TTank.IsOpenCircuit: boolean;
begin
  Result := ((L = INFINITY) or (R = INFINITY)) and (C = 0) and (G = 0);
end;


function TTank.IsShortCircuit: boolean;
begin
  Result := ((L = 0) and (R = 0)) or (C = INFINITY) or (G = INFINITY);
end;



end.

