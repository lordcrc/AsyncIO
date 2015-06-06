unit AsyncIO.Test.AsyncReadUntil;

interface

procedure RunAsyncReadUntilDelimTest;

implementation

uses
  System.SysUtils, System.Classes,
  AsyncIO, AsyncIO.ErrorCodes, AsyncIO.Filesystem;

type
  FileReader = class
  private
    FInputStream: AsyncFileStream;
    FOutputStream: TStringStream;
    FBuffer: StreamBuffer;
    procedure HandleRead(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Service: IOService; const Filename: string);
  end;


procedure RunAsyncReadUntilDelimTest;
var
  inputFilename: string;
  ios: IOService;
  reader: FileReader;
  r: Int64;
begin
  ios := nil;
  reader := nil;
  try
    ios := NewIOService();

    inputFilename := ParamStr(1);

    if (inputFilename = '') then
      raise Exception.Create('Missing command line parameter');

    reader := FileReader.Create(ios, inputFilename);

    r := ios.Run;

    WriteLn(Format('%d handlers executed', [r]));

  finally
    reader.Free;
  end;
end;

{ FileReader }

constructor FileReader.Create(const Service: IOService; const Filename: string);
begin
  inherited Create;

  FInputStream := NewAsyncFileStream(Service, Filename, fcOpenExisting, faRead, fsNone);
  FOutputStream := TStringStream.Create('', TEncoding.ASCII, False);
  FBuffer := StreamBuffer.Create();

  AsyncReadUntil(FInputStream, FBuffer, [13, 10], HandleRead);
end;

procedure FileReader.HandleRead(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
begin
//  if (ErrorCode) then
//  begin
//    if (ErrorCode = IOErrorCode.EndOfFile) then
//    begin
//      WriteLn(Format('Finished reading %d bytes from file', [FBytesRead]));
//      exit;
//    end;
//
//    WriteLn('Error: ' + ErrorCode.Message);
//    exit;
//  end;

  if (ErrorCode <> IOErrorCode.EndOfFile) then
  begin
    WriteLn('Error: ' + ErrorCode.Message);
    FInputStream.Service.Stop;
    exit;
  end;

  WriteLn(Format('Read %d bytes from file', [BytesTransferred]));

  FInputStream.Service.Stop;
end;

end.
