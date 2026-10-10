# Existing router-side bond is IEEE802.3ad. DSM must use the same mode.
# Retain hash policy, LACP rate, MAC and monitoring settings on an existing bond.

:if ([:len [/interface bridge port find where interface="ether1"]] > 0) do={ :error "ether1 is a bridge port; cannot use it as a bond slave" }
:if ([:len [/interface bridge port find where interface="ether2"]] > 0) do={ :error "ether2 is a bridge port; cannot use it as a bond slave" }

:do {
    :local existing [/interface bonding find where name="syno1"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bonding object: name=syno1" }
    :if ([:len $existing] = 0) do={
        /interface bonding add name=syno1 mode=802.3ad slaves=ether1,ether2 disabled=no comment="Synology LACP"
    } else={
        /interface bonding set $existing name=syno1 mode=802.3ad slaves=ether1,ether2 disabled=no comment="Synology LACP"
    }
}
