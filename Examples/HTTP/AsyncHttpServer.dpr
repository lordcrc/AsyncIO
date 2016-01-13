program AsyncHttpServer;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  BufStream in '..\..\..\BufferedStreamReader\BufStream.pas',
  BufStreamReader in '..\..\..\BufferedStreamReader\BufStreamReader.pas',
  EncodingHelper in '..\..\..\BufferedStreamReader\EncodingHelper.pas',
  RegularExpr.Detail in '..\..\..\RegularExpr\RegularExpr.Detail.pas',
  RegularExpr in '..\..\..\RegularExpr\RegularExpr.pas',
  AsyncIO.Detail in '..\..\Source\AsyncIO.Detail.pas',
  AsyncIO.Detail.StreamBufferImpl in '..\..\Source\AsyncIO.Detail.StreamBufferImpl.pas',
  AsyncIO.OpResults in '..\..\Source\AsyncIO.OpResults.pas',
  AsyncIO.Filesystem.Detail in '..\..\Source\AsyncIO.Filesystem.Detail.pas',
  AsyncIO.Filesystem in '..\..\Source\AsyncIO.Filesystem.pas',
  AsyncIO.Net.IP.Detail in '..\..\Source\AsyncIO.Net.IP.Detail.pas',
  AsyncIO.Net.IP.Detail.TCPImpl in '..\..\Source\AsyncIO.Net.IP.Detail.TCPImpl.pas',
  AsyncIO.Net.IP in '..\..\Source\AsyncIO.Net.IP.pas',
  AsyncIO in '..\..\Source\AsyncIO.pas',
  AsyncIO.StreamReader in '..\..\Source\AsyncIO.StreamReader.pas',
  AsyncHttpServer.Impl in 'AsyncHttpServer.Impl.pas',
  AsyncHttpServer.Mime in 'AsyncHttpServer.Mime.pas',
  AsyncHttpServer.Headers in 'AsyncHttpServer.Headers.pas',
  AsyncHttpServer.Request in 'AsyncHttpServer.Request.pas',
  AsyncHttpServer.RequestParser in 'AsyncHttpServer.RequestParser.pas',
  AsyncHttpServer.Response in 'AsyncHttpServer.Response.pas',
  AsyncHttpServer.RequestHandler in 'AsyncHttpServer.RequestHandler.pas',
  AsyncHttpServer.Connection in 'AsyncHttpServer.Connection.pas',
  HttpDateTime in 'HttpDateTime.pas';

//function MakeRequestBuffer(const RequestData: string): StreamBuffer;
//var
//  data: TBytes;
//  buf: MemoryBuffer;
//begin
//  data := TEncoding.ASCII.GetBytes(RequestData);
//  result := StreamBuffer.Create();
//  buf := result.PrepareCommit(Length(data));
//  Move(data[0], buf.Data^, buf.Size);
//  result.Commit(buf.Size);
//end;
//
//procedure Run;
//var
//  r: HttpRequest;
//  p: HttpRequestParser;
//  req: string;
//  reqBuffer: StreamBuffer;
//  res: HttpRequestState;
//  hdr: HttpHeader;
//begin
//  r := NewHttpRequest;
//  p := NewHttpRequestParser;
//
//  req :=
//    'GET /index.html';
//
//  reqBuffer := MakeRequestBuffer(req);
//
//  res := p.Parse(r, reqBuffer);
//  if (res = HttpRequestStateNeedMoreData) then
//  begin
//    WriteLn('Indeterminate');
//  end
//  else if (res = HttpRequestStateInvalid) then
//  begin
//    WriteLn('Invalid');
//  end
//  else
//  begin
//    WriteLn('Valid');
//  end;
//
//  req :=
////    'GET /index.html HTTP/1.0' + #13#10 +
//    ' HTTP/1.0' + #13#10 +
//    'If-Modified-Since: Sat, 29 Oct 1994 19:43:31 GMT' + #13#10 +
//    'Referer: http://www.w3.org/hypertext' + #13#10 +
//    '  /DataSources/Overview.html' + #13#10 +
//    #13#10;
//
//  reqBuffer := MakeRequestBuffer(req);
//
//  res := p.Parse(r, reqBuffer);
//
//  if (res = HttpRequestStateNeedMoreData) then
//  begin
//    WriteLn('Indeterminate');
//  end
//  else if (res = HttpRequestStateInvalid) then
//  begin
//    WriteLn('Invalid');
//  end
//  else
//  begin
//    WriteLn('Valid');
//
//    WriteLn(r.Method);
//    WriteLn(r.URI);
//    WriteLn(r.HttpVersionMajor);
//    WriteLn(r.HttpVersionMinor);
//
//    for hdr in r.Headers do
//    begin
//      WriteLn(hdr.Name, ' => "', hdr.Value, '"');
//    end;
//  end;
//
//  WriteLn(reqBuffer.BufferSize);
//end;

//procedure Run;
//var
//  response: HttpResponse;
//  sb: StreamBuffer;
//  sr: StreamReader;
//  buf: MemoryBuffer;
//begin
//  response := StandardResponse(StatusNotModified);
//
//  sb := response.ToBuffer();
//
//  sb.Stream.Position := 0;
//
//  sr := NewStreamReader(TEncoding.ASCII, sb.Stream);
//
//  WriteLn(sr.ReadToEnd);
//end;

//procedure Run;
//var
//  service: IOService;
//  mime: MimeRegistry;
//  reqhandler: HttpRequestHandler;
//  request: HttpRequest;
//  response: HttpResponse;
//  header: HttpHeader;
//begin
//  service := NewIOService();
//  mime := NewMimeRegistry();
//  reqhandler := NewHttpRequestHandler(service, 'c:\temp\', mime);
//
//  request.Method := 'GET';
//  request.URI := '/music/171355.jpg';
//  request.HttpVersionMajor := 1;
//  request.HttpVersionMinor := 0;
//
//  response := reqhandler.HandleRequest(request);
//
//  WriteLn(response.Status.ToString());
//
//  for header in response.Headers do
//  begin
//    WriteLn(header.Name, ' = ', header.Value);
//  end;
//end;

procedure PrintUsage;
begin
  WriteLn('Usage:');
  WriteLn;
  WriteLn('  AsyncHttpServer docroot [localaddress] [port]');
  WriteLn;
  WriteLn('  docroot       Root directory for server');
  WriteLn('  localaddress  Address which server will listen on, default is 0.0.0.0');
  WriteLn('  port          Port which server will listen on, default is 80');
  WriteLn;
end;

procedure Run;
var
  localAddress: string;
  port: integer;
  docRoot: string;
  httpServer: AsyncHttpSrv;
  mime: MimeRegistry;
begin
  localAddress := '0.0.0.0';
  port := 80;

  if (ParamCount < 1) then
  begin
    PrintUsage;
    exit;
  end;

  docRoot := ParamStr(1);
  docRoot := TPath.GetFullPath(docRoot);

  if (not DirectoryExists(docRoot)) then
    raise EArgumentException.CreateFmt('DocRoot does not exist: "%s"', [docRoot]);

  if (ParamCount > 1) then
    localAddress := ParamStr(2);

  if (ParamCount > 2) then
    port := StrToIntDef(ParamStr(3), -1);

  if (port <= 0) then
    raise EArgumentException.CreateFmt('Invalid port: %d', [port]);

  mime := NewMimeRegistry;

  httpServer := NewAsyncHttpSrv(localAddress, port, docRoot, mime);
  httpServer.Run;
end;


begin
  try
    Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  WriteLn('Done...');
  ReadLn;
end.
