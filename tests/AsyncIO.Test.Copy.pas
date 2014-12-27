unit AsyncIO.Test.Copy;

interface

procedure RunCopyTest;

implementation

uses
  System.SysUtils, System.DateUtils, AsyncIO, AsyncIO.ErrorCodes, System.Math,
  AsyncIO.Filesystem;

type
  FileCopier = class
  private
    FBuffer: TBytes;
    FInputStream: AsyncFileStream;
    FOutputStream: AsyncFileStream;
    FTotalBytesRead: UInt64;
    FTotalBytesWritten: UInt64;
    FReadTimestamp: TDateTime;
    FWriteTimestamp: TDateTime;
    FReadTimeMSec: Int64;
    FWriteTimeMSec: Int64;
    FPrintTimestamp: TDateTime;
    FDoneReading: boolean;

    procedure ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure WriteHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure PrintProgress;
  public
    constructor Create(const Service: IOService; const InputFilename, OutputFilename: string);
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
    ios := NewIOService();

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
  end;
end;

{ FileCopier }

constructor FileCopier.Create(const Service: IOService; const InputFilename,
  OutputFilename: string);
begin
  inherited Create;

  SetLength(FBuffer, 1024*1024);
  FInputStream := NewAsyncFileStream(Service, InputFilename, fcOpenExisting, faRead, fsRead);
  FOutputStream := NewAsyncFileStream(Service, OutputFilename, fcCreateAlways, faWrite, fsNone);
  FDoneReading := False;

  Service.Post(
    procedure
    begin
      // queue read to start things
      FReadTimestamp := Now;
      AsyncRead(FInputStream, FBuffer, TransferAll(), ReadHandler);
    end
  );
end;

procedure FileCopier.PrintProgress;
begin
  if (MilliSecondsBetween(Now, FPrintTimestamp) < 500) then
    exit;

  Write(Format(#13'Read: %3d MB (%.2f MB/s) | Written: %3d MB (%.2f MB/s)         ',
    [FTotalBytesRead shr 20, FTotalBytesRead / (1e3 * Max(1, FReadTimeMSec)),
     FTotalBytesWritten shr 20, FTotalBytesWritten / (1e3 * Max(1, FWriteTimeMSec))]));
  FPrintTimestamp := Now;
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
  FReadTimeMSec := FReadTimeMSec + MilliSecondsBetween(Now, FReadTimestamp);
  PrintProgress;

  if (BytesTransferred = 0) then
    exit;

  // reading done, queue write
  FWriteTimestamp := Now;
  AsyncWrite(FOutputStream, FBuffer, TransferExactly(BytesTransferred), WriteHandler);
end;

procedure FileCopier.WriteHandler(const ErrorCode: IOErrorCode;
  const BytesTransferred: UInt64);
begin
  if (not ErrorCode) then
  begin
    RaiseLastOSError(ErrorCode.Value, 'While writing file');
  end;

  if (FDoneReading) then
    FPrintTimestamp := 0;

  FTotalBytesWritten := FTotalBytesWritten + BytesTransferred;
  FWriteTimeMSec := FWriteTimeMSec + MilliSecondsBetween(Now, FWriteTimestamp);
  PrintProgress;

  if (FDoneReading) then
    exit;

  // writing done and we got more to read, so queue read
  FReadTimestamp := Now;
  AsyncRead(FInputStream, FBuffer, TransferAll(), ReadHandler);
end;

end.
