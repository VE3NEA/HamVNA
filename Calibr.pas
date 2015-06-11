//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit Calibr;

interface

uses
  SysUtils, Classes, VnaCli, ComplMath, IniFiles, Ini;


type
  TCalibrationData = class
  private
  public
    FreqB, FreqE: integer;
    PointCnt: integer;
    Atten: boolean;
    DataO, DataS, DataL: TScanArray;
    FileName: TFileName;
    Changed: boolean;

    constructor Create;
    procedure SetParams(AFreqB, AFreqE, APointCnt: integer; AAtten: boolean);
    procedure LoadFromFile(AFileName: TFileName);
    procedure SaveToFile(AFileName: TFileName);
    function HasReflectionData: boolean;
    function HasTransmissionData: boolean;
    function CorrectTransmissionData(AData: TScanArray): TScanArray;
    function CorrectReflectionData(AData: TScanArray): TScanArray;
  end;


implementation

{ TCalibrationData }

constructor TCalibrationData.Create;
begin
  FreqB := 100000;
  FreqE := 60000000;
  PointCnt := 600;
end;


function TCalibrationData.HasTransmissionData: boolean;
begin
  Result := DataS <> nil;
end;


function TCalibrationData.HasReflectionData: boolean;
begin
  Result := (DataO <> nil) and (DataS <> nil) and (DataL <> nil);
end;


function TCalibrationData.CorrectTransmissionData(AData: TScanArray): TScanArray;
var
  i: integer;
begin
  Result := Copy(AData);
  for i:=0 to High(Result) do
    Result[i].Value := Result[i].Value / DataS[i].Value;
end;


function TCalibrationData.CorrectReflectionData(AData: TScanArray): TScanArray;
var
  i: integer;
  Vo, Vs, Vl, Vm: TComplex;
begin
  Result := Copy(AData);
  for i:=0 to High(Result) do
    try
      Vo := DataO[i].Value;
      Vs := DataS[i].Value;
      Vl := DataL[i].Value;
      Vm := Result[i].Value;

      Result[i].Value := 50 * (Vo - Vl) * (Vm - Vs) / ((Vl - Vs) * (Vo - Vm));
    except
      Result[i].Value := 0;
      Beep;
    end;
end;


procedure TCalibrationData.LoadFromFile(AFileName: TFileName);
var
  Ini: TIniFile;

  procedure LoadArray(var Arr: TScanArray; Name: string);
  var Lst, Pieces: TStringList; i: integer; S: string;
  begin
    Lst := TStringList.Create;
    Pieces := TStringList.Create;
    try
      Ini.ReadSectionValues(Name, Lst);
      SetLength(Arr, Lst.Count);
      if Arr = nil then Exit;

      for i:=0 to Lst.Count-1 do
        begin
        Pieces.Text := StringReplace(StringReplace(Lst[i], '|', #13, [rfReplaceAll]), '=', #13, []);
        Arr[i].Freq := StrToInt(Pieces[0]);
        Arr[i].Value.Re := StrToFloat(Pieces[1]);
        Arr[i].Value.Im := StrToFloat(Pieces[2]);
        Arr[i].Variance := Sqr(StrToFloat(Pieces[3]));
        end;
    finally Lst.Free; Pieces.Free; end;
  end;
begin
  {$IFDEF VER260}System.SysUtils.FormatSettings.{$ENDIF}DecimalSeparator := '.';
  Ini := TIniFile.Create(AFileName);
  try
    FreqB := Ini.ReadInteger('Settings', 'FreqB', FreqB);
    FreqE := Ini.ReadInteger('Settings', 'FreqE', FreqE);
    PointCnt := Ini.ReadInteger('Settings', 'PointCnt', PointCnt);
    Atten := Ini.ReadBool('Settings', 'Attenuator', Atten);

    LoadArray(DataO, 'Open');
    LoadArray(DataS, 'Short');
    LoadArray(DataL, 'Load');

    FileName := AFileName;
    Changed := false;
  finally
    Ini.Free;
  end;
end;


procedure TCalibrationData.SaveToFile(AFileName: TFileName);
var
  Ini: TIniFile;

  procedure SaveArray(Arr: TScanArray; Name: string);
  var Pt: TScanPoint;
  begin
    if Arr <> nil then
      for Pt in Arr do
        Ini.WriteString(Name, Format('%.8d', [Pt.Freq]),
          Format('%13.10f|%13.10f|%13.10f', [Pt.Value.Re, Pt.Value.Im, Sqrt(Pt.Variance)]));
  end;
begin
  if FileExists(AFileName) then DeleteFile(AFileName);

  {$IFDEF VER260}System.SysUtils.FormatSettings.{$ENDIF}DecimalSeparator := '.';
  Ini := TIniFile.Create(AFileName);
  try
    Ini.WriteInteger('Settings', 'FreqB', FreqB);
    Ini.WriteInteger('Settings', 'FreqE', FreqE);
    Ini.WriteInteger('Settings', 'PointCnt', PointCnt);
    Ini.WriteBool('Settings', 'Attenuator', Atten);

    SaveArray(DataO, 'Open');
    SaveArray(DataS, 'Short');
    SaveArray(DataL, 'Load');

    FileName := AFileName;
    Changed := false;
  finally
    Ini.Free;
  end;
end;


procedure TCalibrationData.SetParams(AFreqB, AFreqE, APointCnt: integer; AAtten: boolean);
begin
  FreqB := AFreqB;
  FreqE := AFreqE;
  PointCnt := APointCnt;
  Atten := AAtten;

  DataO := nil;
  DataS := nil;
  DataL := nil;

  FileName := '';
  Changed := false;
end;



end.

