unit AsyncHttpServer.Headers;

interface

type
  HttpHeader = record
    Name: string;
    Value: string;
  end;

//  HttpHeaderRef = record
//  public
//    type HttpHeaderPtr = ^HttpHeader;
//  strict private
//    FHeader: HttpHeaderPtr;
//
//    function GetName: string;
//    function GetValue: string;
//
//    procedure SetName(const Value: string);
//    procedure SetValue(const Value: string);
//  public
//    class operator Implicit(const HeaderPtr: HttpHeaderPtr): HttpHeaderRef;
//
//    property Name: string read GetName write SetName;
//    property Value: string read GetValue write SetValue;
//  end;

  HttpHeaders = TArray<HttpHeader>;

  HttpHeadersHelper = record helper for HttpHeaders
    {$REGION 'Property accessors'}
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);
    {$ENDREGION}

//    procedure Append; overload;
    procedure Append(const Header: HttpHeader); overload;

    function IsEmpty: boolean;

//    function Last: HttpHeaderRef;

    function ToDebugString: string;

    property Value[const Name: string]: string read GetValue write SetValue;
  end;

function EmptyHttpHeader(): HttpHeader;

implementation

uses
  System.SysUtils;

function EmptyHttpHeader(): HttpHeader;
begin
  result.Name := '';
  result.Value := '';
end;

//{ HttpHeaderRef }
//
//function HttpHeaderRef.GetName: string;
//begin
//  result := FHeader^.Name;
//end;
//
//function HttpHeaderRef.GetValue: string;
//begin
//  result := FHeader^.Value;
//end;
//
//class operator HttpHeaderRef.Implicit(
//  const HeaderPtr: HttpHeaderPtr): HttpHeaderRef;
//begin
//  result.FHeader := HeaderPtr;
//end;
//
//procedure HttpHeaderRef.SetName(const Value: string);
//begin
//  FHeader^.Name := Value;
//end;
//
//procedure HttpHeaderRef.SetValue(const Value: string);
//begin
//  FHeader^.Value := Value;
//end;

{ HttpHeadersHelper }

//procedure HttpHeadersHelper.Append;
//var
//  header: HttpHeader;
//begin
//  Self.Append(header);
//end;

procedure HttpHeadersHelper.Append(const Header: HttpHeader);
begin
  if (Header.Name = '') then
    exit;

  Insert(Header, Self, Length(Self));
end;

function HttpHeadersHelper.GetValue(const Name: string): string;
var
  i: integer;
begin
  result := '';
  for i := 0 to High(Self) do
  begin
    if (Self[i].Name = Name) then
    begin
      result := Self[i].Value;
      exit;
    end;
  end;
end;

function HttpHeadersHelper.IsEmpty: boolean;
begin
  result := (Length(Self) = 0);
end;

//function HttpHeadersHelper.Last: HttpHeaderRef;
//begin
//  if (Self.IsEmpty) then
//    raise EInvalidOpException.Create('HttpHeaders.Last called on empty instance');
//
//  result := @Self[High(Self)];
//end;

procedure HttpHeadersHelper.SetValue(const Name, Value: string);
var
  i: integer;
  header: HttpHeader;
begin
  for i := 0 to High(Self) do
  begin
    if (Self[i].Name = Name) then
    begin
      Self[i].Value := Value;
      exit;
    end;
  end;

  // append new header
  header.Name := Name;
  header.Value := Value;
  Self.Append(header);
end;

function HttpHeadersHelper.ToDebugString: string;
var
  h: HttpHeader;
begin
  result := '';
  for h in Self do
  begin
    result := result + #13#10 + '  ' + h.Name + ': ' + h.Value;
  end;
end;

end.
