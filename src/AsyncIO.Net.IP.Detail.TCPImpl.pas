unit AsyncIO.Net.IP.Detail.TCPImpl;

interface

uses
  IdWinsock2, AsyncIO, AsyncIO.Net.IP;

type
  TTCPSocketImpl = class(TInterfacedObject, IPStreamSocket)
  strict private
    FSocketHandle: TSocket;
    FService: IOService;
    FProtocol: IPProtocol;

    procedure CreateSocket;
    procedure ResetSocket;

    function GetSocketInitialized: boolean;
  protected
    property SocketInitialized: boolean read GetSocketInitialized;
  public
    constructor Create(const Service: IOService);
    destructor Destroy; override;

    function GetService: IOService;
    function GetProtocol: IPProtocol;
    function GetLocalEndpoint: IPEndpoint;
    function GetRemoteEndpoint: IPEndpoint;
    function GetSocketHandle: TSocket;

    procedure AsyncConnect(const PeerEndpoint: IPEndpoint; const Handler: OpHandler);

    procedure Bind(const LocalEndpoint: IPEndpoint);

    procedure Connect(const PeerEndpoint: IPEndpoint);
    procedure Close;

    procedure Shutdown(const ShutdownFlag: SocketShutdownFlag = SocketShutdownBoth);

    procedure AsyncSend(const Buffer: MemoryBuffer; const Handler: IOHandler); overload;
    procedure AsyncReceive(const Buffer: MemoryBuffer; const Handler: IOHandler); overload;

    property Service: IOService read FService;
    property SocketHandle: TSocket read FSocketHandle;
    property Protocol: IPProtocol read FProtocol;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, AsyncIO.ErrorCodes, AsyncIO.Detail, AsyncIO.Net.IP.Detail;

{ TTCPSocketImpl }

procedure TTCPSocketImpl.AsyncConnect(const PeerEndpoint: IPEndpoint;
  const Handler: OpHandler);
var
  bytesSent: DWORD;
  ctx: OpHandlerContext;
  res: boolean;
  ec: DWORD;
  localEndpoint: IPEndpoint;
begin
  if (PeerEndpoint.IsIPv4) then
    FProtocol := IPProtocol.TCP.v4
  else if (PeerEndpoint.IsIPv6) then
    FProtocol := IPProtocol.TCP.v6
  else
    FProtocol := IPProtocol.TCP.Unspecified;

  if not SocketInitialized then
    CreateSocket;

  ctx := OpHandlerContext.Create(
    procedure(const ErrorCode: IOErrorCode)
    var
      err: DWORD;
      ec: IOErrorCode;
    begin
      ec := ErrorCode;
      if (ec) then
      begin
        // update socket options
        err := IdWinsock2.setsockopt(SocketHandle, SOL_SOCKET, SO_UPDATE_CONNECT_CONTEXT, nil, 0);
        if (err <> 0) then
          // set code from GetLastError
          ec := IOErrorCode.Create();
      end;

      // if connect succeeded but setsockopt failed, pass the error from the latter
      Handler(ec);
    end
  );

  // bind local endpoint to any address/port
  localEndpoint := Endpoint(Protocol.Family, 0);
  Bind(localEndpoint);

  res := IdWinsock2.ConnectEx(SocketHandle, PeerEndpoint.Data, PeerEndpoint.DataLength, nil, 0, bytesSent, PWSAOverlapped(ctx.Overlapped));
  if (not res) then
  begin
    ec := GetLastError;
    if (ec <> WSA_IO_PENDING) then
      RaiseLastOSError(ec);
  end;
end;

procedure TTCPSocketImpl.AsyncReceive(const Buffer: MemoryBuffer;
  const Handler: IOHandler);
var
  bufs: TWSABuf;
  bytesReceived, flags: DWORD;
  ctx: IOHandlerContext;
  res: integer;
  ec: DWORD;
begin
  bufs.len := Buffer.Size;
  bufs.buf := Buffer.Data;
  ctx := IOHandlerContext.Create(Handler);
  flags := 0;
  res := WSARecv(SocketHandle, @bufs, 1, bytesReceived, flags, PWSAOverlapped(ctx.Overlapped), nil);
  if (res <> 0) then
  begin
    ec := GetLastError;
    if (ec <> WSA_IO_PENDING) then
      RaiseLastOSError(ec);
  end
  else
  begin
    // completed directly, but completion entry is queued by manager
    // no async action, call handler directly
//    IOServicePostCompletion(Service, bytesReceived, ctx);
  end;
end;

procedure TTCPSocketImpl.AsyncSend(const Buffer: MemoryBuffer;
  const Handler: IOHandler);
var
  bufs: TWSABuf;
  bytesSent: DWORD;
  ctx: IOHandlerContext;
  res: integer;
  ec: DWORD;
begin
  bufs.len := Buffer.Size;
  bufs.buf := Buffer.Data;
  ctx := IOHandlerContext.Create(Handler);
  res := WSASend(SocketHandle, @bufs, 1, bytesSent, 0, PWSAOverlapped(ctx.Overlapped), nil);
  if (res <> 0) then
  begin
    ec := GetLastError;
    if (ec <> WSA_IO_PENDING) then
      RaiseLastOSError(ec);
  end
  else
  begin
    // completed directly, but completion entry is queued by manager
    // no async action, call handler directly
//    IOServicePostCompletion(Service, bytesSent, ctx);
  end;
end;

procedure TTCPSocketImpl.Bind(const LocalEndpoint: IPEndpoint);
var
  res: WinsockResult;
begin
  res := IdWinsock2.bind(SocketHandle, LocalEndpoint.Data, LocalEndpoint.DataLength);
end;

procedure TTCPSocketImpl.Close;
var
  s: TSocket;
  res: WinSockResult;
begin
  s := FSocketHandle;
  ResetSocket;
  res := IdWinsock2.closesocket(s)
end;

procedure TTCPSocketImpl.Connect(const PeerEndpoint: IPEndpoint);
var
  res: WinSockResult;
begin
  if (PeerEndpoint.IsIPv4) then
    FProtocol := IPProtocol.TCP.v4
  else if (PeerEndpoint.IsIPv6) then
    FProtocol := IPProtocol.TCP.v6
  else
    FProtocol := IPProtocol.TCP.Unspecified;

  if not SocketInitialized then
    CreateSocket;

  res := IdWinsock2.connect(SocketHandle, PeerEndpoint.Data, PeerEndpoint.DataLength);
end;

constructor TTCPSocketImpl.Create(const Service: IOService);
begin
  inherited Create;

  FService := Service;
  ResetSocket;
end;

procedure TTCPSocketImpl.CreateSocket;
begin
  if (SocketHandle <> INVALID_SOCKET) then
    raise EInvalidOpException.Create('Socket already allocated in CreateSocket (TCP)');

  if (Protocol.SocketType <> SOCK_STREAM) then
    raise EArgumentException.Create('Invalid socket type in CreateSocket (TCP)');

  FSocketHandle := IdWinsock2.socket(Protocol.Family, Protocol.SocketType, Protocol.Protocol);
  if (FSocketHandle = INVALID_SOCKET) then
    RaiseLastOSError(WSAGetLastError, 'CreateSocket (TCP)');

  IOServiceAssociateHandle(Service, SocketHandle);
end;

destructor TTCPSocketImpl.Destroy;
begin
  if (FSocketHandle <> INVALID_SOCKET) then
    Close;

  inherited;
end;

function TTCPSocketImpl.GetLocalEndpoint: IPEndpoint;
begin

end;

function TTCPSocketImpl.GetProtocol: IPProtocol;
begin
  if (GetLocalEndpoint.IsIPv4) then
    FProtocol := IPProtocol.TCP.v4
  else if (GetLocalEndpoint.IsIPv6) then
    FProtocol := IPProtocol.TCP.v6
  else
    FProtocol := IPProtocol.TCP.Unspecified;
end;

function TTCPSocketImpl.GetRemoteEndpoint: IPEndpoint;
begin

end;

function TTCPSocketImpl.GetService: IOService;
begin
  result := FService;
end;

function TTCPSocketImpl.GetSocketHandle: TSocket;
begin
  result := SocketHandle;
end;

function TTCPSocketImpl.GetSocketInitialized: boolean;
begin
  result := SocketHandle <> INVALID_SOCKET;
end;

procedure TTCPSocketImpl.ResetSocket;
begin
  FSocketHandle := INVALID_SOCKET;
  FProtocol := IPProtocol.TCP.Unspecified;
end;

procedure TTCPSocketImpl.Shutdown(const ShutdownFlag: SocketShutdownFlag);
const
  ShutdownFlagMapping: array[SocketShutdownFlag] of integer =
    (SD_RECEIVE, SD_SEND, SD_BOTH);
begin
  IdWinsock2.shutdown(SocketHandle, ShutdownFlagMapping[ShutdownFlag]);
end;

end.
