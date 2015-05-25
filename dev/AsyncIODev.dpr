program AsyncIODev;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AsyncIO.Test.Basic in 'AsyncIO.Test.Basic.pas',
  AsyncIO.Test.Copy in 'AsyncIO.Test.Copy.pas',
  AsyncIO.Test.Socket in 'AsyncIO.Test.Socket.pas',
  AsyncIO.Test.StreamReader in 'AsyncIO.Test.StreamReader.pas',
  AsyncIO.Test.AsyncReadUntil in 'AsyncIO.Test.AsyncReadUntil.pas',
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
  BufStream in '..\..\BufferedStreamReader\BufStream.pas',
  BufStreamReader in '..\..\BufferedStreamReader\BufStreamReader.pas',
  EncodingHelper in '..\..\BufferedStreamReader\EncodingHelper.pas',
  RegularExpr.Detail in '..\..\RegularExpr\RegularExpr.Detail.pas',
  RegularExpr in '..\..\RegularExpr\RegularExpr.pas';

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
