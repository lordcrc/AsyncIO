//   Copyright 2014 Asbjørn Heid
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

unit AsyncIO;

interface

uses
  WinAPI.Windows,
  System.SysUtils,
  AsyncIO.ErrorCodes;

type
  CompletionHandler = reference to procedure;
  OpHandler = reference to procedure(const ErrorCode: IOErrorCode);
  IOHandler = reference to procedure(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);

type
  EIOServiceStopped = class(Exception);

  IOService = interface
    {$REGION 'Property accessors'}
    function GetStopped: boolean;
    {$ENDREGION}

    function Poll: Int64;
    function PollOne: Int64;

    function Run: Int64;
    function RunOne: Int64;

    procedure Post(const Handler: CompletionHandler);

    procedure Stop;

    property Stopped: boolean read GetStopped;
  end;

function NewIOService(const MaxConcurrentThreads: Cardinal = 0): IOService;

type
  MemoryBuffer = record
  strict private
    FData: pointer;
    FSize: cardinal;
  private
    procedure SetSize(const MaxSize: cardinal);
  public
    class operator Implicit(const a: TBytes): MemoryBuffer;

    property Data: pointer read FData;
    property Size: cardinal read FSize;
  end;

  AsyncStream = interface
    {$REGION 'Property accessors'}
    function GetService: IOService;
    {$ENDREGION}

    procedure AsyncReadSome(const Buffer: MemoryBuffer; const Handler: IOHandler);
    procedure AsyncWriteSome(const Buffer: MemoryBuffer; const Handler: IOHandler);

    property Service: IOService read GetService;
  end;

  AsyncHandleStream = interface(AsyncStream)
    {$REGION 'Property accessors'}
    function GetHandle: THandle;
    {$ENDREGION}

    property Handle: THandle read GetHandle;
  end;

  AsyncFileStream = interface(AsyncHandleStream)
    {$REGION 'Property accessors'}
    function GetFilename: string;
    {$ENDREGION}

    property Filename: string read GetFilename;
  end;

  // returns 0 if io operation is complete, otherwise the maximum number of bytes for the subsequent request
  IOCompletionCondition = reference to function(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64): UInt64;

function MakeBuffer(const Buffer: MemoryBuffer; const MaxSize: cardinal): MemoryBuffer;

var
  MaxTransferSize: UInt64 = 65536; // default

function TransferAll: IOCompletionCondition;
function TransferAtLeast(const Minimum: UInt64): IOCompletionCondition;
function TransferExactly(const Size: UInt64): IOCompletionCondition;

procedure AsyncRead(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler);
procedure AsyncWrite(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler);

implementation

uses
  System.Math, AsyncIO.Detail;

{$POINTERMATH ON}

function NewIOService(const MaxConcurrentThreads: Cardinal = 0): IOService;
begin
  result := IOServiceImpl.Create(MaxConcurrentThreads);
end;

function MakeBuffer(const Buffer: MemoryBuffer; const MaxSize: cardinal): MemoryBuffer;
begin
  result := Buffer;
  result.SetSize(MaxSize);
end;

function TransferAll: IOCompletionCondition;
begin
  result :=
    function(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64): UInt64
    begin
      result := IfThen(ErrorCode, MaxTransferSize, 0);
    end;
end;

function TransferAtLeast(const Minimum: UInt64): IOCompletionCondition;
begin
  result :=
    function(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64): UInt64
    begin
      result := IfThen(ErrorCode and (BytesTransferred < Minimum), MaxTransferSize, 0);
    end;
end;

function TransferExactly(const Size: UInt64): IOCompletionCondition;
begin
  result :=
    function(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64): UInt64
    begin
      result := IfThen(ErrorCode and (BytesTransferred < Size), Min(Size - BytesTransferred, MaxTransferSize), 0);
    end;
end;


type
  AsyncReadOp = class(TInterfacedObject, IOHandler)
  strict private
    FTotalBytesTransferred: UInt64;
    FStream: AsyncStream;
    FBuffer: MemoryBuffer;
    FCompletionCondition: IOCompletionCondition;
    FHandler: IOHandler;

    procedure Invoke(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler);
  end;

{ AsyncReadOp }

constructor AsyncReadOp.Create(const Stream: AsyncStream;
  const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition;
  const Handler: IOHandler);
begin
  inherited Create;

  FTotalBytesTransferred := 0;
  FStream := Stream;
  FBuffer := Buffer;
  FCompletionCondition := CompletionCondition;
  FHandler := Handler;
end;

procedure AsyncReadOp.Invoke(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
var
  n: UInt64;
  readMore: boolean;
begin
  FTotalBytesTransferred := FTotalBytesTransferred + BytesTransferred;

  readMore := True;

  if ((not ErrorCode) and (BytesTransferred = 0)) then
    readMore := False;

  n := FCompletionCondition(ErrorCode, FTotalBytesTransferred);
  if (n = 0) or (FTotalBytesTransferred = FBuffer.Size) then
    readMore := False;

  if (readMore) then
  begin
    FStream.AsyncReadSome(MakeBuffer(FBuffer, n), Self);
  end
  else
  begin
    FHandler(ErrorCode, FTotalBytesTransferred);
  end;
end;

procedure AsyncRead(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler);
var
  n: UInt64;
  readOp: IOHandler;
begin
  n := CompletionCondition(IOErrorCode.Success, 0);

  if (n = 0) then
  begin
    Stream.Service.Post(
      procedure
      begin
        Handler(IOErrorCode.Success, 0);
      end
    );
    exit;
  end;

  readOp := AsyncReadOp.Create(Stream, Buffer, CompletionCondition, Handler);
  Stream.AsyncReadSome(MakeBuffer(Buffer, n), readOp);
end;

type
  AsyncWriteOp = class(TInterfacedObject, IOHandler)
  strict private
    FTotalBytesTransferred: UInt64;
    FStream: AsyncStream;
    FBuffer: MemoryBuffer;
    FCompletionCondition: IOCompletionCondition;
    FHandler: IOHandler;

    procedure Invoke(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler);
  end;

{ AsyncWriteOp }

constructor AsyncWriteOp.Create(const Stream: AsyncStream;
  const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition;
  const Handler: IOHandler);
begin
  inherited Create;

  FTotalBytesTransferred := 0;
  FStream := Stream;
  FBuffer := Buffer;
  FCompletionCondition := CompletionCondition;
  FHandler := Handler;
end;

procedure AsyncWriteOp.Invoke(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
var
  n: UInt64;
  readMore: boolean;
begin
  FTotalBytesTransferred := FTotalBytesTransferred + BytesTransferred;

  readMore := True;

  if ((not ErrorCode) and (BytesTransferred = 0)) then
    readMore := False;

  n := FCompletionCondition(ErrorCode, FTotalBytesTransferred);
  if (n = 0) or (FTotalBytesTransferred = FBuffer.Size) then
    readMore := False;

  if (readMore) then
  begin
    FStream.AsyncWriteSome(MakeBuffer(FBuffer, n), Self);
  end
  else
  begin
    FHandler(ErrorCode, FTotalBytesTransferred);
  end;
end;

procedure AsyncWrite(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler);
var
  n: UInt64;
  writeOp: IOHandler;
begin
  n := CompletionCondition(IOErrorCode.Success, 0);

  if (n = 0) then
  begin
    Stream.Service.Post(
      procedure
      begin
        Handler(IOErrorCode.Success, 0);
      end
    );
    exit;
  end;

  writeOp := AsyncWriteOp.Create(Stream, Buffer, CompletionCondition, Handler);
  Stream.AsyncWriteSome(MakeBuffer(Buffer, n), writeOp);
end;

{ MemoryBuffer }

class operator MemoryBuffer.Implicit(const a: TBytes): MemoryBuffer;
begin
  result.FData := @a[0];
  result.FSize := Length(a);
end;

procedure MemoryBuffer.SetSize(const MaxSize: cardinal);
begin
  FSize := Min(FSize, MaxSize);
end;

end.
