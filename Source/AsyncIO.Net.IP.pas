unit AsyncIO.Net.IP;

interface

uses
  IdWinsock2, AsyncIO, AsyncIO.ErrorCodes;

type
  IPv4Address = record
  strict private
    FAddress: UInt32;

    function GetIsLoopback: boolean;
    function GetIsMulticast: boolean;
    function GetIsUnspecified: boolean;
    function GetData: UInt32; inline;
  public
    class function Any: IPv4Address; static;
    class function Loopback: IPv4Address; static;
    class function Broadcast: IPv4Address; static;

    class operator Explicit(const Addr: UInt32): IPv4Address;
    class operator Implicit(const IPAddress: IPv4Address): string;

    class operator Equal(const Addr1, Addr2: IPv4Address): boolean;
    class operator NotEqual(const Addr1, Addr2: IPv4Address): boolean;

    class function TryFromString(const s: string; out Addr: IPv4Address): boolean; static;

    property IsLoopback: boolean read GetIsLoopback;
    property IsMulticast: boolean read GetIsMulticast;
    property IsUnspecified: boolean read GetIsUnspecified;

    property Data: UInt32 read GetData;
  end;

  IPv6Address = record
  public
    type IPv6AddressBytes = array[0..15] of UInt8;
    type PIPv6AddressBytes = ^IPv6AddressBytes;
  strict private
    FAddress: array[0..15] of UInt8;
    FScopeId: UInt32;
    function GetIsLoopback: boolean;
    function GetIsMulticast: boolean;
    function GetIsUnspecified: boolean;
    function GetData: IPv6AddressBytes;
  public
    class function Any: IPv6Address; static;
    class function Loopback: IPv6Address; static;

    class function Create(const Addr: IPv6AddressBytes; const ScopeId: UInt32): IPv6Address; static;

    class operator Explicit(const Addr: IPv6AddressBytes): IPv6Address;
    class operator Implicit(const IPAddress: IPv6Address): string;

    class operator Equal(const Addr1, Addr2: IPv6Address): boolean;
    class operator NotEqual(const Addr1, Addr2: IPv6Address): boolean;

    class function TryFromString(const s: string; out Addr: IPv6Address): boolean; static;

    property IsLoopback: boolean read GetIsLoopback;
    property IsMulticast: boolean read GetIsMulticast;
    property IsUnspecified: boolean read GetIsUnspecified;
    property ScopeId: UInt32 read FScopeId;

    property Data: IPv6AddressBytes read GetData;
  end;

  IPAddress = record
  strict private
    function GetIsLoopback: boolean; inline;
    function GetIsMulticast: boolean; inline;
    function GetIsUnspecified: boolean; inline;
    function GetIsIPv4: boolean; inline;
    function GetIsIPv6: boolean; inline;
    function GetAsIPv4: IPv4Address; inline;
    function GetAsIPv6: IPv6Address; inline;

    procedure SetAsIPv4(const Value: IPv4Address); inline;
    procedure SetAsIPv6(const Value: IPv6Address); inline;
  public
    class operator Explicit(const s: string): IPAddress;
    class operator Implicit(const IPAddress: IPv4Address): IPAddress; inline;
    class operator Implicit(const IPAddress: IPv6Address): IPAddress; inline;
    class operator Implicit(const IPAddress: IPAddress): string; inline;

    class operator Equal(const Addr1, Addr2: IPAddress): boolean;
    class operator NotEqual(const Addr1, Addr2: IPAddress): boolean;

    property IsIPv4: boolean read GetIsIPv4;
    property IsIPv6: boolean read GetIsIPv6;
    property IsLoopback: boolean read GetIsLoopback;
    property IsMulticast: boolean read GetIsMulticast;
    property IsUnspecified: boolean read GetIsUnspecified;

    property AsIPv4: IPv4Address read GetAsIPv4 write SetAsIPv4;
    property AsIPv6: IPv6Address read GetAsIPv6 write SetAsIPv6;
  strict private
    type TAddressType = (atV4, atV6);
  strict private
    FAddressType: TAddressType;
    FIPv4Addr: IPv4Address;
    FIPv6Addr: IPv6Address;
  end;

  IPAddressFamily = record
  strict private
    FValue: UInt16;
  public
    class operator Implicit(const Family: IPAddressFamily): UInt16; inline;
    class operator Equal(const Family1, Family2: IPAddressFamily): boolean; inline;
    class operator NotEqual(const Family1, Family2: IPAddressFamily): boolean; inline;

    class function Unspecified: IPAddressFamily; static;
    class function v4: IPAddressFamily; static;
    class function v6: IPAddressFamily; static;

    function ToString(): string;
  end;

  IPProtocol = record
  strict private
    FFamily: IPAddressFamily;
    FSocketType: integer;
    FProtocol: integer;
  public
    type
      ICMPProtocol = record
        class function v4: IPProtocol; static;
        class function v6: IPProtocol; static;
        class function Unspecified: IPProtocol; static;
      end;
      TCPProtocol = record
        class function v4: IPProtocol; static;
        class function v6: IPProtocol; static;
        class function Unspecified: IPProtocol; static;
      end;
      UDPProtocol = record
        class function v4: IPProtocol; static;
        class function v6: IPProtocol; static;
        class function Unspecified: IPProtocol; static;
      end;
  public
    class function ICMP: ICMPProtocol; static;
    class function TCP: TCPProtocol; static;
    class function UDP: UDPProtocol; static;
    class function v4: IPProtocol; static;
    class function v6: IPProtocol; static;
    class function Unspecified: IPProtocol; static;

    class operator Equal(const Protocol1, Protocol2: IPProtocol): boolean;
    class operator NotEqual(const Protocol1, Protocol2: IPProtocol): boolean;

    function ToString(): string;

    property Family: IPAddressFamily read FFamily;
    property SocketType: integer read FSocketType;
    property Protocol: integer read FProtocol;
  end;

type
  IPEndpoint = record
  strict private
    function GetAddress: IPAddress;
    procedure SetAddress(const Value: IPAddress);
    function GetPort: UInt16;
    procedure SetPort(const Value: UInt16);
    function GetIsIPv4: boolean;
    function GetIsIPv6: boolean;
    function GetProtocol: IPProtocol;
    function GetData: Pointer;
    function GetDataLength: integer;
  private
    class function Create(const Family: IPAddressFamily; const Port: UInt16): IPEndpoint; overload; static;
    class function Create(const Protocol: IPProtocol; const Port: UInt16): IPEndpoint; overload; static;
    class function Create(const Address: IPAddress; const Port: UInt16): IPEndpoint; overload; static;
    class function Create(const SocketAddress4: PSockAddrIn; const AddressLength: NativeUInt): IPEndpoint; overload; static;
    class function Create(const SocketAddress6: PSockAddrIn6; const AddressLength: NativeUInt): IPEndpoint; overload; static;
  public
    class operator Implicit(const Endpoint: IPEndpoint): string;
    class operator Equal(const Endpoint1, Endpoint2: IPEndpoint): boolean;
    class operator NotEqual(const Endpoint1, Endpoint2: IPEndpoint): boolean;
    
    class function FromData(const Data; const DataLength: integer): IPEndpoint; static;

    property Address: IPAddress read GetAddress write SetAddress;
    property Port: UInt16 read GetPort write SetPort;

    property IsIPv4: boolean read GetIsIPv4;
    property IsIPv6: boolean read GetIsIPv6;

    property Protocol: IPProtocol read GetProtocol;

    property Data: Pointer read GetData;
    property DataLength: integer read GetDataLength;
  strict private
    FProtocol: IPProtocol;
    case integer of
      0: (FBase: TSockAddrStorage);
      1: (Fv4: sockaddr_in);
      2: (Fv6: SOCKADDR_IN6_W2KSP1);
  end;

function Endpoint(): IPEndpoint; overload; inline;
function Endpoint(const Family: IPAddressFamily; PortNumber: UInt16): IPEndpoint; overload; inline;
function Endpoint(const Protocol: IPProtocol; PortNumber: UInt16): IPEndpoint; overload; inline;
function Endpoint(const Address: IPAddress; const PortNumber: UInt16): IPEndpoint; overload; inline;

type
  ResolveFlag = (
    ResolvePassive,
    ResolveCannonicalName,
    ResolveNumericHost,
    ResolveNumericService,
    ResolveAllMatching,
    ResolveV4Mapped,
    ResolveAddressConfigured);
  ResolveFlags = set of ResolveFlag;

  ResolverEntry = record
  strict private
    FHostname: string;
    FServiceName: string;
  public

    property HostName: string read FHostname;
    property ServiceName: string read FServicename;
  end;

type
  IPResolver = record
  public
    type
      TAddressInfo = ADDRINFOEXW;
      PAddressInfo = PADDRINFOEXW;
      Query = record
      strict private
        FHints: TAddressInfo;
        FHostName: string;
        FServiceName: string;

        function GetHints: PAddressInfo;
      private
        class function Create(const Protocol: IPProtocol; const Host, Service: string; const Flags: ResolveFlags): IPResolver.Query; static;

        property Hints: PAddressInfo read GetHints;
      public
        property HostName: string read FHostName;
        property ServiceName: string read FServiceName;
      end;
      Entry = record
      strict private
        FEndpoint: IPEndpoint;
        FHostName: string;
        FServiceName: string;
      private
        class function Create(const Endpoint: IPEndpoint; const Host, Service: string): Entry; static;
      public
        property Endpoint: IPEndpoint read FEndpoint;
        property HostName: string read FHostName;
        property ServiceName: string read FServiceName;
      end;
      Results = record
      public
        type
          TResultsEnumerator = class
          strict private
            FResults: TArray<Entry>;
            FIndex: integer;
          private
            function GetCurrent: Entry;
            constructor Create(const Results: TArray<Entry>);
          public
            function MoveNext: boolean;

            property Current: Entry read GetCurrent;
          end;
      strict private
        FResults: TArray<Entry>;
      private
        class function Create(const Host, Service: string; const AddressInfo: PAddressInfo): Results; static;
      public
        function GetEnumerator: TResultsEnumerator;

        function GetEndpoints: TArray<IPEndpoint>;

        function ToArray(): TArray<Entry>;
     end;
  public
    class function Resolve(const ResolveQuery: Query): Results; static;
  end;

function Query(const Protocol: IPProtocol; const Host, Service: string; const Flags: ResolveFlags = [ResolveAddressConfigured]): IPResolver.Query; {TODO - remove when compiler bug is fixed... inline;} overload;
function Query(const Host, Service: string; const Flags: ResolveFlags = [ResolveAddressConfigured]): IPResolver.Query; inline; overload;


type
  SocketShutdownFlag = (
    SocketShutdownRead,
    SocketShutdownWrite,
    SocketShutdownBoth
  );

  IPSocket = interface
{$REGION 'Property accessors'}
    function GetService: IOService;
    function GetProtocol: IPProtocol;
    function GetLocalEndpoint: IPEndpoint;
    function GetRemoteEndpoint: IPEndpoint;
    function GetSocketHandle: TSocket;
{$ENDREGION}

    procedure AsyncConnect(const PeerEndpoint: IPEndpoint; const Handler: OpHandler);

    procedure Bind(const LocalEndpoint: IPEndpoint);

    procedure Connect(const PeerEndpoint: IPEndpoint);
    procedure Close;

    procedure Shutdown(const ShutdownFlag: SocketShutdownFlag = SocketShutdownBoth); overload;

    property Service: IOService read GetService;
    property Protocol: IPProtocol read GetProtocol;
    property LocalEndpoint: IPEndpoint read GetLocalEndpoint;
    property RemoteEndpoint: IPEndpoint read GetRemoteEndpoint;
    property SocketHandle: TSocket read GetSocketHandle;
  end;

  IPStreamSocket = interface(IPSocket)
    procedure AsyncSend(const Buffer: MemoryBuffer; const Handler: IOHandler); overload;
    procedure AsyncReceive(const Buffer: MemoryBuffer; const Handler: IOHandler); overload;
  end;

function NewTCPSocket(const Service: IOService): IPStreamSocket;

type
  IPAcceptor = interface
{$REGION 'Property accessors'}
    function GetService: IOService;
    function GetProtocol: IPProtocol;
    function GetLocalEndpoint: IPEndpoint;
    function GetIsOpen: boolean;
{$ENDREGION}

    procedure AsyncAccept(const Peer: IPSocket; const Handler: OpHandler);

    procedure Open(const Protocol: IPProtocol);

    procedure Bind(const Endpoint: IPEndpoint);

    procedure Listen(); overload;
    procedure Listen(const Backlog: integer); overload;

    procedure Close;

    property Service: IOService read GetService;
    property Protocol: IPProtocol read GetProtocol;
    property LocalEndpoint: IPEndpoint read GetLocalEndpoint;
    property IsOpen: boolean read GetIsOpen;
  end;

// non-open acceptor
function NewTCPAcceptor(const Service: IOService): IPAcceptor; overload;
// open acceptor on the given endpoint
function NewTCPAcceptor(const Service: IOService; const LocalEndpoint: IPEndpoint): IPAcceptor; overload;


type
  AsyncSocketStream = interface(AsyncStream)
    {$REGION 'Property accessors'}
    function GetSocket: IPStreamSocket;
    {$ENDREGION}

    property Socket: IPStreamSocket read GetSocket;
  end;

function NewAsyncSocketStream(const Socket: IPStreamSocket): AsyncSocketStream;

type
  // ErrorCode - error code from last attempt
  // Endpoint - the endpoint of the connection if successful, otherwise unspecified endpoint
  ConnectHandler = reference to procedure(const ErrorCode: IOErrorCode; const Endpoint: IPEndpoint);

  // Should return true if connection should be attempted to the endpoint
  // ErrorCode - error code from last attempt, initialized to Success
  // Endpoint - the endpoint to be used for the next connection attempt
  ConnectCondition = reference to function(const ErrorCode: IOErrorCode; const Endpoint: IPEndpoint): boolean;

procedure AsyncConnect(const Socket: IPSocket; const Endpoints: IPResolver.Results; const Handler: ConnectHandler); overload;
procedure AsyncConnect(const Socket: IPSocket; const Endpoints: TArray<IPEndpoint>; const Handler: ConnectHandler); overload;
procedure AsyncConnect(const Socket: IPSocket; const Endpoints: IPResolver.Results; const Condition: ConnectCondition; const Handler: ConnectHandler); overload;
procedure AsyncConnect(const Socket: IPSocket; const Endpoints: TArray<IPEndpoint>; const Condition: ConnectCondition; const Handler: ConnectHandler); overload;

implementation

uses
  System.RegularExpressions, IdWship6,
  System.SysUtils, System.Math, Winapi.Windows, AsyncIO.Detail,
  AsyncIO.Net.IP.Detail, AsyncIO.Net.IP.Detail.TCPImpl;

function NewAsyncSocketStream(const Socket: IPStreamSocket): AsyncSocketStream;
begin
  result := AsyncSocketStreamImpl.Create(Socket);
end;

{ IPv4Address }

class function IPv4Address.Any: IPv4Address;
begin
  result.FAddress := htonl(INADDR_ANY);
end;

class function IPv4Address.Broadcast: IPv4Address;
begin
  result.FAddress := htonl(INADDR_BROADCAST);
end;

class operator IPv4Address.Equal(const Addr1, Addr2: IPv4Address): boolean;
begin
  result := Addr1.FAddress = Addr2.FAddress;
end;

class operator IPv4Address.Explicit(const Addr: UInt32): IPv4Address;
begin
  result.FAddress := htonl(Addr);
end;

function IPv4Address.GetData: UInt32;
begin
  result := ntohl(FAddress);
end;

function IPv4Address.GetIsLoopback: boolean;
begin
  result := ((Data and $ff000000) = $7f000000);
end;

function IPv4Address.GetIsMulticast: boolean;
begin
  result := ((Data and $f0000000) = $e0000000);
end;

function IPv4Address.GetIsUnspecified: boolean;
begin
  result := (Data = 0);
end;

class operator IPv4Address.Implicit(const IPAddress: IPv4Address): string;
var
  sockAddr: TSockAddr;
  len: cardinal;
  res: WinsockResult;
begin
  FillChar(sockAddr, SizeOf(TSockAddr), 0);

  sockAddr.sin_family := AF_INET;
  sockAddr.sin_addr.S_addr := IPAddress.FAddress;

  SetLength(result, 32);
  len := Length(result);

  res := WSAAddressToString(@sockAddr, SizeOf(sockAddr), nil, @result[1], len);

  SetLength(result, len-1);
end;

class function IPv4Address.Loopback: IPv4Address;
begin
  result.FAddress := htonl(INADDR_LOOPBACK);
end;

class operator IPv4Address.NotEqual(const Addr1, Addr2: IPv4Address): boolean;
begin
  result := Addr1.FAddress <> Addr2.FAddress;
end;

class function IPv4Address.TryFromString(const s: string;
  out Addr: IPv4Address): boolean;
var
  sockAddr: TSockAddr;
  len: integer;
  r: integer;
  res: integer;
begin
  FillChar(sockAddr, SizeOf(TSockAddr), 0);

  sockAddr.sin_family := AF_INET;

  len := SizeOf(sockAddr);

  r := WSAStringToAddress(PChar(s), sockAddr.sin_family, nil, sockAddr, len);
  result := False;
  if (r = SOCKET_ERROR) then
  begin
    res := WSAGetLastError();
    if (res = WSAEINVAL) then
      exit
    else
      RaiseLastOSError(res);
  end
  else // r = 0
  begin
    result := True;
    Addr.FAddress := sockAddr.sin_addr.S_addr;
  end;
end;

{ IPv6Address }

class function IPv6Address.Any: IPv6Address;
begin
  FillChar(result, SizeOf(result), 0);
end;

class function IPv6Address.Create(const Addr: IPv6AddressBytes;
  const ScopeId: UInt32): IPv6Address;
begin
  result := IPv6Address(Addr);
  result.FScopeID := ScopeId;
end;

class operator IPv6Address.Equal(const Addr1, Addr2: IPv6Address): boolean;
begin
  result := CompareMem(@Addr1.FAddress, @Addr2.FAddress, 16);
  result := result and (Addr1.ScopeId = Addr2.ScopeId);
end;

class operator IPv6Address.Explicit(const Addr: IPv6AddressBytes): IPv6Address;
begin
  Move(Addr[0], result.FAddress[0], SizeOf(IPv6AddressBytes));
  result.FScopeID := 0;
end;

function IPv6Address.GetData: IPv6AddressBytes;
begin
  Move(FAddress[0], result[0], SizeOf(IPv6AddressBytes));
end;

function IPv6Address.GetIsLoopback: boolean;
begin
  result :=
    (FAddress[0] = 0) and (FAddress[1] = 0) and
    (FAddress[2] = 0) and (FAddress[3] = 0) and
    (FAddress[4] = 0) and (FAddress[5] = 0) and
    (FAddress[6] = 0) and (FAddress[7] = 0) and
    (FAddress[8] = 0) and (FAddress[9] = 0) and
    (FAddress[10] = 0) and (FAddress[11] = 0) and
    (FAddress[12] = 0) and (FAddress[13] = 0) and
    (FAddress[14] = 0) and (FAddress[15] = 1);
end;

function IPv6Address.GetIsMulticast: boolean;
begin
  result := FAddress[0] = $ff;
end;

function IPv6Address.GetIsUnspecified: boolean;
begin
  result :=
    (FAddress[0] = 0) and (FAddress[1] = 0) and
    (FAddress[2] = 0) and (FAddress[3] = 0) and
    (FAddress[4] = 0) and (FAddress[5] = 0) and
    (FAddress[6] = 0) and (FAddress[7] = 0) and
    (FAddress[8] = 0) and (FAddress[9] = 0) and
    (FAddress[10] = 0) and (FAddress[11] = 0) and
    (FAddress[12] = 0) and (FAddress[13] = 0) and
    (FAddress[14] = 0) and (FAddress[15] = 0);
end;

class operator IPv6Address.Implicit(const IPAddress: IPv6Address): string;
var
  sockAddr: TSockAddrIn6;
  len: cardinal;
  res: WinsockResult;
begin
  FillChar(sockAddr, SizeOf(TSockAddr), 0);

  sockAddr.sin6_family := AF_INET6;
  Move(IPAddress.FAddress, sockAddr.sin6_addr, 16);
  sockAddr.a.sin6_scope_id := IPAddress.FScopeID;

  SetLength(result, 256);
  len := Length(result);

  res := WSAAddressToString(@sockAddr, SizeOf(sockAddr), nil, @result[1], len);

  SetLength(result, len-1);
end;

class function IPv6Address.Loopback: IPv6Address;
begin
  result := IPv6Address.Any;
  result.FAddress[15] := 1;
end;

class operator IPv6Address.NotEqual(const Addr1, Addr2: IPv6Address): boolean;
begin
  result := not (Addr1 = Addr2);
end;

class function IPv6Address.TryFromString(const s: string;
  out Addr: IPv6Address): boolean;
type
  TSockAddrHack = record
    case integer of
      0: (in4: sockaddr_in);
      1: (in6: SOCKADDR_IN6_W2KSP1);
    end;
var
  sockAddr: TSockAddrHack;
  len: integer;
  res: integer;
begin
  FillChar(sockAddr, SizeOf(sockAddr), 0);

  sockAddr.in6.sin6_family := AF_INET6;

  len := SizeOf(sockAddr.in6);

  // stupid use of var parameter forces us to pass the in4 record part
  // length will be that of in6 record, so result is good
  res := WSAStringToAddress(PChar(s), sockAddr.in6.sin6_family, nil, sockAddr.in4, len);
  result := False;
  if (res = SOCKET_ERROR) then
  begin
    res := WSAGetLastError();
    if (res = WSAEINVAL) then
      exit
    else
      RaiseLastOSError(res);
  end
  else // res = 0
  begin
    result := True;
    Move(sockAddr.in6.sin6_addr.s6_bytes, Addr.FAddress, 16);
    Addr.FScopeID := sockAddr.in6.sin6_scope_id;
  end;
end;

{ IPAddress }

class operator IPAddress.Equal(const Addr1, Addr2: IPAddress): boolean;
begin
  result := False;
  if (Addr1.IsIPv4 and Addr2.IsIPv4) then
  begin
    result := Addr1.AsIPv4 = Addr2.AsIPv4
  end
  else if (Addr1.IsIPv6 and Addr2.IsIPv6) then
  begin
    result := Addr1.AsIPv6 = Addr2.AsIPv6;
  end;
end;

class operator IPAddress.Explicit(const s: string): IPAddress;
var
  addr4: IPv4Address;
  addr6: IPv6Address;
  res: boolean;
begin
  res := IPv6Address.TryFromString(s, addr6);
  if (res) then
  begin
    result.AsIPv6 := addr6;
    exit;
  end;

  res := IPv4Address.TryFromString(s, addr4);
  if (res) then
  begin
    result.AsIPv4 := addr4;
    exit;
  end;

  raise EArgumentException.Create('Invalid IP address: "' + s + '"');
end;

function IPAddress.GetAsIPv4: IPv4Address;
begin
  // TODO - handle mapped IPv4 addresses
  if (not IsIPv4) then
    raise EInvalidOpException.Create('Can''t convert IPv6 address to IPv4');
  result := FIPv4Addr;
end;

function IPAddress.GetAsIPv6: IPv6Address;
begin
  // TODO - handle mapped IPv4 addresses
  if (not IsIPv6) then
    raise EInvalidOpException.Create('Can''t convert IPv4 address to IPv6');
  result := FIPv6Addr;
end;

function IPAddress.GetIsLoopback: boolean;
begin
  case FAddressType of
    atV4: result := FIPv4Addr.IsLoopback;
    atV6: result := FIPv6Addr.IsLoopback;
  else
    raise ENotImplemented.Create('GetIsLoopback');
  end;
end;

function IPAddress.GetIsMulticast: boolean;
begin
  case FAddressType of
    atV4: result := FIPv4Addr.IsMulticast;
    atV6: result := FIPv6Addr.IsMulticast;
  else
    raise ENotImplemented.Create('GetIsMulticast');
  end;
end;

function IPAddress.GetIsUnspecified: boolean;
begin
  case FAddressType of
    atV4: result := FIPv4Addr.IsUnspecified;
    atV6: result := FIPv6Addr.IsUnspecified;
  else
    raise ENotImplemented.Create('GetIsUnspecified');
  end;
end;

function IPAddress.GetIsIPv4: boolean;
begin
  result := FAddressType = atV4;
end;

function IPAddress.GetIsIPv6: boolean;
begin
  result := FAddressType = atV6;
end;

class operator IPAddress.Implicit(const IPAddress: IPAddress): string;
begin
  case IPAddress.FAddressType of
    atV4: result := IPAddress.FIPv4Addr;
    atV6: result := IPAddress.FIPv6Addr;
  else
    raise ENotImplemented.Create('IPAddress to string');
  end;
end;

class operator IPAddress.NotEqual(const Addr1, Addr2: IPAddress): boolean;
begin
  result := not (Addr1 = Addr2);
end;

class operator IPAddress.Implicit(const IPAddress: IPv4Address): IPAddress;
begin
  result.AsIPv4 := IPAddress;
end;

class operator IPAddress.Implicit(const IPAddress: IPv6Address): IPAddress;
begin
  result.AsIPv6 := IPAddress;
end;

procedure IPAddress.SetAsIPv4(const Value: IPv4Address);
begin
  FAddressType := atV4;
  FIPv4Addr := Value;
end;

procedure IPAddress.SetAsIPv6(const Value: IPv6Address);
begin
  FAddressType := atV6;
  FIPv6Addr := Value;
end;

{ IPAddressFamily }

class operator IPAddressFamily.Equal(const Family1, Family2: IPAddressFamily): boolean;
begin
  result := Family1.FValue = Family2.FValue;
end;

class operator IPAddressFamily.Implicit(const Family: IPAddressFamily): UInt16;
begin
  result := Family.FValue;
end;

class operator IPAddressFamily.NotEqual(const Family1, Family2: IPAddressFamily): boolean;
begin
  result := Family1.FValue <> Family2.FValue;
end;

function IPAddressFamily.ToString: string;
begin
  case FValue of
    AF_UNSPEC: result := 'Unspecified';
    AF_INET: result := 'IPv4';
    AF_INET6: result := 'IPv6';
  else
    raise EInvalidArgument.CreateFmt('IPAddressFamily.ToString: Unknown address family %d', [FValue]);
  end;
end;

class function IPAddressFamily.Unspecified: IPAddressFamily;
begin
  result.FValue := AF_UNSPEC;
end;

class function IPAddressFamily.v4: IPAddressFamily;
begin
  result.FValue := AF_INET;
end;

class function IPAddressFamily.v6: IPAddressFamily;
begin
  result.FValue := AF_INET6;
end;

{ IPProtocol }

class operator IPProtocol.Equal(const Protocol1, Protocol2: IPProtocol): boolean;
begin
  result :=
    (Protocol1.Protocol = Protocol2.Protocol) and
    (Protocol1.SocketType = Protocol2.SocketType) and
    (Protocol1.Family = Protocol2.Family);
end;

class function IPProtocol.ICMP: ICMPProtocol;
begin
  // just a helper
end;

class operator IPProtocol.NotEqual(const Protocol1, Protocol2: IPProtocol): boolean;
begin
  result := not (Protocol1 = Protocol2);
end;

class function IPProtocol.TCP: TCPProtocol;
begin
  // just a helper
end;

function IPProtocol.ToString: string;
begin
  case FProtocol of
    IPPROTO_IP: result := 'IP';
    IPPROTO_ICMP: result := 'ICMP';
    IPPROTO_TCP: result := 'TCP';
    IPPROTO_UDP: result := 'UDP';
  else
    raise EInvalidArgument.CreateFmt('IPProtocol.ToString: Unknown protocol %d', [FProtocol]);
  end;
  result := result + '/' + Family.ToString;
end;

class function IPProtocol.UDP: UDPProtocol;
begin
  // just a helper
end;

class function IPProtocol.Unspecified: IPProtocol;
begin
  result.FFamily := IPAddressFamily.Unspecified;
  result.FSocketType := 0;
  result.FProtocol := IPPROTO_IP;
end;

class function IPProtocol.v4: IPProtocol;
begin
  result.FFamily := IPAddressFamily.v4;
  result.FSocketType := 0;
  result.FProtocol := IPPROTO_IP;
end;

class function IPProtocol.v6: IPProtocol;
begin
  result.FFamily := IPAddressFamily.v6;
  result.FSocketType := 0;
  result.FProtocol := IPPROTO_IP;
end;

{ IPProtocol.ICMPProtocol }

class function IPProtocol.ICMPProtocol.Unspecified: IPProtocol;
begin
  result.FFamily := IPAddressFamily.Unspecified;
  result.FSocketType := SOCK_RAW;
  result.FProtocol := IPPROTO_ICMP;
end;

class function IPProtocol.ICMPProtocol.v4: IPProtocol;
begin
  result.FFamily := IPAddressFamily.v4;
  result.FSocketType := SOCK_RAW;
  result.FProtocol := IPPROTO_ICMP;
end;

class function IPProtocol.ICMPProtocol.v6: IPProtocol;
begin
  result.FFamily := IPAddressFamily.v6;
  result.FSocketType := SOCK_RAW;
  result.FProtocol := IPPROTO_ICMP;
end;

{ IPProtocol.TCPProtocol }

class function IPProtocol.TCPProtocol.Unspecified: IPProtocol;
begin
  result.FFamily := IPAddressFamily.Unspecified;
  result.FSocketType := SOCK_STREAM;
  result.FProtocol := IPPROTO_TCP;
end;

class function IPProtocol.TCPProtocol.v4: IPProtocol;
begin
  result.FFamily := IPAddressFamily.v4;
  result.FSocketType := SOCK_STREAM;
  result.FProtocol := IPPROTO_TCP;
end;

class function IPProtocol.TCPProtocol.v6: IPProtocol;
begin
  result.FFamily := IPAddressFamily.v6;
  result.FSocketType := SOCK_STREAM;
  result.FProtocol := IPPROTO_TCP;
end;

{ IPProtocol.UDPProtocol }

class function IPProtocol.UDPProtocol.Unspecified: IPProtocol;
begin
  result.FFamily := IPAddressFamily.Unspecified;
  result.FSocketType := SOCK_DGRAM;
  result.FProtocol := IPPROTO_UDP;
end;

class function IPProtocol.UDPProtocol.v4: IPProtocol;
begin
  result.FFamily := IPAddressFamily.v4;
  result.FSocketType := SOCK_DGRAM;
  result.FProtocol := IPPROTO_UDP;
end;

class function IPProtocol.UDPProtocol.v6: IPProtocol;
begin
  result.FFamily := IPAddressFamily.v4;
  result.FSocketType := SOCK_DGRAM;
  result.FProtocol := IPPROTO_UDP;
end;

function Endpoint(): IPEndpoint;
begin
  result := IPEndpoint.Create(IPv4Address.Any, 0);
end;

function Endpoint(const Family: IPAddressFamily; PortNumber: UInt16): IPEndpoint;
begin
  result := IPEndpoint.Create(Family, PortNumber);
end;

function Endpoint(const Protocol: IPProtocol; PortNumber: UInt16): IPEndpoint;
begin
  result := IPEndpoint.Create(Protocol, PortNumber);
end;

function Endpoint(const Address: IPAddress; const PortNumber: UInt16): IPEndpoint;
begin
  result := IPEndpoint.Create(Address, PortNumber);
end;

{ IPEndpoint }

class function IPEndpoint.Create(const Family: IPAddressFamily;
  const Port: UInt16): IPEndpoint;
begin
  FillChar(result, SizeOf(result), 0);
  if (Family = IPAddressFamily.v4) then
  begin
    result.Fv4.sin_family := IPAddressFamily.v4;
    result.Fv4.sin_port := htons(Port);
    result.Fv4.sin_addr.S_addr := htonl(IPv4Address.Any.Data);
    result.FProtocol := IPProtocol.v4;
  end
  else
  begin
    result.Fv6.sin6_family := IPAddressFamily.v6;
    result.Fv6.sin6_port := htons(Port);
    // zeroed above so no need to do it again
    //result.Fv6.sin6_flowinfo := 0;
    //FillChar(result.Fv6.sin6_addr.s6_bytes[0], 16, 0);
    //result.Fv6.sin6_scope_id := 0;
    result.FProtocol := IPProtocol.v6;
  end;
end;

class function IPEndpoint.Create(const Address: IPAddress;
  const Port: UInt16): IPEndpoint;
begin
  FillChar(result, SizeOf(result), 0);
  result.Address := Address;
  result.Port := Port;
  if (Address.IsIPv4) then
  begin
    result.FProtocol := IPProtocol.v4;
  end
  else
  begin
    result.FProtocol := IPProtocol.v6;
  end;
end;

class function IPEndpoint.Create(const SocketAddress4: PSockAddrIn;
  const AddressLength: NativeUInt): IPEndpoint;
begin
  if (AddressLength < SizeOf(result.Fv4)) then
    raise EArgumentException.Create('IPEndpoint.Create: Unknown socket address type');

  FillChar(result, SizeOf(result), 0);
  Move(SocketAddress4^, result.Fv4, SizeOf(result.Fv4));
  result.FProtocol := IPProtocol.v4;
end;

class function IPEndpoint.Create(const SocketAddress6: PSockAddrIn6;
  const AddressLength: NativeUInt): IPEndpoint;
begin
  if (AddressLength < SizeOf(TSockAddrIn6)) then
    raise EArgumentException.Create('IPEndpoint.Create: Unknown socket address type');

  FillChar(result, SizeOf(result), 0);
  Move(SocketAddress6^, result.Fv6, Min(AddressLength, SizeOf(result.Fv6)));
  result.FProtocol := IPProtocol.v6;
end;

class function IPEndpoint.Create(const Protocol: IPProtocol;
  const Port: UInt16): IPEndpoint;
begin
  result := IPEndpoint.Create(Protocol.Family, Port);
  result.FProtocol := Protocol;
end;

class operator IPEndpoint.Equal(const Endpoint1, Endpoint2: IPEndpoint): boolean;
begin
  result :=
    (Endpoint1.Address = Endpoint2.Address) and
    (Endpoint1.Port = Endpoint2.Port);
end;

class function IPEndpoint.FromData(const Data;
  const DataLength: integer): IPEndpoint;
var
  family: integer;
begin
  if DataLength < SizeOf(result.Fv4) then
    raise EArgumentException.Create('IPEndpoint.FromData: Unknown socket address type');

  // if data is at least as larger as SockAddrIn, we'll just assume
  // it contains at least the family identifier
  family := PSockAddrIn(@Data)^.sin_family;
  case family of
    AF_INET: result := IPEndpoint.Create(PSockAddrIn(@Data), DataLength);
    AF_INET6: result := IPEndpoint.Create(PSockAddrIn6(@Data), DataLength);
  else
    raise EArgumentException.CreateFmt('IPEndpoint.FromData: Unknown address family %d', [family]);
  end;
end;

function IPEndpoint.GetAddress: IPAddress;
var
  bytesV6: IPv6Address.IPv6AddressBytes;
begin
  if (IsIPv4) then
  begin
    result := IPv4Address(ntohl(Fv4.sin_addr.S_addr));
  end
  else //if (IsIPv6) then
  begin
    Move(Fv6.sin6_addr.s6_bytes[0], bytesV6[0], 16);
    result := IPv6Address.Create(bytesV6, Fv6.sin6_scope_id);
  end;
end;

function IPEndpoint.GetData: Pointer;
begin
  if (IsIPv4) then
    result := @Fv4
  else //if (IsIPv6) then
    result := @Fv6;
end;

function IPEndpoint.GetDataLength: integer;
begin
  if (IsIPv4) then
    result := SizeOf(Fv4)
  else //if (IsIPv6) then
    result := SizeOf(Fv6);
end;

function IPEndpoint.GetIsIPv4: boolean;
begin
  result := FBase.ss_family = AF_INET;
end;

function IPEndpoint.GetIsIPv6: boolean;
begin
  result := FBase.ss_family = AF_INET6;
end;

function IPEndpoint.GetPort: UInt16;
begin
  if (IsIPv4) then
    result := ntohs(Fv4.sin_port)
  else //if (IsIPv6) then
    result := ntohs(Fv6.sin6_port);
end;

function IPEndpoint.GetProtocol: IPProtocol;
begin
  result := FProtocol;
end;

class operator IPEndpoint.Implicit(const Endpoint: IPEndpoint): string;
var
  s: string;
begin
  s := Endpoint.Address;

  if (Endpoint.IsIPv4) then
    result := s
  else //if (Endpoint.IsIPv6) then
    result := '[' + s + ']';

  result := result + ':' + IntToStr(Endpoint.Port);
end;

class operator IPEndpoint.NotEqual(const Endpoint1, Endpoint2: IPEndpoint): boolean;
begin
  result := not (Endpoint1 = Endpoint2);
end;

procedure IPEndpoint.SetAddress(const Value: IPAddress);
var
  addrV6: IPv6Address;
  bytesV6: IPv6Address.PIPv6AddressBytes;
begin
  if (Value.IsIPv4) then
  begin
    Fv4.sin_family := IPAddressFamily.v4;
    Fv4.sin_port := 0;
    Fv4.sin_addr.S_addr := htonl(Value.AsIPv4.Data);
  end
  else //if (Value.IsIPv6) then
  begin
    addrV6 := Value.AsIPv6;

    Fv6.sin6_family := IPAddressFamily.v6;
    Fv6.sin6_port := 0;
    Fv6.sin6_flowinfo := 0;

    bytesV6 := @Fv6.sin6_addr.s6_bytes;
    bytesV6^ := addrV6.Data;
    Fv6.sin6_scope_id := addrV6.ScopeId;
  end;
end;

procedure IPEndpoint.SetPort(const Value: UInt16);
begin
  if (IsIPv4) then
    Fv4.sin_port := htons(Value)
  else //if (IsIPv6) then
    Fv6.sin6_port := htons(Value);
end;

function Query(const Protocol: IPProtocol; const Host, Service: string; const Flags: ResolveFlags): IPResolver.Query;
begin
  result := IPResolver.Query.Create(Protocol, Host, Service, Flags);
end;

function Query(const Host, Service: string; const Flags: ResolveFlags): IPResolver.Query; inline;
begin
  result := IPResolver.Query.Create(IPProtocol.Unspecified, Host, Service, Flags);
end;

function ResolveFlagsToAIFlags(const Flags: ResolveFlags): integer;
begin
  result := 0;
  if (ResolvePassive in Flags) then
    result := result or AI_PASSIVE;
  if (ResolveCannonicalName in Flags) then
    result := result or AI_CANONNAME;
  if (ResolveNumericHost in Flags) then
    result := result or AI_NUMERICHOST;
  if (ResolveNumericService in Flags) then
    result := result or AI_NUMERICSERV;
  if (ResolveAllMatching in Flags) then
    result := result or AI_ALL;
  if (ResolveV4Mapped in Flags) then
    result := result or AI_V4MAPPED;
  if (ResolveAddressConfigured in Flags) then
    result := result or AI_ADDRCONFIG;
end;

{ IPResolver.Query }

class function IPResolver.Query.Create(const Protocol: IPProtocol; const Host,
  Service: string; const Flags: ResolveFlags): IPResolver.Query;
begin
  result.FHostName := Host;
  result.FServiceName := Service;
  FillChar(result.FHints, SizeOf(result.FHints), 0);
  result.FHints.ai_flags := ResolveFlagsToAIFlags(Flags);
  result.FHints.ai_family := Protocol.Family;
  result.FHints.ai_socktype := Protocol.SocketType;
  result.FHints.ai_protocol := Protocol.Protocol;
end;

function IPResolver.Query.GetHints: PAddressInfo;
begin
  result := @FHints;
end;

{ IPResolver.Entry }

class function IPResolver.Entry.Create(const Endpoint: IPEndpoint; const Host,
  Service: string): Entry;
begin
  result.FEndpoint := Endpoint;
  result.FHostname := Host;
  result.FServiceName := Service;
end;

{ IPResolver.Results.TResultsEnumerator }

constructor IPResolver.Results.TResultsEnumerator.Create(
  const Results: TArray<Entry>);
begin
  inherited Create;

  FResults := Results;
  FIndex := -1;
end;

function IPResolver.Results.TResultsEnumerator.GetCurrent: Entry;
begin
  result := FResults[FIndex];
end;

function IPResolver.Results.TResultsEnumerator.MoveNext: boolean;
var
  i: integer;
begin
  i := FIndex + 1;
  result := (i < Length(FResults));
  if not result then
    exit;
  FIndex := i;
end;

{ IPResolver.Results }

class function IPResolver.Results.Create(
  const Host, Service: string;
  const AddressInfo: PAddressInfo): Results;
var
  addr: PAddressInfo;
  i: integer;
begin
  // lets count
  i := 0;
  addr := AddressInfo;
  while (addr <> nil) do
  begin
    i := i + 1;
    addr := PAddressInfo(addr.ai_next);
  end;

  SetLength(result.FResults, i);

  if (i <= 0) then
    exit;

  // this time for reals
  i := 0;
  addr := AddressInfo;
  while (addr <> nil) do
  begin
    if (addr^.ai_family = AF_INET) then
    begin
      result.FResults[i] := Entry.Create(
        IPEndpoint.Create(PSockAddrIn(addr^.ai_addr), addr^.ai_addrlen),
        Host, Service);
      i := i + 1;
    end
    else if (addr^.ai_family = AF_INET6) then
    begin
      result.FResults[i] := Entry.Create(
        IPEndpoint.Create(PSockAddrIn6(addr^.ai_addr), addr^.ai_addrlen),
        Host, Service);
      i := i + 1;
    end;
    // ignore the others families

    addr := PAddressInfo(addr.ai_next);
  end;

  // possibly down-size
  SetLength(result.FResults, i);
end;

function IPResolver.Results.GetEndpoints: TArray<IPEndpoint>;
var
  i: integer;
begin
  SetLength(result, Length(FResults));

  for i := 0 to High(FResults) do
  begin
    result[i] := FResults[i].Endpoint;
  end;
end;

function IPResolver.Results.GetEnumerator: IPResolver.Results.TResultsEnumerator;
begin
  result := TResultsEnumerator.Create(FResults);
end;

function IPResolver.Results.ToArray: TArray<Entry>;
begin
  result := Copy(FResults);
end;

{ IPResolver }

class function IPResolver.Resolve(const ResolveQuery: Query): Results;
type
  // workaround for broken declaration
  LPFN_GETADDRINFOEX = function(pName : PWideChar; pServiceName : PWideChar;
    const dwNameSpace: UInt32; lpNspId : LPGUID; hints : PAddressInfo;
    var ppResult : PAddressInfo; timeout : Ptimeval; lpOverlapped : LPWSAOVERLAPPED;
    lpCompletionRoutine : LPLOOKUPSERVICE_COMPLETION_ROUTINE;
    lpNameHandle : PHandle) : Integer; stdcall;
var
  res: GetAddrResult;
  addr: PAddressInfo;
begin
  res := LPFN_GETADDRINFOEX(GetAddrInfoEx)(
    PChar(ResolveQuery.HostName),
    PChar(ResolveQuery.ServiceName),
    NS_ALL,
    nil,
    ResolveQuery.Hints,
    addr,
    nil,
    nil,
    nil,
    nil);

  try
    result := Results.Create(ResolveQuery.HostName, ResolveQuery.ServiceName, addr);
  finally
//    FreeAddrInfoEx(PADDRINFOEXA(addr));
    FreeAddrInfoEx(addr);
  end;
end;

function NewTCPSocket(const Service: IOService): IPStreamSocket;
begin
  result := TTCPSocketImpl.Create(Service);
end;

function NewTCPAcceptor(const Service: IOService): IPAcceptor; overload;
begin
  result := TTCPAcceptorImpl.Create(Service);
end;

function NewTCPAcceptor(const Service: IOService; const LocalEndpoint: IPEndpoint): IPAcceptor; overload;
begin
  result := NewTCPAcceptor(Service);
  result.Bind(LocalEndpoint);
  result.Listen();
end;

procedure AsyncConnect(const Socket: IPSocket; const Endpoints: IPResolver.Results; const Handler: ConnectHandler);
begin
  AsyncConnect(Socket, Endpoints.GetEndpoints(), Handler);
end;

procedure AsyncConnect(const Socket: IPSocket; const Endpoints: TArray<IPEndpoint>; const Handler: ConnectHandler);
begin
  AsyncConnect(Socket, Endpoints, DefaultConnectCondition, Handler);
end;

procedure AsyncConnect(const Socket: IPSocket; const Endpoints: IPResolver.Results; const Condition: ConnectCondition; const Handler: ConnectHandler);
begin
  AsyncConnect(Socket, Endpoints.GetEndpoints(), Condition, Handler);
end;

procedure AsyncConnect(const Socket: IPSocket; const Endpoints: TArray<IPEndpoint>; const Condition: ConnectCondition; const Handler: ConnectHandler);
var
  connectOp: OpHandler;
  idx: integer;
begin
  if (Length(Endpoints) <= 0) then
    raise EArgumentException.Create('AsyncConnect: No endpoints');

  idx := -1;

  connectOp :=
    procedure(const ErrorCode: IOErrorCode)
    var
      start: boolean;
      useEndpoint: boolean;
    begin
      start := (idx < 0);

      if (not start) and (ErrorCode = ErrorCode.Success) then
      begin
        Handler(ErrorCode, Endpoints[idx]);
        connectOp := nil; // release handler
        exit;
      end;

      while True do
      begin
        idx := idx + 1;
        if (idx >= Length(Endpoints)) then
        begin
          Handler(ErrorCode, Endpoint());
          connectOp := nil; // release handler
          exit;
        end;

        useEndpoint := Condition(ErrorCode, Endpoints[idx]);

        if (useEndpoint) then
          break;
      end;

      Socket.Close;
      Socket.AsyncConnect(Endpoints[idx], connectOp);
    end;

  connectOp(IOErrorCode.Success);
end;

initialization
  IdWship6.InitLibrary;

end.
