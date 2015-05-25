program AsyncFileCopy;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AsyncIO.Detail.StreamBufferImpl in '..\..\Source\AsyncIO.Detail.StreamBufferImpl.pas',
  AsyncIO.Detail in '..\..\Source\AsyncIO.Detail.pas',
  AsyncIO.ErrorCodes in '..\..\Source\AsyncIO.ErrorCodes.pas',
  AsyncIO.Filesystem.Detail in '..\..\Source\AsyncIO.Filesystem.Detail.pas',
  AsyncIO.Filesystem in '..\..\Source\AsyncIO.Filesystem.pas',
  AsyncIO in '..\..\Source\AsyncIO.pas',
  AsyncFileCopy.Impl in 'AsyncFileCopy.Impl.pas';

procedure PrintUsage;
begin
  WriteLn('Usage:');
  WriteLn;
  WriteLn('  AsyncFileCopy source dest');
  WriteLn;
  WriteLn('  source    Source filename');
  WriteLn('  dest      Destination filename');
  WriteLn;
end;

procedure Run(const SourceFilename, DestFilename: string);
var
  ios: IOService;
  copier: AsyncFileCopier;
  progressHandler: IOProgressHandler;
  r: Int64;
begin
  progressHandler :=
    procedure(const TotalBytesRead, TotalBytesWritten: UInt64; const ReadBPS, WriteBPS: double)
    begin
      Write(Format(#13'Read: %3d MB (%.2f MB/s) | Written: %3d MB (%.2f MB/s)           ',
        [TotalBytesRead shr 20, ReadBPS, TotalBytesWritten shr 20, WriteBPS]));
    end;

  ios := NewIOService();
  copier := NewAsyncFileCopier(ios, progressHandler);

  copier.Execute(SourceFilename, DestFilename);

  r := ios.Run;

  WriteLn;
  WriteLn(Format('%d handlers executed', [r]));
end;

begin
  try
    if (ParamCount() < 2) then
      PrintUsage
    else
      Run(ParamStr(1), ParamStr(2));
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
