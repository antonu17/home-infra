# Pi-hole isolated container subnet: 172.31.254.0/30. Check for overlap before import.
# File20 owns these objects; file09 preserves optional rule ordering.
# No DNS cutover, physical ports, VLAN membership or container startup here.
:if ([:len [/ip firewall filter find where comment="forward default deny"]] != 1) do={ :error "Import file09 first" }
:if ([:len [/ip firewall nat find where comment="WAN Internet masquerade" and disabled=no]] != 1) do={ :error "Existing WAN masquerade required" }
:foreach identity in={"bridge-pihole";"veth-pihole"} do={
    :if ([:len [/interface list member find where interface=$identity]] > 0) do={ :error "Pi-hole transit must not belong to interface lists" }
}
:if ([:len [/interface bridge find where name="bridge-pihole"]] > 1) do={ :error "Duplicate Pi-hole object: /interface bridge" }
:if ([:len [/interface veth find where name="veth-pihole"]] > 1) do={ :error "Duplicate Pi-hole object: /interface veth" }
:if ([:len [/interface bridge port find where interface="veth-pihole"]] > 1) do={ :error "Duplicate Pi-hole object: /interface bridge port" }
:if ([:len [/ip address find where address="172.31.254.1/30" and interface="bridge-pihole"]] > 1) do={ :error "Duplicate Pi-hole object: /ip address" }
:if ([:len [/ip firewall filter find where comment="Pi-hole Home administration"]] > 1) do={ :error "Duplicate Pi-hole firewall identity" }
:if ([:len [/ip firewall filter find where comment="Pi-hole Home DNS UDP"]] > 1) do={ :error "Duplicate Pi-hole firewall identity" }
:if ([:len [/ip firewall filter find where comment="Pi-hole Home DNS TCP"]] > 1) do={ :error "Duplicate Pi-hole firewall identity" }
:if ([:len [/ip firewall filter find where comment="Pi-hole upstream DNS UDP"]] > 1) do={ :error "Duplicate Pi-hole firewall identity" }
:if ([:len [/ip firewall filter find where comment="Pi-hole upstream DNS TCP"]] > 1) do={ :error "Duplicate Pi-hole firewall identity" }
:if ([:len [/ip firewall filter find where comment="Pi-hole blocklist downloads"]] > 1) do={ :error "Duplicate Pi-hole firewall identity" }

:if ([:len [/interface find where name="bridge-pihole"]] != [:len [/interface bridge find where name="bridge-pihole"]]) do={ :error "Pi-hole bridge name belongs to another interface type" }
:if ([:len [/interface find where name="veth-pihole"]] != [:len [/interface veth find where name="veth-pihole"]]) do={ :error "Pi-hole VETH name belongs to another interface type" }
:foreach row in=[/interface bridge port find where bridge="bridge-pihole"] do={
    :if ([/interface bridge port get $row interface] != "veth-pihole") do={ :error "Unexpected port in Pi-hole bridge" }
}
:foreach row in=[/interface bridge port find where interface="veth-pihole"] do={
    :if ([/interface bridge port get $row bridge] != "bridge-pihole") do={ :error "Pi-hole VETH is on another bridge" }
}
:foreach row in=[/ip address find where interface="bridge-pihole"] do={
    :if ([/ip address get $row address] != "172.31.254.1/30") do={ :error "Unexpected Pi-hole bridge address" }
}
:foreach row in=[/ip address find where address="172.31.254.1/30"] do={
    :if ([/ip address get $row interface] != "bridge-pihole") do={ :error "Pi-hole gateway is on another interface" }
}
:if ([:len [/ip firewall address-list find where list="LOCAL-NETWORKS" and address="172.31.254.0/30"]] > 1) do={ :error "Duplicate Pi-hole local subnet" }
:foreach row in=[/ip firewall address-list find where list="LOCAL-NETWORKS" and address="172.31.254.0/30"] do={
    :if ([/ip firewall address-list get $row dynamic] = true) do={ :error "Pi-hole local subnet must be static" }
}
:foreach row in=[/ip firewall address-list find where list="PIHOLE-UPSTREAMS"] do={
    :local address [/ip firewall address-list get $row address]
    :if (($address != "1.1.1.1") && ($address != "9.9.9.9")) do={ :error "Unexpected Pi-hole upstream" }
    :if ([/ip firewall address-list get $row dynamic] = true) do={ :error "Pi-hole upstream must be static" }
}
:if ([:len [/ip firewall address-list find where list="PIHOLE-UPSTREAMS" and address="1.1.1.1"]] > 1) do={ :error "Duplicate Pi-hole upstream" }
:if ([:len [/ip firewall address-list find where list="PIHOLE-UPSTREAMS" and address="9.9.9.9"]] > 1) do={ :error "Duplicate Pi-hole upstream" }

:do {
    :local existing [/interface bridge find where name="bridge-pihole"]
    :if ([:len $existing] = 0) do={
        /interface bridge add name=bridge-pihole protocol-mode=none vlan-filtering=no disabled=no comment="Isolated Pi-hole container transit"
    } else={
        /interface bridge set $existing name=bridge-pihole protocol-mode=none vlan-filtering=no disabled=no comment="Isolated Pi-hole container transit"
    }
}

:do {
    :local existing [/interface veth find where name="veth-pihole"]
    :if ([:len $existing] = 0) do={
        /interface veth add name=veth-pihole address=172.31.254.2/30 gateway=172.31.254.1 dhcp=no disabled=no comment="Pi-hole DNS endpoint"
    } else={
        /interface veth set $existing name=veth-pihole address=172.31.254.2/30 gateway=172.31.254.1 dhcp=no disabled=no comment="Pi-hole DNS endpoint"
    }
}

:do {
    :local existing [/interface bridge port find where interface="veth-pihole"]
    :if ([:len $existing] = 0) do={
        /interface bridge port add interface=veth-pihole bridge=bridge-pihole disabled=no comment="Pi-hole transit attachment"
    } else={
        /interface bridge port set $existing interface=veth-pihole bridge=bridge-pihole disabled=no comment="Pi-hole transit attachment"
    }
}

:do {
    :local existing [/ip address find where address="172.31.254.1/30" and interface="bridge-pihole"]
    :if ([:len $existing] = 0) do={
        /ip address add address=172.31.254.1/30 network=172.31.254.0 interface=bridge-pihole disabled=no comment="Pi-hole transit gateway"
    } else={
        /ip address set $existing address=172.31.254.1/30 network=172.31.254.0 interface=bridge-pihole disabled=no comment="Pi-hole transit gateway"
    }
}

:do {
    :local existing [/ip firewall address-list find where list="PIHOLE-UPSTREAMS" and address="1.1.1.1"]
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=PIHOLE-UPSTREAMS address=1.1.1.1 disabled=no comment="Pi-hole public upstream"
    } else={
        /ip firewall address-list set $existing list=PIHOLE-UPSTREAMS address=1.1.1.1 disabled=no comment="Pi-hole public upstream"
    }
}

# Retire the previous managed Quad9 upstream by exact identity.
/ip firewall address-list remove [find where list="PIHOLE-UPSTREAMS" and address="9.9.9.9"]

:do {
    :local existing [/ip firewall filter find where comment="Pi-hole Home administration"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole Home administration"
        :set existing [/ip firewall filter find where comment="Pi-hole Home administration"]
    }
    /ip firewall filter set $existing !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=tcp dst-port=80,443 disabled=no log=no log-prefix="" comment="Pi-hole Home administration"
    /ip firewall filter move $existing destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local existing [/ip firewall filter find where comment="Pi-hole Home DNS UDP"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole Home DNS UDP"
        :set existing [/ip firewall filter find where comment="Pi-hole Home DNS UDP"]
    }
    /ip firewall filter set $existing !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=udp dst-port=53 disabled=no log=no log-prefix="" comment="Pi-hole Home DNS UDP"
    /ip firewall filter move $existing destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local existing [/ip firewall filter find where comment="Pi-hole Home DNS TCP"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole Home DNS TCP"
        :set existing [/ip firewall filter find where comment="Pi-hole Home DNS TCP"]
    }
    /ip firewall filter set $existing !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=tcp dst-port=53 disabled=no log=no log-prefix="" comment="Pi-hole Home DNS TCP"
    /ip firewall filter move $existing destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local existing [/ip firewall filter find where comment="Pi-hole upstream DNS UDP"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole upstream DNS UDP"
        :set existing [/ip firewall filter find where comment="Pi-hole upstream DNS UDP"]
    }
    /ip firewall filter set $existing !dst-address !src-address-list !out-interface !in-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=bridge-pihole src-address=172.31.254.2 out-interface-list=WAN dst-address-list=PIHOLE-UPSTREAMS protocol=udp dst-port=53 disabled=no log=no log-prefix="" comment="Pi-hole upstream DNS UDP"
    /ip firewall filter move $existing destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local existing [/ip firewall filter find where comment="Pi-hole upstream DNS TCP"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole upstream DNS TCP"
        :set existing [/ip firewall filter find where comment="Pi-hole upstream DNS TCP"]
    }
    /ip firewall filter set $existing !dst-address !src-address-list !out-interface !in-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=bridge-pihole src-address=172.31.254.2 out-interface-list=WAN dst-address-list=PIHOLE-UPSTREAMS protocol=tcp dst-port=53 disabled=no log=no log-prefix="" comment="Pi-hole upstream DNS TCP"
    /ip firewall filter move $existing destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local existing [/ip firewall filter find where comment="Pi-hole blocklist downloads"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole blocklist downloads"
        :set existing [/ip firewall filter find where comment="Pi-hole blocklist downloads"]
    }
    /ip firewall filter set $existing !dst-address !src-address-list !out-interface !in-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=bridge-pihole src-address=172.31.254.2 out-interface-list=WAN dst-address-list=!LOCAL-NETWORKS protocol=tcp dst-port=80,443 disabled=no log=no log-prefix="" comment="Pi-hole blocklist downloads"
    /ip firewall filter move $existing destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local existing [/ip firewall address-list find where list="LOCAL-NETWORKS" and address="172.31.254.0/30"]
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=LOCAL-NETWORKS address=172.31.254.0/30 disabled=no comment="Pi-hole container transit"
    } else={
        /ip firewall address-list set $existing list=LOCAL-NETWORKS address=172.31.254.0/30 disabled=no comment="Pi-hole container transit"
    }
}
