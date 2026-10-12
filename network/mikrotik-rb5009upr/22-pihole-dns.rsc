# Gateway DNS interception: DNAT only, DHCP unchanged.
:do {
    :local instance [/container find where name="pihole"]
    :if ([:len $instance] != 1) do={ :error "One Pi-hole container required" }
    :if ([/container get $instance interface] != "veth-pihole") do={ :error "Unexpected Pi-hole interface" }
    :if ([:len [/interface veth find where name="veth-pihole" and address="172.31.254.2/30"]] != 1) do={ :error "Unexpected Pi-hole endpoint" }
    :if ([:tostr [/ip dns get servers]] != "1.1.1.1") do={ :error "Import 20-pihole-prepare-dns.rsc first; RouterOS must not forward back to Pi-hole" }
    :if ([/ip dns get use-doh-server] != "") do={ :error "RouterOS DoH must be cleared by 20-pihole-prepare-dns.rsc" }
    :if ([/ip dns get allow-remote-requests] != true) do={ :error "RouterOS local DNS must be enabled" }
    :if ([:len [/ip dhcp-client find where disabled=no and use-peer-dns=yes]] > 0) do={ :error "Unexpected DHCP peer DNS" }
    :if ([:len [/ipv6 dhcp-client find where disabled=no and use-peer-dns=yes]] > 0) do={ :error "Unexpected DHCPv6 peer DNS" }
    :if ([:len [/ip firewall nat find where comment="Pi-hole Home gateway DNS UDP"]] != 1) do={ :error "Import file20 first: Pi-hole Home gateway DNS UDP" }
    :if ([:len [/ip firewall nat find where comment="Pi-hole Home gateway DNS TCP"]] != 1) do={ :error "Import file20 first: Pi-hole Home gateway DNS TCP" }
    :if ([:len [/ip firewall nat find where comment="Pi-hole Guest gateway DNS UDP"]] != 1) do={ :error "Import file20 first: Pi-hole Guest gateway DNS UDP" }
    :if ([:len [/ip firewall nat find where comment="Pi-hole Guest gateway DNS TCP"]] != 1) do={ :error "Import file20 first: Pi-hole Guest gateway DNS TCP" }
    :if ([:len [/ip firewall nat find where comment="Pi-hole IoT gateway DNS UDP"]] != 1) do={ :error "Import file20 first: Pi-hole IoT gateway DNS UDP" }
    :if ([:len [/ip firewall nat find where comment="Pi-hole IoT gateway DNS TCP"]] != 1) do={ :error "Import file20 first: Pi-hole IoT gateway DNS TCP" }
    :if ([:len [/ip firewall nat find where comment="Pi-hole Cloud gateway DNS UDP"]] != 1) do={ :error "Import file20 first: Pi-hole Cloud gateway DNS UDP" }
    :if ([:len [/ip firewall nat find where comment="Pi-hole Cloud gateway DNS TCP"]] != 1) do={ :error "Import file20 first: Pi-hole Cloud gateway DNS TCP" }
    # Direct public/local probes precede NAT activation. Verify TCP and blocking separately.
    :do {
        :local answer [:resolve "example.com" server=172.31.254.2]
        :if ([:len [:tostr $answer]] = 0) do={ :error "Empty public answer" }
        :if ([:tostr [:resolve "pulsar.home.antonu.org" server=172.31.254.2]] != "192.168.40.5") do={ :error "Unexpected local answer" }
        :if ([:tostr [:resolve "k8s.home.antonu.org" server=172.31.254.2]] != "192.168.40.20") do={ :error "Unexpected API VIP" }
    } on-error={ :error "Pi-hole DNS probe failed; NAT state unchanged" }
    :foreach identity in={"Pi-hole Home gateway DNS UDP";"Pi-hole Home gateway DNS TCP";"Pi-hole Guest gateway DNS UDP";"Pi-hole Guest gateway DNS TCP";"Pi-hole IoT gateway DNS UDP";"Pi-hole IoT gateway DNS TCP";"Pi-hole Cloud gateway DNS UDP";"Pi-hole Cloud gateway DNS TCP"} do={
        /ip firewall nat enable [find where comment=$identity]
    }
    /ip dns cache flush
    # Existing tracked DNS flows retain their old path until they expire.
}
