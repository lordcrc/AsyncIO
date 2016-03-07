unit AsyncFileCopy.Impl;

interface

uses
  System.SysUtils, System.DateUtils, AsyncIO, AsyncIO.OpResults, System.Math,
  AsyncIO.Filesystem;

type
  IOProgressHandler = reference to procedure(const TotalBytesRead, TotalBytesWritten: UInt64;
    const ReadBPS, WriteBPS: double);

  AsyncFileCopier = interface
  {$REGION Property accessors}
    function GetService: IOService;
  {$ENDREGION}

    procedure Execute(const InputFilename, OutputFilename: string);

    property Service: IOService read GetService;
  end;

function NewAsyncFileCopier(const Service: IOService; const ProgressHandler: IOProgressHandler; const BufferSize: integer = 4*1024): AsyncFileCopier;

implementation

uses
  AsyncIO.Coroutine;

type
  AsyncFileCopierImpl = class(TInterfacedObject, AsyncFileCopier)
  private
    FService: IOService;
    FProgressHandler: IOProgressHandler;
    FBuffer: TBytes;
    FTotalBytesRead: UInt64;
    FTotalBytesWritten: UInt64;
    FReadTimeMSec: Int64;
    FWriteTimeMSec: Int64;
    FProgressTimestamp: TDateTime;

    procedure ProgressUpdate;
  public
    constructor Create(const Service: IOService; const ProgressHandler: IOProgressHandler; const BufferSize: integer);

    function GetService: IOService;

    procedure Execute(const InputFilename, OutputFilename: string);

    property Service: IOService read FService;
  end;

function NewAsyncFileCopier(const Service: IOService; const ProgressHandler: IOProgressHandler; const BufferSize: integer): AsyncFileCopier;
begin
  result := AsyncFileCopierImpl.Create(Service, ProgressHandler, BufferSize);
end;

{ AsyncFileCopierImpl }

constructor AsyncFileCopierImpl.Create(const Service: IOService; const ProgressHandler: IOProgressHandler; const BufferSize: integer);
begin
  inherited Create;

  FService := Service;
  FProgressHandler := ProgressHandler;

  SetLength(FBuffer, BufferSize);
end;

procedure AsyncFileCopierImpl.Execute(const InputFilename, OutputFilename: string);
var
  inputStream: AsyncFileStream;
  outputStream: AsyncFileStream;
  serviceContext: IOServiceCoroutineContext;
  yield: YieldContext;
  readRes: IOResult;
  writeRes: IOResult;
  doneReading: boolean;
  readTimestamp: TDateTime;
  writeTimestamp: TDateTime;
begin
  inputStream := NewAsyncFileStream(Service, InputFilename, fcOpenExisting, faRead, fsRead);
  outputStream := NewAsyncFileStream(Service, OutputFilename, fcCreateAlways, faWrite, fsNone);

  serviceContext := NewIOServiceCoroutineContext(Service);
  yield := NewYieldContext(serviceContext);

  doneReading := False;

  while (True) do
  begin
    // queue the async read
    // this will return once the read has completed
    readTimestamp := Now;
    readRes := AsyncRead(inputStream, FBuffer, TransferAll(), yield);

    if (not readRes.Success) and (readRes <> SystemResults.EndOfFile) then
    begin
      readRes.RaiseException('Reading file');
    end;

    // check for EOF
    if (readRes = SystemResults.EndOfFile) then
      doneReading := True;

    FTotalBytesRead := FTotalBytesRead + readRes.BytesTransferred;
    FReadTimeMSec := FReadTimeMSec + MilliSecondsBetween(Now, readTimestamp);

    ProgressUpdate;

    if (readRes.BytesTransferred = 0) then
    begin
      // stopping to be improved
      Service.Stop;
      exit;
    end;

    // we've read some data, now queue write
    // again this will return once the write has completed
    writeTimestamp := Now;
    writeRes := AsyncWrite(outputStream, FBuffer, TransferExactly(readRes.BytesTransferred), yield);

    if (not writeRes.Success) then
    begin
      writeRes.RaiseException('Writing file');
    end;

    if (doneReading) then
      FProgressTimestamp := 0;

    FTotalBytesWritten := FTotalBytesWritten + writeRes.BytesTransferred;
    FWriteTimeMSec := FWriteTimeMSec + MilliSecondsBetween(Now, writeTimestamp);

    ProgressUpdate;

    if (doneReading) then
    begin
      // stopping to be improved
      Service.Stop;
      exit;
    end

    // writing done and we got more to read, so rinse repeat
  end;
end;

function AsyncFileCopierImpl.GetService: IOService;
begin
  result := FService;
end;

procedure AsyncFileCopierImpl.ProgressUpdate;
var
  readBPS, writeBPS: double;
begin
  if (not Assigned(FProgressHandler)) then
    exit;

  if (MilliSecondsBetween(Now, FProgressTimestamp) < 500) then
    exit;

  readBPS := FTotalBytesRead / (1e3 * Max(1, FReadTimeMSec));
  writeBPS := FTotalBytesWritten / (1e3 * Max(1, FWriteTimeMSec));

  FProgressHandler(FTotalBytesRead, FTotalBytesWritten, readBPS, writeBPS);

  FProgressTimestamp := Now;
end;

end.
