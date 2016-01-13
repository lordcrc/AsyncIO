unit IPStreamSocketMock;

interface

uses
  IdWinsock2, AsyncIO, AsyncIO.Net.IP;

type
  TIPStreamSocketMock = class(TInterfacedObject, IPStreamSocket)
  strict private
    FConnected: boolean;
    FLocalEndpoint: IPEndpoint;
    FPeerEndpoint: IPEndpoint;
    FService: IOService;
  public
    constructor Create(const Service: IOService);

    function GetService: IOService;
    function GetProtocol: IPProtocol;
    function GetLocalEndpoint: IPEndpoint;
    function GetRemoteEndpoint: IPEndpoint;
    function GetSocketHandle: TSocket;

    procedure AsyncConnect(const PeerEndpoint: IPEndpoint; const Handler: OpHandler);

    procedure Bind(const LocalEndpoint: IPEndpoint);

    procedure Connect(const PeerEndpoint: IPEndpoint);
    procedure Close;

    procedure Shutdown(const ShutdownFlag: SocketShutdownFlag = SocketShutdownBoth); overload;

    procedure AsyncSend(const Buffer: MemoryBuffer; const Handler: IOHandler); overload;
    procedure AsyncReceive(const Buffer: MemoryBuffer; const Handler: IOHandler); overload;
  end;

implementation

uses
  System.SysUtils, AsyncIO.OpResults;

{ TIPStreamSocketMock }

procedure TIPStreamSocketMock.AsyncConnect(const PeerEndpoint: IPEndpoint; const Handler: OpHandler);
var
  peer: IPEndpoint;
begin
  peer := PeerEndpoint;
  FService.Post(
    procedure
    begin
      if (FConnected) then
      begin
        Handler(NetResults.IsConnected)
      end
      else
      begin
        FPeerEndpoint := peer;
        FConnected := True;
        Handler(NetResults.Success);
      end;
    end
  );
end;

procedure TIPStreamSocketMock.AsyncReceive(const Buffer: MemoryBuffer; const Handler: IOHandler);
var
  bufferSize: UInt64;
begin
  bufferSize := Buffer.Size;
  FService.Post(
    procedure
    begin
      if (FConnected) then
        Handler(NetResults.Success, bufferSize)
      else
        Handler(NetResults.NotConnected, 0);
    end
  );
end;

procedure TIPStreamSocketMock.AsyncSend(const Buffer: MemoryBuffer; const Handler: IOHandler);
var
  bufferSize: UInt64;
begin
  bufferSize := Buffer.Size;
  FService.Post(
    procedure
    begin
      if (FConnected) then
        Handler(NetResults.Success, bufferSize)
      else
        Handler(NetResults.NotConnected, 0);
    end
  );
end;

procedure TIPStreamSocketMock.Bind(const LocalEndpoint: IPEndpoint);
begin
  FLocalEndpoint := LocalEndpoint;
end;

procedure TIPStreamSocketMock.Close;
begin
  raise ENotImplemented.Create('TIPStreamSocketMock.Close');
end;

procedure TIPStreamSocketMock.Connect(const PeerEndpoint: IPEndpoint);
begin
  if (FConnected) then
    NetResults.IsConnected.RaiseException;

  FPeerEndpoint := PeerEndpoint;
  FConnected := True;
end;

constructor TIPStreamSocketMock.Create(const Service: IOService);
begin
  inherited Create;

  FService := Service;
  FLocalEndpoint := Endpoint();
  FPeerEndpoint := Endpoint();
end;

function TIPStreamSocketMock.GetLocalEndpoint: IPEndpoint;
begin
  result := FLocalEndpoint;
end;

function TIPStreamSocketMock.GetProtocol: IPProtocol;
begin
  raise ENotImplemented.Create('TIPStreamSocketMock.GetProtocol');
end;

function TIPStreamSocketMock.GetRemoteEndpoint: IPEndpoint;
begin
  result := FPeerEndpoint;
end;

function TIPStreamSocketMock.GetService: IOService;
begin
  result := FService;
end;

function TIPStreamSocketMock.GetSocketHandle: TSocket;
begin
  raise ENotImplemented.Create('TIPStreamSocketMock.GetSocketHandle');
end;

procedure TIPStreamSocketMock.Shutdown(const ShutdownFlag: SocketShutdownFlag);
begin
  raise ENotImplemented.Create('TIPStreamSocketMock.Shutdown');
end;

end.
