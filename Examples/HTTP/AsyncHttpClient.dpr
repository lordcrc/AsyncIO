program AsyncHttpClient;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  BufStream in '..\..\..\BufferedStreamReader\BufStream.pas',
  BufStreamReader in '..\..\..\BufferedStreamReader\BufStreamReader.pas',
  EncodingHelper in '..\..\..\BufferedStreamReader\EncodingHelper.pas',
  RegularExpr.Detail in '..\..\..\RegularExpr\RegularExpr.Detail.pas',
  RegularExpr in '..\..\..\RegularExpr\RegularExpr.pas',
  AsyncIO.Detail in '..\..\Source\AsyncIO.Detail.pas',
  AsyncIO.Detail.StreamBufferImpl in '..\..\Source\AsyncIO.Detail.StreamBufferImpl.pas',
  AsyncIO.OpResults in '..\..\Source\AsyncIO.OpResults.pas',
  AsyncIO.Net.IP.Detail in '..\..\Source\AsyncIO.Net.IP.Detail.pas',
  AsyncIO.Net.IP.Detail.TCPImpl in '..\..\Source\AsyncIO.Net.IP.Detail.TCPImpl.pas',
  AsyncIO.Net.IP in '..\..\Source\AsyncIO.Net.IP.pas',
  AsyncIO in '..\..\Source\AsyncIO.pas',
  AsyncIO.StreamReader in '..\..\Source\AsyncIO.StreamReader.pas',
  AsyncHttpClient.Impl in 'AsyncHttpClient.Impl.pas';

procedure PrintUsage;
begin
  WriteLn('Usage:');
  WriteLn;
  WriteLn('  AsyncHttpClient url [filename]');
  WriteLn;
  WriteLn('  url       URL to retrieve');
  WriteLn('  filename  Filename where response is written,');
  WriteLn('            default is response.dat');
  WriteLn;
end;

procedure SaveDataToFile(const Data: TBytes; const Filename: string);
var
  s: TBytesStream;
begin
  s := nil;
  try
    s := TBytesStream.Create(Data);
    s.SaveToFile(Filename);
  finally
    s.Free;
  end;
end;

function IsBinaryData(const Data: TBytes): boolean;
var
  i: NativeInt;
begin
  result := False;
  for I := 0 to High(Data) do
  begin
    if (Data[i] = 0) then
      exit;
  end;
  result := True;
end;

procedure Run(const URL: string; const ResponseFilename: string);
var
  ios: IOService;
  httpClient: AsyncHttpCli;
  responseHandler: HttpClientResponseHandler;
  r: Int64;
begin
  responseHandler :=
    procedure(const Headers: string; const ResponseData: TArray<UInt8>)
    var
      s: string;
    begin
      // rejoin split header lines
      s := Headers;
      s := StringReplace(s, #13#10#32, '', [rfReplaceAll]);
      s := StringReplace(s, #13#10#9, '', [rfReplaceAll]);

      WriteLn('HTTP response headers:');
      WriteLn(s);

      SaveDataToFile(ResponseData, ResponseFilename);
    end;

  ios := NewIOService();
  httpClient := NewAsyncHttpClient(ios, responseHandler);
  httpClient.ProgressHandler :=
    procedure(const Status: string)
    begin
      WriteLn(Status);
    end;

  httpClient.Get(URL);

  r := ios.Run;

  WriteLn;
  WriteLn(Format('%d handlers executed', [r]));
end;

var
  url: string;
  filename: string;
begin
  try
    if (ParamCount() < 1) then
      PrintUsage
    else
    begin
      url := ParamStr(1);

      filename := 'response.dat';
      if (ParamCount() >= 2) then
        filename := ParamStr(2);

      Run(url, filename);
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
