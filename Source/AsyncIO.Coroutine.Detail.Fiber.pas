unit AsyncIO.Coroutine.Detail.Fiber;

interface

uses
  AsyncIO, AsyncIO.OpResults, AsyncIO.Coroutine, AsyncIO.Coroutine.Detail;

type
  TFiberMethod = procedure of object;

  CoroutineFiberImplBase = class abstract(TInterfacedObject, CoroutineFiber)
  strict private
    FFiber: pointer;
    FOwnsFiber: boolean;
  protected
    procedure InitFiber(const Fiber: pointer; const OwnsFiber: boolean);
  public
    constructor Create;
    destructor Destroy; override;

    procedure SwitchTo;
  end;

  CoroutineThreadFiberImpl = class(CoroutineFiberImplBase)
  public
    constructor Create;
  end;

  CoroutineFiberImpl = class(CoroutineFiberImplBase)
  strict private
    FProc: TFiberMethod;
    FFiberMethod: TMethod;
  public
    constructor Create(const Proc: TFiberMethod);
  end;

  IOServiceCoroutineHandler = interface
    ['{AFF5B520-9084-4279-9C9A-1C24AF9E645D}']
    procedure SetHandlerCoroutine(const HandlerCoroutine: CoroutineFiber);
  end;

  IOServiceCoroutineContextImpl = class(TInterfacedObject, IOServiceCoroutineContext, CoroutineFiber, IOServiceCoroutineHandler)
  strict private
    FService: IOService;
    FCoroutine: CoroutineFiber;
    FHandlerCoroutine: CoroutineFiber;
  public
    constructor Create(const Service: IOService);

    function GetService: IOService;

    procedure SetHandlerCoroutine(const HandlerCoroutine: CoroutineFiber);

    procedure RunProc;

    property Service: IOService read FService;
    property Coroutine: CoroutineFiber read FCoroutine implements CoroutineFiber;
    property HandlerCoroutine: CoroutineFiber read FHandlerCoroutine;
  end;

  YieldContextImpl = class(TInterfacedObject, IYieldContext)
  strict private
    FServiceContext: IOServiceCoroutineContext;
    FCoroutine: CoroutineFiber;
    FValid: boolean;
  protected
    procedure SetValid();
  public
    constructor Create(const ServiceContext: IOServiceCoroutineContext);

    procedure Wait;
    procedure SetServiceHandlerCoroutine;

    property ServiceContext: IOServiceCoroutineContext read FServiceContext;
    property Coroutine: CoroutineFiber read FCoroutine;
    property Valid: boolean read FValid;
  end;

implementation

uses
  WinAPI.Windows, System.SysUtils;

type
  TFiberStartRoutine = procedure(lpParameter: pointer); stdcall;

function CreateFiberEx(
  {_In_} dwStackCommitSize: SIZE_T;
  {_In_} dwStackReserveSize: SIZE_T;
  {_In_} dwFlags: DWORD;
  {_In_} lpStartAddress: TFiberStartRoutine;
  {_In_opt_} lpParameter: pointer
): pointer; stdcall; external 'kernel32.dll';

function ConvertThreadToFiberEx(
  {_In_opt_} lpParameter: LPVOID;
  {_In_} dwFlags: DWORD
): pointer; stdcall; external 'kernel32.dll';

function IsThreadAFiber(): boolean; external 'kernel32.dll';

function GetCurrentFiber(): pointer;
{$IF defined(MSWINDOWS)}
{$IF defined(CPUX86)}
asm
 { return (PVOID) (ULONG_PTR) __readfsdword (0x10);}
  mov eax, fs:[$10]
end;
{$ELSEIF defined(CPUX64)}
asm
  mov rax, gs:[$20]
end;
{$ELSE}
{$MESSAGE FATAL 'Unsupported CPU'}
{$ENDIF}
{$ELSE}
{$MESSAGE FATAL 'Unsupported platform'}
{$ENDIF}

procedure FiberStartRoutine(lpParameter: pointer); stdcall;
var
  proc: TFiberMethod;
begin
  proc := TFiberMethod(PMethod(lpParameter)^);

  proc();

  // should never return from that, so...
  raise EProgrammerNotFound.Create('Fiber procedure returned');
end;

function CurrentCoroutineFiber(): CoroutineFiber;
begin
  result := CoroutineThreadFiberImpl.Create();
end;

function NewCoroutineFiber(const Proc: TFiberMethod): CoroutineFiber;
begin
  result := CoroutineFiberImpl.Create(Proc);
end;

{ CoroutineFiberImplBase }

constructor CoroutineFiberImplBase.Create;
begin
  inherited Create;
end;

destructor CoroutineFiberImplBase.Destroy;
begin
  if (FOwnsFiber) then
    DeleteFiber(FFiber);

  inherited;
end;

procedure CoroutineFiberImplBase.InitFiber(const Fiber: pointer;
  const OwnsFiber: boolean);
begin
  FFiber := Fiber;
  FOwnsFiber := OwnsFiber;
end;

procedure CoroutineFiberImplBase.SwitchTo;
begin
  SwitchToFiber(FFiber);
end;

{ CoroutineThreadFiberImpl }

constructor CoroutineThreadFiberImpl.Create;
var
  isCallingThreadFiber: boolean;
  fiber: pointer;
begin
  inherited Create;

  isCallingThreadFiber := IsThreadAFiber();

  if (isCallingThreadFiber) then
  begin
    fiber := GetCurrentFiber()
  end
  else
  begin
    fiber := ConvertThreadToFiberEx(nil, 0);
    if (fiber = nil) then
      RaiseLastOSError();
  end;

  InitFiber(fiber, False);
end;

{ CoroutineFiberImpl }

constructor CoroutineFiberImpl.Create(const Proc: TFiberMethod);
var
  fiber: pointer;
begin
  inherited Create;

  FProc := Proc;
  FFiberMethod := TMethod(FProc);

  fiber := CreateFiberEx(0, 0, 0, FiberStartRoutine, @FFiberMethod);
  if (fiber = nil) then
    RaiseLastOSError();


  InitFiber(fiber, True);
end;

{ IOServiceCoroutineContextImpl }

constructor IOServiceCoroutineContextImpl.Create(const Service: IOService);
begin
  inherited Create;

  FService := Service;
  FCoroutine := NewCoroutineFiber(RunProc);
end;

function IOServiceCoroutineContextImpl.GetService: IOService;
begin
  result := FService;
end;

procedure IOServiceCoroutineContextImpl.RunProc;
begin
  while (not Service.Stopped) do
  begin
    FHandlerCoroutine := nil;
    Service.RunOne;
    // if the async handler assigned us a
    // coroutine, switch to that now
    // otherwise just run again
    if (Assigned(HandlerCoroutine)) then
      HandlerCoroutine.SwitchTo();
  end;
end;

procedure IOServiceCoroutineContextImpl.SetHandlerCoroutine(
  const HandlerCoroutine: CoroutineFiber);
begin
  FHandlerCoroutine := HandlerCoroutine;
end;

{ YieldContextImpl }

constructor YieldContextImpl.Create(const ServiceContext: IOServiceCoroutineContext);
begin
  inherited Create;

  FServiceContext := ServiceContext;
  FCoroutine := CurrentCoroutineFiber();
end;

procedure YieldContextImpl.SetServiceHandlerCoroutine;
var
  serviceHandler: IOServiceCoroutineHandler;
begin
  // make sure service context coroutine switches back to us
  // this ensures the handler is fully processed before
  // execution is switched back to us
  serviceHandler := ServiceContext as IOServiceCoroutineHandler;

  serviceHandler.SetHandlerCoroutine(Coroutine);
end;

procedure YieldContextImpl.SetValid;
begin
  FValid := True;
end;

procedure YieldContextImpl.Wait;
var
  serviceCoroutine: CoroutineFiber;
begin
  serviceCoroutine := ServiceContext as CoroutineFiber;

  serviceCoroutine.SwitchTo();
end;

//{ IOFutureImpl }
//
//function IOFutureImpl.GetBytesTransferred: UInt64;
//begin
//  result := FBytesTransferred;
//end;
//
//function IOFutureImpl.GetHandler: IOHandler;
//begin
//  result :=
//    procedure(const Res: OpResult; const BytesTransferred: UInt64)
//    var
//      serviceHandler: IOServiceCoroutineHandler;
//    begin
//      FResult := Res;
//      FBytesTransferred := BytesTransferred;
//
//      // make sure service context coroutine switches back to us
//      // this ensures the handler is fully processed before
//      // execution is switched back to us
//      serviceHandler := ServiceContext as IOServiceCoroutineHandler;
//      serviceHandler.SetHandlerCoroutine(Coroutine);
//    end;
//end;
//
//function IOFutureImpl.GetResult: OpResult;
//begin
//  result := FResult;
//end;

end.
