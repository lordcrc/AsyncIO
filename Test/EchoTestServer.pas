unit EchoTestServer;

interface

uses
  System.SysUtils, AsyncIO.Net.IP;

type
  IEchoTestServer = interface
    function GetPort: integer;
    function GetReceivedData: TBytes;

    procedure Start;
    procedure Stop;


    property Port: integer read GetPort;
  end;

function NewEchoTestServer(const Port: integer): IEchoTestServer;

implementation

uses
  IdGlobal, IdContext, IdIOHandler, IdCustomTCPServer;

type
  TEchoServer = class(TIdCustomTCPServer)
  private
    FData: TBytes;

    procedure SetData(const Data: TBytes);
  protected
    function DoExecute(AContext:TIdContext): boolean; override;

    function GetData: TBytes;
  end;

{ TEchoServer }

function TEchoServer.DoExecute(AContext: TIdContext): boolean;
var
  LBuffer: TIdBytes;
  Data: TBytes;
  LIOHandler: TIdIOHandler;
begin
  Result := True;
  SetLength(LBuffer, 0);
  LIOHandler := AContext.Connection.IOHandler;
  LIOHandler.ReadBytes(LBuffer, -1);

  SetLength(Data, Length(LBuffer));
  Move(LBuffer[0], Data[0], Length(LBuffer));
  SetData(Data);

  LIOHandler.Write(LBuffer);
end;

function TEchoServer.GetData: TBytes;
begin
  TMonitor.Enter(Self);
  try
    result := Copy(FData);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TEchoServer.SetData(const Data: TBytes);
begin
  TMonitor.Enter(Self);
  try
    FData := FData + Data;
  finally
    TMonitor.Exit(Self);
  end;
end;

type
  TEchoTestServerImpl = class(TInterfacedObject, IEchoTestServer)
  private
    FServer: TECHOServer;
  public
    constructor Create(const Port: integer);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    function GetPort: integer;
    function GetReceivedData: TBytes;
  end;

function NewEchoTestServer(const Port: integer): IEchoTestServer;
begin
  result := TEchoTestServerImpl.Create(Port);
end;

{ TEchoTestServerImpl }

constructor TEchoTestServerImpl.Create(const Port: integer);
begin
  inherited Create;

  FServer := TECHOServer.Create(nil);
  FServer.DefaultPort := Port;
  FServer.MaxConnections := 1;
end;

destructor TEchoTestServerImpl.Destroy;
begin
  FServer.Free;

  inherited;
end;

function TEchoTestServerImpl.GetPort: integer;
begin
  result := FServer.DefaultPort;
end;

function TEchoTestServerImpl.GetReceivedData: TBytes;
begin
  result := FServer.GetData;
end;

procedure TEchoTestServerImpl.Start;
begin
  FServer.Active := True;

  // Give the server threads some time to start listening
  Sleep(100);
end;

procedure TEchoTestServerImpl.Stop;
begin
  FServer.Active := False;
end;

end.
