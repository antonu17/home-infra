:if (([:len [/ip firewall nat find where comment="TEMP Samsung SSDP source test"]] + [:len [/ip firewall nat find where comment="Pulsar SSDP replies to subnet-sensitive clients"]]) > 1) do={ :error "Ambiguous Samsung SSDP NAT identity" }
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

# Samsung SSDP source-subnet compatibility workaround.
# libupnp replies use ephemeral source ports: do not match UDP source1900.
:if ([:len [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and disabled=no]] = 0) do={ :error "Import Samsung SSDP client list first" }
:do {
    :local row [/ip firewall nat find where comment="TEMP Samsung SSDP source test" or comment="Pulsar SSDP replies to subnet-sensitive clients"]
    :if ([:len $row] = 0) do={ /ip firewall nat add chain=srcnat disabled=yes comment="Pulsar SSDP replies to subnet-sensitive clients"; :set row [/ip firewall nat find where comment="Pulsar SSDP replies to subnet-sensitive clients"] }
    /ip firewall nat set $row !dst-address !src-address-list !in-interface !in-interface-list !out-interface-list !src-port !connection-mark !ipsec-policy chain=srcnat action=src-nat src-address=192.168.40.5 dst-address-list=SSDP-SUBNET-CLIENTS out-interface=vlan300-iot protocol=udp dst-port=3942 to-addresses=192.168.30.1 disabled=no comment="Pulsar SSDP replies to subnet-sensitive clients"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}
