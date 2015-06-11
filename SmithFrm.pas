//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit SmithFrm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Math, ComplMath, AngleTxt, VnaCli;

type
  TSmithOptions = (smImpedanceLines, smAdmittanceLines, amSwrLines, amQLines);

  TSmithChartFrame = class(TFrame)
    PaintBox1: TPaintBox;
    procedure PaintBox1Paint(Sender: TObject);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure PaintBox1MouseLeave(Sender: TObject);
  private
    procedure PlotGrid;
    procedure PlotArc(X0, Y0, Radius: integer; Phi1, Phi2: Single);
    procedure PlotCircle(X0, Y0, Radius: integer);
    procedure PlotDataFit;
    procedure PlotDataLine;
    procedure PlotDataEx(AData: TScanArray);
    procedure ChangeCursor(ACursor: TCursor);
    procedure ShowValues(Ax, Ay: integer);
    function SnapToLine(Ax, Ay: integer): single;
  public
    C: TPoint;
    R: integer;
    MouseInCircle: boolean;
  end;




implementation

{$R *.dfm}

uses
  Main;


const
  BG_COLOR: TColor = $00FDEAE2;
  GRID_COLOR = $00AEAE5E;
  MARGIN = 14;


procedure TSmithChartFrame.PaintBox1Paint(Sender: TObject);
begin
  PlotGrid;
  PlotDataFit;
  PlotDataLine;
end;


procedure TSmithChartFrame.PlotGrid;
const
  Zeds: array[0..4] of Single = (0.2, 0.5, 1, 2, 5);
var
  i, x, y: integer;
  Phi: Single;
  Rr, Rx: integer;
  S: string;
begin
  //center and radius
  C := POINT((Width-1) div 2, (Height-1) div 2);
  R := (Min(C.x, C.y) - MARGIN);

  with PaintBox1.Canvas do
    begin
    // background
    Brush.Color := BG_COLOR;
    FillRect(RECT(0, 0, PaintBox1.Width, PaintBox1.Height));
    Brush.Style := bsClear;

    //horizontal line
    Pen.Color := GRID_COLOR;
    Pen.Width := 1;
    MoveTo(C.X-R, C.y); LineTo(C.X+R, C.y);

    for i:=0 to High(Zeds) do
      begin
      Rr := Round(R / (Zeds[i]+1));
      Rx := Round(R * Zeds[i]);
      Phi := 2 * ArcTan2(1, Zeds[i]);

      //condactivity circles
      Brush.Style := bsClear;
      Pen.Style := psDot;
      PlotCircle(C.x-R+Rr, C.y, Rr);

      //resistance circles
      Pen.Style := psSolid;
      PlotCircle(C.x+R-Rr, C.y, Rr);

      //+susceptance circles
      Pen.Style := psDot;
      PlotArc(C.X-R, C.Y-Rx, Rx, 1.5*Pi, 1.5*Pi+Phi);
      //-susceptance circles
      PlotArc(C.X-R, C.Y+Rx, Rx, 0.5*Pi-Phi, 0.5*Pi);

      //+reactance circles
      Pen.Style := psSolid;
      PlotArc(C.X+R, C.Y-Rx, Rx, 1.5*Pi-Phi, 1.5*Pi);
      //-reactance circles
      PlotArc(C.X+R, C.Y+Rx, Rx, 0.5*Pi, 0.5*Pi+Phi);
      end;

    //outer circle
    Brush.Style := bsClear;
    Pen.Color := clTeal;
    Pen.Style := psSolid;
    Pen.Width := 2;
    PlotCircle(C.X, C.Y, R);

    //labels
    Brush.Color := BG_COLOR;
    Font.Color := clBlue;
    for i:=0 to High(Zeds) do
      begin
      Rr := Round(R / (Zeds[i]+1));
      Phi := 2 * ArcTan2(1, Zeds[i]);

      S := Format('%dΩ', [Round(50 * Zeds[i])]);
      Font.Color := clBlue;
      AngleTextOut(PaintBox1.Canvas, C.x + R - 2*Rr, C.y, pvBottomLeft, 0, S);

      //Font.Color := clFuchsia;
      x := Round((R+3)*Cos(Phi));
      y := Round((R+3) * Sin(Phi));
      AngleTextOut(PaintBox1.Canvas, C.x + x, C.y - y, pvBottom, -Pi/2+Phi, 'j' + S);
      AngleTextOut(PaintBox1.Canvas, C.x + x, C.y + y, pvTop, Pi/2-Phi, '-j' + S);
      end;

    AngleTextOut(PaintBox1.Canvas, C.x - R, C.y, pvBottomLeft, 0, '0Ω');
    AngleTextOut(PaintBox1.Canvas, C.x - R-3, C.y, pvBottom, Pi/2, 'j0Ω');
    Font.Size := Font.Size + 2;
    AngleTextOut(PaintBox1.Canvas, C.x + R, C.y, pvLeft, 0, '∞');
    end;

end;


procedure TSmithChartFrame.PlotDataLine;
begin
  if (MainForm.Res.CorrectedData = nil) or not Mainform.IsReflectionMode then Exit;

  with PaintBox1.Canvas do
    begin
    Pen.Color := clRed;
    Pen.Width := 2;
    PlotDataEx(MainForm.Res.CorrectedData);
    end;
end;


procedure TSmithChartFrame.PlotDataFit;
begin
  if MainForm.Res.GetFitData = nil then Exit;
  if not Mainform.IsReflectionMode then Exit;
  if not MainForm.CheckBox1.Checked then Exit;

  with PaintBox1.Canvas do
    begin
    Pen.Color := $A6F0A6;
    Pen.Width := 11;
    PlotDataEx(MainForm.Res.GetFitData);
    end;
end;



procedure TSmithChartFrame.PlotDataEx(AData: TScanArray);
var
  x, y, i: integer;
  Gamma: TComplex;
begin
  with PaintBox1.Canvas do
    begin
    Brush.Color := Pen.Color;
    Pen.Style := psSolid;

    for i:=0 to High(AData) do
      begin
      Gamma := (AData[i].Value - 50) / (AData[i].Value + 50);
      x := C.x + Round(R * Gamma.Re);
      y := C.y - Round(R * Gamma.Im);
      if i = 0 then MoveTo(x, y) else LineTo(x, y);
      if (Pen.Width < 5) and (i = 0) then Ellipse(x-3, y-3, x+4, y+4);
      end;
    end;
end;


procedure TSmithChartFrame.PlotCircle(X0, Y0, Radius: integer);
begin
  PaintBox1.Canvas.Ellipse(X0-Radius, Y0-Radius, X0+Radius+1, Y0+Radius+1);
end;


procedure TSmithChartFrame.PlotArc(X0, Y0, Radius: integer; Phi1, Phi2: Single);
begin
  PaintBox1.Canvas.Arc(X0-Radius, Y0-Radius, X0+Radius+1, Y0+Radius+1,
    X0 + Round(1e5 * Cos(Phi1)), Y0 - Round(1e5 * Sin(Phi1)),
    X0 + Round(1e5 * Cos(Phi2)), Y0 - Round(1e5 * Sin(Phi2)));
end;


procedure TSmithChartFrame.PaintBox1MouseLeave(Sender: TObject);
begin
  MainForm.ShowStatus;
end;


procedure TSmithChartFrame.ChangeCursor(ACursor: TCursor);
begin
  PaintBox1.Cursor := ACursor;
  Screen.Cursor := crCross;
  Screen.Cursor := crDefault;
end;

procedure TSmithChartFrame.PaintBox1MouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  NewMouseInCircle: boolean;
begin
  //circle
  C := POINT((Width-1) div 2, (Height-1) div 2);
  R := (Min(C.x, C.y) - MARGIN);
  NewMouseInCircle := (Sqr(X - C.X) + Sqr(Y - C.Y)) <= Sqr(R);

  //change cursor
  if NewMouseInCircle <> MouseInCircle then
    if NewMouseInCircle
      then ChangeCursor(crCross) else ChangeCursor(crDefault);
  MouseInCircle := NewMouseInCircle;

  //show status text
  if NewMouseInCircle
    then ShowValues(X, Y)
    else MainForm.ShowStatus;
end;


procedure TSmithChartFrame.ShowValues(Ax, Ay: integer);
var
  Data: TScanArray;
  S, ReS, ImS: string;
  Idx: integer;
  IdxF, T: Single;
  Gamma, Z, Y: TComplex;
  F: Single;
  Sign: string;
  ShortCircuit, OpenCircuit: boolean;
begin
  Data := MainForm.Res.CorrectedData;
  IdxF := SnapToLine(Ax, Ay);

  //query point is...
  if IdxF >= 0
    then
      //...on the line
      begin
      Idx := Trunc(IdxF);
      T := Frac(IdxF);
      F := Data[Idx].Freq;
      if IdxF < High(Data) then F := F*(1-T) + Data[Idx+1].Freq *T;
      S := ' F=' + Format('%.3nkHz', [F / 1000]);
      Z := Data[Idx].Value;
      if IdxF < High(Data) then Z := Z*(1-T) + Data[Idx+1].Value*T;
      end
    else
      //...in the clear
      begin
      S := '';
      Gamma := COMPL(Ax - C.X, C.Y - Ay) / R;
      ShortCircuit := Gamma = COMPL(-1, 0);
      OpenCircuit := Gamma = COMPL(1, 0);
      if not OpenCircuit then Z := 50 * (1+Gamma) / (1-Gamma);
      end;

  //Re + j*Im
  if Z.Im < 0 then Sign := '-' else Sign := '+';
  if OpenCircuit
    then S := S + '  Z=(∞ + j*∞)Ω'
    else S := S + Format('  Z=(%.2n %s j*%.2n)Ω', [Z.Re, Sign, Abs(Z.Im)]);

  //Re || j*Im
  if OpenCircuit then S := S + '  Zp=(∞ ‖ j*∞)Ω'
  else if ShortCircuit then  S := S + '  Zp=(0.00 ‖ j*0.00)Ω'
  else
    begin
    Y := (1 / Z).Conj;
    if Y.Re = 0 then ReS := '∞' else ReS := Format('%.2n', [1/Y.Re]);
    if Y.Im = 0 then ImS := '∞'
    else if Y.Im < 0 then ImS := Format('(%.2n)', [1/Y.Im])
    else ImS := Format('%.2n', [1/Y.Im]);
    S := S + Format('  Zp=(%s ‖ j*%s)Ω ', [ReS, ImS]);
    end;

  MainForm.StatusEdit.Font.Color := clTeal;
  MainForm.StatusEdit.Text := S;
end;


//http://programmizm.sourceforge.net/blog/2012/distance-from-a-point-to-a-polyline
function TSmithChartFrame.SnapToLine(Ax, Ay: integer): Single;
var
  i: integer;
  Data: TScanArray;
  Dist, BestDist: Single;
  Idx, BestIdx: integer;
  T, BestT: Single;
  q, a, b, aq, bq, ab: TComplex;
  Inv: Single;
begin
  //point array
  Data := MainForm.Res.CorrectedData;
  if (Data = nil) or not Mainform.IsReflectionMode then Exit(-1);

  //query point
  q := COMPL(Ax - C.X, C.Y - Ay) / R;

  //0-th point
  b := (Data[0].Value - 50) / (Data[0].Value + 50);
  bq := q - b;
  BestDist := bq.SqrMag;
  Result := 0;

  //all other points
  for i:=1 to High(Data) do
    begin
    a := b;
    aq := bq;
    b := (Data[i].Value - 50) / (Data[i].Value + 50);
    bq := q - b;
    ab := b - a;
    Inv := 1 / ab.SqrMag;
    T := (ab.Re * aq.Re + ab.Im * aq.Im) * Inv;

    if T < 0 then Continue
    else if T <= 1 then Dist := Sqr(ab.Re * bq.Im - ab.Im * bq.Re) * Inv
    else Dist := bq.SqrMag;

    if Dist < BestDist then
      begin
      BestDist := Dist;
      Result := i - 1 + Min(1, T);
      end;
    end;

  if (Sqrt(BestDist) * R) > 5 then Result := -1;
end;


end.

