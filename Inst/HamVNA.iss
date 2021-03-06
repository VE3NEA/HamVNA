; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{4BE5E743-7865-443F-83F8-0AD3FF3BE05F}
AppName=Ham VNA
AppVersion=1.1
;AppVerName=Ham VNA 1.1
AppPublisher=Afreet Software, Inc.
AppPublisherURL=http://www.dxatlas.com/HamVNA
AppSupportURL=http://www.dxatlas.com/HamVNA
AppUpdatesURL=http://www.dxatlas.com/HamVNA
DefaultDirName={pf}\Afreet\Ham VNA
DefaultGroupName=Ham VNA
DisableProgramGroupPage=yes
InfoAfterFile=C:\Proj\DSP\HamVNA\Run\Readme.txt
OutputBaseFilename=HamVnaSetup
Compression=lzma
SolidCompression=yes

[Languages]
Name: english; MessagesFile: compiler:Default.isl

[Tasks]
Name: desktopicon; Description: {cm:CreateDesktopIcon}; GroupDescription: {cm:AdditionalIcons}; Flags: unchecked

[Files]
Source: C:\Proj\DSP\HamVNA\Run\HamVNA.exe; DestDir: {app}; Flags: ignoreversion
Source: C:\Proj\DSP\HamVNA\Run\587.dll; DestDir: {app}; Flags: ignoreversion
Source: C:\Proj\DSP\HamVNA\Run\FastMM_FullDebugMode.dll; DestDir: {app}; Flags: ignoreversion
Source: C:\Proj\DSP\HamVNA\Run\HamVNA.exe; DestDir: {app}; Flags: ignoreversion
Source: C:\Proj\DSP\HamVNA\Run\libblas.dll; DestDir: {app}; Flags: ignoreversion
Source: C:\Proj\DSP\HamVNA\Run\libgcc_s_dw2-1.dll; DestDir: {app}; Flags: ignoreversion
Source: C:\Proj\DSP\HamVNA\Run\libgfortran-3.dll; DestDir: {app}; Flags: ignoreversion
Source: C:\Proj\DSP\HamVNA\Run\liblapack.dll; DestDir: {app}; Flags: ignoreversion
Source: C:\Proj\DSP\HamVNA\Run\libquadmath-0.dll; DestDir: {app}; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: {group}\Ham VNA; Filename: {app}\HamVNA.exe
Name: {group}\{cm:UninstallProgram,Ham VNA}; Filename: {uninstallexe}
Name: {commondesktop}\Ham VNA; Filename: {app}\HamVNA.exe; Tasks: desktopicon

[Run]
Filename: {app}\HamVNA.exe; Description: {cm:LaunchProgram,Ham VNA}; Flags: nowait postinstall skipifsilent
