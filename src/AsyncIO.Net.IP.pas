unit AsyncIO.Net.IP;

interface

uses
  IdWinsock2;

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

    class function TryStrToIPv4Address(const s: string; out Addr: IPv4Address): boolean; static;

    property IsLoopback: boolean read GetIsLoopback;
    property IsMulticast: boolean read GetIsMulticast;
    property IsUnspecified: boolean read GetIsUnspecified;

    property Data: UInt32 read GetData;
  end;

  IPv6Address = record
  public
    type IPv6AddressBytes = array[0..15] of UInt8;
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

    class function TryStrToIPv6Address(const s: string; out Addr: IPv6Address): boolean; static;

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
    class operator Equal(const A, B: IPAddressFamily): boolean; inline;
    class operator NotEqual(const A, B: IPAddressFamily): boolean; inline;

    class function v4: IPAddressFamily; static;
    class function v6: IPAddressFamily; static;
  end;

  IPEndpoint = record
  strict private
    function GetAddress: IPAddress;
    procedure SetAddress(const Value: IPAddress);
    function GetPort: UInt16;
    procedure SetPort(const Value: UInt16);
    function GetIsIPv4: boolean;
    function GetIsIPv6: boolean;
  private
    class function Create(const Family: IPAddressFamily; const Port: UInt16): IPEndpoint; overload; static;
    class function Create(const Address: IPAddress; const Port: UInt16): IPEndpoint; overload; static;
  public
    class operator Implicit(const Endpoint: IPEndpoint): string;

    property Address: IPAddress read GetAddress write SetAddress;
    property Port: UInt16 read GetPort write SetPort;

    property IsIPv4: boolean read GetIsIPv4;
    property IsIPv6: boolean read GetIsIPv6;
  strict private
    case integer of
      0: (FBase: TSockAddrStorage);
      1: (Fv4: sockaddr_in);
      2: (Fv6: SOCKADDR_IN6_W2KSP1);
  end;


  ResolverQueryFlag = (
    ResolverQueryPassive,
    ResolverQueryCannonicalName,
    ResolverQueryNumericHost,
    ResolverQueryNumericService,
    ResolverQueryAllMatching,
    ResolverQueryV4Mapped,
    ResolverQueryAddressConfigured);
  ResolverQueryFlags = set of ResolverQueryFlag;

  ResolverEntry = record
  strict private
    FHostname: string;
    FServiceName: string;
  public

    property HostName: string read FHostname;
    property ServiceName: string read FServicename;
  end;

  Resolver = record

  end;

  ResolverQuery = record

  end;

function Endpoint(): IPEndpoint; overload; inline;
function Endpoint(const Family: IPAddressFamily; PortNumber: UInt16): IPEndpoint; overload; inline;
function Endpoint(const Address: IPAddress; const PortNumber: UInt16): IPEndpoint; overload; inline;

implementation

uses
  System.RegularExpressions, AsyncIO.ErrorCodes, IdWship6,
  System.SysUtils;

{ IPv4Address }

class function IPv4Address.Any: IPv4Address;
begin
  result := IPv4Address(INADDR_ANY);
end;

class function IPv4Address.Broadcast: IPv4Address;
begin
  result := IPv4Address(INADDR_BROADCAST);
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
  result := ((FAddress and $ff000000) = $7f000000);
end;

function IPv4Address.GetIsMulticast: boolean;
begin
  result := ((FAddress and $f0000000) = $e0000000);
end;

function IPv4Address.GetIsUnspecified: boolean;
begin
  result := (FAddress = 0);
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

  SetLength(result, 256);
  len := Length(result);

  res := WSAAddressToString(@sockAddr, SizeOf(sockAddr), nil, @result[1], len);

  SetLength(result, len-1);
end;

class function IPv4Address.Loopback: IPv4Address;
begin
  result := IPv4Address(INADDR_LOOPBACK);
end;

class function IPv4Address.TryStrToIPv4Address(const s: string;
  out Addr: IPv4Address): boolean;
var
  sockAddr: TSockAddr;
  len: integer;
  r: integer;
  res: WinsockResult;
begin
  FillChar(sockAddr, SizeOf(TSockAddr), 0);

  sockAddr.sin_family := AF_INET;

  len := SizeOf(sockAddr);

  r := WSAStringToAddress(PChar(s), sockAddr.sin_family, nil, sockAddr, len);
  result := False;
  if (r = WSAEINVAL) then
    exit
  else if (r <> 0) then
    res := r
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

class function IPv6Address.TryStrToIPv6Address(const s: string;
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
  FillChar(sockAddr, SizeOf(TSockAddr), 0);

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

class operator IPAddress.Explicit(const s: string): IPAddress;
var
  addr4: IPv4Address;
  addr6: IPv6Address;
  res: boolean;
begin
  res := IPv6Address.TryStrToIPv6Address(s, addr6);
  if (res) then
  begin
    result.AsIPv6 := addr6;
    exit;
  end;

  res := IPv4Address.TryStrToIPv4Address(s, addr4);
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
    raise ENotImplemented.Create('Address to string');
  end;
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

class operator IPAddressFamily.Equal(const A, B: IPAddressFamily): boolean;
begin
  result := A.FValue = B.FValue;
end;

class operator IPAddressFamily.Implicit(const Family: IPAddressFamily): UInt16;
begin
  result := Family.FValue;
end;

class operator IPAddressFamily.NotEqual(const A, B: IPAddressFamily): boolean;
begin
  result := A.FValue <> B.FValue;
end;

class function IPAddressFamily.v4: IPAddressFamily;
begin
  result.FValue := AF_INET;
end;

class function IPAddressFamily.v6: IPAddressFamily;
begin
  result.FValue := AF_INET6;
end;

function Endpoint(): IPEndpoint;
begin
  result := IPEndpoint.Create(IPv4Address.Any, 0);
end;

function Endpoint(const Family: IPAddressFamily; PortNumber: UInt16): IPEndpoint;
begin
  result := IPEndpoint.Create(Family, PortNumber);
end;

function Endpoint(const Address: IPAddress; const PortNumber: UInt16): IPEndpoint;
begin
  result := IPEndpoint.Create(Address, PortNumber);
end;

{ IPEndpoint }

class function IPEndpoint.Create(const Family: IPAddressFamily;
  const Port: UInt16): IPEndpoint;
begin
  if (Family = IPAddressFamily.v4) then
  begin
    result.Fv4.sin_family := IPAddressFamily.v4;
    result.Fv4.sin_port := htons(Port);
    result.Fv4.sin_addr.S_addr := htonl(IPv4Address.Any.Data);
  end
  else
  begin
    result.Fv6.sin6_family := IPAddressFamily.v6;
    result.Fv6.sin6_port := htons(Port);
    result.Fv6.sin6_flowinfo := 0;
    FillChar(result.Fv6.sin6_addr.s6_bytes[0], 16, 0);
    result.Fv6.sin6_scope_id := 0;
  end;
end;

class function IPEndpoint.Create(const Address: IPAddress;
  const Port: UInt16): IPEndpoint;
begin
  result.Address := Address;
  result.Port := Port;
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

procedure IPEndpoint.SetAddress(const Value: IPAddress);
var
  addrV6: IPv6Address;
  bytesV6: IPv6Address.IPv6AddressBytes;
begin
  if (Value.IsIPv4) then
  begin
    Fv4.sin_family := IPAddressFamily.v4;
    Fv4.sin_port := 0;
    Fv4.sin_addr.S_addr := htonl(Value.AsIPv4.Data);
  end
  else //if (Value.IsIPv6) then
  begin
    Fv6.sin6_family := IPAddressFamily.v6;
    Fv6.sin6_port := 0;
    Fv6.sin6_flowinfo := 0;
    addrV6 := Value.AsIPv6;
    bytesV6 := addrV6.Data;
    Move(bytesV6[0], Fv6.sin6_addr.s6_bytes[0], 16);
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

initialization
  IdWship6.InitLibrary;

end.
