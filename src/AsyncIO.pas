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
  System.Classes,
  AsyncIO.ErrorCodes,
  RegularExpr;

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
    class function Create(const Data: pointer; const Size: cardinal): MemoryBuffer; inline; static;
  public
    class operator Implicit(const a: TBytes): MemoryBuffer;

    property Data: pointer read FData;
    property Size: cardinal read FSize;
  end;

  StreamBuffer = record
  {$REGION 'Implementation details'}
  public
    type
      IStreamBuffer = interface
        {$REGION 'Property accessors'}
        function GetData: pointer;
        function GetBufferSize: UInt64;
        function GetMaxBufferSize: UInt64;
        function GetStream: TStream;
        {$ENDREGION}

        function PrepareCommit(const Size: UInt32): MemoryBuffer;
        procedure Commit(const Size: UInt32);

        function PrepareConsume(const Size: UInt32): MemoryBuffer;
        procedure Consume(const Size: UInt32);

        property Data: pointer read GetData;
        property BufferSize: UInt64 read GetBufferSize;
        property MaxBufferSize: UInt64 read GetMaxBufferSize;
        property Stream: TStream read GetStream; // for TStream access to buffered data
      end;
  {$ENDREGION}
  strict private
    FImpl: IStreamBuffer;

    function GetData: pointer;
    function GetBufferSize: UInt64;
    function GetMaxBufferSize: UInt64;
    function GetStream: TStream;
  private
    property Impl: IStreamBuffer read FImpl;
  public
    type
      StreamBufferParam = (StreamBufferOwnsStream);
      StreamBufferParams = set of StreamBufferParam;
  public
    class operator Implicit(const Impl: IStreamBuffer): StreamBuffer;

    class function Create(const MaxBufferSize: UInt64 = MaxInt): StreamBuffer; static;

    // writing to buffer
    function PrepareCommit(const Size: UInt32): MemoryBuffer;
    procedure Commit(const Size: UInt32);

    // reading from buffer
    function PrepareConsume(const Size: UInt32): MemoryBuffer;
    procedure Consume(const Size: UInt32);

    property Data: pointer read GetData;
    property BufferSize: UInt64 read GetBufferSize;
    property MaxBufferSize: UInt64 read GetMaxBufferSize;
    property Stream: TStream read GetStream; // for TStream access to buffered data
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

function MakeBuffer(const Buffer: MemoryBuffer; const MaxSize: cardinal): MemoryBuffer; overload;
function MakeBuffer(const Data: pointer; const Size: cardinal): MemoryBuffer; overload;

var
  MaxTransferSize: UInt64 = 65536; // default

function TransferAll: IOCompletionCondition;
function TransferAtLeast(const Minimum: UInt64): IOCompletionCondition;
function TransferExactly(const Size: UInt64): IOCompletionCondition;

procedure AsyncRead(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler); overload;
procedure AsyncRead(const Stream: AsyncStream; const Buffer: StreamBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler); overload;
procedure AsyncReadUntil(const Stream: AsyncStream; const Buffer: StreamBuffer; const Delim: array of Byte; const Handler: IOHandler); overload;
procedure AsyncReadUntil(const Stream: AsyncStream; const Buffer: StreamBuffer; const Delim: TArray<Byte>; const Handler: IOHandler); overload;

procedure AsyncWrite(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler); overload;

implementation

uses
  System.Math, AsyncIO.Detail, AsyncIO.Detail.StreamBufferImpl;

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

function MakeBuffer(const Data: pointer; const Size: cardinal): MemoryBuffer; overload;
begin
  result := MemoryBuffer.Create(Data, Size);
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

  if ((not ErrorCode) or (BytesTransferred = 0)) then
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
  AsyncReadStreamAdapterOp = class(TInterfacedObject, IOHandler)
  strict private
    FTotalBytesTransferred: UInt64;
    FStream: AsyncStream;
    FBuffer: StreamBuffer;
    FCompletionCondition: IOCompletionCondition;
    FHandler: IOHandler;

    procedure Invoke(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Stream: AsyncStream; const Buffer: StreamBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler);
  end;

{ AsyncReadStreamAdapterOp }

constructor AsyncReadStreamAdapterOp.Create(const Stream: AsyncStream;
  const Buffer: StreamBuffer; const CompletionCondition: IOCompletionCondition;
  const Handler: IOHandler);
begin
  inherited Create;

  FTotalBytesTransferred := 0;
  FStream := Stream;
  FBuffer := Buffer;
  FCompletionCondition := CompletionCondition;
  FHandler := Handler;
end;

procedure AsyncReadStreamAdapterOp.Invoke(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
var
  n: UInt64;
  readMore: boolean;
  buf: MemoryBuffer;
begin
  FTotalBytesTransferred := FTotalBytesTransferred + BytesTransferred;

  FBuffer.Commit(BytesTransferred);

  readMore := True;

  if ((not ErrorCode) or (BytesTransferred = 0)) then
    readMore := False;

  n := FCompletionCondition(ErrorCode, FTotalBytesTransferred);
  if (n = 0) then
    readMore := False;

  if (readMore) then
  begin
    buf := FBuffer.PrepareCommit(n);
    FStream.AsyncReadSome(buf, Self);
  end
  else
  begin
    FHandler(ErrorCode, FTotalBytesTransferred);
  end;
end;

procedure AsyncRead(const Stream: AsyncStream; const Buffer: StreamBuffer; const CompletionCondition: IOCompletionCondition; const Handler: IOHandler);
var
  n: UInt64;
  readOp: IOHandler;
  buf: MemoryBuffer;
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

  readOp := AsyncReadStreamAdapterOp.Create(Stream, Buffer, CompletionCondition, Handler);
  buf := Buffer.PrepareCommit(n);
  Stream.AsyncReadSome(buf, readOp);
end;


type
  AsyncReadUntilDelimOp = class(TInterfacedObject, IOHandler)
  strict private
    FTotalBytesTransferred: UInt64;
    FStream: AsyncStream;
    FBuffer: StreamBuffer;
    FSearchPosition: UInt64;
    FDelim: TBytes;
    FHandler: IOHandler;

    procedure Invoke(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Stream: AsyncStream; const Buffer: StreamBuffer; const Delim: TArray<Byte>; const Handler: IOHandler);
  end;

function ReadSizeHelper(const Buffer: StreamBuffer; const MaxSize: UInt64): cardinal;
begin
  result := Min(512,
    Max(MaxSize, Buffer.BufferSize));
end;

// returns true if a complete match has been found, start of match in MatchPosition
// returns false with MatchPosition >= 0 indicating the start of the partial match
// returns false with MatchPosition < 0 if no match was found
function PartialSearch(const Data: pointer; const DataLength: NativeInt; const Delim: TArray<Byte>; out MatchPosition: NativeInt): boolean;
var
  d, dataEnd: PByte;
  delimLength: NativeInt;
  i: integer;
begin
  result := False;
  MatchPosition := 0;
  d := PByte(Data);
  dataEnd := d + DataLength;
  delimLength := Length(Delim);

  while (d < dataEnd) do
  begin
    result := False;

    for i := 0 to delimLength-1 do
    begin
      if ((d + i) >= dataEnd) then
        break;

      result := (d[i] = Delim[i]);

      if (not result) then
        break;
    end;

    if (result) then
    begin
      result := ((d + i) >= dataEnd);
      MatchPosition := d - PByte(Data);
      exit;
    end;

    d := d + 1;
  end;

  // no match
  MatchPosition := -1;
end;

{ AsyncReadUntilDelimOp }

constructor AsyncReadUntilDelimOp.Create(const Stream: AsyncStream;
  const Buffer: StreamBuffer; const Delim: TArray<Byte>;
  const Handler: IOHandler);
begin
  inherited Create;

  FTotalBytesTransferred := 0;
  FStream := Stream;
  FBuffer := Buffer;
  FSearchPosition := 0;
  FDelim := Delim;
  FHandler := Handler;
end;

procedure AsyncReadUntilDelimOp.Invoke(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
var
  n: UInt64;
  readMore: boolean;
  buf: MemoryBuffer;
  matchPos: NativeInt;
  match: boolean;
begin
  FTotalBytesTransferred := FTotalBytesTransferred + BytesTransferred;

  FBuffer.Commit(BytesTransferred);

  readMore := True;

  if ((not ErrorCode) or (BytesTransferred = 0)) then
    readMore := False;

  match := PartialSearch(PByte(FBuffer) + FSearchPosition, FSearchPosition - FBuffer.BufferSize, FDelim, matchPos);

  if (match) then
  begin
    // match, we're done
    FSearchPosition := FSearchPosition + matchPos;
    n := 0;
  end
  else if (FBuffer.BufferSize >= FBuffer.MaxBufferSize) then
  begin
    // no more room
    n := 0;
  end
  else
  begin
    if (matchPos >= 0) then
    begin
      // partial match, need more data
      // next search starts at start of match
      FSearchPosition := FSearchPosition + matchPos;
    end
    else
    begin
      // no match
      // next search starts at new data
      FSearchPosition := FSearchPosition + BytesTransferred;
    end;
    n := ReadSizeHelper(FBuffer, MaxTransferSize);
  end;

  if (n = 0) then
    readMore := False;

  if (readMore) then
  begin
    buf := FBuffer.PrepareCommit(n);
    FStream.AsyncReadSome(buf, Self);
  end
  else
  begin
    // write what we have to the destination stream
    n := IfThen(ErrorCode and match, FSearchPosition, 0);
    FHandler(ErrorCode, n);
  end;
end;

procedure AsyncReadUntil(const Stream: AsyncStream; const Buffer: StreamBuffer; const Delim: array of Byte; const Handler: IOHandler);
var
  d: TArray<Byte>;
  i: integer;
begin
  SetLength(d, Length(Delim));
  for i := 0 to High(Delim) do
    d[i] := Delim[i];

  AsyncReadUntil(Stream, Buffer, d, Handler);
end;

procedure AsyncReadUntil(const Stream: AsyncStream; const Buffer: StreamBuffer; const Delim: TArray<Byte>; const Handler: IOHandler);
var
  n: UInt64;
  readOp: IOHandler;
  buf: MemoryBuffer;
begin
  n := ReadSizeHelper(Buffer, MaxTransferSize);
  buf := Buffer.PrepareCommit(n);
  readOp := AsyncReadUntilDelimOp.Create(Stream, Buffer, Delim, Handler);
  Stream.AsyncReadSome(buf, readOp);
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

class function MemoryBuffer.Create(const Data: pointer;
  const Size: cardinal): MemoryBuffer;
begin
  result.FData := Data;
  result.FSize := Size;
end;

class operator MemoryBuffer.Implicit(const a: TBytes): MemoryBuffer;
begin
  result.FData := @a[0];
  result.FSize := Length(a);
end;

procedure MemoryBuffer.SetSize(const MaxSize: cardinal);
begin
  FSize := Min(FSize, MaxSize);
end;

{ StreamBuffer }

procedure StreamBuffer.Commit(const Size: UInt32);
begin
  Impl.Commit(Size);
end;

procedure StreamBuffer.Consume(const Size: UInt32);
begin
  Impl.Consume(Size);
end;

class function StreamBuffer.Create(const MaxBufferSize: UInt64): StreamBuffer;
begin
  result := StreamBufferImpl.Create(MaxBufferSize);
end;

function StreamBuffer.GetBufferSize: UInt64;
begin
  result := Impl.BufferSize;
end;

function StreamBuffer.GetData: pointer;
begin
  result := Impl.Data;
end;

function StreamBuffer.GetMaxBufferSize: UInt64;
begin
  result := Impl.MaxBufferSize;
end;

function StreamBuffer.GetStream: TStream;
begin
  result := Impl.Stream;
end;

class operator StreamBuffer.Implicit(const Impl: StreamBuffer.IStreamBuffer): StreamBuffer;
begin
  result.FImpl := Impl;
end;

function StreamBuffer.PrepareCommit(const Size: UInt32): MemoryBuffer;
begin
  result := Impl.PrepareCommit(Size);
end;

function StreamBuffer.PrepareConsume(const Size: UInt32): MemoryBuffer;
begin
  result := Impl.PrepareConsume(Size);
end;

end.

