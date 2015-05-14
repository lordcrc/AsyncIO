unit AsyncIO.StreamReader;

interface

uses
  System.SysUtils, System.Classes;

type
  StreamReader = interface
    {$REGION 'Property accessors'}
    function GetEncoding: TEncoding;
    function GetStream: TStream;
    function GetOwnsSourceStream: boolean;
    function GetEndOfStream: boolean;
    {$ENDREGION}

    /// <summary>
    ///  <para>
    ///  Reads up to Count characters from the source stream. Returns an empty
    ///  array if there's an error decoding the characters.
    ///  </para>
    /// </summary>
    function ReadChars(const CharCount: integer): TCharArray;

    /// <summary>
    ///  <para>
    ///  Reads a single line of text from the source stream.
    ///  Line breaks detected are LF, CR and CRLF.
    ///  </para>
    ///  <para>
    ///  If no more data can be read from the source stream, it
    ///  returns an empty string.
    ///  </para>
    /// </summary>
    function ReadLine: string;

    /// <summary>
    ///  <para>
    ///  Reads text from the source stream until a delimiter is found or
    ///  the end of the source stream is reached.
    ///  </para>
    ///  <para>
    ///  If no more data can be read from the source stream, it
    ///  returns an empty string.
    ///  </para>
    /// </summary>
    function ReadUntil(const Delimiter: UInt8): string; overload;

    /// <summary>
    ///  <para>
    ///  Reads text from the source stream until a text delimiter is found or
    ///  the end of the source stream is reached. The delimiter is encoded using
    ///  the current Encoding, and the encoded delimiter is used for matching.
    ///  </para>
    ///  <para>
    ///  If no more data can be read from the source stream, it
    ///  returns an empty string.
    ///  </para>
    /// </summary>
    function ReadUntil(const Delimiter: string): string; overload;

    /// <summary>
    ///  <para>
    ///  Reads any remaining text from the source stream.
    ///  </para>
    ///  <para>
    ///  If no more data can be read from the source stream, it
    ///  returns an empty string.
    ///  </para>
    /// </summary>
    function ReadToEnd: string;

    /// <summary>
    ///  <para>
    ///  Encoding of the text to be read.
    ///  </para>
    /// </summary>
    property Encoding: TEncoding read GetEncoding;

    /// <summary>
    ///  The buffered stream. Use this if you need to read aditional
    ///  (possibly binary) data after reading text.
    /// </summary>
    property Stream: TStream read GetStream;
    property OwnsSourceStream: boolean read GetOwnsSourceStream;

    /// <summary>
    ///  True if the end of the source stream was detected during the previous
    ///  read operation.
    /// </summary>
    property EndOfStream: boolean read GetEndOfStream;
  end;

function NewStreamReader(const Encoding: TEncoding; const Stream: TStream; const OwnsStream: boolean = False): StreamReader;

implementation

uses
  BufStreamReader;

type
  StreamReaderImpl = class(TInterfacedObject, StreamReader)
  strict private
    FStreamReader: BufferedStreamReader;
  public
    constructor Create(const Encoding: TEncoding; const Stream: TStream; const OwnsStream: boolean);
    destructor Destroy; override;

    function GetEncoding: TEncoding;
    function GetStream: TStream;
    function GetOwnsSourceStream: boolean;
    function GetEndOfStream: boolean;

    function ReadChars(const CharCount: Integer): System.TArray<System.Char>;
    function ReadLine: string;
    function ReadUntil(const Delimiter: Byte): string; overload;
    function ReadUntil(const Delimiter: string): string; overload;

    function ReadToEnd: string;
  end;

function NewStreamReader(const Encoding: TEncoding; const Stream: TStream; const OwnsStream: boolean): StreamReader;
begin
  result := StreamReaderImpl.Create(Encoding, Stream, OwnsStream);
end;

{ StreamReaderImpl }

constructor StreamReaderImpl.Create(const Encoding: TEncoding;
  const Stream: TStream; const OwnsStream: boolean);
var
  opts: BufferedStreamReaderOptions;
begin
  inherited Create;

  opts := [];
  if OwnsStream then
    Include(opts, BufferedStreamReaderOwnsSource);

  FStreamReader := BufferedStreamReader.Create(Stream, Encoding, opts);
end;

destructor StreamReaderImpl.Destroy;
begin
  FStreamReader.Free;

  inherited;
end;

function StreamReaderImpl.GetEncoding: TEncoding;
begin
  result := FStreamReader.Encoding;
end;

function StreamReaderImpl.GetEndOfStream: boolean;
begin
  result := FStreamReader.EndOfStream;
end;

function StreamReaderImpl.GetOwnsSourceStream: boolean;
begin
  result := FStreamReader.OwnsSourceStream;
end;

function StreamReaderImpl.GetStream: TStream;
begin
  result := FStreamReader.Stream;
end;

function StreamReaderImpl.ReadChars(const CharCount: Integer): System.TArray<System.Char>;
begin
  result := FStreamReader.ReadChars(CharCount);
end;

function StreamReaderImpl.ReadLine: string;
begin
  result := FStreamReader.ReadLine;
end;

function StreamReaderImpl.ReadToEnd: string;
begin
  result := FStreamReader.ReadToEnd;
end;

function StreamReaderImpl.ReadUntil(const Delimiter: string): string;
begin
  result := FStreamReader.ReadUntil(Delimiter);
end;

function StreamReaderImpl.ReadUntil(const Delimiter: Byte): string;
begin
  result := FStreamReader.ReadUntil(Delimiter);
end;

end.
