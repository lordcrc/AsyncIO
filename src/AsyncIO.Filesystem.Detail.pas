unit AsyncIO.Filesystem.Detail;

interface

uses
  AsyncIO, AsyncIO.Detail, AsyncIO.Filesystem;

type
  AsyncFileStreamImpl = class(AsyncHandleStreamImpl, AsyncFileStream)
  private
    FFilename: string;
  public
    constructor Create(const Service: IOService; const Filename: string;
      const CreationDisposition: FileCreationDisposition;
      const Access: FileAccess; const ShareMode: FileShareMode);

    function GetFilename: string;
  end;

implementation

uses
  WinAPI.Windows, System.SysUtils;

{ AsyncFileStreamImpl }

constructor AsyncFileStreamImpl.Create(const Service: IOService;
  const Filename: string; const CreationDisposition: FileCreationDisposition;
  const Access: FileAccess; const ShareMode: FileShareMode);
const
  AccessMapping: array[FileAccess] of DWORD = (GENERIC_READ, GENERIC_WRITE, GENERIC_READ or GENERIC_WRITE);
  CreationDispositionMapping: array[FileCreationDisposition] of DWORD = (CREATE_NEW, CREATE_ALWAYS, OPEN_EXISTING, OPEN_ALWAYS, TRUNCATE_EXISTING);
  ShareModeMapping: array[FileShareMode] of DWORD = (0, FILE_SHARE_DELETE, FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE);
var
  fh, cph: THandle;
  ac, sm, cd, flags: DWORD;
begin
  ac := AccessMapping[Access];
  sm := ShareModeMapping[ShareMode];
  cd := CreationDispositionMapping[CreationDisposition];

  flags := FILE_ATTRIBUTE_NORMAL or FILE_FLAG_OVERLAPPED;

  fh := CreateFile(PChar(Filename), ac, sm, nil, cd, flags, 0);

  if (fh = INVALID_HANDLE_VALUE) then
    RaiseLastOSError();

  // call create here
  // so that the handle is closed if the
  // CreateIoCompletionPort call below fails
  inherited Create(Service, fh);

  FFilename := Filename;
  IOServiceAssociateHandle(Service, fh);
end;

function AsyncFileStreamImpl.GetFilename: string;
begin
  result := FFilename;
end;

end.
