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
{$IFDEF TESTINSIGHT}
  TestInsight.Client,
  TestInsight.DUnit,
{$ENDIF}
  DUnitTestRunner,
  RegularExpr.Detail in '..\..\RegularExpr\RegularExpr.Detail.pas',
  RegularExpr in '..\..\RegularExpr\RegularExpr.pas',
  BufStream in '..\..\BufferedStreamReader\BufStream.pas',
  BufStreamReader in '..\..\BufferedStreamReader\BufStreamReader.pas',
  EncodingHelper in '..\..\BufferedStreamReader\EncodingHelper.pas',
  AsyncIO.Detail in '..\Source\AsyncIO.Detail.pas',
  AsyncIO.Detail.StreamBufferImpl in '..\Source\AsyncIO.Detail.StreamBufferImpl.pas',
  AsyncIO.ErrorCodes in '..\Source\AsyncIO.ErrorCodes.pas',
  AsyncIO.Filesystem.Detail in '..\Source\AsyncIO.Filesystem.Detail.pas',
  AsyncIO.Filesystem in '..\Source\AsyncIO.Filesystem.pas',
  AsyncIO.Net.IP.Detail in '..\Source\AsyncIO.Net.IP.Detail.pas',
  AsyncIO.Net.IP.Detail.TCPImpl in '..\Source\AsyncIO.Net.IP.Detail.TCPImpl.pas',
  AsyncIO.Net.IP in '..\Source\AsyncIO.Net.IP.pas',
  AsyncIO in '..\Source\AsyncIO.pas',
  AsyncIO.StreamReader in '..\Source\AsyncIO.StreamReader.pas',
  NetTestCase in 'NetTestCase.pas',
  IPStreamSocketMock in 'IPStreamSocketMock.pas',
  EchoTestServer in 'EchoTestServer.pas',
  Test.AsyncIO.Detail in 'Test.AsyncIO.Detail.pas',
  Test.AsyncIO.Net.IP in 'Test.AsyncIO.Net.IP.pas',
  Test.AsyncIO.Net.IP.Detail.TCPImpl in 'Test.AsyncIO.Net.IP.Detail.TCPImpl.pas',
  Test.AsyncIO.Net.IP.Detail in 'Test.AsyncIO.Net.IP.Detail.pas',
  EchoTestClient in 'EchoTestClient.pas';

{$R *.RES}

{$IFDEF TESTINSIGHT}
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
{$ELSE}
begin
  DUnitTestRunner.RunRegisteredTests;
{$ENDIF}
end.


