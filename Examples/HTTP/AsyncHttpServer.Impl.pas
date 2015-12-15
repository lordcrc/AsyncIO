unit AsyncHttpServer.Impl;

interface

uses
  System.SysUtils, AsyncIO, AsyncIO.Net.IP, AsyncHttpServer.Mime;

type
  AsyncHttpSrv = interface
    ['{B42FCD26-7EC9-449D-B2B1-7A8BC24AA541}']
    {$REGION 'Property accessors'}
    function GetService: IOService;
    {$ENDREGION}

    procedure Run;

    property Service: IOService read GetService;
  end;

function NewAsyncHttpSrv(const LocalAddress: string; const Port: integer; const DocRoot: string; const Mime: MimeRegistry): AsyncHttpSrv;

implementation

uses
  AsyncIO.ErrorCodes, AsyncHttpServer.Connection,
  AsyncHttpServer.RequestHandler;

type
  AsyncHttpSrvImpl = class(TInterfacedObject, AsyncHttpSrv)
  strict private
    FService: IOService;
    FEndpoint: IPEndpoint;
    FDocRoot: string;
    FMime: MimeRegistry;
    FAcceptor: IPAcceptor;
    FSocket: IPStreamSocket;
    FConnectionManager: HttpConnectionManager;
    FRequestHandler: HttpRequestHandler;

    procedure Log(const Msg: string);

    procedure DoAccept;

    procedure AcceptHandler(const ErrorCode: IOErrorCode);
  public
    constructor Create(const Service: IOService; const Endpoint: IPEndpoint; const DocRoot: string; const Mime: MimeRegistry);

    function GetService: IOService;

    procedure Run;

    property Service: IOService read FService;
    property DocRoot: string read FDocRoot;
    property Mime: MimeRegistry read FMime;
    property RequestHandler: HttpRequestHandler read FRequestHandler;
    property ConnectionManager: HttpConnectionManager read FConnectionManager;
  end;

function NewAsyncHttpSrv(const LocalAddress: string; const Port: integer; const DocRoot: string; const Mime: MimeRegistry): AsyncHttpSrv;
var
  service: IOService;
  qry: IPResolver.Query;
  res: IPResolver.Results;
  endpoints: TArray<IPEndpoint>;
begin
  service := NewIOService();

  qry := Query(IPProtocol.TCP.Unspecified, LocalAddress, IntToStr(Port));

  // TODO - implement async resolve
  res := IPResolver.Resolve(qry);

  endpoints := res.GetEndpoints();

  if (Length(endpoints) <= 0) then
    raise EArgumentException.Create('Invalid listening address');

  result := AsyncHttpSrvImpl.Create(service, endpoints[0], DocRoot, Mime);
end;

{ AsyncHttpSrvImpl }

procedure AsyncHttpSrvImpl.AcceptHandler(const ErrorCode: IOErrorCode);
var
  connection: HttpConnection;
begin
  // check if it's time to go
  if (not FAcceptor.IsOpen) then
    exit;

  if (ErrorCode = IOErrorCode.Success) then
  begin
{$IFDEF DEBUG}
    Log('Accepted connection from ' + FSocket.RemoteEndpoint);
{$ENDIF}

    connection := NewHttpConnection(FSocket, ConnectionManager, RequestHandler);
    connection.Start;
    FSocket := nil;
  end;

  DoAccept;
end;

constructor AsyncHttpSrvImpl.Create(const Service: IOService;
  const Endpoint: IPEndpoint; const DocRoot: string; const Mime: MimeRegistry);
begin
  inherited Create;

  FService := Service;
  FEndpoint := Endpoint;
  FDocRoot := DocRoot;
  FMime := Mime;
  FConnectionManager := NewHttpConnectionManager();
  FRequestHandler := NewHttpRequestHandler(Service, DocRoot, Mime);
end;

procedure AsyncHttpSrvImpl.DoAccept;
begin
  FSocket := NewTCPSocket(Service);
  FAcceptor.AsyncAccept(FSocket, AcceptHandler);
end;

function AsyncHttpSrvImpl.GetService: IOService;
begin
  result := FService;
end;

procedure AsyncHttpSrvImpl.Log(const Msg: string);
begin
  WriteLn('[' + FormatDateTime('yyyy.mm.dd hh:nn:ss.zzz', Now()) + '] ' + Msg);
end;

procedure AsyncHttpSrvImpl.Run;
begin
  if (Assigned(FAcceptor)) then
    raise EInvalidOpException.Create('Run called on running AsyncHttpSrv');

  FAcceptor := NewTCPAcceptor(Service);
  FAcceptor.Open(FEndpoint.Protocol);
  // TODO - set SO_REUSEADDR socket option
  FAcceptor.Bind(FEndpoint);
  FAcceptor.Listen;

  DoAccept;

  // run returns when all connections are done
  // and acceptor has stopped listening
  Service.Run;

  FAcceptor := nil;
end;

end.
