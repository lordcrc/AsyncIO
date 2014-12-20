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

  endp := Endpoint(IPAddress('1234:abcd::1'), 0);
  WriteLn('IPv6 connection endpoint: ' + endp);

  WriteLn;
end;

procedure TestResolve;
var
  qry: IPResolver.Query;
  res: IPResolver.Results;
  ip: IPResolver.Entry;
begin
  qry := Query(IPProtocol.TCPProtocol.Unspecified, 'google.com', '80', [ResolveAllMatching]);
  res := IPResolver.Resolve(qry);

  WriteLn('Resolved ' + qry.HostName + ':' + qry.ServiceName + ' as');
  for ip in res do
  begin
    WriteLn('  ' + ip.Endpoint.Address);
  end;
end;

procedure RunSocketTest;
begin
//  TestAddress;
  TestEndpoint;
  TestResolve;
end;

end.
