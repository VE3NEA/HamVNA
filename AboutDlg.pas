//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2014 Alex Shovkoplyas VE3NEA

unit AboutDlg;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Math, ShellApi, StdCtrls, ExtCtrls;

type
  TAboutDialog = class(TForm)
    Bevel1: TBevel;
    ProgNameLabel2: TLabel;
    ProgNameLabel1: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label7: TLabel;
    Label6: TLabel;
    Label8: TLabel;
    Button1: TButton;
    Image1: TImage;
    procedure Label5Click(Sender: TObject);
    procedure Label6Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
  public
  end;

var
  AboutDialog: TAboutDialog;

procedure OpenEmailClient(Address, Subject: string);
procedure OpenWebPage(Url: string);
function GetVersionString: string;




implementation

uses Main;

{$R *.DFM}

//------------------------------------------------------------------------------
//                        helper functions
//------------------------------------------------------------------------------
procedure OpenEmailClient(Address, Subject: string);
var
  Param: string;
begin
  Param := 'mailto:' + Address;
  if Subject <> '' then Param := Param + '?subject=' + Subject;
  ShellExecute(Application.Handle, nil, PChar(Param), '', '', SW_SHOWNORMAL);
end;

procedure OpenWebPage(Url: string);
begin
  ShellExecute(GetDesktopWindow, 'open', PChar(Url), '', '', SW_SHOWNORMAL);
end;

function GetVersionString: string;
var
  Dummy: DWord;
  Buf: array of Byte;
  Info: PVSFixedFileInfo;
  Len: UINT;
  Version: integer;
begin
  SetLength(Buf, GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy));
  if Length(Buf) = 0 then Exit;
  if not GetFileVersionInfo(PChar(ParamStr(0)), 0, Length(Buf), @Buf[0]) then Exit;
  if not VerQueryValue(@Buf[0], '\', Pointer(Info), Len) then Exit;
  if Len < SizeOf(TVSFixedFileInfo) then Exit;
  Version := Info.dwFileVersionMS;

  Result := Format('%d.%d', [HiWord(Version), LoWord(Version)]);
end;






//------------------------------------------------------------------------------
//                               GUI
//------------------------------------------------------------------------------
procedure TAboutDialog.FormCreate(Sender: TObject);
begin
  Image1.Picture.Icon := Application.Icon;
  ProgNameLabel1.Caption := Application.Title + ' ' + GetVersionString;
  ProgNameLabel2.Caption := ProgNameLabel1.Caption;
  Caption := 'About ' + Application.Title;
  Width := ProgNameLabel1.Left + ProgNameLabel1.Width + Image1.Left + 5;
  Width := Max(Width, Width + 8 - (Button1.Left - Label6.Width - Label6.Left));
  Application.MainForm.Caption := ProgNameLabel1.Caption;
end;


procedure TAboutDialog.Label5Click(Sender: TObject);
begin
  OpenEmailClient('ve3nea@dxatlas.com', Application.Title);
end;


procedure TAboutDialog.Label6Click(Sender: TObject);
begin
  OpenWebPage('http://www.dxatlas.com/HamVNA');
end;



end.

