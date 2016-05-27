//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.

//Copyright (c) 2014 Alex Shovkoplyas VE3NEA
unit LaPackWrap;

interface

uses
  SysUtils, Math, SndTypes0, ComplMath;


procedure QrDecomposition(A: TMatrix; var Q: TMatrix; var R: TMatrix);
procedure MultiplyMatrices(A, B: TMatrix; var AB: TMatrix);
procedure BackSubstitute(A: TMatrix; b: TVector; var x: TVector);
procedure EigenValues(A: TMatrix; var E: TComplexArray);
procedure LeastSquares(A: TMatrix; b: TVector; var X: TVector);
procedure LeastSquaresWithInequalityConstraints(A, G: TMatrix; b: TVector; var x: TVector);



implementation

//------------------------------------------------------------------------------
//                          LAPACK functions
//------------------------------------------------------------------------------
const LAPACK_DLL = 'liblapack.dll';
const BLAS_DLL = 'libblas.dll';


type
  PSingleArr = ^TSingleArr;
  TSingleArr = array[0..MAXINT div SizeOf(Single) - 1] of Single;


//compute a QR factorization of a real M-by-N  matrix
procedure sgeqrf_(var m: integer; var n: Integer; A: PSingleArr;
  var lda: integer; Tau, Work: PSingleArr; var Ldwork: integer; var Info: integer);
  cdecl; external LAPACK_DLL;

//generate an M-by-N real matrix Q with orthonormal columns
procedure sorgqr_(var m: integer; var n: Integer; var k: Integer; A: PSingleArr;
  var lda: integer; Tau, Work: PSingleArr; var Ldwork: integer; var Info: integer);
  cdecl; external LAPACK_DLL;

//sgemm( TRANSA, TRANSB, M, N, K, ALPHA, A, LDA, B, LDB, BETA, C, LDC )
procedure sgemm_(var TransA: AnsiChar; var TransB: AnsiChar;
  var m: integer; var n: Integer; var k: Integer;
  var Alpha: Single; A: PSingleArr; var lda: integer;
  B: PSingleArr; var ldb: integer; var Beta: Single;
  C: PSingleArr; var ldc: integer);
  cdecl; external BLAS_DLL;

//strtrs solves a triangular system of the form  A * X = B  or  A**T * X = B
procedure strtrs_(var Uplo: AnsiChar; var Trans: AnsiChar; var Diag: AnsiChar;
  var N: integer; var NRHS: integer;  A: PSingleArr; var lda: integer;
  B: PSingleArr; var ldb: integer;  var Info: integer);
  cdecl; external LAPACK_DLL;


//compute for an N-by-N real nonsymmetric matrix A, the eigenvalues and,
//optionally, the left and/or right eigenvectors
procedure sgeev_(var JobVL: AnsiChar; var JobVR: AnsiChar; var N: integer;
  A: PSingleArr; var lda: integer; Wr, Wi: PSingleArr; Vl: PSingleArr;
  var ldvl: integer; Vr: PSingleArr; var ldvr: integer; Work: PSingleArr;
  var lwork: integer; var Info: integer);
  cdecl; external LAPACK_DLL;

//computes the minimum-norm solution to a linear least squares problem for GE matrices
//(M, N, NRHS, A, LDA, B, LDB, S, RCOND, RANK, WORK, LWORK, IWORK, INFO)
procedure sgelsd_(var m: integer; var n: integer; var nrhs: integer;
  A: PSingleArr; var lda: integer; B: PSingleArr; var ldb: integer;
  S: PSingleArr; var Rcond: Single; var Rank: integer; Work: PSingleArr;
  var lwork: integer; IWork: PIntegerArray; var info: integer);
  cdecl; external LAPACK_DLL;

//SOLVES A LINEARLY CONSTRAINED LEAST SQUARES PROBLEM WITH BOTH EQUALITY AND INEQUALITY CONSTRAINTS
procedure lsei_(W: PSingleArr; var mdw: integer; var me: integer; var ma: integer;
  var mg: integer; var n: integer; PrgOpt: PSingleArr; x: PSingleArr;
  var rnorme: Single; var rnorml: Single; var mode: integer; Ws: PSingleArr;
  IP: PIntegerArray);
  cdecl; external '587.dll';






//------------------------------------------------------------------------------
//                         helper functions
//------------------------------------------------------------------------------


//allocate memory, copy matrix data to memory in the Fortran format
procedure MatrixToMem(const M: TMatrix; var Mem: PSingleArr);
var
  i, j: integer;
begin
  GetMem(Mem, Length(M) * Length(M[0]) * SizeOf(Single));

  for i:=0 to High(M) do
    for j:=0 to High(M[0]) do
      Mem[j * Length(M) + i] := M[i,j];
end;

//copy data from memory to matrix, free memory
procedure MemToMatrix(const Mem: PSingleArr; var M: TMatrix; Free: boolean = true);
var
  i, j: integer;
begin
  for i:=0 to High(M) do
    for j:=0 to High(M[0]) do
      M[i,j] := Mem[j * Length(M) + i];

  if Free then FreeMem(Mem);
end;

procedure VectorToMem(const V: TVector; var Mem: PSingleArr);
var
  i: integer;
begin
  GetMem(Mem, Length(V) * SizeOf(Single));
  for i:=0 to High(V) do Mem[i] := V[i];
end;

procedure MemToVector(const Mem: PSingleArr; var V: TVector; Free: boolean = true);
var
  i: integer;
begin
  for i:=0 to High(V) do V[i] := Mem[i];
  if Free then FreeMem(Mem);
end;






//------------------------------------------------------------------------------
//                            wrappers
//------------------------------------------------------------------------------
procedure MultiplyMatrices(A, B: TMatrix; var AB: TMatrix);
var
  m, k, n: integer;
  A_mem, B_mem, AB_mem: PSingleArr;
  TransA, TransB: AnsiChar;
  Alpha, Beta: Single;
  lda, ldb, ldc: integer;
begin
  m := Length(A);
  k := Length(A[0]);  Assert(Length(B) = k);
  n := Length(B[0]);
  lda := m;
  ldb := k;
  ldc := m;
  TransA := 'N';
  TransB := 'N';
  Alpha := 1;
  Beta := 0;

  SetLength(AB, m, n);
  MatrixToMem(A, A_mem);
  MatrixToMem(B, B_mem);
  MatrixToMem(AB, AB_mem);

  sgemm_(TransA, TransB, m, n, k, Alpha, A_mem, lda, B_mem, ldb, Beta, AB_mem, ldc);

  MemToMatrix(AB_mem, AB);
  FreeMem(A_mem);
  FreeMem(B_mem);
end;


procedure QrDecomposition(A: TMatrix; var Q: TMatrix; var R: TMatrix);
var
  m, n, k, lda, ldwork, info: integer;
  Tau, Work: TVector;
  A_mem, Tau_mem, Work_mem: PSingleArr;
  i, j: integer;
  BlockSize: integer;
  TransA, TransB: AnsiChar;
begin
  //A[m,n]: m rows, n cols
  m := Length(A);
  n := Length(A[0]);
  lda := m;
  k := n;

  //data to memory
  MatrixToMem(A, A_mem);
  SetLength(Tau, n);
  VectorToMem(Tau, Tau_mem);

  //optimal block size
  ldwork := -1;
  SetLength(Work, 1);
  VectorToMem(Work, Work_mem);
  SGEQRF_(m, n, A_mem, lda, Tau_mem, Work_mem, ldwork, info);
  MemToVector(Work_mem, Work);
  ldwork := n * Round(Work[0]);

  //perform QR decomposition
  SetLength(Work, ldwork);
  VectorToMem(Work, Work_mem);
  SGEQRF_(m, n, A_mem, lda, Tau_mem, Work_mem, ldwork, info);
  SetLength(R, m, n);
  MemToMatrix(A_Mem, R, false);
  SetLength(R, n, n);
  //zero lower triangle
  for i:=1 to n-1 do for j:=0 to i-1 do R[i,j] := 0;

  //unpack Q
  SORGQR_(m, n, k, A_mem, lda, Tau_mem, Work_mem, ldwork, info);
  SetLength(Q, m, n);
  MemToMatrix(A_Mem, Q);
  FreeMem(Tau_mem);
  FreeMem(Work_mem);
end;


procedure BackSubstitute(A: TMatrix; b: TVector; var x: TVector);
var
  Uplo, Trans, Diag: AnsiChar;
  n, nrhs, lda, ldb, info: integer;
  A_mem, B_mem: PSingleArr;
begin
  Uplo := 'U';
  Trans := 'N';
  Diag := 'N';
  n := Length(A);
  nrhs := 1;
  MatrixToMem(A, A_mem);
  lda := n;
  VectorToMem(b, B_mem);
  ldb := n;

  strtrs_(Uplo, Trans, Diag, n, nrhs, A_mem, lda, B_mem, ldb, Info);

  SetLength(x, Length(b));
  MemToVector(B_mem, x);
  FreeMem(A_Mem);
end;


procedure EigenValues(A: TMatrix; var E: TComplexArray);
var
  JobVL, JobVR: AnsiChar;
  i, n, lda, ldvl, ldvr, lwork, info: integer;
  A_mem, Wr_mem, Wi_mem, Work_mem: PSingleArr;
  Wr, Wi, Work: TVector;
begin
  //params
  JobVL := 'N';
  JobVR := 'N';
  n := Length(A);
  MatrixToMem(A, A_mem);
  lda := n;
  SetLength(Wr, n);
  VectorToMem(Wr, Wr_mem);
  SetLength(Wi, n);
  VectorToMem(Wi, Wi_mem);
  ldvl := 1;
  ldvr := 1;

  //optimal lwork
  SetLength(Work, 1);
  VectorToMem(Work, Work_mem);
  lwork := -1;
  sgeev_(JobVL, JobVR, n, A_mem, lda, Wr_mem, Wi_mem, nil, ldvl, nil, ldvr, Work_mem, lwork, Info);
  MemToVector(Work_mem, Work);
  lwork := Round(Work[0]);

  //call to lapack
  SetLength(Work, lwork);
  VectorToMem(Work, Work_mem);
  sgeev_(JobVL, JobVR, n, A_mem, lda, Wr_mem, Wi_mem, nil, ldvl, nil, ldvr, Work_mem, lwork, Info);

  //result
  MemToVector(Wr_mem, Wr);
  MemToVector(Wi_mem, Wi);
  SetLength(E, n);
  for i:=0 to n-1 do E[i] := COMPL(Wr[i], Wi[i]);

  //cleanup
  FreeMem(A_mem);
  FreeMem(Work_mem);
end;


procedure LeastSquares(A:TMatrix; b: TVector; var x: TVector);
var
  m, n, nrhs, lda, ldb, lwork, info: integer;
  Rcond: Single;
  Rank: integer;
  S, Work, IWork: TVector;
  A_mem, B_mem, S_mem, Work_mem, IWork_mem: PSingleArr;
begin
  m := Length(A);
  n := Length(A[0]);
  nrhs := 1;
  MatrixToMem(A, A_mem);
  lda := m;
  VectorToMem(b, B_mem);
  ldb := m;
  SetLength(S, n);
  VectorToMem(S, S_mem);
  Rcond := 1e-4;

  //optimal lwork and liwork
  SetLength(Work, 1);
  VectorToMem(Work, Work_mem);
  SetLength(IWork, 1);
  VectorToMem(IWork, IWork_mem);
  lwork := -1;
  sgelsd_(m, n, nrhs, A_mem, lda, B_mem, ldb, S_mem, Rcond, Rank, Work_mem,
         lwork, PIntegerArray(IWork_mem), info);
  MemToVector(Work_mem, Work);
  MemToVector(IWork_mem, IWork);

  //call lapack
  lwork := Round(Work[0]);
  SetLength(Work, lwork);
  SetLength(IWork, PInteger(@IWork[0])^);
  VectorToMem(Work, Work_mem);
  VectorToMem(IWork, IWork_mem);
  sgelsd_(m, n, nrhs, A_mem, lda, B_mem, ldb, S_mem, Rcond, Rank, Work_mem,
         lwork, PIntegerArray(IWork_mem), info);

  //get result
  SetLength(X, Length(B));
  MemToVector(B_mem, X);
  SetLength(X, n);

  //cleanup
  MemToVector(S_mem, S);
  FreeMem(Work_mem);
  FreeMem(IWork_mem);
  FreeMem(A_mem);
end;


procedure LeastSquaresWithInequalityConstraints(A, G: TMatrix; b: TVector; var x: TVector);
var
  W_mem, X_mem, Ws_mem, Ip_mem: PSingleArr;
  mdw, me, ma, mg, n, mode: integer;
  PrgOpt, rnorme, rnorml: Single;
  W: TMatrix;
  Ws: TVector;
  Ip : TIntegerArray;
  i, j: integer;
begin
  me := 0;
  ma := Length(A);
  mg := Length(G);
  n := Length(A[0]);
  mdw := me + ma + mg;
  PrgOpt := 1; //no custom options

  W := nil; SetLength(W, mdw, n+1);
  for i:=0 to ma-1 do
    begin
    for j:=0 to n-1 do  W[i,j] := A[i,j];
    W[i, n] := b[i];
    end;
  for i:=0 to mg-1 do
    for j:=0 to n-1 do  W[ma+i,j] := G[i,j];
  MatrixToMem(W, W_mem);

  SetLength(x, n);
  VectorToMem(x, X_mem);

  SetLength(Ws,   2*(me + n) + Max(ma + mg, n) + (mg + 2) * (n+7));
  VectorToMem(Ws, Ws_mem);

  SetLength(Ip,   mg + 2 * n + 2);
  Ip[0] := Length(Ws);
  Ip[1] := Length(Ip);
  VectorToMem(TVector(Ip), Ip_mem);

  lsei_(W_mem, mdw, me, ma, mg, n, PSingleArr(@PrgOpt), X_mem, rnorme, rnorml,
    mode, Ws_mem, PIntegerArray(Ip_mem));

  MemToVector(X_mem, x);

  setlength(ws, length(g));
  for i:=0 to high(g) do
    begin
    ws[i] := 0;
    for j:=0 to high(x) do ws[i] := ws[i] + g[i,j]*x[j];
    end;


  FreeMem(W_mem);
  FreeMem(Ws_mem);
  FreeMem(Ip_mem);
end;





//------------------------------------------------------------------------------
//                                tests
//------------------------------------------------------------------------------
procedure test_qr_mul;
var
  a,q,r: TMatrix;
begin
  setlength(a, 3, 2);
  a[0,0] := 1;
  a[0,1] := 2;
  a[1,0] := 3;
  a[1,1] := 4;
  a[2,0] := 5;
  a[2,1] := 6;

  QrDecomposition(a,q,r);

  MultiplyMatrices(q, r, a);
  //expected: 1 2 3 4 5 6
end;


procedure test_backsubst;
var
  a: TMatrix;
  b, x: TVector;
begin
  a := nil; setlength(a, 3, 3);
  a[0,0] := 1;
  a[0,1] := 2;
  a[0,2] := 3;
  a[1,1] := 4;
  a[1,2] := 5;
  a[2,2] := 6;

  b := nil; setlength(b, 3);
  b[0] := 10;
  b[1] := 20;
  b[2] := 30;

  BackSubstitute(a, b, x);
  //expected: -2.5  -1.25  5
end;

procedure test_eigen;
var
  a: TMatrix;
  e: TComplexArray;
begin
  a := nil; setlength(a, 3, 3);
  a[0,0] := 1;
  a[0,1] := 2;
  a[0,2] := 3;
  a[1,0] := 4;
  a[1,1] := 5;
  a[1,2] := 6;
  a[2,0] := 7;
  a[2,1] := 8;
  a[2,2] := 9;

  EigenValues(a, e);
  //expected: 16.117, -1.117, 0
end;

procedure test_leastsq;
var
  a: TMatrix;
  b, x: TVector;
begin
  a := nil; setlength(a, 3, 2);
  a[0,0] := 1;
  a[0,1] := 2;
  a[1,0] := 3;
  a[1,1] := 4;
  a[2,0] := 5;
  a[2,1] := 6;

  b := nil; setlength(b, 3);
  b[0] := 10;
  b[1] := 20;
  b[2] := 30;

  LeastSquares(a, b, x);
  //expected: 0  5
end;

procedure test_constrained_ls;
var
  a, g: TMatrix;
  b, x: TVector;
begin
  a := nil; setlength(a, 3, 2);
  a[0,0] := 1;
  a[0,1] := 2;
  a[1,0] := 3;
  a[1,1] := 4;
  a[2,0] := 5;
  a[2,1] := 6;

  g := nil; setlength(g, 1, 2);
  g[0,0] := 1;
  g[0,1] := 1;

  b := nil; setlength(b, 3);
  b[0] := 10;
  b[1] := 20;
  b[2] := 30;

  LeastSquaresWithInequalityConstraints(a, g, b, x);
  //expected: 0  5
end;


initialization

  //test_constrained_ls;


end.

