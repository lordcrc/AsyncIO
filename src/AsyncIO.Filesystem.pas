unit AsyncIO.Filesystem;

interface

uses
  AsyncIO;

type
  FileAccess = (faRead, faWrite, faReadWrite);

  FileCreationDisposition = (fcCreateNew, fcCreateAlways, fcOpenExisting, fcOpenAlways, fcTruncateExisting);

  FileShareMode = (fsNone, fsDelete, fsRead, fsWrite, fsReadWrite);

function NewAsyncFileStream(const Service: IOService;
  const Filename: string;
  const CreationDisposition: FileCreationDisposition;
  const Access: FileAccess;
  const ShareMode: FileShareMode): AsyncFileStream;

implementation

uses
  AsyncIO.Filesystem.Detail;

function NewAsyncFileStream(const Service: IOService;
  const Filename: string;
  const CreationDisposition: FileCreationDisposition;
  const Access: FileAccess;
  const ShareMode: FileShareMode): AsyncFileStream;
begin
  result := AsyncFileStreamImpl.Create(
    Service, Filename, CreationDisposition, Access, ShareMode
  );
end;

end.
