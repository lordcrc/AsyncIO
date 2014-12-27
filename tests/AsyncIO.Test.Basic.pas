unit AsyncIO.Test.Basic;

interface

procedure RunBasicTest;

implementation

uses
  System.SysUtils, AsyncIO, AsyncIO.ErrorCodes;

type
  FileScanner = class
  private
    FBuffer: TBytes;
    FStream: AsyncFileStream;
    FBytesRead: Int64;
    procedure DoReadData;
    procedure ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
  public
    constructor Create(const Service: IOService; const Filename: string);
    destructor Destroy; override;
  end;


procedure RunBasicTest;
var
  inputFilename: string;
  ios: IOService;
  scanner: FileScanner;
  r: Int64;
begin
  ios := nil;
  scanner := nil;
  try
    ios := NewIOService();

    inputFilename := ParamStr(1);

    if (inputFilename = '') then
      raise Exception.Create('Missing command line parameter');

    scanner := FileScanner.Create(ios, inputFilename);

    ios.Post(
      procedure
      begin
        WriteLn('One');
      end
    );
    ios.Post(
      procedure
      begin
        WriteLn('Two');
      end
    );

    r := ios.Poll;

    WriteLn(Format('%d handlers executed', [r]));

  finally
    scanner.Free;
  end;
end;

{ FileScanner }

constructor FileScanner.Create(const Service: IOService; const Filename: string);
begin
  inherited Create;

  SetLength(FBuffer, 4*1024*1024);
  FStream := AsyncFileStream.Create(Service, Filename, fcOpenExisting, faRead, fsNone);

  Service.Post(
    procedure
    begin
      DoReadData;
    end
  );
end;

destructor FileScanner.Destroy;
begin
  FStream.Free;

  inherited;
end;

procedure FileScanner.DoReadData;
begin
  FStream.AsyncReadSome(FBuffer, ReadHandler);
end;

procedure FileScanner.ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
begin
  if (not ErrorCode) then
  begin
    if (ErrorCode = IOErrorCode.EndOfFile) then
    begin
      WriteLn(Format('Finished reading %d bytes from file', [FBytesRead]));
      exit;
    end;

    WriteLn('Error: ' + ErrorCode.Message);
    exit;
  end;

  FBytesRead := FBytesRead + BytesTransferred;
  WriteLn(Format('Read %d bytes from file (total %d MB)', [BytesTransferred, FBytesRead shr 20]));

  DoReadData;
end;

end.
