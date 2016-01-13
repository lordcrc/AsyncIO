unit NetTestCase;

interface

uses
  System.SysUtils, TestFramework, AsyncIOTestCase, AsyncIO.Net.IP;

type
  TNetTestCase = class(TAsyncIOTestCase)
  protected
    function GenerateData(const Length: integer): TBytes;
  public
    procedure CheckEquals(expected, actual: IPv4Address; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPv6Address; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPAddress; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPEndpoint; msg: string = ''); overload; virtual;
    procedure CheckEquals(expected, actual: IPProtocol; msg: string = ''); overload; virtual;
  end;


implementation

{ TNetTestCase }

function TNetTestCase.GenerateData(const Length: integer): TBytes;
var
  i: integer;
begin
  SetLength(result, Length);

  RandSeed := 1001;
  for i := 0 to Length-1 do
  begin
    result[i] := Random(256);
  end;
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
