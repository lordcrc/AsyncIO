//   Copyright 2014 Asbjørn Heid
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

unit AsyncIO.ErrorCodes;

interface

uses
  WinAPI.Windows;

type
  IOErrorCode = record
  strict private
    FErrorCode: DWORD;
    function GetMessage: string;
    function GetValue: DWORD;
  public
    class function Create(const ErrorCode: DWORD): IOErrorCode; overload; static;
    class function Create(): IOErrorCode; overload; static; // from last error

    property Message: string read GetMessage;
    property Value: DWORD read GetValue;

    class function Success: IOErrorCode; static;
    class function EndOfFile: IOErrorCode; static;

    class operator Implicit(const ec: IOErrorCode): boolean;
    class operator Equal(const A: IOErrorCode; const B: IOErrorCode): boolean;
    class operator NotEqual(const A: IOErrorCode; const B: IOErrorCode): boolean;
    class operator LogicalNot(const ec: IOErrorCode): boolean;
    class operator LogicalAnd(const ec: IOErrorCode; const Other: boolean): boolean;
    class operator LogicalAnd(const Other: boolean; const ec: IOErrorCode): boolean;
  end;


type
  WinsockResult = record
    Value: integer;

    class operator Implicit(const Value: integer): WinsockResult;
  end;

type
  GetAddrResult = record
    Value: integer;

    class operator Implicit(const Value: integer): GetAddrResult;
  end;

implementation

uses
  System.SysUtils, IdWinsock2;

{ IOErrorCode }

class function IOErrorCode.Create(const ErrorCode: DWORD): IOErrorCode;
begin
  result.FErrorCode := ErrorCode;
end;

class function IOErrorCode.Create: IOErrorCode;
begin
  result := Create(GetLastError);
end;

class function IOErrorCode.EndOfFile: IOErrorCode;
begin
  result := IOErrorCode.Create(ERROR_HANDLE_EOF);
end;

class operator IOErrorCode.Equal(const A, B: IOErrorCode): boolean;
begin
  result := A.FErrorCode = B.FErrorCode;
end;

function IOErrorCode.GetMessage: string;
begin
  result := SysErrorMessage(Value);
end;

function IOErrorCode.GetValue: DWORD;
begin
  result := FErrorCode;
end;

class operator IOErrorCode.Implicit(const ec: IOErrorCode): boolean;
begin
  result := ec.Value = ERROR_SUCCESS;
end;

class operator IOErrorCode.LogicalAnd(const Other: boolean;
  const ec: IOErrorCode): boolean;
begin
  result := Other and boolean(ec);
end;

class operator IOErrorCode.LogicalNot(const ec: IOErrorCode): boolean;
begin
  result := not boolean(ec);
end;

class operator IOErrorCode.NotEqual(const A, B: IOErrorCode): boolean;
begin
  result := A.FErrorCode <> B.FErrorCode;
end;

class operator IOErrorCode.LogicalAnd(const ec: IOErrorCode;
  const Other: boolean): boolean;
begin
  result := boolean(ec) and Other;
end;

class function IOErrorCode.Success: IOErrorCode;
begin
  result := IOErrorCode.Create(ERROR_SUCCESS);
end;

{ WinsockResult }

class operator WinsockResult.Implicit(const Value: integer): WinsockResult;
begin
  if (Value = SOCKET_ERROR) then
    RaiseLastOSError(WSAGetLastError);

  result.Value := Value;
end;

{ GetAddrResult }

class operator GetAddrResult.Implicit(const Value: integer): GetAddrResult;
begin
  if (Value <> 0) then
    RaiseLastOSError(WSAGetLastError);

  result.Value := Value;
end;

end.
