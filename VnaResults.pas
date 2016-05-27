//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit VnaResults;

interface

uses
  SysUtils, Classes, Math, VnaCli, ComplMath, RlcFit;


type
  TVnaParam = (
    vpRawMag, vpRawPhase, vpRawDelay, vpRawErr,
    vpImpedMag, vpImpedArg, vpImpedRe, vpImpedIm,
    vpSwr, vpRefMag, vpRefArg, vpRetLoss,
    vpFitMag, vpFitArg, vpFitRe, vpFitIm,
    vpTransGain, vpTransPhase, vpTransDelay
    );

  TVnaParams = set of TVnaParam;

  TVnaParamGroup = (vpgRawParams, vpgReflectionParams, vpgTransmissionParams);

  TParamInfo = record
    ParamLabel, ParamName, ParamUnits: string;
    MaxValue, MinValue: Single;
    end;


  TSingleArray = array of Single;
  TSingleArray2D = array of TSingleArray;


  TPlotPoint = record Arg, Value: Single; end;
  TPlotArray = array of TPlotPoint;


  TVnaResults = class
  private
    function ComputeDelay(AData: TScanArray): TPlotArray;
//    {$IFDEF DEBUG_MODE}procedure AnalyzeDelay;{$ENDIF}
  public
    RawData, CorrectedData: TScanArray;
    Params: array[TVnaParam] of TPlotArray;
    Rlc: TRlcFitter;

    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure ComputeRawParams;
    procedure ComputeReflectionParams;
    procedure ComputeTransmissionParams;

    function HasReflectionData: boolean;
    function HasTransmissionData: boolean;

    function GetS11: TScanArray;
    function GetS21: TScanArray;

    function GetFitData: TScanArray;
  end;


const
  AllowedParamsByGroup: array[TVnaParamGroup] of TVnaParams = (
    [vpRawMag..vpRawErr],
    [vpRawMag..vpRawErr, vpImpedMag..vpFitIm],
    [vpRawMag..vpRawErr, vpTransGain..vpTransDelay]);


  DefaultParamsByGroup: array[TVnaParamGroup] of TVnaParams = (
    [vpRawMag, vpRawErr],
    [vpImpedMag, vpImpedArg, vpFitMag, vpFitArg],
    [vpTransGain, vpTransDelay]);


  ParamInfo: array[TVnaParam] of TParamInfo = (
    (ParamLabel: '| V |';     ParamName: 'Measured Magnitude';      ParamUnits: 'dBFS'; MaxValue: 0;          MinValue: -140),
    (ParamLabel: '∠V';       ParamName: 'Measured Phase';          ParamUnits: '°';    MaxValue: 180;        MinValue: -180),
    (ParamLabel: 'τ(V)';      ParamName: 'Measured Delay';          ParamUnits: 's';    MaxValue: -MaxSingle; MinValue: 0),
    (ParamLabel: 'σ(V)';      ParamName: 'Measurement Error';       ParamUnits: 'dBFS'; MaxValue: 0 ;         MinValue: -140),
    (ParamLabel: '| Z |';     ParamName: 'Magnitude';               ParamUnits: 'Ω';    MaxValue: 1;          MinValue: 0),
    (ParamLabel: '∠Z';       ParamName: 'Argument' ;               ParamUnits: '°';    MaxValue: 180;        MinValue: -180),
    (ParamLabel: 'Re(Z)';     ParamName: 'Real Part';               ParamUnits: 'Ω';    MaxValue: 1;          MinValue: 0),
    (ParamLabel: 'Im(Z)';     ParamName: 'Imaginary Part';          ParamUnits: 'Ω';    MaxValue: 1;          MinValue: 0),
    (ParamLabel: 'SWR';       ParamName: 'Standing Wave Ratio';     ParamUnits: '';     MaxValue: -MaxSingle; MinValue: 1),
    (ParamLabel: '| Γ |';     ParamName: 'Refl. Coeff. Magnitude';  ParamUnits: '' ;    MaxValue: 1;          MinValue: 0),
    (ParamLabel: '∠Γ';       ParamName: 'Refl. Coeff. Argument';   ParamUnits: '°';    MaxValue: 180;        MinValue: -180),
    (ParamLabel: 'R.L.';      ParamName: 'Return Loss';             ParamUnits: 'dB';   MaxValue: 0;          MinValue: -6),
    (ParamLabel: 'Fit | Z |'; ParamName: 'RLC Fit, Magnitude';      ParamUnits: 'Ω';    MaxValue: 1;          MinValue: 0),
    (ParamLabel: 'Fit ∠Z';   ParamName: 'RLC Fit, Argument' ;      ParamUnits: '°';    MaxValue: 180;        MinValue: -180),
    (ParamLabel: 'Fit Re(Z)'; ParamName: 'RLC Fit, Real Part';      ParamUnits: 'Ω';    MaxValue: 1;          MinValue: 0),
    (ParamLabel: 'Fit Im(Z)'; ParamName: 'RLC Fit, Imaginary Part'; ParamUnits: 'Ω';    MaxValue: 1;          MinValue: 0),
    (ParamLabel: '| G |';     ParamName: 'Gain';                    ParamUnits: 'dB';   MaxValue: 0;          MinValue: -6),
    (ParamLabel: '∠G';       ParamName: 'Phase' ;                  ParamUnits:'°';     MaxValue: 180;        MinValue: -180),
    (ParamLabel: 'τ(G)';      ParamName: 'Group Delay' ;            ParamUnits:'s';     MaxValue: 10e-9;      MinValue: 0)
    );






implementation


function ToDb(X: Single): Single;
begin
  Result := 10 * Log10(X + 1e-20);
end;



{ TVnaResults }

procedure TVnaResults.Clear;
var
  Pm: TVnaParam;
begin
  RawData := nil;
  CorrectedData := nil;
  for Pm:= Low(TVnaParam) to High(TVnaParam) do Params[Pm] := nil;
  Rlc.FittedZ := nil;
end;



procedure TVnaResults.ComputeRawParams;
var
  i: integer;
  Pm: TVnaParam;
begin
  //frequencies
  for Pm:=vpRawMag to vpRawErr do
    begin
    SetLength(Params[Pm], Length(RawData));
    for i:=0 to High(RawData) do Params[Pm][i].Arg := RawData[i].Freq;
    end;

  //magnitude
  for i:=0 to High(RawData) do
    Params[vpRawMag][i].Value := ToDb(RawData[i].Value.SqrMag);

  //phase
  for i:=0 to High(RawData) do
    Params[vpRawPhase][i].Value := RawData[i].Value.Arg * 180 / Pi;

  //delay
  Params[vpRawDelay] := ComputeDelay(RawData);
  //AnalyzeDelay;

  //error
  for i:=0 to High(RawData) do
    Params[vpRawErr][i].Value := ToDb(RawData[i].Variance);
end;


//Γ = (Zdut - 50)/(Zdut + 50)
//VSWR = (1 + Γ)/(1 - Γ)
//Return Loss = -20*log10(|Γ|)

procedure TVnaResults.ComputeReflectionParams;
var
  i: integer;
  Pm: TVnaParam;
  Gamma: TScanArray;
begin
  //frequencies
  for Pm:=vpImpedMag to vpFitIm do
    begin
    SetLength(Params[Pm], Length(CorrectedData));
    for i:=0 to High(CorrectedData) do Params[Pm][i].Arg := CorrectedData[i].Freq;
    end;

  //|Z|
  for i:=0 to High(CorrectedData) do Params[vpImpedMag][i].Value := Sqrt(CorrectedData[i].Value.SqrMag);

  //Arg(Z)
  for i:=0 to High(CorrectedData) do Params[vpImpedArg][i].Value := CorrectedData[i].Value.Arg * 180 / Pi;

  //Re
  for i:=0 to High(CorrectedData) do Params[vpImpedRe][i].Value := CorrectedData[i].Value.Re;

  //Im
  for i:=0 to High(CorrectedData) do Params[vpImpedIm][i].Value := CorrectedData[i].Value.Im;

  //Gamma
  Gamma := GetS11;
  for i:=0 to High(CorrectedData) do
    begin
    Params[vpRefMag][i].Value := Gamma[i].Value.Mag;
    Params[vpRefArg][i].Value := Gamma[i].Value.Arg * 180/Pi;
    Params[vpRetLoss][i].Value := 2 * ToDb(Gamma[i].Value.Mag);
    Params[vpSwr][i].Value := Max(1, Min(100, (1 + Gamma[i].Value.Mag) / Max(1e-20, 1 - Gamma[i].Value.Mag)));
    end;

  //rlc
  Rlc.Fit(CorrectedData);
  for i:=0 to High(CorrectedData) do Params[vpFitMag][i].Value := Rlc.FittedZ[i].Value.Mag;
  for i:=0 to High(CorrectedData) do Params[vpFitArg][i].Value := Rlc.FittedZ[i].Value.Arg * 180 / Pi;
  for i:=0 to High(CorrectedData) do Params[vpFitRe][i].Value := Rlc.FittedZ[i].Value.Re;
  for i:=0 to High(CorrectedData) do Params[vpFitIm][i].Value := Rlc.FittedZ[i].Value.Im;
end;



procedure TVnaResults.ComputeTransmissionParams;
var
  i: integer;
  Pm: TVnaParam;
begin
  //frequencies
  for Pm:=vpTransGain to vpTransDelay do
    begin
    SetLength(Params[Pm], Length(CorrectedData));
    for i:=0 to High(CorrectedData) do Params[Pm][i].Arg := CorrectedData[i].Freq;
    end;

  //gain
  for i:=0 to High(CorrectedData) do
    Params[vpTransGain][i].Value := ToDb(CorrectedData[i].Value.SqrMag);

  //phase
  for i:=0 to High(CorrectedData) do
    Params[vpTransPhase][i].Value := CorrectedData[i].Value.Arg * 180 / Pi;

  //delay
  Params[vpTransDelay] := ComputeDelay(CorrectedData);
end;


constructor TVnaResults.Create;
begin
  Rlc := TRlcFitter.Create;
end;

destructor TVnaResults.Destroy;
begin
  Rlc.Free;
  inherited;
end;

function TVnaResults.HasReflectionData: boolean;
begin
  Result := Params[vpImpedMag] <> nil;
end;

function TVnaResults.HasTransmissionData: boolean;
begin
  Result := Params[vpTransGain] <> nil;
end;

//Tau = dPhi / dOmega
function TVnaResults.ComputeDelay(AData: TScanArray): TPlotArray;
var
  i: integer;
  Arr: TSingleArray;
begin
  SetLength(Result, Length(AData));
  SetLength(Arr, Length(AData)-2);

  for i:=0 to High(Arr) do
    Arr[i] := (AData[i+2].Value.Conj * AData[i].Value).Arg /
              (AData[i+2].Freq - AData[i].Freq) / (2*Pi);

  for i:=0 to High(Result) do
    begin
    Result[i].Arg := AData[i].Freq;
    Result[i].Value := Arr[Max(0, Min(High(Arr), i-1))];
    end;
end;


{$IFDEF DEBUG_MODE}
{
procedure TVnaResults.AnalyzeDelay;
var
  i: integer;
  Delay: TPlotArray;
  Pwr: TSingleArray;
  Buf: TComplexArray;
begin
  //fft
  Delay := Copy(Params[vpRawDelay], 1, Length(Params[vpRawDelay])-2);
  Buf := nil;
  SetLength(Buf, 16384);
  SetLength(Pwr, 16384);
  for i:=0 to High(Delay) do Buf[i].Re := Delay[i].Value * 1e9 * BlackmanHarris7TermWin(i/Length(Delay));
  ComplexFFT(Buf);
  //save as text
  for i:=0 to 16384-1 do Pwr[i] := SqrMag(Buf[i]);
  with TStringList.Create do
    try
      for i:=0 to High(Delay) do
        Add(Format('%.5d  %e', [i, Delay[i].Value*1e9]));
      SaveToFile(ExtractFilePath(ParamStr(0)) + 'Delays.txt');

      Clear;
      for i:=0 to High(Pwr) do
        Add(Format('%.5d  %e', [i-8192, Pwr[(i+8192) mod 16384]]));
        //Add(Format('%.5d  %e', [i, Ln(1e-30 + Pwr[i])]));
      SaveToFile(ExtractFilePath(ParamStr(0)) + 'SpurSpect.txt');
    finally
      Free;
    end;
end;
}
{$ENDIF}


function TVnaResults.GetFitData: TScanArray;
begin
  Result := Rlc.FittedZ;
end;

function TVnaResults.GetS11: TScanArray;
var
  i: integer;
begin
  SetLength(Result, Length(CorrectedData));
  for i:=0 to High(CorrectedData) do
    begin
    Result[i].Freq := CorrectedData[i].Freq;
    Result[i].Value := (CorrectedData[i].Value - 50) / (CorrectedData[i].Value + 50);
    end;
end;


function TVnaResults.GetS21: TScanArray;
begin
  Result := Copy(CorrectedData);
end;



end.

