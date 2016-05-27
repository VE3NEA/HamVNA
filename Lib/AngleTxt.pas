//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2014 Alex Shovkoplyas VE3NEA

unit AngleTxt;

interface

uses
  Windows, SysUtils, Classes, Graphics;


type
  TPivotPosition = (
    pvTopLeft, pvTop, pvTopRight,
    pvLeft, pvCenter, pvRight,
    pvBottomLeft, pvBottom, pvBottomRight);



procedure AngleTextOut(Canvas: TCanvas; X, Y: integer; Pivot: TPivotPosition;
  Angle: Single; Text: string);



implementation


//(X,Y) is the pivot point, Pivot is position of the pivot relative to text
//Angle is rotation angle around the pivot point
procedure AngleTextOut(Canvas: TCanvas; X, Y: integer; Pivot: TPivotPosition;
  Angle: Single; Text: string);
var
  Sz: TSize;
  P, Pr: TPoint;

  NewFontHandle, OldFontHandle: hFont;
  LogRec: TLogFont;

  M: TTextMetric;
begin
  //read font parameters
  //SetTextAlign(Canvas.Handle, 0);
  Sz := Canvas.TextExtent(Text);
  GetTextMetrics(Canvas.Handle, M);

  //text origin point relative to the pivot
  case Pivot of
    pvTopLeft, pvLeft, pvBottomLeft:       P.x := 3;
    pvTop, pvCenter, pvBottom:             P.x := -Sz.cx div 2;
    pvTopRight, pvRight, pvBottomRight:    P.x := -Sz.cx - 3;
  end;
  case Pivot of
    pvTopLeft, pvTop, pvTopRight:          P.y := 0;
    pvLeft, pvCenter, pvRight:             P.y := -M.tmInternalLeading - M.tmAscent div 2;
    pvBottomRight, pvBottom, pvBottomLeft: P.y := -M.tmAscent- M.tmDescent;
  end;

  //rotate text origin around pivot
  Pr.x := Round( P.x * Cos(Angle) + P.y * Sin(Angle));
  Pr.y := Round(-P.x * Sin(Angle) + P.y * Cos(Angle));

  //output rotated text at origin
  GetObject(Canvas.Font.Handle, SizeOf(LogRec), Addr(LogRec));
  LogRec.lfEscapement := Round(Angle * 10 * 180/Pi); //angle in tenth of degree
  LogRec.lfOrientation := LogRec.lfEscapement;
  LogRec.lfOutPrecision := OUT_TT_ONLY_PRECIS;
  NewFontHandle := CreateFontIndirect(LogRec);
  OldFontHandle := SelectObject(Canvas.Handle, NewFontHandle);
  Canvas.TextOut(X + Pr.x, Y + Pr.y, Text);
  NewFontHandle := SelectObject(Canvas.Handle, OldFontHandle);
  DeleteObject(NewFontHandle);
end;


end.

