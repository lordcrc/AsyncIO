unit NetTestCase;

interface

uses
  TestFramework, AsyncIO.Net.IP, AsyncIO.ErrorCodes;

type
  TNetTestCase = class(TTestCase)
  public
    procedure CheckEquals(expected, actual: IOErrorCode; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPv4Address; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPv6Address; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPAddress; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPEndpoint; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPProtocol; msg: string = ''); overload; virtual;
  end;


implementation

uses
  System.SysUtils;

{ TNetTestCase }

procedure TNetTestCase.CheckEquals(expected, actual: IOErrorCode; msg: string);
begin
  FCheckCalled := True;
  if (expected <> actual) then
    FailNotEquals(expected.Message, actual.Message, msg);
end;

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

procedure TNetTestCase.CheckEquals(expected, actual: IPAddress; msg: string);
begin
  FCheckCalled := True;
  if (expected <> actual) then
    FailNotEquals(expected, actual, msg);
end;

procedure TNetTestCase.CheckEquals(expected, actual: IPEndpoint; msg: string);
begin
  FCheckCalled := True;
  if (expected <> actual) then
    FailNotEquals(expected, actual, msg);
end;

procedure TNetTestCase.CheckEquals(expected, actual: IPProtocol; msg: string);
begin
  FCheckCalled := True;
  if (expected <> actual) then
    FailNotEquals(expected.ToString, actual.ToString, msg);
end;

end.
