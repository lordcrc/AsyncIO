unit AsyncIO.Test.Socket;

interface

procedure RunSocketTest;

implementation

uses
  System.SysUtils, System.DateUtils, AsyncIO, AsyncIO.ErrorCodes, AsyncIO.Net.IP;

procedure TestAddress;
var
  addr4: IPv4Address;
  addr6: IPv6Address;

  addr: IPAddress;
begin
  addr4 := IPv4Address.Loopback;
  addr := addr4;
  WriteLn('IPv4 loopback: ' + addr);

  addr6 := IPv6Address.Loopback;
  addr := addr6;
  WriteLn('IPv6 loopback: ' + addr);

  addr := IPAddress('192.168.42.2');
  WriteLn('IP address: ' + addr);
  WriteLn('   is IPv4: ' + BoolToStr(addr.IsIPv4, True));
  WriteLn('   is IPv6: ' + BoolToStr(addr.IsIPv6, True));

  addr := IPAddress('abcd::1%42');
  WriteLn('IP address: ' + addr);
  WriteLn('   is IPv4: ' + BoolToStr(addr.IsIPv4, True));
  WriteLn('   is IPv6: ' + BoolToStr(addr.IsIPv6, True));
  WriteLn(' has scope: ' + IntToStr(addr.AsIPv6.ScopeID));

  WriteLn;
end;

procedure TestEndpoint;
var
  endp: IPEndpoint;
begin
  endp := Endpoint(IPAddressFamily.v6, 1234);
  WriteLn('IPv6 listening endpoint: ' + endp);

  endp := Endpoint(IPAddress('192.168.42.1'), 9876);
  WriteLn('IPv4 connection endpoint: ' + endp);

  WriteLn;
end;

procedure TestResolve;
begin

end;

procedure RunSocketTest;
begin
//  TestAddress;
  TestEndpoint;
  TestResolve;
end;

end.
