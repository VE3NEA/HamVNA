//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit Ini;

interface

uses
  Windows, SysUtils, Forms, ShlObj, IniFiles;

procedure ToIni;
procedure FromIni;
function GetIniFolder: TFileName;



implementation

uses
  Main, VnaCli;


//------------------------------------------------------------------------------
//                             ini folder
//------------------------------------------------------------------------------
function GetIniName: TFileName;
var
  AppName: TFileName;
begin
  if (GetVersion and $FF) < 6 //6.0 = Vista
    then
      Result := ChangeFileExt(ParamStr(0), '.ini')
    else
      begin
      AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
      SetLength(Result, MAX_PATH);
      SHGetSpecialFolderPath(Application.Handle, @Result[1], CSIDL_APPDATA, true);
      Result := PChar(Result) + '\Afreet\Products\' + AppName + '\';
      try ForceDirectories(Result); except end;
      Result := Result + AppName + '.ini';
      end;
end;


function GetIniFolder: TFileName;
begin
  Result := ExtractFilePath(GetIniName);
end;






//------------------------------------------------------------------------------
//                             ini read/write
//------------------------------------------------------------------------------
procedure ToIni;
begin
  with TIniFile.Create(GetIniName) do
    try
      WriteBool('Settings', 'Run', MainForm.Cli.State = vsRunning);
      WriteBool('Settings', 'Mode', MainForm.ReflModeRadioButton.Checked);
      WriteBool('Settings', 'SmithChart', MainForm.SmithChartRadioButton.Checked);
      WriteString('Settings', 'CalibrationFile', MainForm.Clb.FileName);
    finally
      Free;
    end;
end;


procedure FromIni;
begin
  with TIniFile.Create(GetIniName) do
    try
      //mode and chart
      MainForm.ReflModeRadioButton.Checked := ReadBool('Settings', 'Mode', MainForm.ReflModeRadioButton.Checked);
      MainForm.TransModeRadioButton.Checked := not MainForm.ReflModeRadioButton.Checked;
      MainForm.SelectSmithMode(ReadBool('Settings', 'SmithChart', MainForm.SmithChartRadioButton.Checked));

      //calibration file
      MainForm.Clb.FileName := ReadString('Settings', 'CalibrationFile', MainForm.Clb.FileName);
      with  MainForm.Clb do if FileName <> '' then LoadFromFile(FileName);

      //auto-start
      if ReadBool('Settings', 'Run', false) then PostMessage(MainForm.Handle, WM_RUN, 0, 0);
    finally
      Free;
    end;
end;



end.

