unit AsyncIO.Coroutine;

interface

uses
  AsyncIO, AsyncIO.OpResults, AsyncIO.Coroutine.Detail;

type
  IOServiceCoroutineContext = interface
    ['{6D2114D3-0061-404A-90C3-5531C5FE96CB}']
    {$REGION 'Property accessors'}
    function GetService: IOService;
    {$ENDREGION}

    property Service: IOService read GetService;
  end;

  YieldContext = record
  {$REGION 'Implementation details'}
  strict private
    FImpl: IYieldContext;
  private
    property Impl: IYieldContext read FImpl;
  public
    class operator Implicit(const Yield: YieldContext): IYieldContext;
  {$ENDREGION}
  public
    // assign nil to free implementation
    class operator Implicit(const Impl: IYieldContext): YieldContext;
  end;

  CoroutineHandler = reference to procedure(const Yield: YieldContext);

  IOResult = record
  {$REGION 'Implementation details'}
  strict private
    FRes: OpResult;
    FBytesTransferred: UInt64;

    function GetValue: integer;
    function GetSuccess: boolean;
    function GetMessage: string;
    function GetResult: OpResult;
  {$ENDREGION}
  public
    class function Create(const Res: OpResult; const BytesTransferred: UInt64): IOResult; static;

    class operator Implicit(const IORes: IOResult): OpResult;

    procedure RaiseException(const AdditionalInfo: string = '');

    property Value: integer read GetValue;

    property Success: boolean read GetSuccess;
    property Message: string read GetMessage;

    property Result: OpResult read GetResult;
    property BytesTransferred: UInt64 read FBytesTransferred;
  end;

function NewIOServiceCoroutineContext(const Service: IOService): IOServiceCoroutineContext;

function NewYieldContext(const ServiceContext: IOServiceCoroutineContext): YieldContext;

procedure Spawn(const ServiceContext: IOServiceCoroutineContext; Coroutine: CoroutineHandler); overload;

function AsyncRead(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Yield: YieldContext): IOResult; overload;
function AsyncRead(const Stream: AsyncStream; const Buffer: StreamBuffer; const CompletionCondition: IOCompletionCondition; const Yield: YieldContext): IOResult; overload;

function AsyncWrite(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Yield: YieldContext): IOResult; overload;
function AsyncWrite(const Stream: AsyncStream; const Buffer: StreamBuffer; const CompletionCondition: IOCompletionCondition; const Yield: YieldContext): IOResult; overload;

implementation

uses
  System.SysUtils, AsyncIO.Coroutine.Detail.Fiber;

function NewIOServiceCoroutineContext(const Service: IOService): IOServiceCoroutineContext;
begin
  result := IOServiceCoroutineContextImpl.Create(Service);
end;

function NewYieldContext(const ServiceContext: IOServiceCoroutineContext): YieldContext;
begin
  result := YieldContextImpl.Create(ServiceContext);
end;

procedure Spawn(const ServiceContext: IOServiceCoroutineContext; Coroutine: CoroutineHandler);
var
  yield: YieldContext;
begin
  yield := NewYieldContext(ServiceContext);

  ServiceContext.Service.Post(
    procedure
    begin
      Coroutine(yield);
    end
  );
end;

function AsyncRead(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Yield: YieldContext): IOResult; overload;
var
  yieldImpl: IYieldContext;
  handler: IOHandler;
  ioRes: IOResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult; const BytesTransferred: UInt64)
    begin
      ioRes := IOResult.Create(Res, BytesTransferred);
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  AsyncRead(Stream, Buffer, CompletionCondition, handler);

  yieldImpl.Wait;

  result := ioRes;
end;

function AsyncRead(const Stream: AsyncStream; const Buffer: StreamBuffer; const CompletionCondition: IOCompletionCondition; const Yield: YieldContext): IOResult;
var
  yieldImpl: IYieldContext;
  handler: IOHandler;
  ioRes: IOResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult; const BytesTransferred: UInt64)
    begin
      ioRes := IOResult.Create(Res, BytesTransferred);
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  AsyncRead(Stream, Buffer, CompletionCondition, handler);

  yieldImpl.Wait;

  result := ioRes;
end;

function AsyncWrite(const Stream: AsyncStream; const Buffer: MemoryBuffer; const CompletionCondition: IOCompletionCondition; const Yield: YieldContext): IOResult; overload;
var
  yieldImpl: IYieldContext;
  handler: IOHandler;
  ioRes: IOResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult; const BytesTransferred: UInt64)
    begin
      ioRes := IOResult.Create(Res, BytesTransferred);
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  AsyncWrite(Stream, Buffer, CompletionCondition, handler);

  yieldImpl.Wait;

  result := ioRes;
end;

function AsyncWrite(const Stream: AsyncStream; const Buffer: StreamBuffer; const CompletionCondition: IOCompletionCondition; const Yield: YieldContext): IOResult;
var
  yieldImpl: IYieldContext;
  handler: IOHandler;
  ioRes: IOResult;
begin
  yieldImpl := Yield;

  handler :=
    procedure(const Res: OpResult; const BytesTransferred: UInt64)
    begin
      ioRes := IOResult.Create(Res, BytesTransferred);
      // set return
      yieldImpl.SetServiceHandlerCoroutine();
    end;

  AsyncWrite(Stream, Buffer, CompletionCondition, handler);

  yieldImpl.Wait;

  result := ioRes;
end;

{ YieldContext }

class operator YieldContext.Implicit(const Impl: IYieldContext): YieldContext;
begin
  result.FImpl := Impl;
end;

class operator YieldContext.Implicit(const Yield: YieldContext): IYieldContext;
begin
  result := Yield.Impl;
end;

{ IOResult }

class function IOResult.Create(const Res: OpResult;
  const BytesTransferred: UInt64): IOResult;
begin
  result.FRes := Res;
  result.FBytesTransferred := BytesTransferred;
end;

function IOResult.GetMessage: string;
begin
  result := FRes.Message;
end;

function IOResult.GetResult: OpResult;
begin
  result := FRes;
end;

function IOResult.GetSuccess: boolean;
begin
  result := FRes.Success;
end;

function IOResult.GetValue: integer;
begin
  result := FRes.Value;
end;

class operator IOResult.Implicit(const IORes: IOResult): OpResult;
begin
  result := IORes.FRes;
end;

procedure IOResult.RaiseException(const AdditionalInfo: string);
begin
  FRes.RaiseException(AdditionalInfo);
end;

end.
