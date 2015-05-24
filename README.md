# AsyncIO

Delphi.AsyncIO library, inspired by Boost.ASIO.

Under development! Currently mostly for fun.

Uses IOCP under the hood.

## TPC echo client example

Library is under development, but this should show the direction.

```delphi
type
  EchoClient = class
  private
    FRequest: string;
    FData: TBytes;
    FSocket: IPStreamSocket;
    FStream: AsyncSocketStream;

    procedure HandleConnect(const ErrorCode: IOErrorCode);
    procedure HandleWrite(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure HandleRead(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
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
  qry := Query(IPProtocol.TCPProtocol.v6, 'localhost', '7', [ResolveAllMatching]);
  res := IPResolver.Resolve(qry);

  ip := res[0]; // TODO - make connect take resolver result set, connect until success

  ios := nil;
  client := nil;
  try
    ios := NewIOService;

    WriteLn('Connecting to ' + ip.Endpoint);

    client := EchoClient.Create(ios, ip.Endpoint, 'Hello Internet!');

    r := ios.Run;

    WriteLn;
    WriteLn('Done');
  finally
    client.Free;
  end;
end;

{ EchoClient }

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

procedure EchoClient.HandleConnect(const ErrorCode: IOErrorCode);
begin
  if (not ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  WriteLn('Client connected');
  WriteLn('Local endpoint: ' + FSocket.LocalEndpoint);
  WriteLn('Remote endpoint: ' + FSocket.RemoteEndpoint);
  WriteLn('Sending echo request');

  // encode echo request
  FData := TEncoding.Unicode.GetBytes(FRequest);

  // use a socket stream for the actual read/write operations
  FStream := NewAsyncSocketStream(FSocket);

  AsyncWrite(FStream, FData, TransferAll(), HandleWrite);
end;

procedure EchoClient.HandleWrite(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
begin
  if (not ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  // half close
  FSocket.Shutdown(SocketShutdownWrite);

  // zero our response buffer so we know we got the right stuff back
  FillChar(FData[0], Length(FData), 0);

  AsyncRead(FStream, FResponseData, TransferAtLeast(Length(FData)), HandleRead);
end;

procedure EchoClient.HandleRead(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
var
  s: string;
  responseMatches: boolean;
begin
  if (not ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  // decode echo response
  s := TEncoding.Unicode.GetString(FData, 0, BytesTransferred);

  WriteLn('Echo reply: "' + s + '"');

  FSocket.Close();

  // stopping to be improved
  FStream.Socket.Service.Stop;
end;
```

Output from the above program:
```
Connecting to [::1]:7
Client connected
Local endpoint: [::1]:61659
Remote endpoint: [::1]:7
Sending echo request
Echo reply: "Hello Internet!"
```

