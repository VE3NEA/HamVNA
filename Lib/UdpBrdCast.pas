//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2015 Alex Shovkoplyas VE3NEA

unit UdpBrdCast;

interface


uses
  Windows, SysUtils, Types, IdWship6, JwaIpTypes, IdWinsock2;


function GetBroadcastAddresses: TStringDynArray;



implementation

function GetAdaptersAddresses(Family:cardinal; Flags:cardinal; Reserved:pointer;
  pAdapterAddresses: PIP_ADAPTER_ADDRESSES; pOutBufLen:pcardinal):cardinal;stdcall;
  external 'iphlpapi.dll';


function GetBroadcastAddresses: TStringDynArray;
var
  BufLen: DWord;
  Buf : array of Byte;
  rc: DWord;
  Adapter: PIP_ADAPTER_ADDRESSES;
  Host: array [0..NI_MAXHOST-1] of Char;
  Pref: PIP_ADAPTER_PREFIX;
begin
  BufLen := 0;
  rc := GetAdaptersAddresses(AF_INET,  GAA_FLAG_INCLUDE_PREFIX, nil, nil, @BufLen);
  if rc <> ERROR_BUFFER_OVERFLOW then raise Exception.Create('GetAdaptersInfo() failed');

  SetLength(Buf, BufLen);
  Adapter := @Buf[0];
  rc := GetAdaptersAddresses(AF_INET, GAA_FLAG_INCLUDE_PREFIX, nil, Adapter, @BufLen);
  if rc <> ERROR_SUCCESS then raise Exception.Create('GetAdaptersInfo() failed');

  Result := nil;
  repeat
    if (Adapter.FirstPrefix <> nil) and
       (Adapter.FirstPrefix.Next <> nil) and
       (Adapter.FirstPrefix.Next.Next <> nil) then
      begin
      Pref := Adapter.FirstPrefix.Next.Next;
      rc := GetNameInfo(PSockAddr(Pref.Address.lpSockaddr),
        Pref.Address.iSockaddrLength, Host, NI_MAXHOST, nil, 0, NI_NUMERICHOST);
      if rc <> ERROR_SUCCESS then raise Exception.Create('GetNameInfo() failed');

      SetLength(Result, Length(Result)+1);
      Result[High(Result)] := AnsiString(PChar(@Host[0]));
      end;

    Adapter := Adapter.Next;
  until Adapter = nil;
end;



end.

