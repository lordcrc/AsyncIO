unit AsyncHttpServer.RequestParser;

interface

uses
  System.SysUtils, AsyncIO, AsyncHttpServer.Request;

type
  HttpRequestState = (
    HttpRequestStateNeedMoreData,
    HttpRequestStateValid,
    HttpRequestStateInvalid
  );

  HttpRequestParser = interface
    ['{02575C91-D940-4399-B2AD-BE943B6A3DAB}']

    function Parse(var Request: HttpRequest; const Buffer: StreamBuffer): HttpRequestState;

    function GetParsedData: TBytes;

    property ParsedData: TBytes read GetParsedData;
  end;

function NewHttpRequestParser: HttpRequestParser;

implementation

uses
  System.Math, AsyncHttpServer.Headers;

{$POINTERMATH ON}

type
  Octet = UInt8;
  POctet = ^Octet;

  OctetHelper = record helper for Octet
    function IsChar: boolean; overload;
    function IsChar(const C: char): boolean; overload;
    function IsCtl: boolean;
    function IsDigit: boolean;
    function IsSP: boolean;
    function IsHT: boolean;
    function IsToken: boolean;
    function IsTSpecial: boolean;
    function IsCR: boolean;
    function IsLF: boolean;

    function AsDigit: UInt8;
  end;

  ParserState = (
    RequestLineStart,
    Method,
    RequestURI,
    HTTPVersionH,
    HTTPVersionT1,
    HTTPVersionT2,
    HTTPVersionP,
    HTTPVersionSlash,
    HTTPVersionMajorStart,
    HTTPVersionMajorNext,
    HTTPVersionMinorStart,
    HTTPVersionMinorNext,
    RequestLineEnd,
    HeaderLineStart,
    HeaderLWS,
    HeaderName,
    HeaderNameValueSeparator,
    HeaderValue,
    HeaderLineEnd,
    RequestEnd,
    Done
  );

  HttpRequestParserImpl = class(TInterfacedObject, HttpRequestParser)
  strict private
    FState: ParserState;
    FCharMapping: array[Octet] of char;
    FParsedData: TBytes;
    FCurHeader: HttpHeader;

    function OctetAsChar(const Input: Octet): char;

    procedure CreateCharMapping(const Encoding: TEncoding);

    function ProcessInput(var Request: HttpRequest; const Input: Octet): HttpRequestState;

    property State: ParserState read FState write FState;
  public
    constructor Create;

    function GetParsedData: TBytes;

    function Parse(var Request: HttpRequest; const Buffer: StreamBuffer): HttpRequestState;
  end;

function NewHttpRequestParser: HttpRequestParser;
begin
  result := HttpRequestParserImpl.Create;
end;

function OctetHelper.AsDigit: UInt8;
begin
  result := (Self - Ord('0'));
end;

function OctetHelper.IsChar: boolean;
begin
  result := (Self <= 127);
end;

function OctetHelper.IsChar(const C: char): boolean;
begin
  result := IsChar() and (Self = Ord(C));
end;

function OctetHelper.IsCR: boolean;
begin
  result := (Self = 13);
end;

function OctetHelper.IsCtl: boolean;
begin
  result := (Self <= 31) or (Self = 127);
end;

function OctetHelper.IsDigit: boolean;
begin
  result := (Self >= Ord('0')) or (Self <= Ord('9'));
end;

function OctetHelper.IsHT: boolean;
begin
  result := (Self = 9);
end;

function OctetHelper.IsLF: boolean;
begin
  result := (Self = 10);
end;

function OctetHelper.IsSP: boolean;
begin
  result := (Self = 32);
end;

function OctetHelper.IsToken: boolean;
begin
  result := IsChar and (not IsCtl) and (not IsTSpecial);
end;

function OctetHelper.IsTSpecial: boolean;
begin
  result :=
    (Self.IsChar('(')) or
    (Self.IsChar(')')) or
    (Self.IsChar('<')) or
    (Self.IsChar('>')) or
    (Self.IsChar('@')) or
    (Self.IsChar(',')) or
    (Self.IsChar(';')) or
    (Self.IsChar(':')) or
    (Self.IsChar('\')) or
    (Self.IsChar('"')) or
    (Self.IsChar('/')) or
    (Self.IsChar('[')) or
    (Self.IsChar(']')) or
    (Self.IsChar('?')) or
    (Self.IsChar('=')) or
    (Self.IsChar('{')) or
    (Self.IsChar('}')) or
    IsSP or
    IsHT;
end;

{ HttpRequestParserImpl }

constructor HttpRequestParserImpl.Create;
begin
  inherited Create;

  // HTTP standard says to use system encoding so we do...
  CreateCharMapping(TEncoding.Default);
end;

procedure HttpRequestParserImpl.CreateCharMapping(const Encoding: TEncoding);
var
  input: Octet;
  b: TBytes;
  c: TArray<char>;
begin
  SetLength(b, 1);
  for input := Low(Octet) to High(Octet) do
  begin
    b[0] := input;

    c := Encoding.GetChars(b);

    if (Length(c) <> 1) then
      raise EArgumentException.Create('Encoding not compatible');

    FCharMapping[input] := c[0];
  end;
end;

function HttpRequestParserImpl.GetParsedData: TBytes;
begin
  result := FParsedData;
end;

function HttpRequestParserImpl.OctetAsChar(const Input: Octet): char;
begin
  result := FCharMapping[Input];
end;

function HttpRequestParserImpl.Parse(var Request: HttpRequest;
  const Buffer: StreamBuffer): HttpRequestState;
var
  i: UInt32;
  inputBuffer: MemoryBuffer;
  inputData: POctet;
  input: Octet;
begin
  result := HttpRequestStateNeedMoreData;

  while (Buffer.BufferSize > 0) and (result = HttpRequestStateNeedMoreData) do
  begin
    // prepare consume a block from the buffer
    inputBuffer := Buffer.PrepareConsume(Min(Buffer.BufferSize, MaxInt));

    inputData := inputBuffer.Data;
    i := 0;
    while (i < inputBuffer.Size) do
    begin
      input := inputData[i];
      result := ProcessInput(Request, input);

      i := i + 1;

      if (result <> HttpRequestStateNeedMoreData) then
        break;
    end;

    Buffer.Consume(i);
  end;
end;

function HttpRequestParserImpl.ProcessInput(var Request: HttpRequest;
  const Input: Octet): HttpRequestState;
begin
  Insert(Input, FParsedData, Length(FParsedData));

  case State of
    RequestLineStart: begin
      if (Input.IsToken) then
      begin
        State := Method;
        Request.Method := OctetAsChar(Input);
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    Method: begin
      if (Input.IsSP) then
      begin
        Request.URI := '';
        State := RequestURI;
        result := HttpRequestStateNeedMoreData;
      end
      else if (Input.IsToken) then
      begin
        Request.Method := Request.Method + OctetAsChar(Input);
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    RequestURI: begin
      if (Input.IsSP) then
      begin
        State := HTTPVersionH;
        result := HttpRequestStateNeedMoreData;
      end
      else if (not Input.IsCtl) then
      begin
        Request.URI := Request.URI + OctetAsChar(Input);
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionH: begin
      if (Input.IsChar('H')) then
      begin
        State := HTTPVersionT1;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionT1: begin
      if (Input.IsChar('T')) then
      begin
        State := HTTPVersionT2;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionT2: begin
      if (Input.IsChar('T')) then
      begin
        State := HTTPVersionP;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionP: begin
      if (Input.IsChar('P')) then
      begin
        State := HTTPVersionSlash;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionSlash: begin
      if (Input.IsChar('/')) then
      begin
        State := HTTPVersionMajorStart;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionMajorStart: begin
      Request.HttpVersionMajor := 0;
      Request.HttpVersionMinor := 0;

      if (Input.IsDigit) then
      begin
        Request.HttpVersionMajor := (Request.HttpVersionMajor * 10) + Input.AsDigit;
        State := HTTPVersionMajorNext;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionMajorNext: begin
      if (Input.IsChar('.')) then
      begin
        State := HTTPVersionMinorStart;
        result := HttpRequestStateNeedMoreData;
      end
      else if (Input.IsDigit) then
      begin
        Request.HttpVersionMajor := (Request.HttpVersionMajor * 10) + Input.AsDigit;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionMinorStart: begin
      if (Input.IsDigit) then
      begin
        Request.HttpVersionMinor := (Request.HttpVersionMinor * 10) + Input.AsDigit;
        State := HTTPVersionMinorNext;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HTTPVersionMinorNext: begin
      if (Input.IsCR()) then
      begin
        State := RequestLineEnd;
        result := HttpRequestStateNeedMoreData;
      end
      else if (Input.IsDigit) then
      begin
        Request.HttpVersionMinor := (Request.HttpVersionMinor * 10) + Input.AsDigit;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    RequestLineEnd: begin
      if (Input.IsLF) then
      begin
        State := HeaderLineStart;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HeaderLineStart: begin
      if (Input.IsCR) then
      begin
        Request.Headers.Append(FCurHeader);
        FCurHeader := EmptyHttpHeader();
        State := RequestEnd;
        result := HttpRequestStateNeedMoreData;
      end
      else if ((not Request.Headers.IsEmpty) and (Input.IsSP or Input.IsHT)) then
      begin
        State := HeaderLWS;
        result := HttpRequestStateNeedMoreData;
      end
      else if (Input.IsToken) then
      begin
        Request.Headers.Append(FCurHeader);
        FCurHeader.Name := OctetAsChar(Input);
        FCurHeader.Value := '';
        State := HeaderName;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HeaderLWS: begin
      if (Input.IsCR) then
      begin
        State := RequestLineEnd;
        result := HttpRequestStateNeedMoreData;
      end
      else if (Input.IsSP or Input.IsHT) then
      begin
        result := HttpRequestStateNeedMoreData;
      end
      else if (not Input.IsCtl) then
      begin
        FCurHeader.Value := FCurHeader.Value + OctetAsChar(Input);
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HeaderName: begin
      if (Input.IsChar(':')) then
      begin
        State := HeaderNameValueSeparator;
        result := HttpRequestStateNeedMoreData;
      end
      else if (Input.IsToken) then
      begin
        FCurHeader.Name := FCurHeader.Name + OctetAsChar(Input);
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HeaderNameValueSeparator: begin
      if (Input.IsSP) then
      begin
        State := HeaderValue;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HeaderValue: begin
      if (Input.IsCR) then
      begin
        State := HeaderLineEnd;
        result := HttpRequestStateNeedMoreData;
      end
      else if (not Input.IsCtl) then
      begin
        FCurHeader.Value := FCurHeader.Value + OctetAsChar(Input);
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    HeaderLineEnd: begin
      if (Input.IsLF) then
      begin
        State := HeaderLineStart;
        result := HttpRequestStateNeedMoreData;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    RequestEnd: begin
      if (Input.IsLF) then
      begin
        State := Done;
        result := HttpRequestStateValid;
      end
      else
      begin
        result := HttpRequestStateInvalid;
      end;
    end;

    Done: begin
      raise EProgrammerNotFound.Create('HttpRequestParser.Parse called after parsing completed');
    end;
  else
    raise EProgrammerNotFound.Create('HttpRequestParser in unknown parser state');
  end;
end;

end.
