# One import block keeps local variables in scope across commands.
:do {
    # DNS cutover only after file20/21 and explicit TCP/UDP acceptance checks.
    # RouterOS remains local DNS authority and DHCP-advertised resolver.
    :local instance [/container find where name="pihole"]
    :if ([:len $instance] != 1) do={ :error "One Pi-hole container required" }
    :if ([/container get $instance interface] != "veth-pihole") do={ :error "Unexpected Pi-hole interface" }
    :if ([:len [/interface veth find where name="veth-pihole" and address="172.31.254.2/30"]] != 1) do={ :error "Unexpected Pi-hole endpoint" }
    :local wan [/ip dhcp-client find where interface="sfp-sfpplus1"]
    :if ([:len $wan] > 1) do={ :error "Duplicate WAN DHCP clients" }
    # Refuse alternate DHCP DNS providers instead of silently retaining a bypass.
    :foreach client in=[/ip dhcp-client find where disabled=no and use-peer-dns=yes] do={
        :if ([/ip dhcp-client get $client interface] != "sfp-sfpplus1") do={ :error "Other DHCP peer DNS must be reconciled in source before cutover" }
    }
    :if ([:len [/ipv6 dhcp-client find where disabled=no and use-peer-dns=yes]] > 0) do={ :error "DHCPv6 peer DNS must be reconciled in source before cutover" }
    # Prove recursion to an independent public upstream before changing DNS settings.
    # This probes UDP DNS; verify TCP53 and blocking before importing.
    :do {
        :local answer [:resolve "example.com" server=172.31.254.2]
        :if ([:len [:tostr $answer]] = 0) do={ :error "Empty Pi-hole DNS answer" }
    } on-error={ :error "Pi-hole recursion failed; DNS settings unchanged" }
    # DHCP peer DNS is explicitly disabled on the known WAN. No client is recreated.
    :if ([:len $wan] = 1) do={ /ip dhcp-client set $wan use-peer-dns=no }
    /ip dns set servers=172.31.254.2 use-doh-server="" allow-remote-requests=yes
    /ip dns cache flush
    # No automatic bypass resolver: an unavailable Pi-hole fails closed.
    # Persistent local static records and mDNS settings are not changed.
}
