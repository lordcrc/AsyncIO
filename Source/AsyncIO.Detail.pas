unit AsyncIO.Detail;

interface

uses
  WinAPI.Windows, System.SysUtils, System.Classes, AsyncIO, AsyncIO.OpResults;

type
  IOCPContext  = class
  strict private
    FOverlapped: TOverlapped;
    function GetOverlapped: POverlapped;
    function GetOverlappedOffset: UInt64;
    procedure SetOverlappedOffset(const Value: UInt64);
  public
    constructor Create;
    destructor Destroy; override;

    property Overlapped: POverlapped read GetOverlapped;
    property OverlappedOffset: UInt64 read GetOverlappedOffset write SetOverlappedOffset;

    procedure ExecHandler(const res: OpResult; const transferred: Int64); virtual;

    class function FromOverlapped(const Overlapped: POverlapped): IOCPContext;
  end;

  HandlerContext = class(IOCPContext)
  strict private
    FHandler: CompletionHandler;
  public
    constructor Create(const Handler: CompletionHandler);

    procedure ExecHandler(const res: OpResult; const transferred: Int64); override;

    property Handler: CompletionHandler read FHandler;
  end;

  OpHandlerContext = class(IOCPContext)
  strict private
    FHandler: OpHandler;
  public
    constructor Create(const Handler: OpHandler);

    procedure ExecHandler(const res: OpResult; const transferred: Int64); override;

    property Handler: OpHandler read FHandler;
  end;

  IOHandlerContext = class(IOCPContext)
  strict private
    FHandler: IOHandler;
  public
    constructor Create(const Handler: IOHandler);

    procedure ExecHandler(const res: OpResult; const transferred: Int64); override;

    property Handler: IOHandler read FHandler;
  end;

procedure IOServicePostCompletion(const Service: IOService;
  const BytesTransferred: DWORD;
  const Ctx: IOCPContext);

procedure IOServiceAssociateHandle(const Service: IOService;
  const Handle: THandle);

type
  IOServiceIOCP = interface
    ['{B26EA70A-4501-4232-B07F-1495FD945979}']
    procedure AssociateHandle(const Handle: THandle);
    procedure PostCompletion(const BytesTransferred: DWORD;
      const Ctx: IOCPContext);
  end;

  IOServiceImpl = class(TInterfacedObject, IOService, IOServiceIOCP)
  strict private
    FIOCP: THandle;
    FStopped: integer;

    function GetStopped: boolean;
    function DoPollOne(const Timeout: DWORD): integer;
    procedure DoDequeueStoppedHandlers;
  protected
    property IOCP: THandle read FIOCP;
  public
    constructor Create(const MaxConcurrentThreads: Cardinal);
    destructor Destroy; override;

    procedure AssociateHandle(const Handle: THandle);
    procedure PostCompletion(const BytesTransferred: DWORD;
      const Ctx: IOCPContext);

    function Poll: Int64;
    function PollOne: Int64;

    function Run: Int64;
    function RunOne: Int64;

    procedure Post(const Handler: CompletionHandler);

    procedure Stop;

    property Stopped: boolean read GetStopped;
  end;

  AsyncStreamImplBase = class(TInterfacedObject, AsyncStream)
  strict private
    FService: IOService;
  public
    constructor Create(const Service: IOService);

    function GetService: IOService;

    procedure AsyncReadSome(const Buffer: MemoryBuffer; const Handler: IOHandler); virtual; abstract;
    procedure AsyncWriteSome(const Buffer: MemoryBuffer; const Handler: IOHandler); virtual; abstract;

    property Service: IOService read FService;
  end;

  AsyncMemoryStreamImpl = class(AsyncStreamImplBase, AsyncMemoryStream)
  strict private
    FData: TBytes;
    FOffset: UInt64;
  public
    constructor Create(const Service: IOService; const Data: TBytes);
    destructor Destroy; override;

    function GetData: TBytes;

    procedure AsyncReadSome(const Buffer: MemoryBuffer; const Handler: IOHandler); override;
    procedure AsyncWriteSome(const Buffer: MemoryBuffer; const Handler: IOHandler); override;

    property Data: TBytes read FData;
  end;

  AsyncHandleStreamImpl = class(AsyncStreamImplBase, AsyncHandleStream)
  strict private
    FHandle: THandle;
    FOffset: UInt64;
  public
    constructor Create(const Service: IOService; const Handle: THandle);
    destructor Destroy; override;

    function GetHandle: THandle;

    procedure AsyncReadSome(const Buffer: MemoryBuffer; const Handler: IOHandler); override;
    procedure AsyncWriteSome(const Buffer: MemoryBuffer; const Handler: IOHandler); override;

    property Handle: THandle read FHandle;
  end;

implementation

uses
  System.Math;

{$POINTERMATH ON}

const
  COMPLETION_KEY_EXIT = 0;
  COMPLETION_KEY_OPERATION = 1;
  COMPLETION_KEY_OPERATION_DIR = 2;

procedure IOServicePostCompletion(const Service: IOService;
  const BytesTransferred: DWORD;
  const Ctx: IOCPContext);
var
  iocpService: IOServiceIOCP;
begin
  iocpService := Service as IOServiceIOCP;
  iocpService.PostCompletion(BytesTransferred, Ctx);
end;

procedure IOServiceAssociateHandle(const Service: IOService;
  const Handle: THandle);
var
  iocpService: IOServiceIOCP;
begin
  iocpService := Service as IOServiceIOCP;
  iocpService.AssociateHandle(Handle);
end;

{ IOCPContext }

constructor IOCPContext.Create;
begin
  inherited Create;

//  WriteLn(Format('DEBUG overlapped created: %.8x', [NativeUInt(Self.Overlapped)]));
end;

destructor IOCPContext.Destroy;
begin
//  WriteLn(Format('DEBUG overlapped destroyed: %.8x', [NativeUInt(Self.Overlapped)]));

  inherited;
end;

procedure IOCPContext.ExecHandler(const res: OpResult; const transferred: Int64);
begin
  raise ENotImplemented.Create('Invalid context handler');
end;

class function IOCPContext.FromOverlapped(const Overlapped: POverlapped): IOCPContext;
type
  PUInt8 = ^UInt8;
begin
  result := TObject(PUInt8(Overlapped) - SizeOf(pointer)) as IOCPContext;
end;

function IOCPContext.GetOverlapped: POverlapped;
begin
  result := @FOverlapped;
end;

function IOCPContext.GetOverlappedOffset: UInt64;
begin
  result := FOverlapped.Offset  + (UInt64(FOverlapped.OffsetHigh) shl 32);
end;

procedure IOCPContext.SetOverlappedOffset(const Value: UInt64);
begin
  FOverlapped.Offset := UInt32(Value and $ffffffff);
  FOverlapped.OffsetHigh := UInt32((Value shr 32) and $ffffffff);
end;

{ HandlerContext }

constructor HandlerContext.Create(const Handler: CompletionHandler);
begin
  inherited Create;

  FHandler := Handler;
end;

procedure HandlerContext.ExecHandler(const res: OpResult; const transferred: Int64);
begin
  Handler();
end;

{ OpHandlerContext }

constructor OpHandlerContext.Create(const Handler: OpHandler);
begin
  inherited Create;

  FHandler := Handler;
end;

procedure OpHandlerContext.ExecHandler(const res: OpResult; const transferred: Int64);
begin
  Handler(res);
end;

{ IOHandlerContext }

constructor IOHandlerContext.Create(const Handler: IOHandler);
begin
  inherited Create;

  FHandler := Handler;
end;

procedure IOHandlerContext.ExecHandler(const res: OpResult; const transferred: Int64);
begin
  Handler(res, transferred);
end;

{ IOServiceImpl }

procedure IOServiceImpl.AssociateHandle(const Handle: THandle);
var
  cph: THandle;
begin
  // Associate with IOCP
  cph := CreateIoCompletionPort(Handle, IOCP, COMPLETION_KEY_OPERATION, 0);

  if (cph = 0) then
    RaiseLastOSError;
end;

constructor IOServiceImpl.Create(const MaxConcurrentThreads: Cardinal);
begin
  inherited Create;

  FIOCP := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, MaxConcurrentThreads);
  if (FIOCP = 0) then
  begin
    FIOCP := INVALID_HANDLE_VALUE;
    RaiseLastOSError;
  end;
end;

destructor IOServiceImpl.Destroy;
begin
  if (not Stopped) then
  begin
    Stop;
    DoDequeueStoppedHandlers;
  end;

  if (IOCP <> INVALID_HANDLE_VALUE) then
    CloseHandle(IOCP);

  inherited;
end;

procedure IOServiceImpl.DoDequeueStoppedHandlers;
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

function IOServiceImpl.DoPollOne(const Timeout: DWORD): integer;
var
  success: boolean;
  overlapped: POverlapped;
  completionKey: ULONG_PTR;
  transferred: DWORD;
  res: OpResult;
  ctx: IOCPContext;
begin
  result := 0;

  ctx := nil;
  overlapped := nil;
  success := GetQueuedCompletionStatus(IOCP, transferred, completionKey, overlapped, Timeout);

//  WriteLn('DEBUG completion key: ', completionKey);
//  WriteLn(Format('DEBUG completion overlapped: %.8x', [NativeUInt(overlapped)]));

  if success then
  begin
    res := SystemResults.Success;
  end
  else
  begin
    res := SystemResults.LastError;
    if Assigned(overlapped) then
    begin
      // failed IO operation, trigger handler
    end
    else if (res = SystemResults.WaitTimeout) then
    begin
      // nothing to do
      exit;
    end
    else
      res.RaiseException();
  end;

  if completionKey = COMPLETION_KEY_EXIT then
    exit;

  Assert((completionKey = COMPLETION_KEY_OPERATION) or (completionKey = COMPLETION_KEY_OPERATION_DIR), 'Invalid completion key');

  ctx := IOCPContext.FromOverlapped(overlapped);
//  WriteLn(Format('DEBUG exec context: %.8x', [NativeUInt(ctx)]));

  try
    result := 1;
    if not Stopped then
      ctx.ExecHandler(res, transferred);
  finally
    ctx.Free;
  end;
end;

function IOServiceImpl.GetStopped: boolean;
begin
  result := FStopped <> 0;
end;

function IOServiceImpl.Poll: Int64;
var
  r: Int64;
begin
  result := 0;
  while True do
  begin
    r := PollOne();
    if (r = 0) then
      break;
    result := result + 1;
  end;
end;

function IOServiceImpl.PollOne: Int64;
begin
  result := 0;
  if Stopped then
  begin
    DoDequeueStoppedHandlers;
    exit;
  end;

  result := DoPollOne(0);
end;

procedure IOServiceImpl.Post(const Handler: CompletionHandler);
var
  ctx: HandlerContext;
begin
  if Stopped then
    raise EIOServiceStopped.Create('Cannot post to a stopped IOService');

  ctx := HandlerContext.Create(Handler);
  PostQueuedCompletionStatus(IOCP, 0, COMPLETION_KEY_OPERATION, ctx.Overlapped);
end;

procedure IOServiceImpl.PostCompletion(const BytesTransferred: DWORD;
  const Ctx: IOCPContext);
begin
  if Stopped then
    raise EIOServiceStopped.Create('Cannot post to a stopped IOService');

//  WriteLn(Format('DEBUG post overlapped: %.8x', [NativeUInt(ctx.Overlapped)]));
  PostQueuedCompletionStatus(IOCP, BytesTransferred, COMPLETION_KEY_OPERATION_DIR, Ctx.Overlapped);
end;

function IOServiceImpl.Run: Int64;
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

function IOServiceImpl.RunOne: Int64;
begin
  result := 0;
  if Stopped then
  begin
    DoDequeueStoppedHandlers;
    exit;
  end;

  while (result <= 0) and (not Stopped) do
  begin
    // From Boost.ASIO:
    // Timeout to use with GetQueuedCompletionStatus. Some versions of windows
    // have a "bug" where a call to GetQueuedCompletionStatus can appear stuck
    // even though there are events waiting on the queue. Using a timeout helps
    // to work around the issue.
    result := DoPollOne(500);
  end;
end;

procedure IOServiceImpl.Stop;
begin
  InterlockedExchange(FStopped, 1);
  CancelIo(IOCP);
  PostQueuedCompletionStatus(IOCP, 0, COMPLETION_KEY_EXIT, nil);
end;

{ AsyncStreamImplBase }

constructor AsyncStreamImplBase.Create(const Service: IOService);
begin
  inherited Create;

  FService := Service;
end;

function AsyncStreamImplBase.GetService: IOService;
begin
  result := FService;
end;

{ AsyncMemoryStreamImpl }

procedure AsyncMemoryStreamImpl.AsyncReadSome(const Buffer: MemoryBuffer;
  const Handler: IOHandler);
var
  ctx: IOHandlerContext;
  remainingData: Int64;
  bytesRead: UInt32;
begin
  ctx := IOHandlerContext.Create(Handler);

  if (Length(Data) > 0) then
  begin
    remainingData := Length(Data) - FOffset;
    bytesRead := Min(Buffer.Size, remainingData);
  end
  else
  begin
    bytesRead := 0;
  end;

  Move(Data[FOffset], Buffer.Data^, bytesRead);

  FOffset := FOffset + bytesRead;

  IOServicePostCompletion(Service, bytesRead, ctx);
end;

procedure AsyncMemoryStreamImpl.AsyncWriteSome(const Buffer: MemoryBuffer;
  const Handler: IOHandler);
var
  ctx: IOHandlerContext;
  bytesWritten: UInt32;
  newSize: Int64;
begin
  ctx := IOHandlerContext.Create(Handler);

  bytesWritten := Buffer.Size;

  newSize := bytesWritten + FOffset;

  if (newSize > Length(Data)) then
  begin
    try
      SetLength(FData, newSize);
    except
      on E: EOutOfMemory do
        bytesWritten := 0;
    end;
  end;

  Move(Buffer.Data^, Data[FOffset], bytesWritten);

  FOffset := FOffset + bytesWritten;

  IOServicePostCompletion(Service, bytesWritten, ctx);
end;

constructor AsyncMemoryStreamImpl.Create(const Service: IOService;
  const Data: TBytes);
begin
  inherited Create(Service);

  FData := Data;
end;

destructor AsyncMemoryStreamImpl.Destroy;
begin
  FData := nil;

  inherited;
end;

function AsyncMemoryStreamImpl.GetData: TBytes;
begin
  result := FData;
end;


{ AsyncHandleStreamImpl }

procedure AsyncHandleStreamImpl.AsyncReadSome(const Buffer: MemoryBuffer;
  const Handler: IOHandler);
var
  bytesRead: DWORD;
  ctx: IOHandlerContext;
  res: boolean;
  ec: DWORD;
begin
  ctx := IOHandlerContext.Create(
    procedure(const Res: OpResult; const BytesTransferred: UInt64)
    begin
      FOffset := FOffset + BytesTransferred;
      Handler(Res, BytesTransferred);
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

procedure AsyncHandleStreamImpl.AsyncWriteSome(const Buffer: MemoryBuffer;
  const Handler: IOHandler);
var
  bytesWritten: DWORD;
  ctx: IOHandlerContext;
  res: boolean;
  ec: DWORD;
begin
  ctx := IOHandlerContext.Create(
    procedure(const Res: OpResult; const BytesTransferred: UInt64)
    begin
      FOffset := FOffset + BytesTransferred;
      Handler(Res, BytesTransferred);
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

constructor AsyncHandleStreamImpl.Create(const Service: IOService;
  const Handle: THandle);
begin
  inherited Create(Service);

  FHandle := Handle;
end;

destructor AsyncHandleStreamImpl.Destroy;
begin
  CloseHandle(FHandle);

  inherited;
end;

function AsyncHandleStreamImpl.GetHandle: THandle;
begin
  result := FHandle;
end;

end.
