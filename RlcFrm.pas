//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2014 Alex Shovkoplyas VE3NEA
unit RlcFrm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Types, Plot, Math, Dialogs, ExtCtrls, RlcFit, ImgList;

type
  TRlcFrame = class(TFrame)
    Panel1: TPanel;
    ScrollBox: TScrollBox;
    ImageList1: TImageList;
    Image1: TImage;
  private
    FTanks: TTanks;
    TankW, RowH, TotalW: integer;
    CntC, CntR, CntL: integer;
    procedure PaintImage;
  public
    procedure PlotCircuit(ATanks: TTanks);
  end;

implementation

{$R *.dfm}


const
  MARG_W = 20;
  GAP_W = 10;
  MARG_H = 6;


procedure TRlcFrame.PaintImage;
var
  W, H, X0, Y0, x, y, dy, p, PrevY: integer;

  procedure PutCircles;
  begin
    if y > PrevY then
      with Image1.Picture.Bitmap.Canvas do
        begin
        MoveTo(x, PrevY);
        LineTo(x, y);
        MoveTo(x+TankW-1, PrevY);
        LineTo(x+TankW-1, y);

        Brush.Color := clBlack;
        Ellipse(x-2, PrevY-2, x+3, PrevY+3);
        Ellipse(x+TankW-3, PrevY-2, x + TankW + 2, PrevY+3);
        end;
    PrevY := y;
    Inc(y, RowH);
  end;

  procedure PutText(AText: string);
  var
    Sz: TSize;
  begin
    with Image1.Picture.Bitmap.Canvas do
      begin
      Brush.Style := bsClear;
      Sz := Image1.Picture.Bitmap.Canvas.TextExtent(AText);
      TextOut(x + (TankW - Sz.cx) div 2, y - RowH div 2, AText);
      end;

    Inc(y, RowH);
  end;

begin
  W := Image1.Picture.Bitmap.Width;
  H := Image1.Picture.Bitmap.Height;

  with Image1.Picture.Bitmap.Canvas do
    begin
    //background
    Brush.Color := clWhite;
    FillRect(Rect(0,0,W,H));
    if Ftanks = nil then Exit;

    //origin
    X0 := Max(MARG_W, (W - TotalW) div 2);
    Y0 := MARG_H + RowH div 2;

    //terminals
    Brush.Color := clRed;
    Pen.Color := Brush.Color;
    Ellipse(X0-7, Y0-3, X0, Y0+4);
    Ellipse(X0+TotalW, Y0-3, X0+TotalW+7, Y0+4);

    Brush.Color := clBlack;
    Pen.Color := Brush.Color;
    Font.Color := clBlue;

    MoveTo(X0, Y0);
    x := X0 + GAP_W;
    y := Y0;
    LineTo(x, Y0);

    CntC := 1; CntR := 1; CntL := 1;

    if FTanks[0].IsShortCircuit or FTanks[0].IsOpenCircuit then
      begin
      ImageList1.Draw(Image1.Picture.Bitmap.Canvas, x, y - RowH div 2, 1);
      Inc(y, RowH);
      if FTanks[0].IsShortCircuit then PutText('R1  0 Ω') else PutText('R1  ∞ Ω');
      Inc(x, TankW); MoveTo(x, Y0);
      Inc(x, GAP_W+1); LineTo(x, Y0);
      end

    else
      //tanks
      for p:=0 to FTanks.Count-1 do
        begin
        y := Y0;
        PrevY := Y0;

        if FTanks[p].C <> 0 then
          begin
          ImageList1.Draw(Image1.Picture.Bitmap.Canvas, x, y - RowH div 2, 0);
          PutCircles;
          PutText(Format('C%d  %sF', [CntC, FormatWithPrefix(FTanks[p].C)]));
          Inc(CntC);
          end;

        if FTanks[p].G <> 0 then
          begin
          ImageList1.Draw(Image1.Picture.Bitmap.Canvas, x, y - RowH div 2, 1);
          PutCircles;
          PutText(Format('R%d  %sΩ', [CntC, FormatWithPrefix(1 / FTanks[p].G)]));
          Inc(CntR);
          end;

        if (FTanks[p].L <> INFINITY) and (FTanks[p].R <> INFINITY) then
          if FTanks[p].R <> 0
            then
              begin
              ImageList1.Draw(Image1.Picture.Bitmap.Canvas, x, y - RowH div 2, 2);
              PutCircles;
              PutText(Format('L%d  %sH', [CntC, FormatWithPrefix(FTanks[p].L)]));
              PutText(Format('R%d  %sΩ', [CntR, FormatWithPrefix(FTanks[p].R)]));
              Inc(CntR); Inc(CntL);
              end
            else
              begin
              ImageList1.Draw(Image1.Picture.Bitmap.Canvas, x, y - RowH div 2, 3);
              PutCircles;
              PutText(Format('L%d  %sH', [CntL, FormatWithPrefix(FTanks[p].L)]));
              Inc(CntL);
              end;

        //link to next tank
        Inc(x, TankW);
        MoveTo(x, Y0);
        Inc(x, GAP_W+1);
        LineTo(x, Y0);
        end;
    end;
end;


procedure TRlcFrame.PlotCircuit(ATanks: TTanks);
var
  Tank: TTank;
begin
  FTanks := ATanks;
  ScrollBox.Visible := Ftanks <> nil;
  if Ftanks = nil then Exit;

  TankW := ImageList1.Width;
  RowH := ImageList1.Height;
  TotalW := GAP_W + (TankW + GAP_W + 1) * FTanks.Count;

  Image1.Picture.Bitmap.PixelFormat := pf24Bit;
  Image1.Picture.Bitmap.Height := Image1.Height;
  Image1.Picture.Bitmap.Width := Max(ScrollBox.ClientWidth, TotalW + 2 * MARG_W);
  Image1.Width := Image1.Picture.Bitmap.Width;
  PaintImage;
  Image1.Repaint;
end;



end.

