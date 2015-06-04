unit AsyncFileCopy.Impl;

interface

uses
  System.SysUtils, System.DateUtils, AsyncIO, AsyncIO.ErrorCodes, System.Math,
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

function NewAsyncFileCopier(const Service: IOService; const ProgressHandler: IOProgressHandler; const BufferSize: integer = 1024*1024): AsyncFileCopier;

implementation

type
  AsyncFileCopierImpl = class(TInterfacedObject, AsyncFileCopier)
  private
    FService: IOService;
    FProgressHandler: IOProgressHandler;
    FBuffer: TBytes;
    FInputStream: AsyncFileStream;
    FOutputStream: AsyncFileStream;
    FTotalBytesRead: UInt64;
    FTotalBytesWritten: UInt64;
    FReadTimestamp: TDateTime;
    FWriteTimestamp: TDateTime;
    FReadTimeMSec: Int64;
    FWriteTimeMSec: Int64;
    FProgressTimestamp: TDateTime;
    FDoneReading: boolean;

    procedure StartReadOperation;
    procedure StartWriteOperation(const BytesToWrite: UInt64);

    procedure ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
    procedure WriteHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
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
begin
  FInputStream := NewAsyncFileStream(Service, InputFilename, fcOpenExisting, faRead, fsRead);
  FOutputStream := NewAsyncFileStream(Service, OutputFilename, fcCreateAlways, faWrite, fsNone);

  FDoneReading := False;

  Service.Post(
    procedure
    begin
      StartReadOperation;
    end
  );
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

procedure AsyncFileCopierImpl.ReadHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
begin
  if (not ErrorCode) and (ErrorCode <> IOErrorCode.EndOfFile) then
  begin
    RaiseLastOSError(ErrorCode.Value, 'Reading file');
  end;

  // check for EOF
  if (ErrorCode = IOErrorCode.EndOfFile) then
    FDoneReading := True;

  FTotalBytesRead := FTotalBytesRead + BytesTransferred;
  FReadTimeMSec := FReadTimeMSec + MilliSecondsBetween(Now, FReadTimestamp);

  ProgressUpdate;

  if (BytesTransferred = 0) then
    exit;

  // we've read some data, now queue write
  StartWriteOperation(BytesTransferred);
end;

procedure AsyncFileCopierImpl.StartReadOperation;
begin
  FReadTimestamp := Now;
  AsyncRead(FInputStream, FBuffer, TransferAll(), ReadHandler);
end;

procedure AsyncFileCopierImpl.StartWriteOperation(const BytesToWrite: UInt64);
begin
  FWriteTimestamp := Now;
  AsyncWrite(FOutputStream, FBuffer, TransferExactly(BytesToWrite), WriteHandler);
end;

procedure AsyncFileCopierImpl.WriteHandler(const ErrorCode: IOErrorCode; const BytesTransferred: UInt64);
begin
  if (not ErrorCode) then
  begin
    RaiseLastOSError(ErrorCode.Value, 'Writing file');
  end;

  if (FDoneReading) then
    FProgressTimestamp := 0;

  FTotalBytesWritten := FTotalBytesWritten + BytesTransferred;
  FWriteTimeMSec := FWriteTimeMSec + MilliSecondsBetween(Now, FWriteTimestamp);

  ProgressUpdate;

  if (FDoneReading) then
  begin
    // stopping to be improved
    Service.Stop;
  end
  else
  begin
    // writing done and we got more to read, so queue read
    StartReadOperation;
  end;
end;

end.
