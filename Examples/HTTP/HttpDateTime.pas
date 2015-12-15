unit HttpDateTime;

interface

uses
  WinAPI.Windows, System.SysUtils;

function SystemTimeToHttpDate(const st: TSystemTime): string;
function TryHttpDateToSystemTime(const HttpDate: string; out st: TSystemTime): boolean;

function CurrentSystemTime: TSystemTime;
function CompareSystemTime(const A, B: TSystemTime): integer;

implementation

uses
  System.Types;

const
  WeekdayNames: array[0..6] of string = (
    'Sun', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Mon'
  );
  MonthNames: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  );

function SystemTimeToHttpDate(const st: TSystemTime): string;
begin
  if ((st.wDayOfWeek > 6) or (st.wMonth < 1) or (st.wMonth > 12)) then
    raise EConvertError.Create('SystemTimeToHTTPDate: Invalid date');

  result := Format('%s, %.2d %s %.4d %.2d:%.2d:%.2d GMT',
    [WeekdayNames[st.wDayOfWeek], st.wDay, MonthNames[st.wMonth], st.wYear, st.wHour, st.wMinute, st.wSecond]
  );
end;

function TryHttpDateToSystemTime(const HttpDate: string; out st: TSystemTime): boolean;
var
  dateElm: TArray<string>;
  i, ybase: integer;
  foundWeekday: boolean;
  foundMonth: boolean;
begin
  result := False;

  // transform both date formats to similar form
  dateElm := HttpDate.Replace('-', ' ').Replace(':', ' ').Split([' ']);

  if (Length(dateElm) <> 8) then
    exit;


  // weekday
  for i := Low(WeekdayNames) to High(WeekdayNames) do
  begin
    foundWeekday := dateElm[0].StartsWith(WeekdayNames[i]);
    if (foundWeekday) then
    begin
      st.wDayOfWeek := i;
      break;
    end;
  end;

  if (not foundWeekday) then
    exit;


  // day
  i := StrToIntDef(dateElm[1], -1);
  if ((i < 1) or (i > 31)) then
    exit;

  st.wDay := i;


  // month
  for i := Low(MonthNames) to High(MonthNames) do
  begin
    foundMonth := dateElm[2].StartsWith(MonthNames[i]);
    if (foundMonth) then
    begin
      st.wMonth := i;
      break;
    end;
  end;

  if (not foundMonth) then
    exit;


  // year
  i := StrToIntDef(dateElm[3], -1);
  if ((i < 1) or (i > 9999)) then
    exit;

  if (i < 100) then
  begin
    // hardcoded century window because that's what people who use 2-digit years get
    ybase := CurrentYear() - 50;
    i := i + ((ybase div 100) * 100);
    if (i < ybase) then
      i := i + 100;
  end;

  st.wYear := i;


  // hour
  i := StrToIntDef(dateElm[4], -1);
  if ((i < 0) or (i > 23)) then
    exit;

  st.wHour := i;


  // minute
  i := StrToIntDef(dateElm[5], -1);
  if ((i < 0) or (i > 59)) then
    exit;

  st.wMinute := i;


  // second
  i := StrToIntDef(dateElm[6], -1);
  if ((i < 0) or (i > 60)) then // accept leap seconds?
    exit;

  st.wSecond := i;


  // timezone required to be GMT per HTTP
  if (dateElm[7] <> 'GMT') then
    exit;

  result := True;
end;

function CompareSystemTime(const A, B: TSystemTime): integer;
var
  dateA, dateB: integer;
  timeA, timeB: integer;
begin
  dateA := (A.wYear * 10000) + (A.wMonth * 100) + A.wDay;
  dateB := (B.wYear * 10000) + (B.wMonth * 100) + B.wDay;

  timeA := (A.wHour * 10000) + (A.wMinute * 100) + A.wSecond;
  timeB := (B.wHour * 10000) + (B.wMinute * 100) + B.wSecond;

  if (dateA < dateB) then
  begin
    result := LessThanValue;
  end
  else if (dateA > dateB) then
  begin
    result := GreaterThanValue;
  end
  else if (timeA < timeB) then
  begin
    result := LessThanValue;
  end
  else if (timeA > timeB) then
  begin
    result := GreaterThanValue;
  end
  else
  begin
    result := EqualsValue;
  end;
end;

function CurrentSystemTime: TSystemTime;
begin
  GetSystemTime(result);
end;

end.
