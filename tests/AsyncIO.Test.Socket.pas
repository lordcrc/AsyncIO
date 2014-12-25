unit AsyncIO.Test.Socket;

interface

procedure RunSocketTest;

implementation

uses
  System.SysUtils, System.DateUtils, AsyncIO, AsyncIO.ErrorCodes, AsyncIO.Net.IP,
  System.Math;

procedure TestAddress;
var
  addr4: IPv4Address;
  addr6: IPv6Address;

  addr: IPAddress;
begin
  addr4 := IPv4Address.Loopback;
  addr := addr4;
  WriteLn('IPv4 loopback: ' + addr);

  addr6 := IPv6Address.Loopback;
  addr := addr6;
  WriteLn('IPv6 loopback: ' + addr);

  addr := IPAddress('192.168.42.2');
  WriteLn('IP address: ' + addr);
  WriteLn('   is IPv4: ' + BoolToStr(addr.IsIPv4, True));
  WriteLn('   is IPv6: ' + BoolToStr(addr.IsIPv6, True));

  addr := IPAddress('abcd::1%42');
  WriteLn('IP address: ' + addr);
  WriteLn('   is IPv4: ' + BoolToStr(addr.IsIPv4, True));
  WriteLn('   is IPv6: ' + BoolToStr(addr.IsIPv6, True));
  WriteLn(' has scope: ' + IntToStr(addr.AsIPv6.ScopeID));

  WriteLn;
end;

procedure TestEndpoint;
var
  endp: IPEndpoint;
begin
  endp := Endpoint(IPAddressFamily.v6, 1234);
  WriteLn('IPv6 listening endpoint: ' + endp);

  endp := Endpoint(IPAddress('192.168.42.1'), 9876);
  WriteLn('IPv4 connection endpoint: ' + endp);

  endp := Endpoint(IPAddress('1234:abcd::1'), 0);
  WriteLn('IPv6 connection endpoint: ' + endp);

  WriteLn;
end;

procedure TestResolve;
var
  qry: IPResolver.Query;
  res: IPResolver.Results;
  ip: IPResolver.Entry;
begin
  qry := Query(IPProtocol.TCPProtocol.v6, 'google.com', '80', [ResolveAllMatching]);
  res := IPResolver.Resolve(qry);

  WriteLn('Resolved ' + qry.HostName + ':' + qry.ServiceName + ' as');
  for ip in res do
  begin
    WriteLn('  ' + ip.Endpoint.Address);
  end;
end;

type
  EchoClient = class
  private
    FRequestData: string;
    FResponse: TBytes;
    FStream: AsyncSocketStream;

    procedure ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure WriteHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Socket: IPStreamSocket; const RequestData: string);
    destructor Destroy; override;
  end;

procedure TestEcho;
var
  qry: IPResolver.Query;
  res: IPResolver.Results;
  ip: IPResolver.Entry;
  sock: IPStreamSocket;
  ios: IOService;
  client: EchoClient;
  r: Int64;
begin
  qry := Query(IPProtocol.TCPProtocol.v4, 'localhost', '7', [ResolveAllMatching]);
  res := IPResolver.Resolve(qry);

//  WriteLn('Resolved ' + qry.HostName + ':' + qry.ServiceName + ' as');
  for ip in res do
    // TODO - fix this crap, need way to get first result
    break;

  ios := nil;
  client := nil;
  try
    ios := IOService.Create;
    ios.Initialize();

    WriteLn('Connecting to ' + ip.Endpoint);

    sock := TCPSocket(ios);
    sock.Connect(ip.Endpoint);

    WriteLn('Sending echo request');
    client := EchoClient.Create(sock, 'Hello Internet!');

    r := ios.Run;

    WriteLn;
    WriteLn(Format('%d handlers executed', [r]));
  finally
    client.Free;
    ios.Free;
  end;
end;

procedure RunSocketTest;
begin
//  TestAddress;
//  TestEndpoint;
//  TestResolve;

  TestEcho;
end;

{ EchoClient }

constructor EchoClient.Create(const Socket: IPStreamSocket;
  const RequestData: string);
var
  data: TBytes;
  datalen: integer;
begin
  inherited Create;

  FRequestData := RequestData;
  FStream := AsyncSocketStream.Create(Socket);

  data := TEncoding.Unicode.GetBytes(FRequestData);
  datalen := Length(data);

  SetLength(FResponse, datalen);

  // queue write to start things
  AsyncWrite(FStream, data, TransferAll(), WriteHandler);
end;

destructor EchoClient.Destroy;
begin
  FStream.Free;

  inherited;
end;

procedure EchoClient.ReadHandler(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
var
  s: string;
begin
  if (not ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  s := TEncoding.Unicode.GetString(FResponse, 0, BytesTransferred);

  WriteLn('Echo reply: "' + s + '"');

  FStream.Socket.Service.Stop;
end;

procedure EchoClient.WriteHandler(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
begin
  if (not ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  AsyncRead(FStream, FResponse, TransferAtLeast(Length(FResponse)), ReadHandler);
end;

end.
