# Pi-hole isolated container subnet: 172.31.254.0/30. Check for overlap before import.
# File20 owns these objects; file09 preserves optional rule ordering.
# Gateway DNS DNAT is created disabled; file22 owns activation. DHCP is unchanged.
:if ([:len [/ip firewall filter find where comment="input default deny"]] != 1) do={ :error "Import file09 first" }
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

# Client DNS keeps its source address. No internal SNAT.

:do {
    :local row [/ip firewall filter find where comment="Pi-hole Guest DNS UDP"]
    :if ([:len $row] > 1) do={ :error "Duplicate firewall identity: Pi-hole Guest DNS UDP" }
    :if ([:len $row] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole Guest DNS UDP"
        :set row [/ip firewall filter find where comment="Pi-hole Guest DNS UDP"]
    }
    /ip firewall filter set $row !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=GUEST src-address-list=GUEST-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=udp dst-port=53 disabled=no log=no comment="Pi-hole Guest DNS UDP"
    /ip firewall filter move $row destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local row [/ip firewall filter find where comment="Pi-hole Guest DNS TCP"]
    :if ([:len $row] > 1) do={ :error "Duplicate firewall identity: Pi-hole Guest DNS TCP" }
    :if ([:len $row] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole Guest DNS TCP"
        :set row [/ip firewall filter find where comment="Pi-hole Guest DNS TCP"]
    }
    /ip firewall filter set $row !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=GUEST src-address-list=GUEST-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=tcp dst-port=53 disabled=no log=no comment="Pi-hole Guest DNS TCP"
    /ip firewall filter move $row destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local row [/ip firewall filter find where comment="Pi-hole IoT DNS UDP"]
    :if ([:len $row] > 1) do={ :error "Duplicate firewall identity: Pi-hole IoT DNS UDP" }
    :if ([:len $row] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole IoT DNS UDP"
        :set row [/ip firewall filter find where comment="Pi-hole IoT DNS UDP"]
    }
    /ip firewall filter set $row !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=IOT src-address-list=IOT-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=udp dst-port=53 disabled=no log=no comment="Pi-hole IoT DNS UDP"
    /ip firewall filter move $row destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local row [/ip firewall filter find where comment="Pi-hole IoT DNS TCP"]
    :if ([:len $row] > 1) do={ :error "Duplicate firewall identity: Pi-hole IoT DNS TCP" }
    :if ([:len $row] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole IoT DNS TCP"
        :set row [/ip firewall filter find where comment="Pi-hole IoT DNS TCP"]
    }
    /ip firewall filter set $row !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=IOT src-address-list=IOT-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=tcp dst-port=53 disabled=no log=no comment="Pi-hole IoT DNS TCP"
    /ip firewall filter move $row destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local row [/ip firewall filter find where comment="Pi-hole Cloud DNS UDP"]
    :if ([:len $row] > 1) do={ :error "Duplicate firewall identity: Pi-hole Cloud DNS UDP" }
    :if ([:len $row] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole Cloud DNS UDP"
        :set row [/ip firewall filter find where comment="Pi-hole Cloud DNS UDP"]
    }
    /ip firewall filter set $row !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address-list=CLOUD-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=udp dst-port=53 disabled=no log=no comment="Pi-hole Cloud DNS UDP"
    /ip firewall filter move $row destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local row [/ip firewall filter find where comment="Pi-hole Cloud DNS TCP"]
    :if ([:len $row] > 1) do={ :error "Duplicate firewall identity: Pi-hole Cloud DNS TCP" }
    :if ([:len $row] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Pi-hole Cloud DNS TCP"
        :set row [/ip firewall filter find where comment="Pi-hole Cloud DNS TCP"]
    }
    /ip firewall filter set $row !src-address !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address-list=CLOUD-NETWORKS out-interface=bridge-pihole dst-address=172.31.254.2 protocol=tcp dst-port=53 disabled=no log=no comment="Pi-hole Cloud DNS TCP"
    /ip firewall filter move $row destination=[/ip firewall filter find where comment="forward default deny"]
}

:do {
    :local row [/ip firewall filter find where comment="Pi-hole local DNS UDP"]
    :if ([:len $row] > 1) do={ :error "Duplicate firewall identity: Pi-hole local DNS UDP" }
    :if ([:len $row] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Pi-hole local DNS UDP"
        :set row [/ip firewall filter find where comment="Pi-hole local DNS UDP"]
    }
    /ip firewall filter set $row !src-address-list !dst-address-list !in-interface-list !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=bridge-pihole src-address=172.31.254.2 dst-address=172.31.254.1 protocol=udp dst-port=53 disabled=no log=no comment="Pi-hole local DNS UDP"
    /ip firewall filter move $row destination=[/ip firewall filter find where comment="input default deny"]
}

:do {
    :local row [/ip firewall filter find where comment="Pi-hole local DNS TCP"]
    :if ([:len $row] > 1) do={ :error "Duplicate firewall identity: Pi-hole local DNS TCP" }
    :if ([:len $row] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Pi-hole local DNS TCP"
        :set row [/ip firewall filter find where comment="Pi-hole local DNS TCP"]
    }
    /ip firewall filter set $row !src-address-list !dst-address-list !in-interface-list !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=bridge-pihole src-address=172.31.254.2 dst-address=172.31.254.1 protocol=tcp dst-port=53 disabled=no log=no comment="Pi-hole local DNS TCP"
    /ip firewall filter move $row destination=[/ip firewall filter find where comment="input default deny"]
}


:do {
    :local row [/ip firewall nat find where comment="Pi-hole Home gateway DNS UDP"]
    :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity: Pi-hole Home gateway DNS UDP" }
    :if ([:len $row] = 0) do={
        /ip firewall nat add chain=dstnat disabled=yes comment="Pi-hole Home gateway DNS UDP"
        :set row [/ip firewall nat find where comment="Pi-hole Home gateway DNS UDP"]
    }
    # Preserve enabled state; file22 owns activation after readiness checks.
    /ip firewall nat set $row !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-mark !ipsec-policy chain=dstnat action=dst-nat in-interface-list=HOME src-address=192.168.100.0/24 dst-address=192.168.100.1 protocol=udp dst-port=53 to-addresses=172.31.254.2 to-ports=53 log=no comment="Pi-hole Home gateway DNS UDP"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}

:do {
    :local row [/ip firewall nat find where comment="Pi-hole Home gateway DNS TCP"]
    :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity: Pi-hole Home gateway DNS TCP" }
    :if ([:len $row] = 0) do={
        /ip firewall nat add chain=dstnat disabled=yes comment="Pi-hole Home gateway DNS TCP"
        :set row [/ip firewall nat find where comment="Pi-hole Home gateway DNS TCP"]
    }
    # Preserve enabled state; file22 owns activation after readiness checks.
    /ip firewall nat set $row !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-mark !ipsec-policy chain=dstnat action=dst-nat in-interface-list=HOME src-address=192.168.100.0/24 dst-address=192.168.100.1 protocol=tcp dst-port=53 to-addresses=172.31.254.2 to-ports=53 log=no comment="Pi-hole Home gateway DNS TCP"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}

:do {
    :local row [/ip firewall nat find where comment="Pi-hole Guest gateway DNS UDP"]
    :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity: Pi-hole Guest gateway DNS UDP" }
    :if ([:len $row] = 0) do={
        /ip firewall nat add chain=dstnat disabled=yes comment="Pi-hole Guest gateway DNS UDP"
        :set row [/ip firewall nat find where comment="Pi-hole Guest gateway DNS UDP"]
    }
    # Preserve enabled state; file22 owns activation after readiness checks.
    /ip firewall nat set $row !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-mark !ipsec-policy chain=dstnat action=dst-nat in-interface-list=GUEST src-address=192.168.200.0/24 dst-address=192.168.200.1 protocol=udp dst-port=53 to-addresses=172.31.254.2 to-ports=53 log=no comment="Pi-hole Guest gateway DNS UDP"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}

:do {
    :local row [/ip firewall nat find where comment="Pi-hole Guest gateway DNS TCP"]
    :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity: Pi-hole Guest gateway DNS TCP" }
    :if ([:len $row] = 0) do={
        /ip firewall nat add chain=dstnat disabled=yes comment="Pi-hole Guest gateway DNS TCP"
        :set row [/ip firewall nat find where comment="Pi-hole Guest gateway DNS TCP"]
    }
    # Preserve enabled state; file22 owns activation after readiness checks.
    /ip firewall nat set $row !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-mark !ipsec-policy chain=dstnat action=dst-nat in-interface-list=GUEST src-address=192.168.200.0/24 dst-address=192.168.200.1 protocol=tcp dst-port=53 to-addresses=172.31.254.2 to-ports=53 log=no comment="Pi-hole Guest gateway DNS TCP"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}

:do {
    :local row [/ip firewall nat find where comment="Pi-hole IoT gateway DNS UDP"]
    :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity: Pi-hole IoT gateway DNS UDP" }
    :if ([:len $row] = 0) do={
        /ip firewall nat add chain=dstnat disabled=yes comment="Pi-hole IoT gateway DNS UDP"
        :set row [/ip firewall nat find where comment="Pi-hole IoT gateway DNS UDP"]
    }
    # Preserve enabled state; file22 owns activation after readiness checks.
    /ip firewall nat set $row !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-mark !ipsec-policy chain=dstnat action=dst-nat in-interface-list=IOT src-address=192.168.30.0/24 dst-address=192.168.30.1 protocol=udp dst-port=53 to-addresses=172.31.254.2 to-ports=53 log=no comment="Pi-hole IoT gateway DNS UDP"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}

:do {
    :local row [/ip firewall nat find where comment="Pi-hole IoT gateway DNS TCP"]
    :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity: Pi-hole IoT gateway DNS TCP" }
    :if ([:len $row] = 0) do={
        /ip firewall nat add chain=dstnat disabled=yes comment="Pi-hole IoT gateway DNS TCP"
        :set row [/ip firewall nat find where comment="Pi-hole IoT gateway DNS TCP"]
    }
    # Preserve enabled state; file22 owns activation after readiness checks.
    /ip firewall nat set $row !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-mark !ipsec-policy chain=dstnat action=dst-nat in-interface-list=IOT src-address=192.168.30.0/24 dst-address=192.168.30.1 protocol=tcp dst-port=53 to-addresses=172.31.254.2 to-ports=53 log=no comment="Pi-hole IoT gateway DNS TCP"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}

:do {
    :local row [/ip firewall nat find where comment="Pi-hole Cloud gateway DNS UDP"]
    :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity: Pi-hole Cloud gateway DNS UDP" }
    :if ([:len $row] = 0) do={
        /ip firewall nat add chain=dstnat disabled=yes comment="Pi-hole Cloud gateway DNS UDP"
        :set row [/ip firewall nat find where comment="Pi-hole Cloud gateway DNS UDP"]
    }
    # Preserve enabled state; file22 owns activation after readiness checks.
    /ip firewall nat set $row !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-mark !ipsec-policy chain=dstnat action=dst-nat in-interface-list=CLOUD src-address=192.168.40.0/24 dst-address=192.168.40.1 protocol=udp dst-port=53 to-addresses=172.31.254.2 to-ports=53 log=no comment="Pi-hole Cloud gateway DNS UDP"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}

:do {
    :local row [/ip firewall nat find where comment="Pi-hole Cloud gateway DNS TCP"]
    :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity: Pi-hole Cloud gateway DNS TCP" }
    :if ([:len $row] = 0) do={
        /ip firewall nat add chain=dstnat disabled=yes comment="Pi-hole Cloud gateway DNS TCP"
        :set row [/ip firewall nat find where comment="Pi-hole Cloud gateway DNS TCP"]
    }
    # Preserve enabled state; file22 owns activation after readiness checks.
    /ip firewall nat set $row !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-mark !ipsec-policy chain=dstnat action=dst-nat in-interface-list=CLOUD src-address=192.168.40.0/24 dst-address=192.168.40.1 protocol=tcp dst-port=53 to-addresses=172.31.254.2 to-ports=53 log=no comment="Pi-hole Cloud gateway DNS TCP"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}
