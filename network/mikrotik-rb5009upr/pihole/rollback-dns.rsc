# One import block keeps local variables in scope across commands.
:do {
    # DNS rollback: unfiltered public DNS, independent of NAS.
    :local wan [/ip dhcp-client find where interface="sfp-sfpplus1"]
    :if ([:len $wan] > 1) do={ :error "Duplicate WAN DHCP clients" }
    :foreach identity in={"Pi-hole Home gateway DNS UDP";"Pi-hole Home gateway DNS TCP";"Pi-hole Guest gateway DNS UDP";"Pi-hole Guest gateway DNS TCP";"Pi-hole IoT gateway DNS UDP";"Pi-hole IoT gateway DNS TCP";"Pi-hole Cloud gateway DNS UDP";"Pi-hole Cloud gateway DNS TCP"} do={
        :if ([:len [/ip firewall nat find where comment=$identity]] > 1) do={ :error "Duplicate DNS NAT identity" }
    }
    :do {
        :local answer [:resolve "example.com" server=1.1.1.1]
        :if ([:len [:tostr $answer]] = 0) do={ :error "Empty public DNS answer" }
    } on-error={ :error "Public DNS probe failed; DNS settings unchanged" }
    :if ([:len $wan] = 1) do={ /ip dhcp-client set $wan use-peer-dns=no }
    /ip dns set servers=1.1.1.1 use-doh-server="" allow-remote-requests=yes
    # Stop gateway interception; DHCP still advertises the same router addresses.
    :foreach identity in={"Pi-hole Home gateway DNS UDP";"Pi-hole Home gateway DNS TCP";"Pi-hole Guest gateway DNS UDP";"Pi-hole Guest gateway DNS TCP";"Pi-hole IoT gateway DNS UDP";"Pi-hole IoT gateway DNS TCP";"Pi-hole Cloud gateway DNS UDP";"Pi-hole Cloud gateway DNS TCP"} do={
        :local row [/ip firewall nat find where comment=$identity]
        :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity" }
        :if ([:len $row] = 1) do={ /ip firewall nat disable $row }
    }
    /ip dns cache flush
}
