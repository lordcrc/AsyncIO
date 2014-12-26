program AsyncIOTest;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AsyncIO.ErrorCodes in '..\src\AsyncIO.ErrorCodes.pas',
  AsyncIO in '..\src\AsyncIO.pas',
  AsyncIO.Detail in '..\src\AsyncIO.Detail.pas',
  AsyncIO.Net.IP in '..\src\AsyncIO.Net.IP.pas',
  AsyncIO.Net.IP.Detail in '..\src\AsyncIO.Net.IP.Detail.pas',
  AsyncIO.Net.IP.Detail.TCPImpl in '..\src\AsyncIO.Net.IP.Detail.TCPImpl.pas',
  AsyncIO.Test.Basic in 'AsyncIO.Test.Basic.pas',
  AsyncIO.Test.Copy in 'AsyncIO.Test.Copy.pas',
  AsyncIO.Test.Socket in 'AsyncIO.Test.Socket.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  try
//    RunBasicTest;
//    RunCopyTest;

    RunSocketTest;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ReadLn;
end.
