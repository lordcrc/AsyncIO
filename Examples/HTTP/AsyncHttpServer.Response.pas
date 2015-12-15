unit AsyncHttpServer.Response;

interface

uses
  System.SysUtils, AsyncIO, AsyncHttpServer.Headers;

type
  HttpStatus = (
    StatusNoStatus = 0,
    StatusOK = 200,
    StatusCreated = 201,
    StatusAccepted = 202,
    StatusNoContent = 204,
    StatusMultipleChoices = 300,
    StatusMovedPermanently = 301,
    StatusMovedTemporarily = 302,
    StatusNotModified = 304,
    StatusBadRequest = 400,
    StatusUnauthorized = 401,
    StatusForbidden = 403,
    StatusNotFound = 404,
    StatusInternalServerError = 500,
    StatusNotImplemented = 501,
    StatusBadGateway = 502,
    StatusServiceUnavailable = 503
  );

  HttpStatusHelper = record helper for HttpStatus
    function ToString(): string;
  end;

  HttpResponse = record
    Status: HttpStatus;
    Headers: HttpHeaders;
    Content: TBytes;
    ContentStream: AsyncStream;

    // get a StreamBuffer containing the response, including Content
    // ContentStream needs to be handled separately if assigned
    // TODO - use array of MemoryBuffer once that's supported
    function ToBuffer(): StreamBuffer;
  end;

function StandardResponse(const Status: HttpStatus): HttpResponse;

implementation

uses
  System.Classes, Generics.Collections;

type
  TStreamHelper = class helper for TStream
    procedure WriteASCIIData(const s: string);
  end;

{ TStreamHelper }

procedure TStreamHelper.WriteASCIIData(const s: string);
var
  b: TBytes;
begin
  b := TEncoding.ASCII.GetBytes(s);
  Self.WriteBuffer(b, Length(b));
end;

{ HttpStatusHelper }

function HttpStatusHelper.ToString: string;
begin
  case Self of
    StatusOK:
      result := 'OK';
    StatusCreated:
      result := 'Created';
    StatusAccepted:
      result := 'Accepted';
    StatusNoContent:
      result := 'No Content';
    StatusMultipleChoices:
      result := 'Multiple Choices';
    StatusMovedPermanently:
      result := 'Moved Permanently';
    StatusMovedTemporarily:
      result := 'Moved Temporarily';
    StatusNotModified:
      result := 'Not Modified';
    StatusBadRequest:
      result := 'Bad Request';
    StatusUnauthorized:
      result := 'Unauthorized';
    StatusForbidden:
      result := 'Forbidden';
    StatusNotFound:
      result := 'Not Found';
    StatusInternalServerError:
      result := 'Internal ServerError';
    StatusNotImplemented:
      result := 'Not Implemented';
    StatusBadGateway:
      result := 'Bad Gateway';
    StatusServiceUnavailable:
      result := 'Service Unavailable';
  else
    raise EArgumentException.Create('Invalid HTTP status');
  end;
end;

function StandardResponse(const Status: HttpStatus): HttpResponse;
var
  s: string;
begin
  if (Status = StatusNotModified) then
  begin
    // no entity body for this one
    result.Status := Status;
    result.Content := nil;
    result.ContentStream := nil;
    result.Headers := nil;
  end
  else
  begin
    s := Status.ToString;
    s :=
     '<html>' +
     '<title>' + s + '</title>' +
     '<body><h1>' + IntToStr(Ord(Status)) + ' ' + s + '</h1></body>' +
     '</html>';

    result.Status := Status;
    result.Content := TEncoding.ASCII.GetBytes(s);
    result.ContentStream := nil;
    result.Headers := nil;
    result.Headers.Value['Content-Length'] := IntToStr(Length(result.Content));
    result.Headers.Value['Content-Type'] := 'text/html';
  end;
end;

{ HttpResponse }

function HttpResponse.ToBuffer: StreamBuffer;
var
  i: integer;
begin
  // so currently this is very sub-optimal
  // however without scattered buffer support it's the best we can do
  result := StreamBuffer.Create();

  result.Stream.WriteASCIIData('HTTP/1.0 ' + IntToStr(Ord(Status)) + ' ' + Status.ToString + #13#10);

  for i := 0 to High(Headers) do
  begin
    result.Stream.WriteASCIIData(Headers[i].Name);
    result.Stream.WriteASCIIData(': ');
    result.Stream.WriteASCIIData(Headers[i].Value);
    result.Stream.WriteASCIIData(#13#10); // CRLF
  end;

  result.Stream.WriteASCIIData(#13#10); // CRLF

  if (Length(Content) > 0) then
  begin
    result.Stream.WriteBuffer(Content, Length(Content));
  end;
end;

end.
