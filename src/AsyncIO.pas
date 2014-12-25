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
  WaitHandler = reference to procedure(const ErrorCode: IOErrorCode);
  IOHandler = reference to procedure(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);

type
  EIOServiceStopped = class(Exception);

  IOService = class
  strict private
    FIOCP: THandle;
    FStopped: integer;

    function GetStopped: boolean;
    function DoPollOne(const Timeout: DWORD): integer;
    procedure DoDequeueStoppedHandlers;
  protected
    property IOCP: THandle read FIOCP;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize(const MaxConcurrentThreads: Cardinal = 0);

    function Poll: Int64;
    function PollOne: Int64;

    function Run: Int64;
    function RunOne: Int64;

    procedure Post(const Handler: CompletionHandler);

    procedure Stop;

    property Stopped: boolean read GetStopped;
  end;

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

  AsyncStream = class
  private
    FIOService: IOService;
  protected
    property Service: IOService read FIOService;
  public
    constructor Create(const Service: IOService);

    procedure AsyncReadSome(const Buffer: MemoryBuffer; const Handler: IOHandler); virtual; abstract;
    procedure AsyncWriteSome(const Buffer: MemoryBuffer; const Handler: IOHandler); virtual; abstract;
  end;

  AsyncHandleStream = class(AsyncStream)
  private
    FHandle: THandle;
    FOffset: UInt64;
  public
    constructor Create(const Service: IOService; const Handle: THandle);
    destructor Destroy; override;

    procedure AsyncReadSome(const Buffer: MemoryBuffer; const Handler: IOHandler); override;
    procedure AsyncWriteSome(const Buffer: MemoryBuffer; const Handler: IOHandler); override;

    property Handle: THandle read FHandle;
  end;

  FileAccess = (faRead, faWrite, faReadWrite);

  FileCreationDisposition = (fcCreateNew, fcCreateAlways, fcOpenExisting, fcOpenAlways, fcTruncateExisting);

  FileShareMode = (fsNone, fsDelete, fsRead, fsWrite, fsReadWrite);

  AsyncFileStream = class(AsyncHandleStream)
  public
    constructor Create(const Service: IOService; const Filename: string;
      const CreationDisposition: FileCreationDisposition; const Access: FileAccess; const ShareMode: FileShareMode);
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

const
  COMPLETION_KEY_EXIT = 0;
  COMPLETION_KEY_OPERATION = 1;
  COMPLETION_KEY_OPERATION_DIR = 2;

{ IOService }

constructor IOService.Create;
begin
  inherited Create;

  FIOCP := INVALID_HANDLE_VALUE;
end;

destructor IOService.Destroy;
begin
  if (IOCP <> INVALID_HANDLE_VALUE) then
    CloseHandle(IOCP);

  inherited;
end;

procedure IOService.DoDequeueStoppedHandlers;
var
  r: integer;
begin
  if not Stopped then
    exit;

  // dequeue all pending handlers
  while True do
  begin
    r := DoPollOne(0);
    if (r = 0) then
      break;
  end;
end;

function IOService.DoPollOne(const Timeout: DWORD): integer;
var
  res: boolean;
  overlapped: POverlapped;
  completionKey: ULONG_PTR;
  transferred: DWORD;
  ec: IOErrorCode;
  ctx: IOCPContext;
begin
  result := 0;

  ctx := nil;
  overlapped := nil;
  res := GetQueuedCompletionStatus(IOCP, transferred, completionKey, overlapped, Timeout);

//  WriteLn('DEBUG completion key: ', completionKey);
//  WriteLn(Format('DEBUG completion overlapped: %.8x', [NativeUInt(overlapped)]));

  if res then
  begin
    ec := IOErrorCode.Success;
  end
  else
  begin
    ec := IOErrorCode.Create();
    if Assigned(overlapped) then
    begin
      // failed IO operation, trigger handler
    end
    else if ec.Value = WAIT_TIMEOUT then
    begin
      // nothing to do
      exit;
    end
    else
      RaiseLastOSError;
  end;

  if completionKey = COMPLETION_KEY_EXIT then
    exit;

  Assert((completionKey = COMPLETION_KEY_OPERATION) or (completionKey = COMPLETION_KEY_OPERATION_DIR), 'Invalid completion key');

  ctx := IOCPContext.FromOverlapped(overlapped);
//  WriteLn(Format('DEBUG exec context: %.8x', [NativeUInt(ctx)]));

  try
    result := 1;
    if not Stopped then
      ctx.ExecHandler(ec, transferred);
  finally
    ctx.Free;
  end;
end;

function IOService.GetStopped: boolean;
begin
  result := FStopped <> 0;
end;

procedure IOService.Initialize(const MaxConcurrentThreads: Cardinal = 0);
begin
  Assert(IOCP = INVALID_HANDLE_VALUE, 'IOService already Initialized');

  FIOCP := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, MaxConcurrentThreads);
  if (FIOCP = 0) then
  begin
    FIOCP := INVALID_HANDLE_VALUE;
    RaiseLastOSError;
  end;
end;

function IOService.Poll: Int64;
var
  r: Int64;
begin
  result := 0;
  while True do
  begin
    r := PollOne();
    if r = 0 then
      break;
    result := result + 1;
  end;
end;

function IOService.PollOne: Int64;
begin
  result := 0;
  if Stopped then
  begin
    DoDequeueStoppedHandlers;
    exit;
  end;

  result := DoPollOne(0);
end;

procedure IOService.Post(const Handler: CompletionHandler);
var
  ctx: HandlerContext;
begin
  if Stopped then
    raise EIOServiceStopped.Create('Cannot post to a stopped IOService');

  ctx := HandlerContext.Create(Handler);
  PostQueuedCompletionStatus(IOCP, 0, COMPLETION_KEY_OPERATION, ctx.Overlapped);
end;

function IOService.Run: Int64;
var
  r: Int64;
begin
  result := 0;
  while True do
  begin
    r := RunOne();
    if (r = 0) and (Stopped) then
      break;
    result := result + 1;
  end;
end;

function IOService.RunOne: Int64;
begin
  result := 0;
  if Stopped then
  begin
    DoDequeueStoppedHandlers;
    exit;
  end;

  // From Boost.ASIO:
  // Timeout to use with GetQueuedCompletionStatus. Some versions of windows
  // have a "bug" where a call to GetQueuedCompletionStatus can appear stuck
  // even though there are events waiting on the queue. Using a timeout helps
  // to work around the issue.
  result := DoPollOne(500);
end;

procedure IOService.Stop;
begin
  InterlockedExchange(FStopped, 1);
  CancelIo(IOCP);
  PostQueuedCompletionStatus(IOCP, 0, COMPLETION_KEY_EXIT, nil);
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

{ AsyncStream }

constructor AsyncStream.Create(const Service: IOService);
begin
  inherited Create;

  FIOService := Service;
end;

{ AsyncHandleStream }

procedure AsyncHandleStream.AsyncReadSome(const Buffer: MemoryBuffer; const Handler: IOHandler);
var
  bytesRead: DWORD;
  ctx: IOHandlerContext;
  res: boolean;
  ec: DWORD;
begin
  ctx := IOHandlerContext.Create(
    procedure(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64)
    begin
      FOffset := FOffset + BytesTransferred;
      Handler(ErrorCode, BytesTransferred);
    end
  );
  // offset is ignored if handle does not support it
  ctx.OverlappedOffset := FOffset;
  bytesRead := 0;
  res := ReadFile(Handle, Buffer.Data^, Buffer.Size, bytesRead, ctx.Overlapped);
  if (not res) then
  begin
    ec := GetLastError;
    if (ec <> ERROR_IO_PENDING) then
      RaiseLastOSError(ec);
  end
  else
  begin
    // completed directly, but completion entry is queued by manager
    // no async action, call handler directly
//    IOServicePostCompletion(Service, bytesRead, ctx);
  end;
end;

procedure AsyncHandleStream.AsyncWriteSome(const Buffer: MemoryBuffer; const Handler: IOHandler);
var
  bytesWritten: DWORD;
  ctx: IOHandlerContext;
  res: boolean;
  ec: DWORD;
begin
  ctx := IOHandlerContext.Create(
    procedure(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64)
    begin
      FOffset := FOffset + BytesTransferred;
      Handler(ErrorCode, BytesTransferred);
    end
  );
  // offset is ignored if handle does not support it
  ctx.OverlappedOffset := FOffset;
  res := WriteFile(Handle, Buffer.Data^, Buffer.Size, bytesWritten, ctx.Overlapped);
  if (not res) then
  begin
    ec := GetLastError;
    if (ec <> ERROR_IO_PENDING) then
      RaiseLastOSError(ec);
  end
  else
  begin
    // completed directly, but completion entry is queued by manager
    // no async action, call handler directly
//    IOServicePostCompletion(Service, bytesWritten, ctx);
  end;
end;

constructor AsyncHandleStream.Create(const Service: IOService; const Handle: THandle);
begin
  inherited Create(Service);

  FHandle := Handle;
end;

destructor AsyncHandleStream.Destroy;
begin
  CloseHandle(FHandle);

  inherited;
end;

{ AsyncFileStream }

constructor AsyncFileStream.Create(const Service: IOService; const Filename: string;
  const CreationDisposition: FileCreationDisposition; const Access: FileAccess; const ShareMode: FileShareMode);
const
  AccessMapping: array[FileAccess] of DWORD = (GENERIC_READ, GENERIC_WRITE, GENERIC_READ or GENERIC_WRITE);
  CreationDispositionMapping: array[FileCreationDisposition] of DWORD = (CREATE_NEW, CREATE_ALWAYS, OPEN_EXISTING, OPEN_ALWAYS, TRUNCATE_EXISTING);
  ShareModeMapping: array[FileShareMode] of DWORD = (0, FILE_SHARE_DELETE, FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE);
var
  fh, cph: THandle;
  ac, sm, cd, flags: DWORD;
begin
  ac := AccessMapping[Access];
  sm := ShareModeMapping[ShareMode];
  cd := CreationDispositionMapping[CreationDisposition];

  flags := FILE_ATTRIBUTE_NORMAL or FILE_FLAG_OVERLAPPED;

  fh := CreateFile(PChar(Filename), ac, sm, nil, cd, flags, 0);

  if (fh = INVALID_HANDLE_VALUE) then
    RaiseLastOSError();

  // call create here
  // so that the handle is closed if the
  // CreateIoCompletionPort call below fails
  inherited Create(Service, fh);

  cph := CreateIoCompletionPort(fh, Service.IOCP, COMPLETION_KEY_OPERATION, 0);

  if (cph = 0) then
    RaiseLastOSError;
end;

end.
