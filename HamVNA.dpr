//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

program HamVNA;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  ChartFrm in 'ChartFrm.pas' {ChartFrame: TFrame},
  VnaCli in 'VnaCli.pas',
  ProgrDlg in 'ProgrDlg.pas' {ProgressDialog},
  ComplMath in '..\..\VCL\Math\ComplMath.pas',
  CalibDlg in 'CalibDlg.pas' {CalibrationDialog},
  Ini in 'Ini.pas',
  Calibr in 'Calibr.pas',
  ChartSelFrm in 'ChartSelFrm.pas' {ChartSelectionFrame: TFrame},
  VnaResults in 'VnaResults.pas',
  SmithFrm in 'SmithFrm.pas' {SmithChartFrame: TFrame},
  TouchStone in 'TouchStone.pas',
  Plot in 'Plot.pas',
  AngleTxt in '..\..\VCL\AlCommon\AngleTxt.pas',
  RlcFit in 'RlcFit.pas',
  SndTypes0 in '..\..\VCL\SND\SndTypes0.pas',
  LaPackWrap in '..\..\VCL\Math\LaPackWrap.pas',
  VectFitt in '..\..\VCL\Math\VectFitt.pas',
  RlcFrm in 'RlcFrm.pas' {RlcFrame: TFrame},
  AboutDlg in 'AboutDlg.pas' {AboutDialog};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Ham VNA';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TProgressDialog, ProgressDialog);
  Application.CreateForm(TCalibrationDialog, CalibrationDialog);
  Application.CreateForm(TAboutDialog, AboutDialog);
  Application.Run;
end.

