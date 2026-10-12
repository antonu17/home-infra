# One import block keeps local variables in scope across commands.
:do {
    # DNS rollback: unfiltered public DNS, independent of NAS.
    :local wan [/ip dhcp-client find where interface="sfp-sfpplus1"]
    :if ([:len $wan] > 1) do={ :error "Duplicate WAN DHCP clients" }
    :do {
        :local answer [:resolve "example.com" server=1.1.1.1]
        :if ([:len [:tostr $answer]] = 0) do={ :error "Empty public DNS answer" }
    } on-error={ :error "Public DNS probe failed; DNS settings unchanged" }
    :if ([:len $wan] = 1) do={ /ip dhcp-client set $wan use-peer-dns=no }
    /ip dns set servers=1.1.1.1 use-doh-server="" allow-remote-requests=yes
    /ip dns cache flush
}
