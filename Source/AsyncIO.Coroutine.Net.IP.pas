unit AsyncIO.Coroutine.Net.IP;

interface

uses
  AsyncIO, AsyncIO.OpResults, AsyncIO.Net.IP, AsyncIO.Coroutine;

type
  ConnectResult = record
  {$REGION 'Implementation details'}
  strict private
    FRes: OpResult;
    FEndpoint: IPEndpoint;

    function GetValue: integer;
    function GetSuccess: boolean;
    function GetMessage: string;
    function GetResult: OpResult;
  private
    function GetEndpoint: IPEndpoint;
  {$ENDREGION}
  public
    class function Create(const Res: OpResult; const Endpoint: IPEndpoint): ConnectResult; static;

    class operator Implicit(const ConnectRes: ConnectResult): OpResult;

    procedure RaiseException(const AdditionalInfo: string = '');

    property Value: integer read GetValue;

    property Success: boolean read GetSuccess;
    property Message: string read GetMessage;

    property Result: OpResult read GetResult;
    property Endpoint: IPEndpoint read GetEndpoint;
  end;

function AsyncAccept(const Acceptor: IPAcceptor; const Peer: IPSocket; const Yield: YieldContext): OpResult; overload;

function AsyncConnect(const Socket: IPSocket; const Endpoints: IPResolver.Results; const Yield: YieldContext): ConnectResult; overload;
function AsyncConnect(const Socket: IPSocket; const Endpoints: TArray<IPEndpoint>; const Yield: YieldContext): ConnectResult; overload;
function AsyncConnect(const Socket: IPSocket; const Endpoints: IPResolver.Results; const Condition: ConnectCondition; const Yield: YieldContext): ConnectResult; overload;
function AsyncConnect(const Socket: IPSocket; const Endpoints: TArray<IPEndpoint>; const Condition: ConnectCondition; const Yield: YieldContext): ConnectResult; overload;

implementation

uses
  AsyncIO.Coroutine.Detail;

function AsyncAccept(const Acceptor: IPAcceptor; const Peer: IPSocket; const Yield: YieldContext): OpResult;
var
  yieldImpl: IYieldContext;
  handler: OpHandler;
  opRes: OpResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult)
    begin
      opRes := Res;
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  Acceptor.AsyncAccept(Peer, handler);

  yieldImpl.Wait;

  result := opRes;
end;

function AsyncConnect(const Socket: IPSocket; const Endpoints: IPResolver.Results; const Yield: YieldContext): ConnectResult;
var
  yieldImpl: IYieldContext;
  handler: ConnectHandler;
  connectRes: ConnectResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult; const Endpoint: IPEndpoint)
    begin
      connectRes := ConnectResult.Create(Res, Endpoint);
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  AsyncIO.Net.IP.AsyncConnect(Socket, Endpoints, handler);

  yieldImpl.Wait;

  result := connectRes;
end;

function AsyncConnect(const Socket: IPSocket; const Endpoints: TArray<IPEndpoint>; const Yield: YieldContext): ConnectResult;
var
  yieldImpl: IYieldContext;
  handler: ConnectHandler;
  connectRes: ConnectResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult; const Endpoint: IPEndpoint)
    begin
      connectRes := ConnectResult.Create(Res, Endpoint);
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  AsyncIO.Net.IP.AsyncConnect(Socket, Endpoints, handler);

  yieldImpl.Wait;

  result := connectRes;
end;

function AsyncConnect(const Socket: IPSocket; const Endpoints: IPResolver.Results; const Condition: ConnectCondition; const Yield: YieldContext): ConnectResult;
var
  yieldImpl: IYieldContext;
  handler: ConnectHandler;
  connectRes: ConnectResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult; const Endpoint: IPEndpoint)
    begin
      connectRes := ConnectResult.Create(Res, Endpoint);
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  AsyncIO.Net.IP.AsyncConnect(Socket, Endpoints, handler);

  yieldImpl.Wait;

  result := connectRes;
end;

function AsyncConnect(const Socket: IPSocket; const Endpoints: TArray<IPEndpoint>; const Condition: ConnectCondition; const Yield: YieldContext): ConnectResult;
var
  yieldImpl: IYieldContext;
  handler: ConnectHandler;
  connectRes: ConnectResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult; const Endpoint: IPEndpoint)
    begin
      connectRes := ConnectResult.Create(Res, Endpoint);
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  AsyncIO.Net.IP.AsyncConnect(Socket, Endpoints, handler);

  yieldImpl.Wait;

  result := connectRes;
end;

{ ConnectResult }

class function ConnectResult.Create(const Res: OpResult;
  const Endpoint: IPEndpoint): ConnectResult;
begin
  result.FRes := Res;
  result.FEndpoint := Endpoint;
end;

function ConnectResult.GetEndpoint: IPEndpoint;
begin
  result := FEndpoint;
end;

function ConnectResult.GetMessage: string;
begin
  result := FRes.Message;
end;

function ConnectResult.GetResult: OpResult;
begin
  result := FRes;
end;

function ConnectResult.GetSuccess: boolean;
begin
  result := FRes.Success;
end;

function ConnectResult.GetValue: integer;
begin
  result := FRes.Value;
end;

class operator ConnectResult.Implicit(
  const ConnectRes: ConnectResult): OpResult;
begin
  result := ConnectRes.FRes;
end;

procedure ConnectResult.RaiseException(const AdditionalInfo: string);
begin
  FRes.RaiseException(AdditionalInfo);
end;

end.
