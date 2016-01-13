unit AsyncIOTestCase;

interface

uses
  System.SysUtils, TestFramework, AsyncIO.OpResults;

type
  TAsyncIOTestCase = class(TTestCase)
  public
    procedure CheckEquals(expected, actual: OpResult; msg: string = ''); overload; virtual;
  end;


implementation

{ TAsyncIOTestCase }

procedure TAsyncIOTestCase.CheckEquals(expected, actual: OpResult; msg: string);
begin
  FCheckCalled := True;
  if (expected <> actual) then
    FailNotEquals(expected.Message, actual.Message, msg);
end;

end.
