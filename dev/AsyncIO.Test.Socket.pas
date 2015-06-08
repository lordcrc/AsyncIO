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
    FRequest: string;
    FRequestData: TBytes;
    FResponseData: TBytes;
    FSocket: IPStreamSocket;
    FStream: AsyncSocketStream;

    procedure HandleConnect(const ErrorCode: IOErrorCode);
    procedure HandleRead(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure HandleWrite(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Service: IOService;
      const ServerEndpoint: IPEndpoint;
      const Request: string);
  end;

procedure TestEcho;
var
  qry: IPResolver.Query;
  res: IPResolver.Results;
  ip: IPResolver.Entry;
  ios: IOService;
  client: EchoClient;
  r: Int64;
begin
  qry := Query(IPProtocol.TCP.v6, 'localhost', '7', [ResolveAllMatching]);
  res := IPResolver.Resolve(qry);

  for ip in res do
    // TODO - make connect take resolver result set, connect until success
    break;

  ios := nil;
  client := nil;
  try
    ios := NewIOService;

    WriteLn('Connecting to ' + ip.Endpoint);

    client := EchoClient.Create(ios, ip.Endpoint, 'Hello Internet!');

    r := ios.Run;

    WriteLn;
    WriteLn('Done');
    WriteLn(Format('%d handlers executed', [r]));
  finally
    client.Free;
  end;
end;

type
  EchoServer = class
  private
    FData: TBytes;
    FAcceptor: IPAcceptor;
    FPeerSocket: IPStreamSocket;
    FStream: AsyncSocketStream;

    procedure HandleAccept(const ErrorCode: IOErrorCode);
    procedure HandleRead(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure HandleWrite(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Service: IOService; const LocalEndpoint: IPEndpoint);
  end;

procedure TestEchoServer;
var
  ip: IPEndpoint;
  ios: IOService;
  server: EchoServer;
  r: Int64;
begin
  ios := nil;
  server := nil;
  try
    ip := Endpoint(IPAddressFamily.v6, 7);

    ios := NewIOService;

    WriteLn('Listening on ' + ip);

    server := EchoServer.Create(ios, ip);

    r := ios.Run;

    WriteLn;
    WriteLn('Done');
    WriteLn(Format('%d handlers executed', [r]));
  finally
    server.Free;
  end;
end;

procedure RunSocketTest;
begin
//  TestAddress;
//  TestEndpoint;
//  TestResolve;

//  TestEcho;

  TestEchoServer;
end;

{ EchoClient }

procedure EchoClient.HandleConnect(const ErrorCode: IOErrorCode);
begin
  if (ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  WriteLn('Client connected');
  WriteLn('Local endpoint: ' + FSocket.LocalEndpoint);
  WriteLn('Remote endpoint: ' + FSocket.RemoteEndpoint);
  WriteLn('Sending echo request');

  FRequestData := TEncoding.Unicode.GetBytes(FRequest);

  // we'll use a socket stream for the actual read/write operations
  FStream := NewAsyncSocketStream(FSocket);

  AsyncWrite(FStream, FRequestData, TransferAll(), HandleWrite);
end;

constructor EchoClient.Create(
  const Service: IOService;
  const ServerEndpoint: IPEndpoint;
  const Request: string);
begin
  inherited Create;

  FRequest := Request;
  FSocket := NewTCPSocket(Service);

  FSocket.AsyncConnect(ServerEndpoint, HandleConnect);
end;

procedure EchoClient.HandleRead(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
var
  s: string;
  responseMatches: boolean;
begin
  if (ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  s := TEncoding.Unicode.GetString(FResponseData, 0, BytesTransferred);

  WriteLn('Echo reply: "' + s + '"');

  // compare request and reply
  responseMatches := (Length(FRequestData) = Length(FResponseData)) and
    CompareMem(@FRequestData[0], @FResponseData[0], Length(FRequestData));

  if (responseMatches) then
    WriteLn('Response matches, yay')
  else
    WriteLn('RESPONSE DOES NOT MATCH');

  FSocket.Close();

  // and we're done...
  FStream.Socket.Service.Stop;
end;

procedure EchoClient.HandleWrite(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
begin
  if (ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  // half close
  FSocket.Shutdown(SocketShutdownWrite);

  // zero our response buffer so we know we got the right stuff back
  FResponseData := nil;
  SetLength(FResponseData, Length(FRequestData));

  AsyncRead(FStream, FResponseData, TransferAtLeast(Length(FResponseData)), HandleRead);
end;

{ EchoServer }

constructor EchoServer.Create(const Service: IOService; const LocalEndpoint: IPEndpoint);
begin
  inherited Create;

  FAcceptor := NewTCPAcceptor(Service, LocalEndpoint);
  FPeerSocket := NewTCPSocket(Service);

  FAcceptor.AsyncAccept(FPeerSocket, HandleAccept);
end;

procedure EchoServer.HandleAccept(const ErrorCode: IOErrorCode);
begin
  if (ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  WriteLn('Client connected');
  WriteLn('Local endpoint: ' + FPeerSocket.LocalEndpoint);
  WriteLn('Remote endpoint: ' + FPeerSocket.RemoteEndpoint);
  WriteLn('Receiving echo request');

  FData := nil;
  SetLength(FData, 512);

  FPeerSocket.AsyncReceive(FData, HandleRead);
end;

procedure EchoServer.HandleRead(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
begin
  if (ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  WriteLn(Format('Received %d bytes', [BytesTransferred]));

  SetLength(FData, BytesTransferred);

  // use stream to write result so we reply it all
  FStream := NewAsyncSocketStream(FPeerSocket);

  AsyncWrite(FStream, FData, TransferAll(), HandleWrite);
end;

procedure EchoServer.HandleWrite(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
begin
  if (ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  WriteLn(Format('Sent %d bytes', [BytesTransferred]));
  WriteLn('Shutting down...');

  // deviate from echo protocol, shut down once write completes
  FPeerSocket.Shutdown();
  FPeerSocket.Close();

  FPeerSocket.Service.Stop;
end;

end.
