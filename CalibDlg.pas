//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit CalibDlg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Spin, ComCtrls, Buttons, ImgList, AppEvnts,
  VnaCli, Ini;

type
  TCalibrationDialog = class(TForm)
    Panel1: TPanel;
    OkBtn: TButton;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    SpinEdit1: TSpinEdit;
    SpinEdit2: TSpinEdit;
    SpinEdit3: TSpinEdit;
    CheckBox1: TCheckBox;
    ImageList1: TImageList;
    LoadBtn: TSpeedButton;
    SaveBtn: TSpeedButton;
    ApplicationEvents1: TApplicationEvents;
    SpeedButton1: TSpeedButton;
    Panel2: TPanel;
    GroupBox2: TGroupBox;
    OpenBtn: TSpeedButton;
    CalibrateSBtn: TSpeedButton;
    CalibrateLBtn: TSpeedButton;
    Panel3: TPanel;
    Image1: TImage;
    Panel4: TPanel;
    Image2: TImage;
    Panel5: TPanel;
    Image3: TImage;
    Panel6: TPanel;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    FileNameLabel: TLabel;
    procedure ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
    procedure CalibrateBtnClick(Sender: TObject);
    procedure LoadBtnClick(Sender: TObject);
    procedure SaveBtnClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    CalibrationType: integer;
    function IsSameParams: boolean;
    procedure ToDlg;
  public
    procedure ProcessScannedData(AData: TScanArray);
  end;


var
  CalibrationDialog: TCalibrationDialog;




implementation

{$R *.dfm}

uses
  Main, ProgrDlg;


function TCalibrationDialog.IsSameParams: boolean;
begin
  Result := ((SpinEdit1.Value * 1000) = MainForm.Clb.FreqB) and
                ((SpinEdit2.Value * 1000) = MainForm.Clb.FreqE) and
                (SpinEdit3.Value = MainForm.Clb.PointCnt) and
                (CheckBox1.Checked = MainForm.Clb.Atten);
end;


procedure TCalibrationDialog.ApplicationEvents1Idle(Sender: TObject;
  var Done: Boolean);
var
  SameParams: boolean;
begin
  SameParams := IsSameParams;

  if SameParams and (MainForm.Clb.DataO <> nil)
    then Image1.Left := -16 else Image1.Left := 0;
  if SameParams and (MainForm.Clb.DataS <> nil)
    then Image2.Left := -16 else Image2.Left := 0;
  if SameParams and (MainForm.Clb.DataL <> nil)
    then Image3.Left := -16 else Image3.Left := 0;

  SaveBtn.Enabled := MainForm.Clb.Changed;
end;

//start calibration
procedure TCalibrationDialog.CalibrateBtnClick(Sender: TObject);
begin
  if MainForm.Cli.State < vsRunning then begin Beep; Exit; end;

  CalibrationType := (Sender as TSpeedButton).Tag;

  MainForm.Cli.SetAtten(CheckBox1.Checked);
  MainForm.Cli.Scan(SpinEdit1.Value * 1000, SpinEdit2.Value * 1000, SpinEdit3.Value);

  ProgressDialog.ProgressBar1.Position := 0;
  ProgressDialog.ShowModal;
end;


procedure TCalibrationDialog.FormCreate(Sender: TObject);
var
  Dir: TFileName;
begin
  Dir := GetIniFolder + 'Calibration';
  ForceDirectories(Dir);
  OpenDialog1.InitialDir := Dir;
  SaveDialog1.InitialDir := Dir;
end;

procedure TCalibrationDialog.FormShow(Sender: TObject);
begin
  ToDlg;
end;

procedure TCalibrationDialog.ToDlg;
begin
  SpinEdit1.Value := Round(MainForm.Clb.FreqB / 1000);
  SpinEdit2.Value := Round(MainForm.Clb.FreqE / 1000);
  SpinEdit3.Value := MainForm.Clb.PointCnt;
  CheckBox1.Checked := MainForm.Clb.Atten;

  FileNameLabel.Caption := 'Calibration File: ' + ExtractFileName(MainForm.Clb.FileName);
  FileNameLabel.Hint := MainForm.Clb.FileName;
end;

//scan finished
procedure TCalibrationDialog.ProcessScannedData(AData: TScanArray);
begin
  //calibration preformed for different parameters, erase old data
  if not IsSameParams then MainForm.Clb.SetParams(SpinEdit1.Value * 1000,
    SpinEdit2.Value * 1000, SpinEdit3.Value, CheckBox1.Checked);

  //store new data
  case CalibrationType of
    1: MainForm.Clb.DataO := AData;
    2: MainForm.Clb.DataS := AData;
    3: MainForm.Clb.DataL := AData;
    end;

  MainForm.Clb.Changed := true;
end;


//load calibration data
procedure TCalibrationDialog.LoadBtnClick(Sender: TObject);
begin
  if not OpenDialog1.Execute then Exit;
  MainForm.Clb.LoadFromFile(OpenDialog1.FileName);
  ToDlg;
end;


//save calibration data
procedure TCalibrationDialog.SaveBtnClick(Sender: TObject);
begin
  if not SaveDialog1.Execute then Exit;
  Screen.Cursor := crHourGlass;
  try
    MainForm.Clb.SaveToFile(SaveDialog1.FileName);
    ToDlg;
  finally
    Screen.Cursor := crDefault;
  end;
end;

//erase calibration data
procedure TCalibrationDialog.SpeedButton1Click(Sender: TObject);
begin
  MainForm.Clb.SetParams(SpinEdit1.Value * 1000,
    SpinEdit2.Value * 1000, SpinEdit3.Value, CheckBox1.Checked);
end;

end.

