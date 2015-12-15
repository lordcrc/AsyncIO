unit AsyncHttpServer.Mime;

interface

type
  MimeRegistry = interface
    ['{66E11440-29E8-4D27-B7BF-2D8D1EA52540}']

    function DefaultMimeType: string;
    function FileExtensionToMimeType(const Extension: string): string;
  end;

function NewMimeRegistry: MimeRegistry;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Win.Registry,
  System.Generics.Collections;

type
  MimeRegistryImpl = class(TInterfacedObject, MimeRegistry)
  strict private
    FLookupCache: TDictionary<string,string>;
    FRegistry: TRegistry;
  public
    constructor Create;
    destructor Destroy; override;

    function DefaultMimeType: string;
    function FileExtensionToMimeType(const Extension: string): string;
  end;

function NewMimeRegistry: MimeRegistry;
begin
  result := MimeRegistryImpl.Create;
end;

{ MimeRegistryImpl }

constructor MimeRegistryImpl.Create;
begin
  inherited Create;

  FLookupCache := TDictionary<string,string>.Create;
  FRegistry := TRegistry.Create;
  FRegistry.RootKey := HKEY_CLASSES_ROOT;
end;

function MimeRegistryImpl.DefaultMimeType: string;
begin
  result := 'text/plain';
end;

destructor MimeRegistryImpl.Destroy;
begin
  FLookupCache.Free;
  FRegistry.Free;
  
  inherited;
end;

function MimeRegistryImpl.FileExtensionToMimeType(
  const Extension: string): string;
var
  ext: string;
  validExtension: boolean;
  cachedValue: boolean;
  hasRegEntry: boolean;
begin
  validExtension := (Extension.StartsWith('.'));  
  if (not validExtension) then
    raise EArgumentException.CreateFmt('Invalid file extension: "%s"', [Extension]);

  // keep it simple  
  ext := Extension.ToLower;

  cachedValue := FLookupCache.TryGetValue(ext, result);
  if (cachedValue) then
    exit;
    
  // default is blank, meaning unknown
  result := '';
    
  hasRegEntry := FRegistry.OpenKeyReadOnly(ext);
  if (not hasRegEntry) then
    exit;

  try
    // returns blank if no Content Type value  
    result := FRegistry.ReadString('Content Type');   

    if (result <> '') then
      FLookupCache.Add(ext, result);
  finally
    FRegistry.CloseKey;
  end;
end;

end.
