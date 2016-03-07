unit AsyncIO.Coroutine.Detail;

interface

uses
  AsyncIO, AsyncIO.OpResults;

type
  CoroutineFiber = interface
    ['{EDF6A454-9887-4605-A84C-CFB6F07E7F4D}']
    procedure SwitchTo;
  end;

  IYieldContext = interface
    procedure Wait;
    procedure SetServiceHandlerCoroutine;
  end;

implementation


end.
