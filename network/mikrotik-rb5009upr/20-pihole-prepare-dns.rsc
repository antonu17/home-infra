# One import block keeps local variables in scope across commands.
:do {
    # RouterOS recursion must be independent before Pi-hole forwards local queries here.
    :local wan [/ip dhcp-client find where interface="sfp-sfpplus1"]
    :if ([:len $wan] > 1) do={ :error "Duplicate WAN DHCP clients" }
    :foreach client in=[/ip dhcp-client find where disabled=no and use-peer-dns=yes] do={
        :if ([/ip dhcp-client get $client interface] != "sfp-sfpplus1") do={ :error "Reconcile other DHCP peer DNS in source first" }
    }
    :if ([:len [/ipv6 dhcp-client find where disabled=no and use-peer-dns=yes]] > 0) do={ :error "Reconcile DHCPv6 peer DNS in source first" }
    :do {
        :local answer [:resolve "example.com" server=1.1.1.1]
        :if ([:len [:tostr $answer]] = 0) do={ :error "Empty public DNS answer" }
    } on-error={ :error "Public DNS probe failed; DNS settings unchanged" }
    :if ([:len $wan] = 1) do={ /ip dhcp-client set $wan use-peer-dns=no }
    /ip dns set servers=1.1.1.1 use-doh-server="" allow-remote-requests=yes
    /ip dns cache flush
}
