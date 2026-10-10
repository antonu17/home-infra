# Adopt the factory WAN masquerade and use a descriptive stable comment.
# Refuse an additional enabled WAN-list masquerade under another comment;
# reconcile its key in source rather than creating a duplicate.
:foreach row in=[/ip firewall nat find where chain="srcnat" and action="masquerade" and out-interface-list="WAN" and disabled=no] do={
    :if (([/ip firewall nat get $row comment] != "defconf: masquerade") && ([/ip firewall nat get $row comment] != "WAN Internet masquerade")) do={ :error "WAN masquerade has another comment; reconcile its key before import" }
}

:do {
    :local existing [/ip firewall nat find where comment="defconf: masquerade" or comment="WAN Internet masquerade"]
    :if ([:len $existing] > 1) do={ :error "Duplicate factory or managed WAN masquerade" }
    :if ([:len $existing] = 0) do={
        /ip firewall nat add chain=srcnat action=masquerade out-interface-list=WAN ipsec-policy=out,none disabled=no comment="WAN Internet masquerade" log=no log-prefix=""
    } else={
        /ip firewall nat set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !in-interface-list !protocol !src-port !dst-port chain=srcnat action=masquerade out-interface-list=WAN ipsec-policy=out,none disabled=no comment="WAN Internet masquerade" log=no log-prefix=""
    }
}

# Preserve other NAT rules; audit internal masquerades and published services.
# No NAT is created between VLANs or for BGP-routed LoadBalancer addresses.
