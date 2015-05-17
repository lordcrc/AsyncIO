unit NetTestCase;

interface

uses
  TestFramework, AsyncIO.Net.IP;

type
  TNetTestCase = class(TTestCase)
  public
    procedure CheckEquals(expected, actual: IPv4Address; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPv6Address; msg: string = ''); overload; virtual;
  end;


implementation

{ TNetTestCase }

procedure TNetTestCase.CheckEquals(expected, actual: IPv4Address; msg: string);
begin
  FCheckCalled := True;
  if (expected <> actual) then
    FailNotEquals(expected, actual, msg);
end;

procedure TNetTestCase.CheckEquals(expected, actual: IPv6Address; msg: string);
begin
  FCheckCalled := True;
  if (expected <> actual) then
    FailNotEquals(expected, actual, msg);
end;

end.
