unit AsyncHttpClient.Impl;

interface

uses
  System.SysUtils, AsyncIO, AsyncIO.ErrorCodes, AsyncIO.Net.IP;

type
  HttpClientProgressHandler = reference to procedure(const Status: string);
  HttpClientResponseHandler = reference to procedure(const Headers: string; const ResponseData: TBytes);

  AsyncHttpCli = interface
    {$REGION 'Property accessors'}
    function GetService: IOService;
    function GetProgressHandler: HttpClientProgressHandler;

    procedure SetProgressHandler(const Value: HttpClientProgressHandler);
    {$ENDREGION}

    procedure Get(const URL: string);

    property Service: IOService read GetService;
    property ProgressHandler: HttpClientProgressHandler read GetProgressHandler write SetProgressHandler;
  end;

function NewAsyncHttpClient(const Service: IOService; const ResponseHandler: HttpClientResponseHandler): AsyncHttpCli;

implementation

uses
  AsyncIO.StreamReader;

type
  AsyncHttpCliImpl = class(TInterfacedObject, AsyncHttpCli)
  private
    FService: IOService;
    FProgressHandler: HttpClientProgressHandler;
    FResponseHandler: HttpClientResponseHandler;
    FHost: string;
    FPath: string;
    FPort: integer;
    FUsername: string;
    FPassword: string;
    FSocket: IPStreamSocket;
    FStream: AsyncSocketStream;
    FResponseBuffer: StreamBuffer;

    function ConnectCondition(const ErrorCode: IOErrorCode; const Endpoint: IPEndpoint): boolean;
    procedure ConnectHandler(const ErrorCode: IOErrorCode; const Endpoint: IPEndpoint);
    procedure ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure WriteHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);

    procedure ProgressUpdate(const Status: string);
    procedure HandleResponse(const Headers: string; const ResponseData: TBytes);

    procedure ParseURL(const URL: string);
  public
    constructor Create(const Service: IOService; const ResponseHandler: HttpClientResponseHandler);

    function GetService: IOService;

    procedure Get(const URL: string);
    function GetProgressHandler: HttpClientProgressHandler;

    procedure SetProgressHandler(const Value: HttpClientProgressHandler);

    property Service: IOService read FService;
    property Host: string read FHost;
    property Port: integer read FPort;
    property Username: string read FUsername;
    property Password: string read FPassword;
  end;

function NewAsyncHttpClient(const Service: IOService; const ResponseHandler: HttpClientResponseHandler): AsyncHttpCli;
begin
  result := AsyncHttpCliImpl.Create(Service, ResponseHandler);
end;

{ AsyncHttpClientImpl }

function AsyncHttpCliImpl.ConnectCondition(const ErrorCode: IOErrorCode;
  const Endpoint: IPEndpoint): boolean;
begin
  if (ErrorCode) then
  begin
    ProgressUpdate('Connection attempt failed: ' + ErrorCode.Message);
  end;

  ProgressUpdate('Connecting to ' + Endpoint);

  // we use this just for status updates
  result := True;
end;

procedure AsyncHttpCliImpl.ConnectHandler(const ErrorCode: IOErrorCode;
  const Endpoint: IPEndpoint);
var
  request: string;
  requestData: TBytes;
begin
  if (ErrorCode) then
  begin
    ProgressUpdate('Connection attempt failed: ' + ErrorCode.Message);
    ProgressUpdate('Unable to connect to host');
    Service.Stop; // TODO - better stopping
    exit;
  end;

  ProgressUpdate('Connected');
  ProgressUpdate('Local endpoint: ' + FSocket.LocalEndpoint);
  ProgressUpdate('Remote endpoint: ' + FSocket.RemoteEndpoint);
  ProgressUpdate('Sending GET request');

  FStream := NewAsyncSocketStream(FSocket);

  // Form the request. We specify the "Connection: close" header so that the
  // server will close the socket after transmitting the response. This will
  // allow us to treat all data up until the EOF as the content.
  request :=
      'GET ' + FPath + ' HTTP/1.0' + #13#10
    + 'Host: ' + FHost + #13#10
    + 'Accept: */*' + #13#10
    + 'Connection: close' + #13#10
    + #13#10;

  requestData := TEncoding.ASCII.GetBytes(request);

  // ok, we're connected, so send the GET request
  AsyncWrite(FStream, requestData, TransferAll(), WriteHandler);
end;

constructor AsyncHttpCliImpl.Create(const Service: IOService;
  const ResponseHandler: HttpClientResponseHandler);
begin
  inherited Create;

  FService := Service;
  FResponseHandler := ResponseHandler;
end;

procedure AsyncHttpCliImpl.Get(const URL: string);
var
  qry: IPResolver.Query;
  res: IPResolver.Results;
begin
  ParseURL(URL);

  FSocket := NewTCPSocket(Service);

  qry := Query(IPProtocol.TCP.Unspecified, Host, IntToStr(Port));

  ProgressUpdate('Resolving "' + Host + '"');

  // TODO - implement async resolve
  res := IPResolver.Resolve(qry);

  // first we need to connect
  AsyncConnect(FSocket, res, ConnectCondition, ConnectHandler);
end;

function AsyncHttpCliImpl.GetProgressHandler: HttpClientProgressHandler;
begin
  result := FProgressHandler;
end;

function AsyncHttpCliImpl.GetService: IOService;
begin
  result := FService;
end;

procedure AsyncHttpCliImpl.HandleResponse(const Headers: string;
  const ResponseData: TBytes);
begin
  if (Assigned(FResponseHandler)) then
    FResponseHandler(Headers, ResponseData);
end;

procedure AsyncHttpCliImpl.ParseURL(const URL: string);

  procedure RaiseURLError(const Msg: string);
  begin
    raise EArgumentException.CreateFmt('%s: "%s"', [Msg, URL]);
  end;

var
  s: string;
  i: integer;
begin
  FHost := '';
  FPath := '';
  FUsername := '';
  FPassword := '';
  FPort := 0;

  s := URL;

  i := s.IndexOf('http://');
  if (i < 0) then
    RaiseURLError('Invalid URL');

  s := s.Remove(0, Length('http://'));

  i := s.IndexOf('/');
  if (i < 0) then
  begin
    FHost := s;
  end
  else
  begin
    FHost := s.Substring(0, i);
    FPath := s.Remove(0, i);
  end;

  if (FPath = '') then
    FPath := '/';

  // extract credentials if present
  s := FHost;
  i := s.IndexOf('@');
  if (i >= 0) then
  begin
    FHost := s.Substring(i+1);
    s := s.Remove(0, i+1);
    i := s.IndexOf(':');
    if (i < 0) then
    begin
      FUsername := s;
    end
    else
    begin
      FUsername := s.Substring(0, i);
      FPassword := s.Remove(0, i+1);
    end;
  end;

  // extract port
  s:= FHost;
  i := s.IndexOf(':');
  if (i >= 0) then
  begin
    FHost := s.Substring(0, i);
    s := s.Remove(0, i+1);
    FPort := StrToIntDef(s, -1);
    if (FPort <= 0) then
      RaiseURLError('Invalid port in URL');
  end;

  if (FPort <= 0) then
    FPort := 80;
end;

procedure AsyncHttpCliImpl.ProgressUpdate(const Status: string);
begin
  if (Assigned(FProgressHandler)) then
    FProgressHandler(Status);
end;

procedure AsyncHttpCliImpl.ReadHandler(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
var
  headers: string;
  responseData: TBytes;
  reader: StreamReader;
begin
  if (ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  FSocket.Close();

  // stopping to be improved
  Service.Stop;

  reader := NewStreamReader(TEncoding.ASCII, FResponseBuffer.Stream);

  headers := reader.ReadUntil(#13#10#13#10);

  // read response data
  SetLength(responseData, reader.Stream.Size - reader.Stream.Position);
  reader.Stream.ReadBuffer(responseData, Length(responseData));

  HandleResponse(headers, responseData);
end;

procedure AsyncHttpCliImpl.SetProgressHandler(
  const Value: HttpClientProgressHandler);
begin
  FProgressHandler := Value;
end;

procedure AsyncHttpCliImpl.WriteHandler(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
begin
  if (ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  // half close
  FSocket.Shutdown(SocketShutdownWrite);

  // zero our response buffer so we know we got the right stuff back
  FResponseBuffer := StreamBuffer.Create();

  // finally read the http response back
  // server will close socket when done, so read it all
  // for simplicity, just assume we can hold it all in memory
  AsyncRead(FStream, FResponseBuffer, TransferAll(), ReadHandler);
end;

end.
