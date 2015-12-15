unit AsyncHttpServer.Request;

interface

uses
  AsyncHttpServer.Headers;

type
  HttpRequest = record
    Method: string;
    URI: string;
    HttpVersionMajor: integer;
    HttpVersionMinor: integer;
    Headers: HttpHeaders;
  end;

function NewHttpRequest: HttpRequest;

implementation

function NewHttpRequest: HttpRequest;
begin
  result.HttpVersionMajor := 0;
  result.HttpVersionMinor := 0;
end;

end.
