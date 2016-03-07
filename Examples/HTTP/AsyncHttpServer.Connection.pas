unit AsyncHttpServer.Connection;

interface

uses
  System.SysUtils, AsyncIO, AsyncIO.Net.IP, AsyncHttpServer.Request,
  AsyncHttpServer.RequestHandler, AsyncHttpServer.Response;

type
  HttpConnectionManager = interface;

  HttpConnection = interface
    ['{A7AC1C03-AE5C-4A4C-B49E-C591050176B0}']
    {$REGION 'Property accessors'}
    function GetSocket: IPStreamSocket;
    function GetConnectionManager: HttpConnectionManager;
    function GetRequestHandler: HttpRequestHandler;
    {$ENDREGION}

    procedure Start;
    procedure Stop;

    property Socket: IPStreamSocket read GetSocket;
    property ConnectionManager: HttpConnectionManager read GetConnectionManager;
    property RequestHandler: HttpRequestHandler read GetRequestHandler;
  end;

  HttpConnectionManager = interface
    ['{4B05AE86-77DC-442C-8679-518353DFAB34}']

    procedure StopAll;
  end;

function NewHttpConnection(const Socket: IPStreamSocket; const ConnectionManager: HttpConnectionManager; const RequestHandler: HttpRequestHandler): HttpConnection;
function NewHttpConnectionManager: HttpConnectionManager;

procedure ManageHttpConnection(const Connection: HttpConnection; const ConnectionManager: HttpConnectionManager);
procedure RemoveHttpConnection(const Connection: HttpConnection; const ConnectionManager: HttpConnectionManager);

implementation

uses
  System.Generics.Collections, AsyncIO.OpResults,
  AsyncHttpServer.RequestParser, AsyncHttpServer.Headers, HttpDateTime;

type
  HttpConnectionImpl = class(TInterfacedObject, HttpConnection)
  public
    const MaxRequestSize = 16 * 1024 * 1024; // max request size
    const MaxContentBufferSize = 64 * 1024; // max buffer size when sending content
  strict private
    FSocket: IPStreamSocket;
    FStream: AsyncSocketStream;
    FConnectionManager: HttpConnectionManager;
    FRequestHandler: HttpRequestHandler;
    FRequestParser: HttpRequestParser;
    FBuffer: StreamBuffer;
    FContentBuffer: TBytes;
    FRequest: HttpRequest;
    FResponse: HttpResponse;

    procedure Log(const Msg: string);

    procedure DoReadRequest;

    procedure DoParseRequest;

    procedure DoReadResponseContent;

    procedure DoWriteResponse;

    procedure StartWriteResponseContent;

    procedure DoStartConnection;

    procedure DoShutdownConnection;
    procedure DoStopConnection;

    procedure HandleRequest;
    procedure HandleInvalidRequest;

    procedure ReadRequestHandler(const Res: OpResult; const BytesTransferred: UInt64);
    procedure WriteResponseHandler(const Res: OpResult; const BytesTransferred: UInt64);

    procedure ReadResponseContentHandler(const Res: OpResult; const BytesTransferred: UInt64);
    procedure WriteResponseContentHandler(const Res: OpResult; const BytesTransferred: UInt64);
  public
    constructor Create(const Socket: IPStreamSocket; const ConnectionManager: HttpConnectionManager; const RequestHandler: HttpRequestHandler; const RequestParser: HttpRequestParser);

    function GetSocket: IPStreamSocket;
    function GetConnectionManager: HttpConnectionManager;
    function GetRequestHandler: HttpRequestHandler;

    procedure Start;
    procedure Stop;

    property Socket: IPStreamSocket read FSocket;
    property ConnectionManager: HttpConnectionManager read FConnectionManager;
    property RequestHandler: HttpRequestHandler read FRequestHandler;
    property RequestParser: HttpRequestParser read FRequestParser;
  end;

function NewHttpConnection(const Socket: IPStreamSocket; const ConnectionManager: HttpConnectionManager; const RequestHandler: HttpRequestHandler): HttpConnection;
var
  requestParser: HttpRequestParser;
begin
  requestParser := NewHttpRequestParser();
  result := HttpConnectionImpl.Create(Socket, ConnectionManager, RequestHandler, requestParser);
end;

{ HttpConnectionImpl }

constructor HttpConnectionImpl.Create(const Socket: IPStreamSocket;
  const ConnectionManager: HttpConnectionManager;
  const RequestHandler: HttpRequestHandler;
  const RequestParser: HttpRequestParser);
begin
  inherited Create;

  FSocket := Socket;
  FConnectionManager := ConnectionManager;
  FRequestHandler := RequestHandler;
  FRequestParser := RequestParser;
end;

procedure HttpConnectionImpl.DoParseRequest;
var
  reqStatus: HttpRequestState;
begin
  // any read data has been appended to our buffer
  // so pass it to the parser
  reqStatus := RequestParser.Parse(FRequest, FBuffer);

  case reqStatus of
    HttpRequestStateValid: begin
      // we got a valid request, time to handle it
      HandleRequest;
    end;
    HttpRequestStateNeedMoreData: begin
      // haven't got entire request yet, so queue another read
      DoReadRequest;
    end;
  else
    // request was bad, send an error response
    HandleInvalidRequest;
  end;
end;

procedure HttpConnectionImpl.DoReadRequest;
begin
  AsyncRead(FStream, FBuffer, TransferAtLeast(1), ReadRequestHandler);
end;

procedure HttpConnectionImpl.DoReadResponseContent;
begin
  AsyncRead(FResponse.ContentStream, FContentBuffer, TransferAtLeast(1), ReadResponseContentHandler);
end;

procedure HttpConnectionImpl.DoShutdownConnection;
begin
  FStream.Socket.Shutdown();
  DoStopConnection;
end;

procedure HttpConnectionImpl.DoStartConnection;
var
  con: HttpConnection;
begin
  con := Self;
  ManageHttpConnection(con, ConnectionManager);
end;

procedure HttpConnectionImpl.DoStopConnection;
var
  con: HttpConnection;
begin
  con := Self;
  // socket has been closed
  RemoveHttpConnection(con, ConnectionManager);
end;

procedure HttpConnectionImpl.DoWriteResponse;
begin
  // start sending the response we got
  FBuffer := FResponse.ToBuffer();

  AsyncWrite(FStream, FBuffer, TransferAll(), WriteResponseHandler);
end;

function HttpConnectionImpl.GetConnectionManager: HttpConnectionManager;
begin
  result := FConnectionManager;
end;

function HttpConnectionImpl.GetRequestHandler: HttpRequestHandler;
begin
  result := FRequestHandler;
end;

function HttpConnectionImpl.GetSocket: IPStreamSocket;
begin
  result := FSocket;
end;

procedure HttpConnectionImpl.HandleInvalidRequest;
begin
  FResponse := StandardResponse(StatusBadRequest);
  DoWriteResponse;
end;

procedure HttpConnectionImpl.HandleRequest;
begin
  // we've got a valid request, we need to handle it and send the response

{$IFDEF DEBUG}
  Log(Format(#13#10 + '  %s %s HTTP/%d.%d', [FRequest.Method, FRequest.URI, FRequest.HttpVersionMajor, FRequest.HttpVersionMinor]) + FRequest.Headers.ToDebugString());
{$ENDIF}

  try
    // get the response from our request handler
    FResponse := RequestHandler.HandleRequest(FRequest);

{$IFDEF DEBUG}
    Log(Format(#13#10 + '  %d %s', [Ord(FResponse.Status), FResponse.Status.ToString()]) + FResponse.Headers.ToDebugString());
{$ENDIF}
  except
    on E: Exception do
    begin
      // something went wrong, get an error response
      Log(Format('Error processing request (%s %s HTTP/%d.%d): [%s] %s', [FRequest.Method, FRequest.URI, FRequest.HttpVersionMajor, FRequest.HttpVersionMinor, E.ClassName, E.Message]));
      FResponse := StandardResponse(StatusInternalServerError);
    end;
  end;

  FResponse.Headers.Value['Date'] := SystemTimeToHttpDate(CurrentSystemTime());
  FResponse.Headers.Value['Server'] := 'AsyncHttpServer';

  // send whatever response we got
  DoWriteResponse;
end;

procedure HttpConnectionImpl.Log(const Msg: string);
begin
  WriteLn('[' + FormatDateTime('yyyy.mm.dd hh:nn:ss.zzz', Now()) + '] ' + FSocket.RemoteEndpoint + ' | ' + Msg);
end;

procedure HttpConnectionImpl.ReadRequestHandler(const Res: OpResult;
  const BytesTransferred: UInt64);
begin
  if ((Res.Success) and (BytesTransferred > 0))  then
  begin
    // we got at least some data forming the request, parse it and handle response if possible
    DoParseRequest();
  end
  else if ((Res = NetResults.OperationAborted) or (BytesTransferred = 0)) then
  begin
    // socket has been closed or shut down
    DoStopConnection;
  end;
  // ingore other errors
end;

procedure HttpConnectionImpl.ReadResponseContentHandler(
  const Res: OpResult; const BytesTransferred: UInt64);
begin
  if ((Res.Success) or (Res = SystemResults.EndOfFile)) then
  begin
    if (BytesTransferred > 0) then
    begin
      // we got some data from the response content stream
      // so send it to the client
      AsyncWrite(FStream, MakeBuffer(FContentBuffer, BytesTransferred), TransferAll(), WriteResponseContentHandler);
    end
    else
    begin
      // nothing more to read, so shut down connection
      DoShutdownConnection;
    end;
  end
  else
  begin
    // something went wrong, so kill connection
    DoStopConnection;
  end;
end;

procedure HttpConnectionImpl.Start;
begin
  FBuffer := StreamBuffer.Create(MaxRequestSize);

  FStream := NewAsyncSocketStream(Socket);

  FRequest := NewHttpRequest;

  DoStartConnection;

  // we're all good to go, start by reading the request
  DoReadRequest;
end;

procedure HttpConnectionImpl.StartWriteResponseContent;
begin
  if (not Assigned(FResponse.ContentStream)) then
    exit;

  FBuffer := nil;
  FContentBuffer := nil;
  SetLength(FContentBuffer, MaxContentBufferSize);

  // start by reading from the response content stream
  DoReadResponseContent;
end;

procedure HttpConnectionImpl.Stop;
begin
  FSocket.Close;
end;

procedure HttpConnectionImpl.WriteResponseContentHandler(
  const Res: OpResult; const BytesTransferred: UInt64);
var
  con: HttpConnection;
begin
  if (Res.Success) then
  begin
    // response content stream data has been sent, so try reading some more
    DoReadResponseContent;
  end
  else
  begin
    FSocket.Shutdown(SocketShutdownBoth);

    if (Res = NetResults.OperationAborted) then
    begin
      con := Self;
      RemoveHttpConnection(con, ConnectionManager);
    end;
  end;
end;

procedure HttpConnectionImpl.WriteResponseHandler(const Res: OpResult;
  const BytesTransferred: UInt64);
begin
  if (Res.Success) then
  begin
    // response has been sent, send response content stream if applicable
    StartWriteResponseContent;
  end
  else
  begin
    FSocket.Shutdown(SocketShutdownBoth);

    if (Res = NetResults.OperationAborted) then
    begin
      DoStopConnection;
    end;
  end;
end;

type
  THttpConnectionSet = class
  strict private
    FDict: TDictionary<HttpConnection, integer>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Add(const Connection: HttpConnection);
    procedure Remove(const Connection: HttpConnection);

    function GetEnumerator: TEnumerator<HttpConnection>;
  end;

{ THttpConnectionSet }

procedure THttpConnectionSet.Add(const Connection: HttpConnection);
begin
  FDict.Add(Connection, 1);
end;

constructor THttpConnectionSet.Create;
begin
  inherited Create;

  FDict := TDictionary<HttpConnection, integer>.Create;
end;

destructor THttpConnectionSet.Destroy;
begin
  FDict.Free;

  inherited;
end;

function THttpConnectionSet.GetEnumerator: TEnumerator<HttpConnection>;
begin
  result := FDict.Keys.GetEnumerator();
end;

procedure THttpConnectionSet.Remove(const Connection: HttpConnection);
var
  hasConnection: boolean;
begin
  hasConnection := FDict.ContainsKey(Connection);

  if (not hasConnection) then
    exit;

  FDict.Remove(Connection);
end;

type
  HttpConnectionManagerAssociation = interface
    ['{7E5B70C1-A9AD-463F-BDED-7EB0C6DFD854}']

    procedure Manage(const Connection: HttpConnection);
    procedure Remove(const Connection: HttpConnection);
  end;

  HttpConnectionManagerImpl = class(TInterfacedObject, HttpConnectionManager, HttpConnectionManagerAssociation)
  strict private
    FConnections: THttpConnectionSet;

    property Connections: THttpConnectionSet read FConnections;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Manage(const Connection: HttpConnection);
    procedure Remove(const Connection: HttpConnection);

    procedure StopAll;
  end;

function NewHttpConnectionManager: HttpConnectionManager;
begin
  result := HttpConnectionManagerImpl.Create;
end;

procedure ManageHttpConnection(const Connection: HttpConnection; const ConnectionManager: HttpConnectionManager);
var
  assoc: HttpConnectionManagerAssociation;
begin
  assoc := ConnectionManager as HttpConnectionManagerAssociation;
  assoc.Manage(Connection);
end;

procedure RemoveHttpConnection(const Connection: HttpConnection; const ConnectionManager: HttpConnectionManager);
var
  assoc: HttpConnectionManagerAssociation;
begin
  assoc := ConnectionManager as HttpConnectionManagerAssociation;
  assoc.Remove(Connection);
end;

{ HttpConnectionManagerImpl }

constructor HttpConnectionManagerImpl.Create;
begin
  inherited Create;

  FConnections := THttpConnectionSet.Create;
end;

destructor HttpConnectionManagerImpl.Destroy;
begin
  StopAll;

  FConnections.Free;

  inherited;
end;

procedure HttpConnectionManagerImpl.Manage(const Connection: HttpConnection);
begin
  FConnections.Add(Connection);
end;

procedure HttpConnectionManagerImpl.Remove(const Connection: HttpConnection);
begin
  FConnections.Remove(Connection);
end;

procedure HttpConnectionManagerImpl.StopAll;
var
  con: HttpConnection;
begin
  for con in Connections do
  begin
    con.Stop;
    Remove(con);
  end;
end;

end.
