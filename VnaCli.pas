//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2013 Alex Shovkoplyas VE3NEA

unit VnaCli;

interface

uses
  Windows, SysUtils, Classes, ExtCtrls, Math, ComplMath,
  IdBaseComponent, IdComponent, IdUDPBase, IdUDPServer, IdSocketHandle, IdGlobal;


type
  {$IFDEF VER260}TBytes = TIdBytes;{$ENDIF}


  THermesVnaState = (vsStopped, vsUdpError, vsTimeout, vsDiscoverySent,
    vsStartSent, vsRunning);

  TIntComplex = record Re, Im: integer; end;
  TIntComplexArray = array of TIntComplex;

  PScanPoint = ^TScanPoint;
  TScanPoint = record
    Freq: integer;
    Value: TComplex;
    Variance: Single;
    {$IFDEF DEBUG_MODE}IqData: TIntComplexArray;{$ENDIF}
    end;
  TScanArray = array of TScanPoint;

  TDataEvent = procedure(Sender: TObject; AData: TIntComplexArray) of object;
  TScanEvent = procedure(Sender: TObject; AData: TScanArray) of object;


  THermesVnaClient = class
  private
    FUdp: TIdUDPServer;

    FState: THermesVnaState;

    FPacketCnt: integer;
    FBlock: TIntComplexArray;
    FBlockSize: integer;
    FCurrentPos: integer;
    FWindow: array of Single;
    FScanIdx: integer;

    FOnConnectionChange: TNotifyEvent;
    FOnPacket: TDataEvent;
    FOnBlock: TDataEvent;
    FOnScan: TScanEvent;

    procedure SetupHermes;
    procedure StartIQ(Value: boolean);
    procedure ProcessData(AData: TBytes);

    procedure UdpReadEvent(AThread: TIdUDPListenerThread;
      {$IFDEF VER260}const{$ENDIF} AData: TBytes; ABinding: TIdSocketHandle);
    procedure UdpExceptionEvent(AThread: TIdUDPListenerThread; ABinding:
      TIdSocketHandle; const AMessage: string; const AExceptionClass: TClass);
    procedure TimerEvent(Sender: TObject);
    procedure AddToBlock(AData: TIntComplexArray);
    procedure SetBlockSize(const Value: integer);
    procedure AddToScan;
  public
    HermesMac, HermesIp, HermesVersion: string;
    Clipping, MissedPackets: boolean;
    FScanArray: TScanArray;

    //put it back to private
    FTimer: TTimer;

    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;

    procedure SetFreq(AFreq: integer);
    procedure SetAtten(AEnable: boolean);
    procedure GetBlock(AFreq: integer);
    procedure Scan(FreqB, FreqE, Points: integer);
    function ScanProgress: Single;
    procedure AbortScan;

    property State: THermesVnaState read FState;
    property BlockSize: integer read FBlockSize write SetBlockSize;

    //connection estableshed or lost
    property OnConnectionChange: TNotifyEvent read FOnConnectionChange write FOnConnectionChange;
    //single udp packet arrived
    property OnPacket: TDataEvent read FOnPacket write FOnPacket;
    //a block of required number of samples received (in multiple udp packets)
    property OnBlock: TDataEvent read FOnBlock write FOnBlock;
    //block received and processed at every scan frequency
    property OnScan: TScanEvent read FOnScan write FOnScan;
  end;


const
  StatusText: array[THermesVnaState] of string = (
    'Stopped', 'UDP Error', 'No response from VNA', 'Connecting...', 'Connecting...', 'Connected');






implementation

//------------------------------------------------------------------------------
//                      hermes packet structure
//------------------------------------------------------------------------------
type
  //Command and Control (C&C) bytes
  TCCArray = array[0..4] of byte;


  //data sample = (I + Q + Mic)
  TSample = packed record
    i3, i2, i1: Byte;
    q3, q2, q1: Byte;
    m1, m2: Byte;
    function AsComplex: TIntComplex;
    end;


  //former USB frame, still used inside a UDP packet
  TFrame = packed record
    SevenF: array[0..2] of Byte;
    CC: TCCArray;
    Data: array[0..62] of TSample;
    end;


  //UDP data packet from Hermes
  PPacket = ^TPacket;
  TPacket = packed record
    Effe, Command: Word;
    SeqNumber: integer;
    Frame1, Frame2: TFrame;
    procedure Clear;
    end;


function TSample.AsComplex: TIntComplex;
begin
  Result.Im := ((i3 shl 24) + (i2 shl 16) + (i1 shl 8));
  Result.Re := ((q3 shl 24) + (q2 shl 16) + (q1 shl 8));
end;


procedure TPacket.Clear;
begin
  ZeroMemory(@Self, SizeOf(TPacket));
  Effe := $FEEF;
  Command := $0201;
  Frame1.SevenF[0] := $7F;
  Frame1.SevenF[1] := $7F;
  Frame1.SevenF[2] := $7F;
  Frame2.SevenF := Frame1.SevenF;
end;


procedure ReverseBytes(Src, Dst: PByteArray; Count: integer);
var
  i: integer;
begin
  for i:=0 to Count-1 do Dst[i] := Src[Count-1-i];
end;






//------------------------------------------------------------------------------
//                        interface to hardware
//------------------------------------------------------------------------------
const
  //C&C words to initialize hardware
  CC1: TCCArray = ($00, $00, $00, $04, $00); //rate = 48 kHz, attenuator = off
  CC2: TCCArray = ($12, $00, $80, $00, $00); //VNA mode = on

  SAMPLES_PER_PACKET = 126;

  //128{fir} + 5{cordic+cic+varcic}, but ignore the last 33
  SAMPLES_TO_DISCARD = 100;

  HERMES_PORT = 1024;



{ THermesVnaClient }

constructor THermesVnaClient.Create;
begin
  FUdp := TIdUDPServer.Create(nil);
  FUdp.OnUDPRead := UdpReadEvent;
  FUdp.OnUDPException := UdpExceptionEvent;
  FUdp.BroadcastEnabled := true;

  FTimer := TTimer.Create(nil);
  FTimer.OnTimer := TimerEvent;
  FTimer.Interval := 3000;

  BlockSize := 90;//64;

  Stop;
end;


destructor THermesVnaClient.Destroy;
begin
  FTimer.Free;
  FUdp.Active := false;
  FUdp.Free;
  inherited;
end;


procedure THermesVnaClient.Start;
const
  DiscoveryPacket: array[0..2] of byte = ($EF, $FE, $02);
  DISCOVERY_PACKET_SIZE = 63;
var
  Bytes: TBytes;
begin
  //send discovery packet
  Bytes := nil;
  SetLength(Bytes, DISCOVERY_PACKET_SIZE);
  Move(DiscoveryPacket, Bytes[0], Length(DiscoveryPacket));
  FUdp.Broadcast(Bytes, HERMES_PORT);

  Clipping := false;
  MissedPackets := false;

  //reset timer
  FTimer.Enabled := false;
  FTimer.Enabled := true;

  FState := vsDiscoverySent;
end;


procedure THermesVnaClient.Stop;
begin
  FTimer.Enabled := false;

  if FState = vsRunning then StartIQ(false);

  Clipping := false;
  MissedPackets := false;

  //disable block and scan modes
  FCurrentPos := MAXINT;
  FScanIdx := MAXINT;

  FState := vsStopped;
end;


procedure THermesVnaClient.SetupHermes;
var
  Packet: PPacket;
  Bytes: TBytes;
begin
  Bytes := nil;
  SetLength(Bytes, SizeOf(TPacket));
  Packet := PPacket(@Bytes[0]);
  Packet.Clear;

  Packet.Frame1.CC := CC1;
  Packet.Frame2.CC := CC1;
  FUdp.SendBuffer(HermesIp, HERMES_PORT, Id_IPv4, Bytes);

  Packet.Frame1.CC := CC2;
  Packet.Frame2.CC := CC2;
  FUdp.SendBuffer(HermesIp, HERMES_PORT, Id_IPv4, Bytes);
end;


procedure THermesVnaClient.StartIQ(Value: boolean);
const
  StartPacket: array[0..3] of byte = ($EF, $FE, $04, $01);
  START_PACKET_SIZE = 64;
var
  Bytes: TBytes;
begin
  Bytes := nil;
  SetLength(Bytes, START_PACKET_SIZE);
  Move(StartPacket, Bytes[0], SizeOf(StartPacket));
  if Value then Bytes[3] := $01 else Bytes[3] := $00;
  FUdp.SendBuffer(HermesIp, HERMES_PORT, Id_IPv4, Bytes);
  FState := vsStartSent;
end;


procedure THermesVnaClient.SetAtten(AEnable: boolean);
var
  Packet: PPacket;
  Bytes: TBytes;
begin
  if FState <> vsRunning then begin Beep; Exit; end;

  Bytes := nil;
  SetLength(Bytes, SizeOf(TPacket));
  Packet := PPacket(@Bytes[0]);
  Packet.Clear;
  Packet.Frame1.CC := CC1;

  if AEnable
    then Packet.Frame1.CC[3] := $00
    else Packet.Frame1.CC[3] := $04;

  Packet.Frame2.CC := Packet.Frame1.CC;
  FUdp.SendBuffer(HermesIp, HERMES_PORT, Id_IPv4, Bytes);
end;


procedure THermesVnaClient.SetFreq(AFreq: integer);
const
  M2: Int64 = 1172812403;
var
  Packet: PPacket;
  Bytes: TBytes;
  //PrevRes, Res: Double;
begin
  if FState <> vsRunning then begin Beep; Exit; end;

  //This code was added to minimize phase jitter in CORDIC
  //by making the truncated part of the frequency word as small as possible
  //This did not help to remove spikes from the VNA data so the code
  //has been disabled
{
  PrevRes := 0;
  repeat
    Res := ((AFreq * M2) shr 25) and $7FF;
    if Res < PrevRes then Break;
    Inc(AFreq);
    PrevRes := Res;
  until false;
}

  //init packet
  Bytes := nil;
  SetLength(Bytes, SizeOf(TPacket));
  Packet := PPacket(@Bytes[0]);
  Packet.Clear;

  //Set TX Frequency command
  Packet.Frame1.CC[0] := $02;

  //frequency, big endian
  ReverseBytes(@AFreq,  @Packet.Frame1.CC[1], 4);
  Packet.Frame2.CC := Packet.Frame1.CC;

  //send
  FUdp.SendBuffer(HermesIp, HERMES_PORT, Id_IPv4, Bytes);
end;


procedure THermesVnaClient.TimerEvent(Sender: TObject);
begin
  case FState of
    //connection failed. wait 1.5 seconds before restarting
    vsDiscoverySent, vsStartSent, vsRunning:
      begin
      Stop;
      FState := vsTimeout;
      FTimer.Enabled := true;
      end;

    //end of 1.5s interval. restart
    vsUdpError, vsTimeout:
      Start;
    end;

  if Assigned(FOnConnectionChange) then FOnConnectionChange(Self);
end;


procedure THermesVnaClient.UdpExceptionEvent(AThread: TIdUDPListenerThread;
  ABinding: TIdSocketHandle; const AMessage: string;
  const AExceptionClass: TClass);
begin
  if FState = vsStopped then Exit;

  //StatusText := 'UDP error: ' + AMessage;
  FState := vsUdpError;
  if Assigned(FOnConnectionChange) then FOnConnectionChange(Self);
  FTimer.Enabled := true;
end;






//------------------------------------------------------------------------------
//                        read received packet
//------------------------------------------------------------------------------

procedure THermesVnaClient.UdpReadEvent(AThread: TIdUDPListenerThread;
  {$IFDEF VER260}const{$ENDIF} AData: TBytes; ABinding: TIdSocketHandle);
var
  b: byte;
begin
  case FState of
    //reply to discovery packet
    vsDiscoverySent:
      begin
      //is Hermes?
      if not (AData[2] in [2,3]) then Exit;
      //save info
      HermesMac := Format('%.2x %.2x %.2x %.2x %.2x %.2x', [AData[3],AData[4],AData[5],AData[6], AData[7], AData[8]]);
      HermesIp := ABinding.PeerIP;
      HermesVersion := Format('%3.1f', [0.1*AData[9]]);
      //start operation
      SetupHermes;
      StartIQ(true);
      end;

    //first data packet
    vsStartSent:
      begin
      FState := vsRunning;
      if Assigned(FOnConnectionChange) then FOnConnectionChange(Self);
      ProcessData(AData);
      end;

    //subsequent data packets
    vsRunning:
      ProcessData(AData);

    else
      //do not reset timer
      Exit;
    end;

  //reset timeout
  FTimer.Enabled := false;
  FTimer.Enabled := true;
end;


procedure THermesVnaClient.ProcessData(AData: TBytes);
var
  Packet: PPacket;
  i, Cnt: integer;
  IqData: TIntComplexArray;
  NewPacketCnt: integer;
  MarkerPos: integer;
begin
  Packet := @AData[0];

  //detect clipping
  if ((Packet.Frame1.CC[0] and $F8) = 0) and ((Packet.Frame1.CC[1] and $01) <> 0)
    then Clipping := true;
  if ((Packet.Frame2.CC[0] and $F8) = 0) and ((Packet.Frame2.CC[1] and $01) <> 0)
    then Clipping := true;

  //detect gaps
  ReverseBytes(@Packet.SeqNumber, @NewPacketCnt, 4);
  if (FPacketCnt <> 0) and (NewPacketCnt <> (FPacketCnt+1))
    then MissedPackets := true;
  FPacketCnt := NewPacketCnt;

  ///allocate buffer for data
  Cnt := Length(Packet.Frame1.Data);
  IqData := nil;
  SetLength(IqData, 2 * Cnt);

  //import data
  for i:=0 to Cnt-1 do
    begin
    IqData[i] := Packet.Frame1.Data[i].AsComplex;
    IqData[Cnt+i] := Packet.Frame2.Data[i].AsComplex;
    end;

  //look for start marker
  MarkerPos := MAXINT;
  for i:=0 to Cnt-1 do
    if ((Packet.Frame1.Data[i].m2 and 1) = 1)
      then begin MarkerPos := i; Break; end;
  if MarkerPos = MAXINT then
    for i:=0 to Cnt-1 do
      if ((Packet.Frame2.Data[i].m2 and 1) = 1)
        then begin MarkerPos := Cnt+i; Break; end;
  if MarkerPos <> MAXINT then
    FCurrentPos := Max(FCurrentPos, -MarkerPos - SAMPLES_TO_DISCARD);

  //use data
  if Assigned(FOnPacket) then FOnPacket(Self, IqData);
  AddToBlock(IqData);
end;






//------------------------------------------------------------------------------
//                        get block of I/Q data
//------------------------------------------------------------------------------

//skip old packets, receive new packets into the FBlock array
procedure THermesVnaClient.GetBlock(AFreq: integer);
begin
  if FState <> vsRunning then begin Beep; Exit; end;

  SetLength(FBlock, FBlockSize);

  //if start marker not found in the first 8 packets, start anyway
  FCurrentPos := - 8 * SAMPLES_PER_PACKET;

  //set frequency, start receiving packets
  Clipping := false;
  MissedPackets := false;
  FPacketCnt := 0;
  SetFreq(AFreq);
end;


procedure THermesVnaClient.AddToBlock(AData: TIntComplexArray);
var
  i: integer;
begin
  //no data needed
  if FCurrentPos >= FBlockSize then Exit;

  //data needed
  for i:=0 to High(AData) do
    begin
    //data available
    if (FCurrentPos >= Low(FBlock)) and (FCurrentPos <= High(FBlock)) then
      FBlock[FCurrentPos] := AData[i];
    Inc(FCurrentPos);
    end;

  //finished collecting data
  if FCurrentPos >= FBlockSize then
    begin
    if Assigned(FOnBlock) then FOnBlock(Self, FBlock);
    AddToScan;
    end;
end;






//------------------------------------------------------------------------------
//                               scan
//------------------------------------------------------------------------------
procedure THermesVnaClient.SetBlockSize(const Value: integer);

  function BlackmanHarrisWin(x: Single): Single;
    const a0 = 0.35875; a1 = 0.48829;	a2 = 0.14128;	a3 = 0.01168;
    begin Result := a0 - a1*Cos(2*Pi*x) + a2*Cos(4*Pi*x) - a3*Cos(6*Pi*x); end;

var
  i: integer;
  Sum: Single;
begin
  FBlockSize := Value;

  //blackman-harris window function
  SetLength(FWindow, FBlockSize);
  for i:=0 to FBlockSize-1 do FWindow[i] := BlackmanHarrisWin(i / FBlockSize);
  Sum := 0;
  for i:=0 to FBlockSize-1 do Sum := Sum + FWindow[i];
  for i:=0 to FBlockSize-1 do FWindow[i] := FWindow[i] / Sum;
end;


//at every scan point set frequency, receive block of data, process
procedure THermesVnaClient.Scan(FreqB, FreqE, Points: integer);
var
  i: integer;
begin
  if FState <> vsRunning then begin Beep; Exit; end;

  //validate parameters
  FreqE := Max(FreqE, FreqB);
  Points := Min(Points, FreqE - FreqB + 1);

  //allocate buffer
  FScanArray := nil;
  SetLength(FScanArray, Points);

  //compute frequencies
  for i:=0 to Points-1 do
    FScanArray[i].Freq := FreqB + Round(((FreqE-FreqB) / (Points-1)) * i);

  //request first block of data
  FScanIdx := 0;
  GetBlock(FreqB);
end;


function THermesVnaClient.ScanProgress: Single;
begin
  Result := Max(0, Min(1, FScanIdx / Length(FScanArray)));
end;


//block of data received, compute complex signal and noise
procedure THermesVnaClient.AddToScan;
var
  i: integer;
  C: TComplex;
  Variance: Double;

  function Cpl(C: TIntComplex): TComplex;
    begin Result := COMPL(FBlock[i].Re, FBlock[i].Im) / MAXINT; end;

begin
  if FScanIdx > High(FScanArray) then Exit;

  //signal = sample mean
  C := ZeroComplex;
  for i:=0 to FBlockSize-1 do C := C + Cpl(FBlock[i]) * FWindow[i];

  //variance of samples
  Variance := 0;
  for i:=0 to FBlockSize-1 do Variance := Variance + (Cpl(FBlock[i]) - C).SqrMag;
  Variance := Variance / (FBlockSize-1);
  //variance of the mean
  Variance := Variance / (FBlockSize / 4{filter bandwidth});

  FScanArray[FScanIdx].Value := C;
  FScanArray[FScanIdx].Variance := Variance;
  {$IFDEF DEBUG_MODE}FScanArray[FScanIdx].IqData := Copy(FBlock);{$ENDIF}

  Inc(FScanIdx);
  if FScanIdx <= High(FScanArray)
    //request data for the next point
    then GetBlock(FScanArray[FScanIdx].Freq)
    //all points done, return results
    else if Assigned(FOnScan) then FOnScan(Self, FScanArray);
end;


procedure THermesVnaClient.AbortScan;
begin
  FCurrentPos := MAXINT;
  FScanIdx := MAXINT;
end;


end.

