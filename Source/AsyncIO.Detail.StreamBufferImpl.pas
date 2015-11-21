unit AsyncIO.Detail.StreamBufferImpl;

interface

uses
  System.SysUtils, System.Classes, AsyncIO;

type
  StreamBufferImpl = class(TInterfacedObject, StreamBuffer.IStreamBuffer)
  strict private
    type
      StreamBufferStreamImpl = class(TStream)
      strict private
        FStreamBuffer: StreamBufferImpl;
        FPosition: Int64;
      protected
        function GetSize: Int64; override;
        procedure SetSize(NewSize: Longint); override;
        procedure SetSize(const NewSize: Int64); override;
      public
        constructor Create(const StreamBuffer: StreamBufferImpl);

        function Read(var Buffer; Count: Longint): Longint; override;
        function Write(const Buffer; Count: Longint): Longint; override;

        function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
      end;
  strict private
    FBuffer: TArray<Byte>;
    FMaxBufferSize: integer;
    FCommitPosition: UInt64;
    FCommitSize: UInt32;
    FConsumeSize: UInt64;
    FStream: TStream;
  public
    constructor Create(const MaxBufferSize: UInt64); overload;

    destructor Destroy; override;

    function GetData: pointer;
    function GetBufferSize: UInt64;
    function GetMaxBufferSize: UInt64;
    function GetStream: TStream;

    function PrepareCommit(const Size: UInt32): MemoryBuffer;
    procedure Commit(const Size: UInt32);

    function PrepareConsume(const Size: UInt32): MemoryBuffer;
    procedure Consume(const Size: UInt32);

    property BufferSize: UInt64 read GetBufferSize;
    property Data: pointer read GetData;
  end;

implementation

uses
  System.Math;

{$POINTERMATH ON}

{ StreamBufferImpl }

procedure StreamBufferImpl.Commit(const Size: UInt32);
begin
  if (Size > FCommitSize) then
    raise EArgumentException.Create('ByteStreamAdapter commit size larger than prepared size');

  SetLength(FBuffer, FCommitPosition + Size);
end;

procedure StreamBufferImpl.Consume(const Size: UInt32);
var
  len: UInt32;
begin
  if (Size > FConsumeSize) then
    raise EArgumentException.Create('ByteStreamAdapter consume size larger than prepared size');

  len := Length(FBuffer);
  Move(FBuffer[Size], FBuffer[0], len - Size);
  SetLength(FBuffer, len - Size);
end;

constructor StreamBufferImpl.Create(const MaxBufferSize: UInt64);
begin
  inherited Create;

  FMaxBufferSize := MaxBufferSize;
end;

destructor StreamBufferImpl.Destroy;
begin
  FStream.Free;
  inherited;
end;

function StreamBufferImpl.GetBufferSize: UInt64;
begin
  result := Length(FBuffer);
end;

function StreamBufferImpl.GetData: pointer;
begin
  result := @FBuffer[0];
end;

function StreamBufferImpl.GetMaxBufferSize: UInt64;
begin
  result := FMaxBufferSize;
end;

function StreamBufferImpl.GetStream: TStream;
begin
  if (FStream = nil) then
  begin
    FStream := StreamBufferStreamImpl.Create(Self);
  end;
  result := FStream;
end;

function StreamBufferImpl.PrepareCommit(const Size: UInt32): MemoryBuffer;
var
  bufSize: UInt32;
begin
  bufSize := Length(FBuffer);
  SetLength(FBuffer, bufSize + Size);

  FCommitSize := Size;
  FCommitPosition := bufSize;

  result := MakeBuffer(@FBuffer[FCommitPosition], FCommitSize);
end;

function StreamBufferImpl.PrepareConsume(const Size: UInt32): MemoryBuffer;
begin
  if (Size > BufferSize) then
    raise EArgumentException.Create('StreamBufferImpl.PrepareConsume size larger than buffer size');

  FConsumeSize := Size;

  result := MakeBuffer(FBuffer, FConsumeSize);
end;

{ StreamBufferImpl.StreamBufferStreamImpl }

constructor StreamBufferImpl.StreamBufferStreamImpl.Create(const StreamBuffer: StreamBufferImpl);
begin
  inherited Create;

  FStreamBuffer := StreamBuffer;
end;

function StreamBufferImpl.StreamBufferStreamImpl.GetSize: Int64;
begin
  result := FStreamBuffer.GetBufferSize;
end;

function StreamBufferImpl.StreamBufferStreamImpl.Read(var Buffer; Count: Integer): Longint;
var
  data: PByte;
  len: NativeInt;
begin
  result := 0;
  if (Count <= 0) then
    exit;
  if (FPosition < 0) then
    exit;
  if (FPosition >= FStreamBuffer.BufferSize) then
    exit;

  // non-consuming read
  data := PByte(FStreamBuffer.Data) + FPosition;
  len := Min(Int64(Count), FStreamBuffer.BufferSize - FPosition);
  Move(data^, Buffer, len);

  FPosition := FPosition + len;

  result := len;
end;

procedure StreamBufferImpl.StreamBufferStreamImpl.SetSize(NewSize: Integer);
begin
  SetSize(Int64(NewSize));
end;

function StreamBufferImpl.StreamBufferStreamImpl.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FPosition := Offset;
    soCurrent: FPosition := FPosition + Offset;
    soEnd: FPosition := FStreamBuffer.BufferSize - Offset;
  else
    raise ENotSupportedException.CreateFmt(
      'StreamBufferImpl.StreamBufferStreamImpl.Seek: Invalid seek origin (%d)',
      [Ord(Origin)]);
  end;
  result := FPosition;
end;

procedure StreamBufferImpl.StreamBufferStreamImpl.SetSize(const NewSize: Int64);
begin
  //raise ENotSupportedException.Create('StreamBufferStreamImpl.SetSize');
end;

function StreamBufferImpl.StreamBufferStreamImpl.Write(const Buffer; Count: Integer): Longint;
var
  buf: MemoryBuffer;
begin
  if (FPosition <> FStreamBuffer.BufferSize) then
    raise ENotSupportedException.Create('StreamBufferImpl.StreamBufferStreamImpl.Write: Unsupported writing position (must be at end of stream)');

  result := 0;
  if (Count <= 0) then
    exit;

  buf := FStreamBuffer.PrepareCommit(Count);

  Move(Buffer, buf.Data^, Count);

  FStreamBuffer.Commit(Count);

  FPosition := FPosition + Count;

  result := Count;
end;

end.
