program AsyncIOTests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  TestInsight.Client,
  TestInsight.DUnit,
  DUnitTestRunner,
  Test.AsyncIO.Detail in 'Test.AsyncIO.Detail.pas',
  AsyncIO.Detail in '..\src\AsyncIO.Detail.pas',
  AsyncIO.Detail.StreamBufferImpl in '..\src\AsyncIO.Detail.StreamBufferImpl.pas',
  AsyncIO.ErrorCodes in '..\src\AsyncIO.ErrorCodes.pas',
  AsyncIO.Filesystem.Detail in '..\src\AsyncIO.Filesystem.Detail.pas',
  AsyncIO.Filesystem in '..\src\AsyncIO.Filesystem.pas',
  AsyncIO.Net.IP.Detail in '..\src\AsyncIO.Net.IP.Detail.pas',
  AsyncIO.Net.IP.Detail.TCPImpl in '..\src\AsyncIO.Net.IP.Detail.TCPImpl.pas',
  AsyncIO.Net.IP in '..\src\AsyncIO.Net.IP.pas',
  AsyncIO in '..\src\AsyncIO.pas',
  AsyncIO.StreamReader in '..\src\AsyncIO.StreamReader.pas',
  RegularExpr.Detail in '..\..\RegularExpr\RegularExpr.Detail.pas',
  RegularExpr in '..\..\RegularExpr\RegularExpr.pas',
  BufStream in '..\..\BufferedStreamReader\BufStream.pas',
  BufStreamReader in '..\..\BufferedStreamReader\BufStreamReader.pas',
  EncodingHelper in '..\..\BufferedStreamReader\EncodingHelper.pas',
  Test.AsyncIO.Net.IP in 'Test.AsyncIO.Net.IP.pas',
  NetTestCase in 'NetTestCase.pas',
  Test.AsyncIO.Net.IP.Detail.TCPImpl in 'Test.AsyncIO.Net.IP.Detail.TCPImpl.pas',
  Test.AsyncIO.Net.IP.Detail in 'Test.AsyncIO.Net.IP.Detail.pas',
  IPStreamSocketMock in 'IPStreamSocketMock.pas',
  EchoTestServer in 'EchoTestServer.pas';

{$R *.RES}

function IsTestInsightRunning: Boolean;
var
  client: ITestInsightClient;
begin
  client := TTestInsightRestClient.Create;
  client.StartedTesting(0);
  Result := not client.HasError;
end;

begin
  if IsTestInsightRunning then
    TestInsight.DUnit.RunRegisteredTests
  else
    DUnitTestRunner.RunRegisteredTests;
end.


