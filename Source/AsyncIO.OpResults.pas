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

unit AsyncIO.OpResults;

interface

uses
  WinAPI.Windows, System.SysUtils;

type
  // abstract base for various categories
  OpResultCategory = class;
  OpCategory = class of OpResultCategory;

  OpResult = record
  strict private
    FValue: integer;
    FCategory: OpCategory;

    function GetMessage: string;
    function GetSuccess: boolean;
  public
    class function Create(const ResultValue: integer; const ResultCategory: OpCategory): OpResult; overload; static;

    procedure RaiseException(const AdditionalInfo: string = '');

    property Value: integer read FValue;
    property Category: OpCategory read FCategory;

    property Success: boolean read GetSuccess;
    property Message: string read GetMessage;

    class operator Equal(const A: OpResult; const B: OpResult): boolean;
    class operator NotEqual(const A: OpResult; const B: OpResult): boolean;
  end;

  OpResultCategory = class
  public
    class function IsSuccess(const ResultValue: integer): boolean; virtual; abstract;
    class function Message(const ResultValue: integer): string; virtual; abstract;
    class function Equivalent(const ResultValue: integer; const OtherResult: OpResult): boolean; virtual; abstract;
    class procedure RaiseException(const ResultValue: integer; const AdditionalInfo: string); virtual; abstract;
  end;

  EGenericError = class(Exception);
  GenericCategory = class(OpResultCategory)
  public
    class function IsSuccess(const ResultValue: integer): boolean; override;
    class function Message(const ResultValue: integer): string; override;
    class function Equivalent(const ResultValue: integer; const OtherResult: OpResult): boolean; override;
    class procedure RaiseException(const ResultValue: integer; const AdditionalInfo: string); override;
  end;

  GenericResults = record
    class function Success: OpResult; static;
    class function EndOfFile: OpResult; static;
  end;

  SystemCategory = class(OpResultCategory)
  public
    class function IsSuccess(const ResultValue: integer): boolean; override;
    class function Message(const ResultValue: integer): string; override;
    class function Equivalent(const ResultValue: integer; const OtherResult: OpResult): boolean; override;
    class procedure RaiseException(const ResultValue: integer; const AdditionalInfo: string); override;
  end;

  SystemResults = record
    class function Success: OpResult; static;
    class function LastError: OpResult; static;
    class function EndOfFile: OpResult; static;
    class function OperationAborted: OpResult; static;
    class function WaitTimeout: OpResult; static;
  end;

function SystemResult(const ResultValue: DWORD): OpResult;

implementation

uses
  IdWinsock2;

function SystemResult(const ResultValue: DWORD): OpResult;
begin
  result := OpResult.Create(integer(ResultValue), SystemCategory);
end;

{ OpResult }

class function OpResult.Create(const ResultValue: integer; const ResultCategory: OpCategory): OpResult;
begin
  result.FValue := ResultValue;
  result.FCategory := ResultCategory;
end;

class operator OpResult.Equal(const A, B: OpResult): boolean;
begin
  if (A.Category = B.Category) then
  begin
    result := (A.Value = B.Value)
  end
  else
  begin
    result := A.Category.Equivalent(A.Value, B)
      or B.Category.Equivalent(B.Value, A);
  end;
end;

function OpResult.GetMessage: string;
begin
  result := Category.Message(Value);
end;

function OpResult.GetSuccess: boolean;
begin
  result := Category.IsSuccess(Value);
end;

class operator OpResult.NotEqual(const A, B: OpResult): boolean;
begin
  result := not (A = B);
end;

procedure OpResult.RaiseException(const AdditionalInfo: string);
begin
  Category.RaiseException(Value, AdditionalInfo);
end;

type
  GenericResultCodes = (
    ResultSuccess,
    ResultEndOfFile
  );

const
  GenericResultMessages: array[GenericResultCodes] of string = (
    'Success',
    'End of file'
  );

function GenericResult(ResultCode: GenericResultCodes): OpResult;
begin
  result := OpResult.Create(Ord(ResultCode), GenericCategory);
end;

{ GenericCategory }

class function GenericCategory.Equivalent(const ResultValue: integer;
  const OtherResult: OpResult): boolean;
begin
  result := False;
end;

class function GenericCategory.IsSuccess(const ResultValue: integer): boolean;
begin
  result := (GenericResultCodes(ResultValue) = ResultSuccess);
end;

class function GenericCategory.Message(const ResultValue: integer): string;
begin
  if ((ResultValue < Ord(Low(GenericResultCodes))) and (ResultValue > Ord(High(GenericResultCodes)))) then
    raise EArgumentException.Create('GenericCategory.Message: Invalid result value');

  result := GenericResultMessages[GenericResultCodes(ResultValue)];
end;

class procedure GenericCategory.RaiseException(const ResultValue: integer; const AdditionalInfo: string);
begin
  raise EGenericError.Create(Message(ResultValue) + AdditionalInfo);
end;

{ GenericResults }

class function GenericResults.EndOfFile: OpResult;
begin
  result := GenericResult(ResultEndOfFile);
end;

class function GenericResults.Success: OpResult;
begin
  result := GenericResult(ResultSuccess);
end;

{ SystemCategory }

class function SystemCategory.Equivalent(const ResultValue: integer;
  const OtherResult: OpResult): boolean;
begin
  result := False;

  if (OtherResult.Category = GenericCategory) then
  begin
    case ResultValue of
      ERROR_SUCCESS: result := (OtherResult = GenericResults.Success);
      ERROR_HANDLE_EOF: result := (OtherResult = GenericResults.EndOfFile);
    end;
  end;
end;

class function SystemCategory.IsSuccess(
  const ResultValue: integer): boolean;
begin
  result := (DWORD(ResultValue) = ERROR_SUCCESS);
end;

class function SystemCategory.Message(const ResultValue: integer): string;
begin
  result := SysErrorMessage(DWORD(ResultValue));
end;

class procedure SystemCategory.RaiseException(const ResultValue: integer; const AdditionalInfo: string);
begin
  RaiseLastOSError(DWORD(ResultValue), AdditionalInfo);
end;

{ SystemResults }

class function SystemResults.EndOfFile: OpResult;
begin
  result := SystemResult(ERROR_HANDLE_EOF);
end;

class function SystemResults.LastError: OpResult;
begin
  result := SystemResult(GetLastError());
end;

class function SystemResults.OperationAborted: OpResult;
begin
  result := SystemResult(ERROR_OPERATION_ABORTED);
end;

class function SystemResults.Success: OpResult;
begin
  result := SystemResult(ERROR_SUCCESS);
end;

class function SystemResults.WaitTimeout: OpResult;
begin
  result := SystemResult(WAIT_TIMEOUT);
end;


end.
