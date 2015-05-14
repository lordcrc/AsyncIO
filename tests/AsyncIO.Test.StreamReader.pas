unit AsyncIO.Test.StreamReader;

interface

procedure RunStreamReaderTest;

implementation

uses
  System.SysUtils, System.Classes, AsyncIO.StreamReader;


function unc(const s: string): string;
begin
  result := TEncoding.UTF8.GetString(TEncoding.UTF8.GetBytes(s));
end;

procedure Test1;
var
  s1, s2, s3: string;
  r1, r2, r3, r4: string;
  enc: TEncoding;
  b: TBytes;
  bs: TBytesStream;
  sr: StreamReader;
begin
  s1 := 'This is a test';
  s2 := 'Это тест';
  s3 := 'これはテストです';

  enc := TEncoding.UTF8;

  b := enc.GetBytes(s1 + #13#10 + s2 + #13#10 + #13#10 + s3);

  bs := TBytesStream.Create(b);
  sr := NewStreamReader(enc, bs, True);

  r1 := sr.ReadLine;
  r2 := sr.ReadLine;
  r4 := sr.ReadLine;
  r3 := sr.ReadLine;

  if (not SameStr(r1, s1)) then
    WriteLn('Test1 error, r1 <> s1');
  if (not SameStr(r2, s2)) then
    WriteLn('Test1 error, r2 <> s2');
  if (not SameStr(r3, s3)) then
    WriteLn('Test1 error, r3 <> s3');
  if (not SameStr(r4, '')) then
    WriteLn('Test1 error, r4 <> ''''');
end;

procedure RunStreamReaderTest;
begin
  Test1;
end;

end.
