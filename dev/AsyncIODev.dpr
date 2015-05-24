program AsyncIODev;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AsyncIO.ErrorCodes in '..\src\AsyncIO.ErrorCodes.pas',
  AsyncIO in '..\src\AsyncIO.pas',
  AsyncIO.Detail in '..\src\AsyncIO.Detail.pas',
  AsyncIO.Filesystem in '..\src\AsyncIO.Filesystem.pas',
  AsyncIO.Filesystem.Detail in '..\src\AsyncIO.Filesystem.Detail.pas',
  AsyncIO.Net.IP in '..\src\AsyncIO.Net.IP.pas',
  AsyncIO.Net.IP.Detail in '..\src\AsyncIO.Net.IP.Detail.pas',
  AsyncIO.Net.IP.Detail.TCPImpl in '..\src\AsyncIO.Net.IP.Detail.TCPImpl.pas',
  AsyncIO.StreamReader in '..\src\AsyncIO.StreamReader.pas',
  AsyncIO.Test.Basic in 'AsyncIO.Test.Basic.pas',
  AsyncIO.Test.Copy in 'AsyncIO.Test.Copy.pas',
  AsyncIO.Test.Socket in 'AsyncIO.Test.Socket.pas',
  AsyncIO.Test.StreamReader in 'AsyncIO.Test.StreamReader.pas',
  AsyncIO.Detail.StreamBufferImpl in '..\src\AsyncIO.Detail.StreamBufferImpl.pas',
  AsyncIO.Test.AsyncReadUntil in 'AsyncIO.Test.AsyncReadUntil.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  try
//    RunBasicTest;
//    RunCopyTest;
    RunSocketTest;
//    RunStreamReaderTest;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ReadLn;
end.
