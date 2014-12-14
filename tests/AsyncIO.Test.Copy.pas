unit AsyncIO.Test.Copy;

interface

procedure RunCopyTest;

implementation

uses
  System.SysUtils, AsyncIO, AsyncIO.ErrorCodes;

type
  FileCopier = class
  private
    FBuffer: TBytes;
    FInputStream: AsyncFileStream;
    FOutputStream: AsyncFileStream;
    FTotalBytesRead: UInt64;
    FTotalBytesWritten: UInt64;
    FDoneReading: boolean;

    procedure ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure WriteHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure PrintProgress;
  public
    constructor Create(const Service: IOService; const InputFilename, OutputFilename: string);
    destructor Destroy; override;
  end;

procedure RunCopyTest;
var
  inputFilename, outputFilename: string;
  ios: IOService;
  copier: FileCopier;
  r: Int64;
begin
  ios := nil;
  copier := nil;
  try
    ios := IOService.Create;

    ios.Initialize();

    inputFilename := ParamStr(1);
    outputFilename := ParamStr(2);

    if (inputFilename = '') or (outputFilename = '') then
      raise Exception.Create('Missing command line parameters');

    copier := FileCopier.Create(ios, inputFilename, outputFilename);

    r := ios.Poll;

    WriteLn;
    WriteLn(Format('%d handlers executed', [r]));

  finally
    copier.Free;
    ios.Free;
  end;
end;

{ FileCopier }

constructor FileCopier.Create(const Service: IOService; const InputFilename,
  OutputFilename: string);
begin
  inherited Create;

  SetLength(FBuffer, 1024*1024);
  FInputStream := AsyncFileStream.Create(Service, InputFilename, fcOpenExisting, faRead, fsRead);
  FOutputStream := AsyncFileStream.Create(Service, OutputFilename, fcCreateAlways, faWrite, fsNone);
  FDoneReading := False;

  Service.Post(
    procedure
    begin
      // queue read to start things
      AsyncRead(FInputStream, FBuffer, TransferAll(), ReadHandler);
    end
  );
end;

destructor FileCopier.Destroy;
begin
  FInputStream.Free;
  FOutputStream.Free;

  inherited;
end;

procedure FileCopier.PrintProgress;
begin
  Write(Format(#13'Read: %3d MB / Written: %3d MB       ', [FTotalBytesRead shr 20, FTotalBytesWritten shr 20]));
end;

procedure FileCopier.ReadHandler(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
begin
  if (not ErrorCode) and (ErrorCode <> IOErrorCode.EndOfFile) then
  begin
    RaiseLastOSError(ErrorCode.Value, 'While reading file');
  end;

  if (ErrorCode = IOErrorCode.EndOfFile) then
    FDoneReading := True;

  FTotalBytesRead := FTotalBytesRead + BytesTransferred;
  PrintProgress;

  if (BytesTransferred = 0) then
    exit;

  // reading done, queue write
  AsyncWrite(FOutputStream, FBuffer, TransferExactly(BytesTransferred), WriteHandler);
end;

procedure FileCopier.WriteHandler(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
begin
  if (not ErrorCode) then
  begin
    RaiseLastOSError(ErrorCode.Value, 'While writing file');
  end;

  FTotalBytesWritten := FTotalBytesWritten + BytesTransferred;
  PrintProgress;

  if (FDoneReading) then
    exit;

  // writing done and we got more to read, so queue read
  AsyncRead(FInputStream, FBuffer, TransferAll(), ReadHandler);
end;

end.
