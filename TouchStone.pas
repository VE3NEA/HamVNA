//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit TouchStone;

interface

uses
  SysUtils, Classes, Forms, VnaCli, ComplMath;


procedure WriteSnPFile(AFileName: TFIleName; s11, s21: TScanArray);
procedure ReadSnPFile(AFileName: TFIleName; var s11: TScanArray; var s21: TScanArray);



implementation

procedure WriteSnPFile(AFileName: TFIleName; s11, s21: TScanArray);
var
  Lines: TStringList;
  i: integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('!Created with program: ' + Application.Title);
    Lines.Add('!Creation time: ' + FormatDateTime('yyyy-nn-dd hh:nn:ss', Now));
    Lines.Add('# GHz S MA R 50');

    //two-port data
    if s21 <> nil then
      begin
      if s11 = nil then SetLength(s11, Length(s21));
      for i:=0 to High(s21) do
        Lines.Add(Format('0.0%.8d   %8.6f %7.2f   %8.6f %7.2f   0.000000    0.00   0.000000    0.00',
          [s21[i].Freq, s11[i].Value.Mag, s11[i].Value.Arg * 180/Pi,
                        s21[i].Value.Mag, s21[i].Value.Arg * 180/Pi]));
      end

    //one-port data
    else if s11 <> nil then
      for i:=0 to High(s11) do
        Lines.Add(Format('0.0%.8d   %8.6f %7.2f',
          [s11[i].Freq, s11[i].Value.Mag, s11[i].Value.Arg * 180/Pi]));

    Lines.SaveToFile(AFileName, TEncoding.ASCII);
  finally
    Lines.Free;
  end;
end;



procedure ReadSnPFile(AFileName: TFIleName; var s11: TScanArray; var s21: TScanArray);
type
  TReadPhase = (rfStart, rfOptions, rfS11, rfS21);
var
  Lines, Fields: TStringList;
  p, i, Cnt: integer;
  S: string;
  Phase: TReadPhase;
  FreqMult: Single;
  Arr: TScanArray;
  Mag, Arg: Single;
  C: TComplex;

  procedure Err;
    begin raise Exception.CreateFmt('Syntax error in %s on line %d', [ExtractFileName(AFileName), i+1]); end;

begin
  {$IFDEF VER260}System.SysUtils.FormatSettings.{$ENDIF}DecimalSeparator := '.';
  Lines := TStringList.Create;
  Fields := TStringList.Create;
  Cnt := 0;
  SetLength(Arr, 100);
  FreqMult := 1e9;

  try
    Lines.LoadFromFile(AFileName);
    Phase := rfStart;
    for i:=0 to Lines.Count-1 do
      begin
      //skip comments and blank lines
      S := Lines[i];
      p := Pos('!', S);
      if p > 0 then Delete(S, p, MAXINT);
      if Trim(S) = '' then Continue;

      //options line '# GHz S MA R 50'
      if S[1] = '#' then
        begin
        //multiple options lines not allowed
        if Phase <> rfStart then Err;

        //validate options
        S := UpperCase(S);
        p := Pos('HZ', S);
        if p < 2 then Err;

        Fields.CommaText := Copy(S, p+2, MAXINT);
        if Fields.CommaText <> 'S,MA,R,50' then
          raise Exception.CreateFmt('Unsupported options in %s, must be "S MA R 50"',
            [ExtractFileName(AFileName)]);

        //frequency format
        case S[p-1] of
          'G':  FreqMult := 1e9;
          'M':  FreqMult := 1e6;
          'K':  FreqMult := 1e3;
          '#', ' ':  FreqMult := 1;
          else Err;
          end;

        Phase := rfOptions;
        Continue;
        end;

      //data line
      Fields.CommaText := S;
      case Phase of
        //options line required before any data
        rfStart: Err;

        //first data line, see if S11 or S21
        rfOptions:
          if Fields.Count = 3 then Phase := rfS11
          else if Fields.Count = 9 then Phase := rfS21
          else Err;

        //cannot switch between S11 and S21
        rfS11: if Fields.Count <> 3 then Err;
        rfS21: if Fields.Count <> 9 then Err;
        end;

      //read data
      case Phase of
        rfS11:
          begin
          Mag := StrToFloat(Fields[1]);
          Arg := StrToFloat(Fields[2]);
          C := POLAR_COMPL(Mag, Arg * Pi / 180);
          C := (1 + C) / (1 - C) * 50;
          end;
        rfS21:
          begin
          Mag := StrToFloat(Fields[3]);
          Arg := StrToFloat(Fields[4]);
          C := POLAR_COMPL(Mag, Arg * Pi / 180);
          end;
        end;

      //put data in array
      if Cnt = Length(Arr) then SetLength(Arr, Cnt * 2);
      Arr[Cnt].Freq := Round(StrToFloat(Fields[0]) * FreqMult);
      Arr[Cnt].Value := C;
      Inc(Cnt);
      end;
  finally
    Lines.Free;
    Fields.Free;
  end;

  //return data
  SetLength(Arr, Cnt);
  s11 := nil; s21 := nil;
  if Phase = rfS11 then s11 := Arr else s21 := Arr;
end;


end.

