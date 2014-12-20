program AsyncIOTest;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AsyncIO.ErrorCodes in '..\src\AsyncIO.ErrorCodes.pas',
  AsyncIO in '..\src\AsyncIO.pas',
  AsyncIO.Test.Basic in 'AsyncIO.Test.Basic.pas',
  AsyncIO.Test.Copy in 'AsyncIO.Test.Copy.pas',
  AsyncIO.Net.IP in '..\src\AsyncIO.Net.IP.pas';

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
