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

implementation

uses
  System.SysUtils;

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

end.
