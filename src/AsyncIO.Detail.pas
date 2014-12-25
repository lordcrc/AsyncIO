unit AsyncIO.Detail;

interface

uses
  WinAPI.Windows, AsyncIO, AsyncIO.ErrorCodes;

type
  IOCPContext  = class
  private
    FOverlapped: TOverlapped;
    function GetOverlapped: POverlapped;
    function GetOverlappedOffset: UInt64;
    procedure SetOverlappedOffset(const Value: UInt64);
  public
    constructor Create;
    destructor Destroy; override;

    property Overlapped: POverlapped read GetOverlapped;
    property OverlappedOffset: UInt64 read GetOverlappedOffset write SetOverlappedOffset;

    procedure ExecHandler(const ec: IOErrorCode; const transferred: Int64); virtual;

    class function FromOverlapped(const Overlapped: POverlapped): IOCPContext;
  end;

  HandlerContext = class(IOCPContext)
  private
    FHandler: CompletionHandler;
  public
    constructor Create(const Handler: CompletionHandler);
    destructor Destroy; override;

    procedure ExecHandler(const ec: IOErrorCode; const transferred: Int64); override;

    property Handler: CompletionHandler read FHandler;
  end;

  IOHandlerContext = class(IOCPContext)
  private
    FHandler: IOHandler;
  public
    constructor Create(const Handler: IOHandler);

    procedure ExecHandler(const ec: IOErrorCode; const transferred: Int64); override;

    property Handler: IOHandler read FHandler;
  end;

procedure IOServicePostCompletion(const Service: IOService;
  const BytesTransferred: DWORD;
  const Ctx: IOCPContext);

procedure IOServiceAssociateHandle(const Service: IOService;
  const Handle: THandle);

implementation

uses
  System.SysUtils;

{$POINTERMATH ON}

const
  COMPLETION_KEY_OPERATION = 1;
  COMPLETION_KEY_OPERATION_DIR = 2;

type
  IOServiceAccess = class(IOService)
  end;

procedure IOServicePostCompletion(const Service: IOService;
  const BytesTransferred: DWORD;
  const Ctx: IOCPContext);
begin
  if Service.Stopped then
    raise EIOServiceStopped.Create('Cannot post to a stopped IOService');

//  WriteLn(Format('DEBUG post overlapped: %.8x', [NativeUInt(ctx.Overlapped)]));
  PostQueuedCompletionStatus(IOServiceAccess(Service).IOCP, BytesTransferred, COMPLETION_KEY_OPERATION_DIR, Ctx.Overlapped);
end;

procedure IOServiceAssociateHandle(const Service: IOService;
  const Handle: THandle);
var
  cph: THandle;
begin
  // Associate with IOCP
  cph := CreateIoCompletionPort(Handle, IOServiceAccess(Service).IOCP, COMPLETION_KEY_OPERATION, 0);

  if (cph = 0) then
    RaiseLastOSError;
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

procedure IOCPContext.ExecHandler(const ec: IOErrorCode; const transferred: Int64);
begin
  raise ENotImplemented.Create('Invalid context handler');
end;

class function IOCPContext.FromOverlapped(const Overlapped: POverlapped): IOCPContext;
type
  PUInt8 = ^UInt8;
begin
  result := TObject(PUInt8(Overlapped) - 4) as IOCPContext;
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

destructor HandlerContext.Destroy;
begin
  FHandler := nil;

  inherited;
end;

procedure HandlerContext.ExecHandler(const ec: IOErrorCode; const transferred: Int64);
begin
  Handler();
end;

{ IOHandlerContext }

constructor IOHandlerContext.Create(const Handler: IOHandler);
begin
  inherited Create;

  FHandler := Handler;
end;

procedure IOHandlerContext.ExecHandler(const ec: IOErrorCode; const transferred: Int64);
begin
  Handler(ec, transferred);
end;

end.
