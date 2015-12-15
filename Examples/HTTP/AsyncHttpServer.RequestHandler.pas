unit AsyncHttpServer.RequestHandler;

interface

uses
  AsyncIO, AsyncHttpServer.Mime, AsyncHttpServer.Request, AsyncHttpServer.Response;

type
  HttpRequestHandler = interface
    ['{AC26AF7B-589F-41D1-8449-995ECDADB2B4}']
    {$REGION 'Property accessors'}
    function GetService: IOService;
    {$ENDREGION}

    function HandleRequest(const Request: HttpRequest): HttpResponse;

    property Service: IOService read GetService;
  end;

function NewHttpRequestHandler(const Service: IOService; const DocRoot: string; const Mime: MimeRegistry): HttpRequestHandler;

implementation

uses
  WinAPI.Windows, System.SysUtils, System.Math, System.IOUtils, EncodingHelper,
  AsyncIO.Filesystem, AsyncHttpServer.Headers, HttpDateTime;

const
  HTTP_GET_METHOD = 'GET';
  HTTP_HEAD_METHOD = 'HEAD';

// I shouldn't complain, it's not even a decade since Vista was released...
function GetFileSizeEx(hFile: THandle; out lpFileSize: int64): BOOL; stdcall; external kernel32;

type
  URLParts = record
    Path: string;
    Query: string;
  end;

function DecodeURLSegment(const Input: string; out Output: string; const PlusToSpace: boolean): boolean;
var
  i, v: integer;
  c: char;
  hs: string;
  validHex: boolean;
  encc: string;
begin
  result := False;
  Output := '';

  i := 0;
  while (i < Input.Length) do
  begin
    c := Input.Chars[i];
    if (c = '%') then
    begin
      hs := '$' + Input.Substring(i+1, 2);
      if (hs.Length <> 3) then
        exit;

      validHex := TryStrToInt(hs, v);
      if (not validHex) then
        exit;

      // assume encoded character is in default encoding
      encc := TEncoding.Default.GetString(PByte(@v), 0, 1);
      Output := Output + encc;
      i := i + 3;
    end
    else if (PlusToSpace and (c = '+')) then
    begin
      Output := Output + ' ';
      i := i + 1;
    end
    else
    begin
      Output := Output + c;
      i := i + 1;
    end;
  end;

  result := True;
end;

function DecodeURL(const URL: string; out Decoded: URLParts): boolean;
var
  path: string;
  query: string;
  paramIndex, queryIndex, pathEndIndex: integer;
begin
  // here we assume the URL represents an absolute path

  paramIndex := URL.IndexOf(';');
  queryIndex := URL.IndexOf('?');

  path := '';
  query := '';

  if ((paramIndex < 0) and (queryIndex < 0)) then
  begin
    // no path parameters nor query segment
    path := URL;
  end
  else
  begin
    if ((paramIndex < 0) or ((queryIndex >= 0) and (queryIndex < paramIndex))) then
    begin
      pathEndIndex := queryIndex; // no path parameter separator in path segment
    end
    else
    begin
      pathEndIndex := paramIndex; // path stops at path parameter separator
    end;

    path := URL.Substring(0, pathEndIndex);

    if (queryIndex > 0) then
    begin
      query := URL.Substring(queryIndex + 1, URL.Length);
    end;
  end;

  // now to decode the segments
  result := DecodeURLSegment(path, Decoded.Path, False);
  if (not result) then
    exit;

  result := DecodeURLSegment(query, Decoded.Query, True);
  if (not result) then
    exit;
end;

type
  HttpRequestHandlerImpl = class(TInterfacedObject, HttpRequestHandler)
  strict private
    FService: IOService;
    FDocRoot: string;
    FMime: MimeRegistry;

    function GetFullPath(const Filename: string): string;

    function GetFileModifiedTime(const FileStream: AsyncFileStream): TSystemTime;
    function GetFileSize(const FileStream: AsyncFileStream): Int64;

    procedure Log(const Msg: string);
  public
    constructor Create(const Service: IOService; const DocRoot: string; const Mime: MimeRegistry);

    function GetService: IOService;

    function HandleRequest(const Request: HttpRequest): HttpResponse;

    property Service: IOService read FService;
    property DocRoot: string read FDocRoot;
    property Mime: MimeRegistry read FMime;
  end;

function NewHttpRequestHandler(const Service: IOService; const DocRoot: string; const Mime: MimeRegistry): HttpRequestHandler;
begin
  result := HttpRequestHandlerImpl.Create(Service, DocRoot, Mime);
end;

{ HttpRequestHandlerImpl }

constructor HttpRequestHandlerImpl.Create(const Service: IOService; const DocRoot: string; const Mime: MimeRegistry);
begin
  inherited Create;

  FService := Service;
  FDocRoot := IncludeTrailingPathDelimiter(DocRoot);
  FMime := Mime;
end;

function HttpRequestHandlerImpl.GetFileSize(
  const FileStream: AsyncFileStream): Int64;
var
  res: boolean;
begin
  res := GetFileSizeEx(FileStream.Handle, result);
  if (not res) then
    RaiseLastOSError();
end;

function HttpRequestHandlerImpl.GetFileModifiedTime(
  const FileStream: AsyncFileStream): TSystemTime;
var
  res: boolean;
  mt: TFileTime;
begin
  res := WinAPI.Windows.GetFileTime(FileStream.Handle, nil, nil, @mt);
  if (not res) then
    RaiseLastOSError();

  res := WinAPI.Windows.FileTimeToSystemTime(mt, result);
  if (not res) then
    RaiseLastOSError();
end;

function HttpRequestHandlerImpl.GetFullPath(const Filename: string): string;
var
  p: TArray<string>;
  i: integer;
begin
  result := '';

  p := Filename.Split(['/']);

  // we know start of Filename starts with / and ends with a filename
  Delete(p, 0, 1);
  i := 0;
  while (i < Length(p)) do
  begin
    if (p[i] = '..') then
    begin
      // check if we're attempting to escape root
      if (i < 1) then
        exit;

      i := i - 1;
      Delete(p, i, 2);
    end
    else
    begin
      i := i + 1;
    end;
  end;

  result := DocRoot + string.Join(PathDelim, p);
end;

function HttpRequestHandlerImpl.GetService: IOService;
begin
  result := FService;
end;

function HttpRequestHandlerImpl.HandleRequest(const Request: HttpRequest): HttpResponse;
var
  url: URLParts;
  urlValid: boolean;
  filename: string;
  fileExists: boolean;
  contentStream: AsyncFileStream;
  fileSize: Int64;
  modifiedTime: TSystemTime;
  hasIfModifiedSinceTime: boolean;
  ifModifiedSinceTime: TSystemTime;
  contentModified: boolean;
  contentType: string;
begin
  try
    if (Request.HttpVersionMajor <> 1) then
    begin
      result := StandardResponse(StatusNotImplemented);
      exit;
    end;

    if ((Request.Method <> HTTP_GET_METHOD) and (Request.Method <> HTTP_HEAD_METHOD)) then
    begin
      result := StandardResponse(StatusNotImplemented);
      exit;
    end;

    urlValid := DecodeURL(Request.URI, url);

    // require absolute path
    urlValid := urlValid
      and (url.Path.Length > 0)
      and (url.Path.Chars[0] = '/')
      and (url.Path.IndexOf('//') < 0);

    if (not urlValid) then
    begin
      result := StandardResponse(StatusBadRequest);
      exit;
    end;

    filename := url.Path;
    if (filename.EndsWith('/')) then
      filename := filename + 'index.html';

    filename := GetFullPath(filename);

    // check if all went well with resolving the full path
    // and that file actually exists
    fileExists := (filename <> '') and TFile.Exists(filename);

    if (not fileExists) then
    begin
      result := StandardResponse(StatusNotFound);
      exit;
    end;

    // all looking good
    // now to open the file and get the details for the headers
    contentStream := NewAsyncFileStream(Service, filename, fcOpenExisting, faRead, fsRead);

    fileSize := GetFileSize(contentStream);
    modifiedTime := GetFileModifiedTime(contentStream);
    // TESTING
    //DateTimeToSystemTime(Now(), modifiedTime);
    contentType := Mime.FileExtensionToMimeType(ExtractFileExt(filename));

    hasIfModifiedSinceTime := TryHttpDateToSystemTime(Request.Headers.Value['If-Modified-Since'], ifModifiedSinceTime);

    if (hasIfModifiedSinceTime) then
    begin
      contentModified := CompareSystemTime(modifiedTime, ifModifiedSinceTime) > 0;

      if (not contentModified) then
      begin
        // content not modified, so we just send a standard 304 response
        result := StandardResponse(StatusNotModified);
        exit;
      end;
    end;

    result.Status := StatusOK;
    result.Headers.Value['Content-Length'] := IntToStr(fileSize);
    result.Headers.Value['Content-Type'] := contentType;
    result.Headers.Value['Last-Modified'] := SystemTimeToHttpDate(modifiedTime);

    // only send content if we've been asked to
    if (Request.Method = HTTP_GET_METHOD) then
    begin
      result.Content := nil;
      result.ContentStream := contentStream;
    end;
  except
    on E: Exception do
    begin
      Log('Error processing request');
      Log(Format('Exception: [%s] %s', [E.ClassName, E.Message]));
      Log(Format('Request: %s %s HTTP/%d.%d', [Request.Method, Request.URI, Request.HttpVersionMajor, '.', Request.HttpVersionMinor]));

      result := StandardResponse(StatusInternalServerError);
    end;
  end;
end;

procedure HttpRequestHandlerImpl.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

end.
