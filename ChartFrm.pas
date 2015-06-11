//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit ChartFrm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Math, VnaResults, Plot;


const
  MAX_PLOTS = 4;

  PlotColors: array[0..MAX_PLOTS-1] of TColor = (clRed, clBlue, $00AA00, clFuchsia);
  BleachColors: array[0..MAX_PLOTS-1] of TColor = ($F0A6A6, $F0A6A6, $A6F0A6, $F0A6F0);
  BG_COLOR: TColor = $00FDEAE2;
  FRAME_COLOR = clTeal;
  LINE_COLOR = $00AEAE5E;


type
  TChartFrame = class(TFrame)
    PaintBox1: TPaintBox;
    procedure PaintBox1Paint(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseLeave(Sender: TObject);
  private
    procedure PlotHorizontalScale;
    procedure PlotVerticalScale(Plt: TPlot; X0: integer; Mirrored: boolean; Clr: TColor);
    procedure ComputeScaleParams(Sc: TScale; AWidth: integer);
    procedure ComputeDegreesScaleParam(Sc: TScale; AWidth: integer);
    procedure PaintCaption(AText: string; APos: TPoint; AJustify: integer);
    function GetLow(const Sc: TScale): Single;
    function GetHigh(const Sc: TScale): Single;
    procedure ChangeCursor(ACursor: TCursor);
    procedure PanCharts(dX, dY: integer);
    procedure ShowValues(X, Y: integer);
    function FindFrequency(AFreq: Single): integer;
    function Bleach(AColor: TColor): TColor;
    procedure PlotData(APlot: TPlot; Clr: TColor);
    procedure PlotDataEx(APlot: TPlot; ShowDots: boolean = true);
    procedure PlotFitData(APlot: TPlot; Clr: TColor);
  public
    Plots: TPlots;
    Scales: TScales;

    Sx: TScale;
    R: TRect;

    ZoomX, ZoomY, OffsetX, OffsetY: Single;
    MouseDownPos: TPoint;
    MouseDownOffsetX, MouseDownOffsetY: Single;
    PanMode: boolean;
    FLastPointIndex: integer;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure MouseWheel(Shift: TShiftState; MousePos: TPoint; Up: boolean);
    procedure ResetZoom;

    procedure ParamsToChart;
  end;




implementation

uses Main;

{$R *.dfm}



//------------------------------------------------------------------------------
//                             TChartFrame
//------------------------------------------------------------------------------
constructor TChartFrame.Create(AOwner: TComponent);
begin
  inherited;

  Plots := TPlots.Create;
  Scales := TScales.Create;
  Sx := TScale.CreateX;
end;


destructor TChartFrame.Destroy;
begin
  Plots.Free;
  Scales.Free;
  Sx.Free;

  inherited;
end;

procedure TChartFrame.ParamsToChart;
var
  Pm: TVnaParam;
  Plt: TPlot;
begin
  Plots.Clear;
  Scales.Clear;

  //list plottable parameters
  for Pm:=Low(TVnaParam) to High(TVnaParam) do
    if MainForm.ChartSelectionFrame1.IsParamSelected(Pm) then
      begin
      Plt := Plots.Add(Pm, MainForm.Res.Params[Pm]);
      if Plots.Count = 4 then Break;
      end;

  //create scales
  Plots.SynchronizePlots;
  for Plt in Plots do Scales.SetScale(Plt);

  Invalidate;
end;




procedure TChartFrame.PaintBox1Paint(Sender: TObject);
var
  Idx, x, i: integer;
  Scl: TScale;
begin
  R := RECT(0, 0, PaintBox1.Width, PaintBox1.Height);
  InflateRect(R, -60, -25);
  Dec(R.Bottom, 15);

  //background
  with PaintBox1.Canvas do
    begin
    Brush.Color := BG_COLOR;
    FillRect(RECT(0, 0, PaintBox1.Width, PaintBox1.Height));
    Brush.Color := FRAME_COLOR;
    FrameRect(R);
    end;

  //scale parameters
  if Plots.Count > 0
    then begin Sx.Vmin := Plots[0].Data[0].Arg; Sx.Vmax := Plots[0].Data[High(Plots[0].Data)].Arg; end
    else begin Sx.Vmin := MainForm.Clb.FreqB; Sx.Vmax := MainForm.Clb.FreqE; end;
  ComputeScaleParams(Sx, R.Right - R.Left - 1);
  for Scl in Scales do ComputeScaleParams(Scl, R.Bottom - R.Top - 1);

  //plot fits
  for i:=0 to Plots.Count-1 do
    if Plots[i].Pm in [vpFitMag..vpFitIm] then
      PlotFitData(Plots[i], Bleach(PlotColors[i]));

  //horizontal scale
  PlotHorizontalScale;

  //vert scales and plots
  Idx := Plots.Count * 10;

  for i:=0 to Plots.Count-1 do
    begin
    case Idx+i of
      10, 20: x := R.Left;
      30, 40: x := R.Left - 4;
      21, 31: x := R.Right - 1;
      41:     x := R.Right + 3;
      32, 42: x := R.Left;
      else{43:} x := R.Right - 1;
      end;
    PlotVerticalScale(Plots[i], x, i in [1, 2], PlotColors[i]);
    if not (Plots[i].Pm in [vpFitMag..vpFitIm]) then
      PlotData(Plots[i], PlotColors[i]);
    end;
end;


function TChartFrame.GetHigh(const Sc: TScale): Single;
begin
  if Sc = Sx
    then Result := GetLow(Sx) + (Sx.VMax - Sx.VMin)  / ZoomX
    else Result := GetLow(Sc) + (Sc.VMax - Sc.VMin)  / ZoomY;
end;


function TChartFrame.GetLow(const Sc: TScale): Single;
begin
  //initilaization
  if ZoomX = 0 then ResetZoom;

  if Sc = Sx
    then Result := Sx.VMin + (Sx.VMax - Sx.VMin) * OffsetX
    else Result := Sc.VMin + (Sc.VMax - Sc.VMin) * OffsetY;
end;

procedure TChartFrame.ResetZoom;
begin
  ZoomX := 1; ZoomY := 1;
  OffsetX := 0; OffsetY := 0;
end;

procedure TChartFrame.PlotHorizontalScale;
var
  x, i: integer;
  S: string;
begin
  with PaintBox1.Canvas do
    begin
    // caption
    S := Format('%s, %s', ['Frequency', Sx.FullUnitsName]);
    x := (R.Right + R.Left) div 2;
    Font.Color := FRAME_COLOR;
    PaintCaption(S, POINT(x, R.Bottom + 21), 0);

    // small ticks
    Pen.Width := 1;
    Brush.Color := FRAME_COLOR;
    for i := Ceil(GetLow(Sx) / (Sx.SmallTickStep)) to MAXINT do
      begin
      x := R.Left + Round((i * Sx.SmallTickStep - GetLow(Sx)) / Sx.Scale);
      if x >= R.Right then
        Break
      else
        FillRect(RECT(x, R.Bottom, x + 1, R.Bottom + 3));
      end;

    // large ticks
    for i := Ceil(GetLow(Sx) / Sx.TickStep) to MAXINT do
      begin
      x := R.Left + Round((i * Sx.TickStep - GetLow(Sx)) / Sx.Scale);
      if x >= R.Right then
        Break
      else
        FillRect(RECT(x, R.Bottom, x + 1, R.Bottom + 6));
      end;

    // lines
    Brush.Style := bsClear;
    Pen.Color := LINE_COLOR;
    //Pen.Style := psDot;
    for i := Ceil(GetLow(Sx) / Sx.LabelStep) to MAXINT do
      begin
      x := R.Left + Round((i * Sx.LabelStep - GetLow(Sx)) / Sx.Scale);
      if x = R.Left then Continue;
      if x >= (R.Right-1) then Break;
      MoveTo(x, R.Top);
      LineTo(x, R.Bottom);
      end;

    // labels
    Font.Color := FRAME_COLOR;
    Brush.Color := BG_COLOR;
    for i := Ceil(GetLow(Sx) / Sx.LabelStep) to MAXINT do
      begin
      x := R.Left + Round((i * Sx.LabelStep - GetLow(Sx)) / Sx.Scale);
      if x >= R.Right then Break;
      S := FloatToStrF(i * Sx.LabelStep / PrefixMult(Sx.UnitsPrefix), ffFixed, Sx.LabelDigits+5, Sx.LabelDigits);
      TextOut(x - TextWidth(S) div 2, R.Bottom + 7, S);
      end;
    end;
end;


procedure TChartFrame.PlotVerticalScale(Plt: TPlot; X0: integer; Mirrored: boolean; Clr: TColor);
var
  y, i: integer;
  S: string;
  Size: TSize;
  Sc: TScale;
begin
  Sc := Plt.Scale;

  with PaintBox1.Canvas do
    begin
    Brush.Color := Clr;
    FillRect(RECT(X0, R.Top, X0+1, R.Bottom));

    //caption
    Font.Color := Clr;
    if Mirrored
      then PaintCaption(Plt.Title, POINT(X0 + 8, 4), 1)
      else PaintCaption(Plt.Title, POINT(X0 - 8, 4), -1);

    //small ticks
    Pen.Width := 1;
    Brush.Color := Clr;
    for i := Ceil(GetLow(Sc) / (Sc.SmallTickStep)) to MAXINT do
      begin
      y := R.Bottom-1 - Round((i * Sc.SmallTickStep - GetLow(Sc)) / Sc.Scale);
      if y < R.Top then Break
      else if Mirrored then FillRect(RECT(X0, y, X0+4, y+1))
      else FillRect(RECT(X0-3, y, X0, y+1));
      end;

    //large ticks
    for i := Ceil(GetLow(Sc) / Sc.TickStep) to MAXINT do
      begin
      y := R.Bottom-1 - Round((i * Sc.TickStep - GetLow(Sc)) / Sc.Scale);
      if y < R.Top then Break
      else if Mirrored then FillRect(RECT(X0, y, X0+7, y+1))
      else FillRect(RECT(X0-6, y, X0, y+1));
      end;

    //0 line
    if (GetLow(Sc) < 0) and (GetHigh(Sc) > 0) then
      begin
      y := R.Bottom-1 + Round(GetLow(Sc) / Sc.Scale);
      Brush.Color := $00AEAE5E;
      FillRect(RECT(R.Left+1, y, R.Right-1, y+1));
      end;

    //labels
    Font.Color := Clr;
    Brush.Color := BG_COLOR;
    for i := Ceil(GetLow(Sc) / Sc.LabelStep) to MAXINT do
      begin
      y := R.Bottom-1 - Round((i * Sc.LabelStep - GetLow(Sc)) / Sc.Scale);
      S := FloatToStrF(i * Sc.LabelStep / PrefixMult(Sc.UnitsPrefix), ffFixed, Sc.LabelDigits+5, Sc.LabelDigits);
      S := S + Sc.FullUnitsName;
      Size := TextExtent(S);

      if y < R.Top then Break
      else if Mirrored then TextOut(X0 + 8, y - Size.cy div 2, S)
      else  TextOut(X0 - Size.cx - 8, y - Size.cy div 2, S)
      end;
    end;
end;


procedure TChartFrame.PlotData(APlot: TPlot; Clr: TColor);
begin
  with PaintBox1.Canvas do
    begin
    Pen.Color := Clr;
    Brush.Color := Clr;
    Pen.Width := 1;
    end;

  PlotDataEx(APlot);
end;


procedure TChartFrame.PlotFitData(APlot: TPlot; Clr: TColor);
begin
  with PaintBox1.Canvas do
    begin
    Pen.Color := Clr;
    Pen.Width := 7;
    end;
  PlotDataEx(APlot, false);
end;

function TChartFrame.Bleach(AColor: TColor): TColor;
var
  i: integer;
begin
  for i:=0 to High(PlotColors) do
    if AColor = PlotColors[i] then Exit(BleachColors[i]);
  Result := clSilver;
end;


procedure TChartFrame.PlotDataEx(APlot: TPlot; ShowDots: boolean = true);
var
  x, y, i: integer;
  FirstPoint: boolean;
begin
  ShowDots := ShowDots and (((R.Right-1 - R.Left) * ZoomX / High(APlot.Data)) > 7);

  with PaintBox1.Canvas do
    begin
    for i:=0 to High(APlot.Data) do
      begin
      x := R.Left + Round((APlot.Data[i].Arg - GetLow(Sx)) / Sx.Scale);
      if x < R.Left then Continue else if x > R.Right then Break;

      FirstPoint := (i = 0) or (Round((APlot.Data[i-1].Arg - GetLow(Sx)) / Sx.Scale) < 0);

      y := R.Bottom-1 - Round((APlot.Data[i].Value - GetLow(APlot.Scale)) / APlot.Scale.Scale);
      y := Max(R.Top+1, Min(R.Bottom-2, y));

      if FirstPoint then MoveTo(x, y) else LineTo(x, y);
      if ShowDots then Ellipse(x-2, y-2, x+3, y+3);
      end;
    end;
end;





procedure TChartFrame.ComputeScaleParams(Sc: TScale; AWidth: integer);
var
  StepCnt: integer;
  StepExp, MaxExp: integer;
  Mant: Single;
begin
  // scale
  Sc.Scale := (GetHIgh(Sc) - GetLow(Sc)) / AWidth;

  // compute approximate  step, 1 label per 60 pixels
  StepCnt := Max(2, Min(10, AWidth div 60));
  Sc.LabelStep := AWidth * Sc.Scale / StepCnt;

  //special case for degrees
  if (Sc.UnitsName = '°') and (Sc.LabelStep > Sqrt(10*15)) then
    begin ComputeDegreesScaleParam(Sc, AWidth); Exit; end;

  // decompose step into exponent and mantissa
  StepExp := Floor(Log10(Sc.LabelStep));
  Mant := Sc.LabelStep * IntPower(10, -StepExp);

  // select the nearest round mantissa
  if Mant < Sqrt(2) then Mant := 1
  else if Mant < Sqrt(2 * 5) then Mant := 2
  else if Mant < Sqrt(5 * 10) then Mant := 5
  else begin Inc(StepExp); Mant := 1; end;

  //combine exponent and mantissa
  Sc.LabelStep := Mant * IntPower(10, StepExp);

  // high ticks in the middle for steps of 1 and 2 units but not for 5
  if Mant = 5
    then Sc.TickStep := Sc.LabelStep
    else Sc.TickStep := 0.5 * Sc.LabelStep;
  Sc.SmallTickStep := Sc.TickStep / 5;

  //units prefix
  MaxExp := Floor(Log10(Max(Abs(GetLow(Sc)), Abs(GetHigh(Sc)))));
  Sc.UnitsPrefix := TUnitsPrefix(Ord(upNone) + Floor(MaxExp / 3));

  //decimal digits in labels
  Sc.LabelDigits := Max(0, 3 * Floor(MaxExp / 3) - StepExp);
end;


procedure TChartFrame.PaintCaption(AText: string; APos: TPoint; AJustify: integer);
var
  Wid: integer;
begin
  with PaintBox1.Canvas do
    begin
    Brush.Color := BG_COLOR;
    Font.Size := Font.Size + 1;
    try
      Wid := TextWidth(AText);
      case AJustify of
        -1: Dec(APos.x, Wid);
         0: Dec(APos.x, Wid div 2);
         end;
      TextOut(APos.x, APos.y, AText);
    finally Font.Size := Font.Size - 1; end;
    end;
end;


//scale in degrees, steps of 15° and higher
procedure TChartFrame.ComputeDegreesScaleParam(Sc: TScale; AWidth: integer);
type
  TStepInfo = record LabelStep, TickStep, SmallTickStep: integer; end;

const
  DegSteps: array[0..4] of TStepInfo = (
    (LabelStep: 15; TickStep: 5; SmallTickStep: 1),
    (LabelStep: 30; TickStep: 10; SmallTickStep: 2),
    (LabelStep: 45; TickStep: 15; SmallTickStep: 5),
    (LabelStep: 90; TickStep: 45; SmallTickStep: 15),
    (LabelStep: 180; TickStep: 90; SmallTickStep: 30)
    );
var
  Idx: integer;
begin
  if Sc.LabelStep < Sqrt(15*30) then Idx := 0
  else if Sc.LabelStep < Sqrt(30*45) then Idx := 1
  else if Sc.LabelStep < Sqrt(45*90) then Idx := 2
  else if Sc.LabelStep < Sqrt(90*180) then Idx := 3
  else Idx := 4;

  Sc.LabelStep := DegSteps[Idx].LabelStep;
  Sc.TickStep := DegSteps[Idx].TickStep;
  Sc.SmallTickStep := DegSteps[Idx].SmallTickStep;

  Sc.UnitsPrefix := upNone;
  Sc.LabelDigits := 0;
end;



//------------------------------------------------------------------------------
//                         mouse functions
//------------------------------------------------------------------------------
procedure TChartFrame.MouseWheel(Shift: TShiftState; MousePos: TPoint;
  Up: boolean);
const
  ZoomStep = 1.412;
var
  CenterX, CenterY: Single;
begin
  //if cannot zoom, exit
  MousePos := ScreenToClient(MousePos);
  if not PtInRect(R, MousePos) then Exit;
  if Plots.Count = 0 then Exit;

  //stop panning
  PaintBox1MouseUp(nil, mbLeft, [], 0, 0);

  //current state
  CenterX := (MousePos.X - R.Left) / (R.Right-1 - R.Left);
  CenterY := (MousePos.Y - (R.Bottom-1)) / (R.Top - (R.Bottom-1));
  OffsetX := OffsetX + CenterX / ZoomX;
  OffsetY := OffsetY + CenterY / ZoomY;

  //zoom in/out
  if Up and not (ssShift in Shift) then ZoomX := ZoomX * ZoomStep;
  if Up and not (ssCtrl in Shift) then ZoomY := ZoomY * ZoomStep;
  if (not Up) and not (ssShift in Shift) then ZoomX := ZoomX / ZoomStep;
  if (not Up) and not (ssCtrl in Shift) then ZoomY := ZoomY / ZoomStep;

  //validate new zoom
  ZoomX := Max(1, Min(200, ZoomX));
  ZoomY := Max(1, Min(200, ZoomY));

  //new offset
  OffsetX := OffsetX - CenterX / ZoomX;
  OffsetY := OffsetY - CenterY / ZoomY;

  //validate new offset
  OffsetX := Max(0, Min(1 - 1 / ZoomX, OffsetX));
  OffsetY := Max(0, Min(1 - 1 / ZoomY, OffsetY));

  //show
  Invalidate;
end;


procedure TChartFrame.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MouseDownPos := POINT(x, y);
  MouseDownOffsetX := OffsetX;
  MouseDownOffsetY := OffsetY;
end;


procedure TChartFrame.PaintBox1MouseLeave(Sender: TObject);
begin
  MainForm.ShowStatus;
end;


procedure TChartFrame.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if (not PanMode) and (ssLeft in Shift) and
     ((Abs(x - MouseDownPos.x) > 1) or (Abs(y - MouseDownPos.y) > 1)) and
     (Plots.Count > 0) and ((ZoomX > 1) or (ZoomY > 1)) then
    begin
    PanMode := true;
    ChangeCursor(crSizeAll);
    end;

  if PanMode
    then PanCharts(x - MouseDownPos.x, y - MouseDownPos.y)
    else ShowValues(x, y);
end;


procedure TChartFrame.PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if PanMode then ChangeCursor(crCross);
  PanMode := false;
end;


procedure TChartFrame.ChangeCursor(ACursor: TCursor);
begin
  PaintBox1.Cursor := ACursor;
  Screen.Cursor := crCross;
  Screen.Cursor := crDefault;
end;

procedure TChartFrame.PanCharts(dX, dY: integer);
begin
  OffsetX := MouseDownOffsetX - dX / ((R.Right-1 - R.Left) * ZoomX);
  OffsetY := MouseDownOffsetY + dY / ((R.Bottom-1 - R.Top) * ZoomY);

  OffsetX := Max(0, Min(1 - 1 / ZoomX, OffsetX));
  OffsetY := Max(0, Min(1 - 1 / ZoomY, OffsetY));

  Invalidate;
end;



function CompareSingle(V1, V2: Single): integer;
begin
  if V1 < V2 then Result := -1
  else if V1 > V2 then Result := 1
  else Result := 0;
end;

function TChartFrame.FindFrequency(AFreq: Single): integer;
var
  L, H, I, C: Integer;
begin
  L := 0;
  H := High(Plots[0].Data);
  while L <= H do
    begin
    I := (L + H) shr 1;
    C := CompareSingle(Plots[0].Data[I].Arg, AFreq);
    if C < 0 then L := I + 1 else
      begin
      H := I - 1;
      if C = 0 then L := I;
      end;
    end;
  Result := L;
end;


procedure TChartFrame.ShowValues(X, Y: integer);
var
  i, Idx: integer;
  Freq: Single;
  S: string;
begin
  if (Plots.Count = 0) or not PtInRect(R, POINT(x, y)) then
    begin MainForm.ShowStatus; Exit; end;


  Freq := GetLow(Sx) + (GetHigh(Sx) - GetLow(Sx)) * (X - R.Left) / (R.Right-1-R.Left);
  Idx := FindFrequency(Freq);

  if Idx > High(Plots[0].Data) then Idx := High(Plots[0].Data)
  else if (Idx > 0) and ((Freq - Plots[0].Data[Idx-1].Arg) < (Plots[0].Data[Idx].Arg - Freq)) then Dec(Idx);

  FLastPointIndex := Idx;

  S := ' F=' + Format('%.3nkHz  ', [Plots[0].Data[Idx].Arg / 1000]);

  for i:=0 to Plots.Count-1 do
    if Plots[i].Data <> nil then
      if Plots[i].UnitsName = 's'
        then S := S + Format('%s=%.2nns  ', [Plots[i].Title, Plots[i].Data[Idx].Value * 1e9])
        else S := S + StringReplace(Format('%s=%.2n%s', [Plots[i].Title, Plots[i].Data[Idx].Value, Plots[i].UnitsName]), ' ', '', [rfReplaceAll]) + '  ';

  MainForm.StatusEdit.Font.Color := clTeal;
  MainForm.StatusEdit.Text := S;
end;


end.
