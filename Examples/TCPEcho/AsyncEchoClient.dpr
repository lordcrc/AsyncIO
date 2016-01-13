program AsyncEchoClient;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AsyncIO.Detail in '..\..\Source\AsyncIO.Detail.pas',
  AsyncIO.Detail.StreamBufferImpl in '..\..\Source\AsyncIO.Detail.StreamBufferImpl.pas',
  AsyncIO.OpResults in '..\..\Source\AsyncIO.OpResults.pas',
  AsyncIO.Net.IP.Detail in '..\..\Source\AsyncIO.Net.IP.Detail.pas',
  AsyncIO.Net.IP.Detail.TCPImpl in '..\..\Source\AsyncIO.Net.IP.Detail.TCPImpl.pas',
  AsyncIO.Net.IP in '..\..\Source\AsyncIO.Net.IP.pas',
  AsyncIO in '..\..\Source\AsyncIO.pas',
  AsyncEchoClient.Impl in 'AsyncEchoClient.Impl.pas';

procedure PrintUsage;
begin
  WriteLn('Usage:');
  WriteLn;
  WriteLn('  AsyncEchoClient host [port]');
  WriteLn;
  WriteLn('  host      Echo server hostname');
  WriteLn('  port      Port, default 7');
  WriteLn;
end;

procedure Run(const Host: string; const Port: integer);
var
  ios: IOService;
  echoClient: AsyncTCPEchoClient;
  progressHandler: EchoClientProgressHandler;
  data: TBytes;
  r: Int64;
begin
  progressHandler :=
    procedure(const Status: string)
    begin
      WriteLn(Status);
    end;

  data := TEncoding.UTF8.GetBytes('AsyncEchoClient test');

  ios := NewIOService();
  echoClient := NewAsyncTCPEchoClient(ios, progressHandler);

  echoClient.Execute(data, Host, Port);

  r := ios.Run;

  WriteLn;
  WriteLn(Format('%d handlers executed', [r]));
end;

var
  host: string;
  port: integer;
begin
  try
    if (ParamCount() < 1) then
      PrintUsage
    else
    begin
      host := ParamStr(1);

      if (ParamCount() < 2) then
        port := 7
      else
        port := StrToInt(ParamStr(2));

      Run(host, port);
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
