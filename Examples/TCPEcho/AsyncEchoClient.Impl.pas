unit AsyncEchoClient.Impl;

interface

uses
  System.SysUtils, AsyncIO, AsyncIO.ErrorCodes, AsyncIO.Net.IP;

type
  EchoClientProgressHandler = reference to procedure(const Status: string);

  AsyncTCPEchoClient = interface
  {$REGION Property accessors}
    function GetService: IOService;
  {$ENDREGION}

    procedure Execute(const Data: TBytes; const Host: string; const Port: integer = 7);

    property Service: IOService read GetService;
  end;

function NewAsyncTCPEchoClient(const Service: IOService; const ProgressHandler: EchoClientProgressHandler): AsyncTCPEchoClient;

implementation

uses
  System.Math;

type
  AsyncTCPEchoClientImpl = class(TInterfacedObject, AsyncTCPEchoClient)
  private
    FService: IOService;
    FProgressHandler: EchoClientProgressHandler;
    FData: TBytes;
    FResponseData: TBytes;
    FSocket: IPStreamSocket;
    FStream: AsyncSocketStream;

    function ConnectCondition(const ErrorCode: IOErrorCode; const Endpoint: IPEndpoint): boolean;
    procedure ConnectHandler(const ErrorCode: IOErrorCode; const Endpoint: IPEndpoint);
    procedure ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure WriteHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);

    procedure ProgressUpdate(const Status: string);
  public
    constructor Create(const Service: IOService; const ProgressHandler: EchoClientProgressHandler);

    function GetService: IOService;

    procedure Execute(const Data: TBytes; const Host: string; const Port: integer = 7);

    property Service: IOService read FService;
  end;

function NewAsyncTCPEchoClient(const Service: IOService; const ProgressHandler: EchoClientProgressHandler): AsyncTCPEchoClient;
begin
  result := AsyncTCPEchoClientImpl.Create(Service, ProgressHandler);
end;

{ AsyncTCPEchoClientImpl }

function AsyncTCPEchoClientImpl.ConnectCondition(const ErrorCode: IOErrorCode; const Endpoint: IPEndpoint): boolean;
begin
  if (not ErrorCode) then
  begin
    ProgressUpdate('Connection attempt failed: ' + ErrorCode.Message);
  end;

  ProgressUpdate('Connecting to ' + Endpoint);

  // we use this just for status updates
  result := True;
end;

procedure AsyncTCPEchoClientImpl.ConnectHandler(const ErrorCode: IOErrorCode; const Endpoint: IPEndpoint);
begin
  if (not ErrorCode) then
  begin
    ProgressUpdate('Connection attempt failed: ' + ErrorCode.Message);
    ProgressUpdate('Unable to connect to host');
    Service.Stop; // TODO - better stopping
    exit;
  end;

  ProgressUpdate('Connected');
  ProgressUpdate('Local endpoint: ' + FSocket.LocalEndpoint);
  ProgressUpdate('Remote endpoint: ' + FSocket.RemoteEndpoint);
  ProgressUpdate('Sending echo request');

  FStream := NewAsyncSocketStream(FSocket);

  // ok, we're connected, so send the echo request
  AsyncWrite(FStream, FData, TransferAll(), WriteHandler);
end;

constructor AsyncTCPEchoClientImpl.Create(const Service: IOService; const ProgressHandler: EchoClientProgressHandler);
begin
  inherited Create;

  FService := Service;
  FProgressHandler := ProgressHandler;
end;

procedure AsyncTCPEchoClientImpl.Execute(const Data: TBytes; const Host: string; const Port: integer);
var
  qry: IPResolver.Query;
  res: IPResolver.Results;
begin
  FData := Copy(Data);

  FSocket := NewTCPSocket(Service);

  qry := Query(IPProtocol.TCP.Unspecified, Host, IntToStr(Port));

  ProgressUpdate('Resolving "' + Host + '"');

  // TODO - implement async resolve
  res := IPResolver.Resolve(qry);

  // first we need to connect
  AsyncConnect(FSocket, res, ConnectCondition, ConnectHandler);
end;

function AsyncTCPEchoClientImpl.GetService: IOService;
begin
  result := FService;
end;

procedure AsyncTCPEchoClientImpl.ProgressUpdate(const Status: string);
begin
  if Assigned(FProgressHandler) then
    FProgressHandler(Status);
end;

procedure AsyncTCPEchoClientImpl.ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
var
  matches: boolean;
begin
  if (not ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  // we got the response, compare with what we sent
  matches := CompareMem(FData, FResponseData, Min(Length(FData), BytesTransferred));

  if (matches) then
    ProgressUpdate('Response matches, yay!')
  else
    ProgressUpdate('RESPONSE MISMATCH');

  FSocket.Close();

  // stopping to be improved
  Service.Stop;
end;

procedure AsyncTCPEchoClientImpl.WriteHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
begin
  if (not ErrorCode) then
    RaiseLastOSError(ErrorCode.Value);

  ProgressUpdate('Retrieving echo response');

  // half close
  FSocket.Shutdown(SocketShutdownWrite);

  // zero our response buffer so we know we got the right stuff back
  FResponseData := nil;
  SetLength(FResponseData, Length(FData));

  // finally read the echo response back
  AsyncRead(FStream, FResponseData, TransferAtLeast(Length(FData)), ReadHandler);
end;

end.
