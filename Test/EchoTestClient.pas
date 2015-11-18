unit EchoTestClient;

interface

uses
  System.Threading;

type
  IEchoTestClient = interface
    function GetPort: integer;
    function GetHost: string;

    function ConnectAndSend(const s: string): IFuture<string>;

    property Port: integer read GetPort;
    property Host: string read GetHost;
  end;

function NewEchoTestClient(const Host: string; const Port: integer): IEchoTestClient;

implementation

uses
  IdEcho, IdException, System.SysUtils, IdGlobal, IdStack;

type
  TEchoTestServerImpl = class(TInterfacedObject, IEchoTestClient)
  private
    FClient: TIdEcho;
    FCurrent: IFuture<string>;
  public
    constructor Create(const Host: string; const Port: integer);
    destructor Destroy; override;

    function GetPort: integer;
    function GetHost: string;

    procedure Shutdown;

    function ConnectAndSend(const s: string): IFuture<string>;
  end;


function NewEchoTestClient(const Host: string; const Port: integer): IEchoTestClient;
begin
  result := TEchoTestServerImpl.Create(Host, Port);
end;

{ TEchoTestServerImpl }

function TEchoTestServerImpl.ConnectAndSend(const s: string): IFuture<string>;
begin
  if ((FCurrent <> nil) and (FCurrent.Status <> TTaskStatus.Completed)) then
    raise EInvalidOpException.Create('ConnectAndSend: already in progress');

  FCurrent := TTask.Future<string>(
    function: string
    begin
      FClient.Connect;

      result := FClient.Echo(s);

      Shutdown();
    end
  );

  FCurrent.Start;

  result := FCurrent;
end;

constructor TEchoTestServerImpl.Create(const Host: string; const Port: integer);
begin
  inherited Create;

  FClient := TIdEcho.Create(nil);
  FClient.Host := Host;
  FClient.Port := Port;
  FClient.IPVersion := Id_IPv6;

  FCurrent := nil;
end;

destructor TEchoTestServerImpl.Destroy;
begin
  if (FCurrent <> nil) then
  begin
    FCurrent.Wait();
  end;

  inherited;
end;

function TEchoTestServerImpl.GetHost: string;
begin
  result := FClient.Host;
end;

function TEchoTestServerImpl.GetPort: integer;
begin
  result := FClient.Port;
end;

procedure TEchoTestServerImpl.Shutdown;
begin
  try
    FClient.Disconnect(True);
  except
    on E: EIdSilentException do;
  end;
end;

end.
