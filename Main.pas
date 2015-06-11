//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ImgList, ComCtrls, ToolWin, ExtCtrls, StdCtrls, Buttons, Menus,
  ChartFrm, VnaCli, Ini, Calibr, CategoryButtons, CheckLst, PngImage,
  ChartSelFrm, VnaResults, Clipbrd, SmithFrm, AppEvnts, TouchStone, ShellApi,
  AboutDlg, Spin, RlcFrm;


const
  WM_RUN = WM_USER + 1;


type
  TMainForm = class(TForm)
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    ExitMNU: TMenuItem;
    Help1: TMenuItem;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    Panel7: TPanel;
    StatusImage: TImage;
    Chart: TChartFrame;
    ImageList1: TImageList;
    Timer1: TTimer;
    LoadCalibrationDataMNU: TMenuItem;
    SaveCalibrationDataMNU: TMenuItem;
    LoadSnPfileMNU: TMenuItem;
    SaveS1PFileMNU: TMenuItem;
    N3: TMenuItem;
    N1: TMenuItem;
    VNA1: TMenuItem;
    ConnectMNU: TMenuItem;
    SweepMNU: TMenuItem;
    CalibrateMNU: TMenuItem;
    View1: TMenuItem;
    SmithChartMNU: TMenuItem;
    N5: TMenuItem;
    StatusEdit: TEdit;
    PopupMenu1: TPopupMenu;
    PutRawIQDatatoClipboard1: TMenuItem;
    ControlBar1: TControlBar;
    Panel1: TPanel;
    SpeedButton4: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton1: TSpeedButton;
    SaveS2PFileMNU: TMenuItem;
    AppendToS2PFileMNU: TMenuItem;
    ReflectionModeMNU: TMenuItem;
    TransmissionModeMNU: TMenuItem;
    N6: TMenuItem;
    RectangularChartMNU: TMenuItem;
    AboutMNU: TMenuItem;
    ApplicationEvents1: TApplicationEvents;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    Smith: TSmithChartFrame;
    SaveChartImageMNU: TMenuItem;
    N4: TMenuItem;
    N7: TMenuItem;
    SaveDialog2: TSaveDialog;
    ViewReadmeMNU: TMenuItem;
    Panel11: TPanel;
    Panel8: TPanel;
    ChartSelectionFrame1: TChartSelectionFrame;
    Panel9: TPanel;
    Panel13: TPanel;
    Label1: TLabel;
    RectangularChartRadioButton: TRadioButton;
    SmithChartRadioButton: TRadioButton;
    Panel12: TPanel;
    Label2: TLabel;
    ReflModeRadioButton: TRadioButton;
    TransModeRadioButton: TRadioButton;
    RlcFrame1: TRlcFrame;
    Panel10: TPanel;
    Label3: TLabel;
    TrackBar1: TTrackBar;
    CheckBox1: TCheckBox;
    SaveRlcImageMNU: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure SpeedButton2Click(Sender: TObject);
    procedure SpeedButton4Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure PutRawIQDatatoClipboard1Click(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure ModeRadioGroupClick(Sender: TObject);
    procedure ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
    procedure ChartRadioButtonClick(Sender: TObject);
    procedure SaveS1PFileMNUClick(Sender: TObject);
    procedure SaveS2PFileMNUClick(Sender: TObject);
    procedure LoadSnPfileMNUClick(Sender: TObject);
    procedure LoadCalibrationDataMNUClick(Sender: TObject);
    procedure SaveCalibrationDataMNUClick(Sender: TObject);
    procedure ExitMNUClick(Sender: TObject);
    procedure RectangularChartMNUClick(Sender: TObject);
    procedure SmithChartMNUClick(Sender: TObject);
    procedure ReflectionModeMNUClick(Sender: TObject);
    procedure TransmissionModeMNUClick(Sender: TObject);
    procedure SaveChartImageMNUClick(Sender: TObject);
    procedure AboutMNUClick(Sender: TObject);
    procedure ViewReadmeMNUClick(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
    procedure SaveRlcImageMNUClick(Sender: TObject);
  private
    procedure ConnectionEvent(Sender: TObject);
    procedure ScanEvent(Sender: TObject; AData: TScanArray);
    procedure BlockEvent(Senter: TObject; AData: TIntComplexArray);
    procedure LoadSnP(AFileName: TFileName);
    procedure WmRun(var Message: TMessage); message WM_RUN;
    procedure WmDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
    procedure SaveImage(Box: TPaintBox);
    procedure SaveAsPng(Bmp: TBitMap; FileName: TFileName);
  public
    Cli: THermesVnaClient;
    Clb: TCalibrationData;
    Res: TVnaResults;

    procedure ShowStatus;
    function IsReflectionMode: boolean;
    procedure SelectSmithMode(AValue: boolean);
  end;

var
  MainForm: TMainForm;




implementation

uses ProgrDlg, CalibDlg;

{$R *.dfm}



//------------------------------------------------------------------------------
//                                init
//------------------------------------------------------------------------------
procedure TMainForm.FormCreate(Sender: TObject);
begin
  //interface to the vna hardware
  Cli := THermesVnaClient.Create;
  Cli.OnConnectionChange := ConnectionEvent;
  Cli.OnBlock := BlockEvent;
  Cli.OnScan := ScanEvent;
  ShowStatus;

  //storage for calibration data
  Clb := TCalibrationData.Create;

  //computes results from raw vna data
  Res := TVnaResults.Create;

  //settings stored in an ini file
  FromIni;

  //gui adjustments
  Constraints.MinWidth := Width - Panel5.Width + 150;
  Constraints.MinHeight := Height - Panel5.Height + 150;
  Chart.DoubleBuffered := true;
  Chart.ControlStyle := Chart.ControlStyle + [csOpaque];
  Chart.Align := alClient;
  Smith.DoubleBuffered := true;
  Smith.ControlStyle := Chart.ControlStyle + [csOpaque];

  if ParamCount > 0 then LoadSnP(ParamStr(1));

  DragAcceptFiles(Handle, true);
end;


procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Timer1.Enabled := false;
  ToIni;
  Res.Free;
  Cli.Free;
  Clb.Free;
end;


procedure TMainForm.FormShow(Sender: TObject);
begin
  ChartSelectionFrame1.PrepareToShow;
end;






//------------------------------------------------------------------------------
//                                gui
//------------------------------------------------------------------------------
procedure TMainForm.ExitMNUClick(Sender: TObject);
begin
  Close;
end;


procedure TMainForm.ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
begin
  SaveS1PFileMNU.Enabled := IsReflectionMode and Res.HasReflectionData;
  SaveS2PFileMNU.Enabled := (not IsReflectionMode) and Res.HasTransmissionData;
  AppendToS2PFileMNU.Enabled := IsReflectionMode;
  SmithChartMNU.Enabled := IsReflectionMode;
  SmithChartRadioButton.Enabled := IsReflectionMode;

  ReflectionModeMNU.Checked := IsReflectionMode;
  TransmissionModeMNU.Checked := not IsReflectionMode;

  RectangularChartMNU.Checked := RectangularChartRadioButton.Checked;
  SmithChartMNU.Checked := SmithChartRadioButton.Checked;

  SaveCalibrationDataMNU.Enabled := Clb.Changed;

  {!}//RlcPanel.Visible := IsReflectionMode;
end;


procedure TMainForm.FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
 Chart.MouseWheel(Shift, MousePos, false);
 Handled := true;
end;


procedure TMainForm.FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
 Chart.MouseWheel(Shift, MousePos, true);
 Handled := true;
end;


procedure TMainForm.ModeRadioGroupClick(Sender: TObject);
begin
  if IsReflectionMode
    then ChartSelectionFrame1.ParamGroup := vpgReflectionParams
    else ChartSelectionFrame1.ParamGroup := vpgTransmissionParams;
  Chart.ParamsToChart;

  //smith/rect
  ChartRadioButtonClick(nil);
end;


procedure TMainForm.ChartRadioButtonClick(Sender: TObject);
begin
  Smith.Visible := IsReflectionMode and SmithChartRadioButton.Checked;
  Chart.Visible := not Smith.Visible;
end;


procedure TMainForm.CheckBox1Click(Sender: TObject);
begin
  Smith.Invalidate;
end;

procedure TMainForm.SpeedButton1Click(Sender: TObject);
begin
  if Cli.State = vsStopped then Cli.Start else Cli.Stop;
  ShowStatus;
end;


procedure TMainForm.SpeedButton2Click(Sender: TObject);
begin
  if Cli.State < vsRunning then
     begin
     MessageDlg('Please connect to the VNA first', mtError, [mbOk], 0);
     Exit;
     end;

  if (ReflModeRadioButton.Checked and not Clb.HasReflectionData) or
     ((TransModeRadioButton.Checked) and not Clb.HasTransmissionData) then
     begin
     MessageDlg('Please perform calibration first', mtError, [mbOk], 0);
     Exit;
     end;

  Cli.SetAtten(Clb.Atten);
  Cli.Scan(Clb.FreqB, Clb.FreqE, Clb.PointCnt);

  ProgressDialog.ProgressBar1.Position := 0;
  ProgressDialog.ShowModal;
end;


procedure TMainForm.SpeedButton4Click(Sender: TObject);
begin
  CalibrationDialog.ShowModal;
end;



procedure TMainForm.WmDropFiles(var Msg: TWMDropFiles);
var
  Cnt: integer;
  FileName: TFileName;
begin
  try
    //file count
    Cnt := DragQueryFile(Msg.Drop, $FFFFFFFF, nil, 0);
    if Cnt <> 1 then Exit;

    //filename length
    Cnt := DragQueryFile(Msg.Drop, 0, nil, 0);
    if (Cnt < 1) or (Cnt > 2048) then Exit;

    //file name
    SetLength(FileName, Cnt);
    DragQueryFile(Msg.Drop, 0, @FileName[1], Cnt+1);
    if not FileExists(FileName) then Exit;

    //open file
    LoadSnp(FileName);
  finally
     DragFinish(Msg.Drop);
    Msg.Result := 0;
  end;
end;

procedure TMainForm.WmRun(var Message: TMessage);
begin
  Cli.Start;
  ShowStatus;
end;


procedure TMainForm.LoadCalibrationDataMNUClick(Sender: TObject);
begin
  CalibrationDialog.LoadBtn.Click;
end;


procedure TMainForm.LoadSnPfileMNUClick(Sender: TObject);
begin
  if not OpenDialog1.Execute then Exit;
  LoadSnp(OpenDialog1.FileName);
end;


procedure TMainForm.LoadSnP(AFileName: TFileName);
var
  s11, s21: TScanArray;
begin
  ReadSnPFile(AFileName, s11, s21);

  Res.Clear;

  //reflection mode data
  if s11 <> nil then
    begin
    ReflModeRadioButton.Checked := true;
    Res.CorrectedData := s11;
    Res.ComputeReflectionParams;
    RlcFrame1.PlotCircuit(Res.Rlc.Tanks);
    ChartSelectionFrame1.ParamGroup := vpgReflectionParams;
    Smith.Invalidate;
    end

  //transmission mode data
  else if s21 <> nil then
    begin
    TransModeRadioButton.Checked := true;
    Res.CorrectedData := s21;
    Res.ComputeTransmissionParams;
    RlcFrame1.PlotCircuit(nil);
    ChartSelectionFrame1.ParamGroup := vpgTransmissionParams;
    SelectSmithMode(false);
    end;

  Chart.ParamsToChart;
  ShowStatus;
end;


procedure TMainForm.SaveCalibrationDataMNUClick(Sender: TObject);
begin
  CalibrationDialog.SaveBtn.Click;
end;


procedure TMainForm.SaveChartImageMNUClick(Sender: TObject);
var
  Box: TPaintBox;
begin
  if Smith.Visible then Box := Smith.PaintBox1 else Box := Chart.PaintBox1;
  SaveImage(Box);
end;


procedure TMainForm.SaveImage(Box: TPaintBox);
var
  Bmp: TBitmap;
  Png: TPngImage;
begin
  if not SaveDialog2.Execute then Exit;
  Bmp := TBitMap.Create;
  try
    //paintbox to bitmap
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(Box.Width, Box.Height);
    BitBlt(Bmp.Canvas.Handle, 0, 0, Bmp.Width, Bmp.Height, Box.Canvas.Handle, 0, 0, SRCCOPY);

    //bitmap to png
    SaveAsPng(Bmp, SaveDialog2.FileName);
  finally Bmp.Free; end;
end;

procedure TMainForm.SaveAsPng(Bmp: TBitMap; FileName: TFileName);
var
  Png: TPngImage;
begin
    Png := TPngImage.Create;
    try
      Png.Assign(Bmp);
      Png.SaveToFile(FileName);
    finally Png.Free; end;
end;


procedure TMainForm.SaveRlcImageMNUClick(Sender: TObject);
begin
  if not SaveDialog2.Execute then Exit;
  SaveAsPng(RlcFrame1.Image1.Picture.Bitmap, SaveDialog2.FileName);
end;


procedure TMainForm.SaveS1PFileMNUClick(Sender: TObject);
begin
  SaveDialog1.DefaultExt := 's1p';
  SaveDialog1.Filter := 's1p Files (*.s1p)|*.s1p|All Files (*.*)|*.*';
  if not SaveDialog1.Execute then Exit;
  WriteSnPFile(SaveDialog1.FileName, Res.GetS11, nil);
end;


procedure TMainForm.SaveS2PFileMNUClick(Sender: TObject);
begin
  SaveDialog1.DefaultExt := 's2p';
  SaveDialog1.Filter := 's2p Files (*.s2p)|*.s2p|All Files (*.*)|*.*';
  if not SaveDialog1.Execute then Exit;

  WriteSnPFile(SaveDialog1.FileName, nil, Res.GetS21);
end;


procedure TMainForm.AboutMNUClick(Sender: TObject);
begin
  //MessageDlg('Copyright © 2013 Alex Shovkoplyas, VE3NEA', mtInformation, [mbOK], 0);
  AboutDialog.ShowModal;
end;

procedure TMainForm.PopupMenu1Popup(Sender: TObject);
begin
  PopupMenu1.Items[0].Visible := GetKeyState(VK_CONTROL) < 0;
end;






//------------------------------------------------------------------------------
//                               hardware
//------------------------------------------------------------------------------
procedure TMainForm.ConnectionEvent(Sender: TObject);
begin
  ShowStatus;
  ProgressDialog.Error;
end;


procedure TMainForm.BlockEvent(Senter: TObject; AData: TIntComplexArray);
begin
  if ProgressDialog.Visible then
    begin
    ProgressDialog.ProgressBar1.Position := Round(Cli.ScanProgress * 100) + 1;
    ProgressDialog.ProgressBar1.Position := ProgressDialog.ProgressBar1.Position - 1;
    end;
end;


procedure TMainForm.ScanEvent(Sender: TObject; AData: TScanArray);
begin
  ProgressDialog.Close;

  Res.Clear;
  Res.RawData := Copy(AData);
  Res.ComputeRawParams;

  //calibration data received
  if CalibrationDialog.Visible then
    begin
    CalibrationDialog.ProcessScannedData(AData);
    ChartSelectionFrame1.ParamGroup := vpgRawParams;
    Chart.ResetZoom;
    SelectSmithMode(false);
    end

  //reflection mode data
  else if IsReflectionMode then
    begin
    Res.CorrectedData := Clb.CorrectReflectionData(AData);
    Res.ComputeReflectionParams;
    RlcFrame1.PlotCircuit(Res.Rlc.Tanks);
    ChartSelectionFrame1.ParamGroup := vpgReflectionParams;
    Smith.Invalidate;
    end

  //transmission mode data
  else
    begin
    Res.CorrectedData := Clb.CorrectTransmissionData(AData);
    Res.ComputeTransmissionParams;
    RlcFrame1.PlotCircuit(nil);
    ChartSelectionFrame1.ParamGroup := vpgTransmissionParams;
    SelectSmithMode(false);
    end;

  Chart.ParamsToChart;
  ShowStatus;
end;


procedure TMainForm.SelectSmithMode(AValue: boolean);
begin
  if AValue
    then SmithChartRadioButton.Checked := true
    else RectangularChartRadioButton.Checked := true;
  ModeRadioGroupClick(nil);
end;


procedure TMainForm.ShowStatus;
const
  TextColors: array[0..4] of TColor = (clGray, clRed, clBlue, $CCDDFF, clGreen);
var
  Idx: integer;
begin
  //select bitmap
  Idx := 0;
  case Cli.State of
    vsStopped: Idx := 0;
    vsUdpError, vsTimeout: Idx := 1;
    vsDiscoverySent, vsStartSent: Idx := 2;
    vsRunning: if Cli.Clipping or Cli.MissedPackets then Idx := 3 else Idx := 4;
    end;

  //draw bitmap
  with StatusImage.Picture.Bitmap do
    with Canvas do
    begin
    Brush.Color := clBlue;
    FillRect(Rect(0,0, Width, Height));
    ImageList1.GetBitmap(Idx, StatusImage.Picture.Bitmap);
    end;

  if Cli.State = vsStopped then SpeedButton1.Caption := 'Connect' else SpeedButton1.Caption := 'Disconnect';
  ConnectMNU.Caption := SpeedButton1.Caption;
  SpeedButton1.Down := Cli.State = vsStopped;

  StatusEdit.Font.Color := TextColors[Idx];
  StatusEdit.Text := ' ' + StatusText[Cli.State];

  //if temp errors, set cleanup time
  if Idx = 3 then
    begin
    Cli.Clipping := false;
    Cli.MissedPackets := false;
    Timer1.Enabled := true;

    if Cli.Clipping then StatusEdit.Text := ' Clipping'
    else if Cli.MissedPackets then StatusEdit.Text :=  ' Missed Packets'
    end;
end;


procedure TMainForm.SmithChartMNUClick(Sender: TObject);
begin
  SelectSmithMode(true);
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := false;
  Showstatus;
end;



function TMainForm.IsReflectionMode: boolean;
begin
  Result := ReflModeRadioButton.Checked;
end;






//------------------------------------------------------------------------------
//                                 data
//------------------------------------------------------------------------------
procedure TMainForm.PutRawIQDataToClipboard1Click(Sender: TObject);
{$IFDEF DEBUG_MODE}
var
  i: integer;
  Data: TIntComplexArray;
  {$ENDIF}
begin
  {$IFDEF DEBUG_MODE}
  if (Chart.FLastPointIndex < 0) or (Chart.FLastPointIndex > High(Cli.FScanArray)) then
    begin Beep; Exit; end;

  Data := Cli.FScanArray[Chart.FLastPointIndex].IqData;

  with TStringList.Create do
    try
      for i:=0 to High(Data) do Add(Format('%.03d %.10d', [i, Data[i].Re]));
      Add('');
      for i:=0 to High(Data) do Add(Format('%.03d %.10d', [i, Data[i].Im]));
      Clipboard.AsText := Text;
    finally Free; end;
  {$ENDIF}
end;



procedure TMainForm.RectangularChartMNUClick(Sender: TObject);
begin
  SelectSmithMode(false);
end;


procedure TMainForm.ReflectionModeMNUClick(Sender: TObject);
begin
  ReflModeRadioButton.Checked := true;
end;

procedure TMainForm.TrackBar1Change(Sender: TObject);
begin
  Res.Rlc.Complexity := TrackBar1.Position;
  if Res.Rlc.FittedZ = nil then Exit;

  Res.ComputeReflectionParams;
  RlcFrame1.PlotCircuit(Res.Rlc.Tanks);
  Smith.Invalidate;
  Chart.ParamsToChart;
  ShowStatus;
end;


procedure TMainForm.TransmissionModeMNUClick(Sender: TObject);
begin
  TransModeRadioButton.Checked := true;
end;

procedure TMainForm.ViewReadmeMNUClick(Sender: TObject);
var
  FileName: TFileName;
begin
  FileName := ExtractFilePath(ParamStr(0)) + 'Readme.txt';
  ShellExecute(GetDesktopWindow, 'open', PChar(FileName), '', '', SW_SHOWNORMAL);
end;


end.
