//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2014 Alex Shovkoplyas VE3NEA

unit SndTypes0;

interface

uses
  SysUtils;

const
  TWO_PI = 2 * Pi;

type
  TIntegerArray = array of integer;
  TSingleArray = array of Single;
  TDataBufferF = array of TSingleArray;
  TDataBufferI = array of TIntegerArray;
  TSingleArray2D = array of TSingleArray;
  TByteArray = array of Byte;

  TVector = TSingleArray;
  TMatrix = TSingleArray2D;

implementation

end.

