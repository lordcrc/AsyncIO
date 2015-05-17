unit AsyncIO.Net.IP.Detail;

interface

uses
  AsyncIO, AsyncIO.Detail, AsyncIO.Net.IP;

const
//#define SO_UPDATE_CONNECT_CONTEXT   0x7010
  SO_UPDATE_CONNECT_CONTEXT = $7010;

type
  AsyncSocketStreamImpl = class(AsyncStreamImplBase, AsyncSocketStream)
  private
    FSocket: IPStreamSocket;
  public
    constructor Create(const Socket: IPStreamSocket);
    destructor Destroy; override;

    function GetSocket: IPStreamSocket;

    procedure AsyncReadSome(const Buffer: MemoryBuffer; const Handler: IOHandler); override;
    procedure AsyncWriteSome(const Buffer: MemoryBuffer; const Handler: IOHandler); override;

    property Socket: IPStreamSocket read FSocket;
  end;


implementation

{ AsyncSocketStreamImpl }

procedure AsyncSocketStreamImpl.AsyncReadSome(const Buffer: MemoryBuffer;
  const Handler: IOHandler);
begin
  Socket.AsyncReceive(Buffer, Handler);
end;

procedure AsyncSocketStreamImpl.AsyncWriteSome(const Buffer: MemoryBuffer;
  const Handler: IOHandler);
begin
  Socket.AsyncSend(Buffer, Handler);
end;

constructor AsyncSocketStreamImpl.Create(const Socket: IPStreamSocket);
begin
  inherited Create(Socket.Service);

  FSocket := Socket;
end;

destructor AsyncSocketStreamImpl.Destroy;
begin

  inherited;
end;

function AsyncSocketStreamImpl.GetSocket: IPStreamSocket;
begin
  result := FSocket;
end;

end.
