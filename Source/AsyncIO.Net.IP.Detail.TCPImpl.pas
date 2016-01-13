unit AsyncIO.Net.IP.Detail.TCPImpl;

interface

uses
  IdWinsock2, AsyncIO, AsyncIO.Net.IP, AsyncIO.Net.IP.Detail;

type
  TTCPSocketImpl = class(TInterfacedObject, IPStreamSocket, IPSocketAccess)
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

    // IPSocketAccess
    procedure Assign(const Protocol: IPProtocol; const SocketHandle: TSocket);

    // IPStreamSocket
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

  TTCPAcceptorImpl = class(TInterfacedObject, IPAcceptor)
  strict private
    FSocketHandle: TSocket;
    FService: IOService;
    FProtocol: IPProtocol;

    function CreateSocket: TSocket;
    procedure CloseSocket(const SocketHandle: TSocket);
    procedure ResetSocket;

  protected
    property SocketHandle: TSocket read FSocketHandle;
  public
    constructor Create(const Service: IOService);
    destructor Destroy; override;

    function GetService: IOService;
    function GetProtocol: IPProtocol;
    function GetLocalEndpoint: IPEndpoint;
    function GetIsOpen: boolean;

    procedure AsyncAccept(const Peer: IPSocket; const Handler: OpHandler);

    procedure Open(const Protocol: IPProtocol);

    procedure Bind(const LocalEndpoint: IPEndpoint);

    procedure Listen(); overload;
    procedure Listen(const Backlog: integer); overload;

    procedure Close;

    property Service: IOService read FService;
    property Protocol: IPProtocol read FProtocol;
    property LocalEndpoint: IPEndpoint read GetLocalEndpoint;
    property IsOpen: boolean read GetIsOpen;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, AsyncIO.OpResults, AsyncIO.Detail;

{ TTCPSocketImpl }

procedure TTCPSocketImpl.Assign(const Protocol: IPProtocol; const SocketHandle: TSocket);
begin
  if (SocketInitialized) then
    raise EArgumentException.Create('Socket already open in Assign');

  FSocketHandle := SocketHandle;

  IOServiceAssociateHandle(Service, SocketHandle);
end;

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
    procedure(const Res: OpResult)
    var
      err: DWORD;
      r: OpResult;
    begin
      r := Res;
      if (r.Success) then
      begin
        // update socket options
        // ConnectEx requires this
        err := IdWinsock2.setsockopt(SocketHandle, SOL_SOCKET, SO_UPDATE_CONNECT_CONTEXT, nil, 0);
        if (err <> 0) then
          // set code from GetLastError
          r := SystemResults.LastError;
      end;

      // if connect succeeded but setsockopt failed, pass the error from the latter
      Handler(r);
    end
  );

  // ConnectEx requires a bound socket, so
  // bind local endpoint to and unspecified address and make the
  // provider assign a port
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
  res: OpResult;
begin
  if (LocalEndpoint.IsIPv4) then
    FProtocol := IPProtocol.TCP.v4
  else if (LocalEndpoint.IsIPv6) then
    FProtocol := IPProtocol.TCP.v6
  else
    FProtocol := IPProtocol.TCP.Unspecified;

  if not SocketInitialized then
    CreateSocket;

  res := WinsockResult(IdWinsock2.bind(SocketHandle, LocalEndpoint.Data, LocalEndpoint.DataLength));
  if (not res.Success) then
    res.RaiseException();
end;

procedure TTCPSocketImpl.Close;
var
  s: TSocket;
  res: OpResult;
begin
  s := FSocketHandle;
  ResetSocket;
  if (s <> INVALID_SOCKET) then
  begin
    res := WinsockResult(IdWinsock2.closesocket(s));
    if (not res.Success) then
      res.RaiseException();
  end;
end;

procedure TTCPSocketImpl.Connect(const PeerEndpoint: IPEndpoint);
var
  res: OpResult;
begin
  if (PeerEndpoint.IsIPv4) then
    FProtocol := IPProtocol.TCP.v4
  else if (PeerEndpoint.IsIPv6) then
    FProtocol := IPProtocol.TCP.v6
  else
    FProtocol := IPProtocol.TCP.Unspecified;

  if not SocketInitialized then
    CreateSocket;

  res := WinsockResult(IdWinsock2.connect(SocketHandle, PeerEndpoint.Data, PeerEndpoint.DataLength));
  if (not res.Success) then
    res.RaiseException();
end;

constructor TTCPSocketImpl.Create(const Service: IOService);
begin
  inherited Create;

  FService := Service;
  ResetSocket;
end;

procedure TTCPSocketImpl.CreateSocket;
begin
  if (SocketInitialized) then
    raise EInvalidOpException.Create('Socket already allocated in CreateSocket (TCP)');

  if (Protocol.SocketType <> SOCK_STREAM) then
    raise EArgumentException.Create('Invalid socket type in CreateSocket (TCP)');

  FSocketHandle := IdWinsock2.socket(Protocol.Family, Protocol.SocketType, Protocol.Protocol);
  if (FSocketHandle = INVALID_SOCKET) then
    NetResults.LastError.RaiseException('CreateSocket (TCP)');

  IOServiceAssociateHandle(Service, SocketHandle);
end;

destructor TTCPSocketImpl.Destroy;
begin
  if (SocketInitialized) then
    Close;

  inherited;
end;

function TTCPSocketImpl.GetLocalEndpoint: IPEndpoint;
var
  addr: TSockAddrIn6;
  addrlen: integer;
  res: OpResult;
begin
  FillChar(addr, SizeOf(addr), 0);
  addrlen := SizeOf(addr);

  res := WinsockResult(IdWinsock2.getsockname(SocketHandle, @addr, addrlen));
  if (not res.Success) then
    res.RaiseException();

  result := IPEndpoint.FromData(addr, addrlen);
end;

function TTCPSocketImpl.GetProtocol: IPProtocol;
begin
  result := FProtocol;
end;

function TTCPSocketImpl.GetRemoteEndpoint: IPEndpoint;
var
  addr: TSockAddrIn6;
  addrlen: integer;
  res: OpResult;
begin
  FillChar(addr, SizeOf(addr), 0);
  addrlen := SizeOf(addr);

  res := WinsockResult(IdWinsock2.getpeername(SocketHandle, @addr, addrlen));
  if (not res.Success) then
    res.RaiseException();

  result := IPEndpoint.FromData(addr, addrlen);
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

{ TTCPAcceptorImpl }

procedure TTCPAcceptorImpl.AsyncAccept(const Peer: IPSocket; const Handler: OpHandler);
var
  bytesReceived: DWORD;
  addrLength: integer;
  addrBuffer: TBytes;
  listenSocket: TSocket;
  peerSocket: TSocket;
  peerProtocol: IPProtocol;
  ctx: OpHandlerContext;
  res: boolean;
  ec: DWORD;
begin
  listenSocket := SocketHandle;

  ctx := OpHandlerContext.Create(
    procedure(const Res: OpResult)
    var
      err: DWORD;
      r: OpResult;
    begin
      r := Res;

      // ensure we capture addrBuffer
      // TODO - extract peer endpoint
      addrBuffer := nil;

      // assign the peer socket handle
      IPSocketAssign(Peer, peerProtocol, peerSocket);

      if (not r.Success) then
      begin
        // update socket options, need to associate the listen socket with the accept socket
        // AcceptEx requires this for getsockname/getpeername
        r := WinsockResult(IdWinsock2.setsockopt(Peer.SocketHandle, SOL_SOCKET, SO_UPDATE_ACCEPT_CONTEXT, @listenSocket, SizeOf(listenSocket)));
      end;

      // if connect succeeded but setsockopt failed, pass the error from the latter
      Handler(r);
    end
  );

  // MSDN:
  // The buffer size for the local and remote address must be 16 bytes more than the size of the
  // sockaddr structure for the transport protocol in use because the addresses are written in an internal format.
  addrLength := (SizeOf(TSockAddrStorage) + 16);
  SetLength(addrBuffer, 2 * addrLength);

  peerProtocol := Protocol;
  peerSocket := CreateSocket();

  res := IdWinsock2.AcceptEx(SocketHandle, peerSocket, addrBuffer, 0, addrLength, addrLength, bytesReceived, ctx.Overlapped);
  if (not res) then
  begin
    ec := GetLastError;
    if (ec <> WSA_IO_PENDING) then
      RaiseLastOSError(ec);
  end;
end;

procedure TTCPAcceptorImpl.Bind(const LocalEndpoint: IPEndpoint);
var
  res: OpResult;
begin
  if (LocalEndpoint.IsIPv4) then
    FProtocol := IPProtocol.TCP.v4
  else if (LocalEndpoint.IsIPv6) then
    FProtocol := IPProtocol.TCP.v6
  else
    FProtocol := IPProtocol.TCP.Unspecified;

  if (not IsOpen) then
    Open(Protocol);

  res := WinsockResult(IdWinsock2.bind(SocketHandle, LocalEndpoint.Data, LocalEndpoint.DataLength));
  if (not res.Success) then
    res.RaiseException();
end;

procedure TTCPAcceptorImpl.Close;
var
  s: TSocket;
begin
  s := FSocketHandle;
  ResetSocket;
  CloseSocket(s);
end;

procedure TTCPAcceptorImpl.CloseSocket(const SocketHandle: TSocket);
var
  res: OpResult;
begin
  if (SocketHandle = INVALID_SOCKET) then
    exit;

  res := WinsockResult(IdWinsock2.closesocket(SocketHandle));
  if (not res.Success) then
    res.RaiseException();
end;

constructor TTCPAcceptorImpl.Create(const Service: IOService);
begin
  inherited Create;

  FService := Service;
  ResetSocket;
end;

function TTCPAcceptorImpl.CreateSocket: TSocket;
begin
  result := IdWinsock2.socket(Protocol.Family, Protocol.SocketType, Protocol.Protocol);
  if (result = INVALID_SOCKET) then
    NetResults.LastError.RaiseException('CreateSocket (TCP)');
end;

destructor TTCPAcceptorImpl.Destroy;
begin
  if (SocketHandle <> INVALID_SOCKET) then
    Close;

  inherited;
end;

function TTCPAcceptorImpl.GetIsOpen: boolean;
begin
  result := SocketHandle <> INVALID_SOCKET;
end;

function TTCPAcceptorImpl.GetLocalEndpoint: IPEndpoint;
var
  addr: TSockAddrIn6;
  addrlen: integer;
  res: OpResult;
begin
  FillChar(addr, SizeOf(addr), 0);
  addrlen := SizeOf(addr);

  res := WinsockResult(IdWinsock2.getsockname(SocketHandle, @addr, addrlen));
  if (not res.Success) then
    res.RaiseException();

  result := IPEndpoint.FromData(addr, addrlen);
end;

function TTCPAcceptorImpl.GetProtocol: IPProtocol;
begin
  result := FProtocol;
end;

function TTCPAcceptorImpl.GetService: IOService;
begin
  result := FService;
end;

procedure TTCPAcceptorImpl.Listen(const Backlog: integer);
var
  res: OpResult;
begin
  res := WinsockResult(IdWinsock2.listen(SocketHandle, Backlog));
  if (not res.Success) then
    res.RaiseException();
end;

procedure TTCPAcceptorImpl.Listen;
begin
  Listen(SOMAXCONN);
end;

procedure TTCPAcceptorImpl.Open(const Protocol: IPProtocol);
begin
  if ((Protocol.SocketType <> 0) and (Protocol.SocketType <> SOCK_STREAM)) then
    raise EArgumentException.Create('Invalid socket type in Open (TCP)');

  if (SocketHandle <> INVALID_SOCKET) then
    raise EInvalidOpException.Create('Socket already allocated in Open (TCP)');

  FProtocol := Protocol;

  FSocketHandle := CreateSocket();

  IOServiceAssociateHandle(Service, SocketHandle);
end;

procedure TTCPAcceptorImpl.ResetSocket;
begin
  FSocketHandle := INVALID_SOCKET;
  FProtocol := IPProtocol.TCP.Unspecified;
end;

end.
