//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit ProgrDlg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls;

type
  TProgressDialog = class(TForm)
    Button1: TButton;
    ProgressBar1: TProgressBar;
    procedure Button1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    procedure Error;
  end;

var
  ProgressDialog: TProgressDialog;

implementation

{$R *.dfm}

uses
  Main;


procedure TProgressDialog.Button1Click(Sender: TObject);
begin
  Close;
end;


procedure TProgressDialog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  MainForm.Cli.AbortScan;
end;


procedure TProgressDialog.Error;
begin
  if not Visible then Exit;

  MessageDlgPosHelp('No response from VNA', mtError, [mbOk], 0, Left, Top, '');
  Close;
end;



end.

