//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit Plot;

interface

uses
  SysUtils, Classes, Generics.Collections, VnaResults, Math;


type
  TUnitsPrefix = (upFemto, upPico, upNano, upMicro, upMilli, upNone, upKilo,
    upMega, upGiga, upTera);

  TScale = class;

  TPlot = class
    Pm: TVnaParam;
    Data: TPlotArray;
    Title: string;
    UnitsName: string;
    UnitsPrefix: TUnitsPrefix;
    VMin, VMax: Single;
    Scale: TScale;
    function FullUnitsName: string;
    procedure FindMinMax;
    procedure FindUnitsPrefix;
  end;

  TPlots = class(TObjectList<TPlot>)
  private
    procedure Sync(Plt1, Plt2: TPlot);
  public
    function Add(APm: TVnaParam; AData: TPlotArray): TPlot;
    procedure SynchronizePlots;
  end;

  TScale = class
    VMin, VMax: Single;
    UnitsName: string;
    UnitsPrefix: TUnitsPrefix;

    Scale: Single;
    SmallTickStep: Single;
    TickStep: Single;
    LabelStep: Single;
    LabelDigits: integer;

    function FullUnitsName: string;
    constructor Create(APlot: TPlot);
    constructor CreateX;
  end;

  TScales = class(TObjectList<TScale>)
  public
    procedure SetScale(APlot: TPlot);
  end;



const
  UnitsPrefixText: array [TUnitsPrefix] of string =
    ('f', 'p', 'n', 'µ', 'm', '', 'k', 'M', 'G', 'T');



function PrefixMult(APref: TUnitsPrefix): Single;
function FormatWithPrefix(V: Single): string;




implementation


function PrefixMult(APref: TUnitsPrefix): Single;
begin
  Result := IntPower(10, 3 * (Ord(APref) - Ord(upNone)));
end;


function FormatWithPrefix(V: Single): string;
var
  MaxExp: integer;
  UnitsPrefix: TUnitsPrefix;
  LabelDigits: integer;
begin
  if V = 0 then MaxExp := 0 else MaxExp := Floor(Log10(Abs(V)));
  MaxExp := Ord(upNone) + Floor(MaxExp / 3);
  UnitsPrefix := TUnitsPrefix(Max(Ord(Low(TUnitsPrefix)), Min(Ord(High(TUnitsPrefix)), MaxExp)));

  LabelDigits := 2;
  //LabelDigits := Max(0, 3 * Floor(MaxExp / 3) - StepExp);

  Result := FloatToStrF(V / PrefixMult(UnitsPrefix), ffFixed, LabelDigits+5, LabelDigits);
  Result := Result + ' ' + UnitsPrefixText[UnitsPrefix];
end;



{ TPlot }

procedure TPlot.FindMinMax;
var
  Pnt: TPlotPoint;
begin
  VMin := ParamInfo[Pm].MinValue;
  VMax := ParamInfo[Pm].MaxValue;

  for Pnt in Data do
    begin
    VMin := Min(VMin, Pnt.Value);
    VMax := Max(VMax, Pnt.Value);
    end;
end;


procedure TPlot.FindUnitsPrefix;
var
  MaxExp: integer;
begin
  MaxExp := Floor(Log10(1e-20 + Max(Abs(VMin), Abs(VMax))));
  MaxExp := Ord(upNone) + Floor(MaxExp / 3);
  UnitsPrefix := TUnitsPrefix(Max(Ord(Low(TUnitsPrefix)), Min(Ord(High(TUnitsPrefix)), MaxExp)));
end;


function TPlot.FullUnitsName: string;
begin
  Result := UnitsPrefixText[UnitsPrefix] + UnitsName;
end;


{ TPlots }

function TPlots.Add(APm: TVnaParam; AData: TPlotArray): TPlot;
begin
  Result := TPlot.Create;
  Result.Pm := APm;
  Result.UnitsName := ParamInfo[APm].ParamUnits;
  Result.Title := ParamInfo[APm].ParamLabel;

  Result.Data := AData;
  Result.FindMinMax;
  Result.FindUnitsPrefix;
  inherited Add(Result);
end;


procedure TPlots.Sync(Plt1, Plt2: TPlot);
begin
  Plt1.VMin := Min(Plt1.VMin, Plt2.VMin);
  Plt2.VMin := Min(Plt1.VMin, Plt2.VMin);

  Plt1.VMax := Max(Plt1.VMax, Plt2.VMax);
  Plt2.VMax := Max(Plt1.VMax, Plt2.VMax);

  Plt1.FindUnitsPrefix;
  Plt2.FindUnitsPrefix;
end;


procedure TPlots.SynchronizePlots;
var
  p1, p2: integer;
begin
  //synchronize measured and fitted plots
  for p1:=0 to Count-2 do
    for p2:=p1+1 to Count-1 do
      if (Pos('Fit ', Self[p2].Title) > 0) and (Pos(Self[p1].Title, Self[p2].Title) > 0) then
        Sync(Self[p1], Self[p2]);

  //synchronize plots with the same unit name and multiplier
  for p1:=0 to Count-2 do
    for p2:=p1+1 to Count-1 do
      if (Self[p2].FullUnitsName <> '') and (Self[p2].FullUnitsName = Self[p1].FullUnitsName)
        then Sync(Self[p1], Self[p2]);
end;

{ TScales }

procedure TScales.SetScale(APlot: TPlot);
var
  Sc: TScale;
begin
  //find scale with the same prefix+unit_sname
  if APlot.FullUnitsName <> '' then
    for Sc in Self do
      if Sc.FullUnitsName = APlot.FullUnitsName then
        begin
        APlot.Scale := Sc;
        Exit;
        end;

  //scale not found, create new
  Add(TScale.Create(APlot));
end;




{ TScale }

constructor TScale.Create(APlot: TPlot);
begin
  VMin := APlot.VMin;
  VMax := APlot.VMax;
  UnitsName := APlot.UnitsName;
  UnitsPrefix := APlot.UnitsPrefix;
  APlot.Scale := Self;
end;



//create scale for the horizontal axis
constructor TScale.CreateX;
begin
  Vmin := 100000;
  Vmax := 60000000;
  UnitsName := 'Hz';
end;

function TScale.FullUnitsName: string;
begin
  Result := UnitsPrefixText[UnitsPrefix] + UnitsName;
end;




end.

