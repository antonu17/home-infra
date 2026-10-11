# OPTIONAL: isolated Tailscale transit. Proposed allocation 172.31.255.0/30.
# Operator must verify this subnet does not overlap LAN, VPN or tailnet routes.
# No physical LAN ports/VLANs are changed. No 100.64.0.0/10 return route is added.
:if ([:len [/ip firewall filter find where comment="input default deny"]] != 1) do={ :error "Import file09 first" }
:if ([:len [/ip firewall filter find where comment="forward default deny"]] != 1) do={ :error "Import file09 first" }

:if ([:len [/interface bridge find where name="bridge-tailscale"]] > 1) do={ :error "Duplicate managed Tailscale object: /interface bridge" }
:if ([:len [/interface veth find where name="veth-tailscale"]] > 1) do={ :error "Duplicate managed Tailscale object: /interface veth" }
:if ([:len [/interface bridge port find where interface="veth-tailscale"]] > 1) do={ :error "Duplicate managed Tailscale object: /interface bridge port" }
:if ([:len [/ip address find where address="172.31.255.1/30" and interface="bridge-tailscale"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip address" }
:if ([:len [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="10.40.0.0/24"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip firewall address-list" }
:if ([:len [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="192.168.40.0/24"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip firewall address-list" }
:if ([:len [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="192.168.100.0/24"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip firewall address-list" }
:if ([:len [/ip firewall filter find where comment="Tailscale transit DNS UDP"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip firewall filter" }
:if ([:len [/ip firewall filter find where comment="Tailscale transit DNS TCP"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip firewall filter" }
:if ([:len [/ip firewall filter find where comment="Tailscale advertised router access"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip firewall filter" }
:if ([:len [/ip firewall filter find where comment="Tailscale advertised subnet access"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip firewall filter" }
:if ([:len [/ip firewall filter find where comment="Tailscale container Internet"]] > 1) do={ :error "Duplicate managed Tailscale object: /ip firewall filter" }
# Adopt the previous /25 entry in place; refuse ambiguous old/new duplicates.
:local oldServices [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="10.40.0.0/25"]
:local newServices [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="10.40.0.0/24"]
:if (([:len $oldServices] + [:len $newServices]) > 1) do={ :error "Ambiguous Kubernetes services subnet entries" }
:foreach row in=[/ip address find where address="172.31.255.1/30"] do={
    :if ([/ip address get $row interface] != "bridge-tailscale") do={ :error "Transit gateway is already on another interface" }
}
:foreach row in=[/interface bridge port find where bridge="bridge-tailscale"] do={
    :if ([/interface bridge port get $row interface] != "veth-tailscale") do={ :error "Unexpected interface in Tailscale transit bridge" }
}

:if ([:len [/interface find where name="bridge-tailscale"]] != [:len [/interface bridge find where name="bridge-tailscale"]]) do={ :error "Transit bridge name belongs to another interface type" }
:if ([:len [/interface find where name="veth-tailscale"]] != [:len [/interface veth find where name="veth-tailscale"]]) do={ :error "Transit VETH name belongs to another interface type" }
:foreach row in=[/interface bridge port find where interface="veth-tailscale"] do={
    :if ([/interface bridge port get $row bridge] != "bridge-tailscale") do={ :error "Tailscale VETH already belongs to another bridge" }
}
:foreach row in=[/ip firewall address-list find where list="TAILSCALE-SUBNETS"] do={
    :local subnet [/ip firewall address-list get $row address]
    :if (($subnet != "10.40.0.0/25") && ($subnet != "10.40.0.0/24") && ($subnet != "192.168.40.0/24") && ($subnet != "192.168.100.0/24")) do={ :error "Unexpected TAILSCALE-SUBNETS member; review scope" }
    :if ([/ip firewall address-list get $row dynamic] = true) do={ :error "Tailscale subnet entries must be static" }
}

:do {
    :local existing [/interface bridge find where name="bridge-tailscale"]
    :if ([:len $existing] = 0) do={
        /interface bridge add name=bridge-tailscale protocol-mode=none vlan-filtering=no disabled=no comment="Isolated Tailscale container transit"
    } else={
        /interface bridge set $existing name=bridge-tailscale protocol-mode=none vlan-filtering=no disabled=no comment="Isolated Tailscale container transit"
    }
}

:do {
    :local existing [/interface veth find where name="veth-tailscale"]
    :if ([:len $existing] = 0) do={
        /interface veth add name=veth-tailscale address=172.31.255.2/30 gateway=172.31.255.1 dhcp=no disabled=no comment="Tailscale transit endpoint"
    } else={
        /interface veth set $existing name=veth-tailscale address=172.31.255.2/30 gateway=172.31.255.1 dhcp=no disabled=no comment="Tailscale transit endpoint"
    }
}

:do {
    :local existing [/interface bridge port find where interface="veth-tailscale"]
    :if ([:len $existing] = 0) do={
        /interface bridge port add interface=veth-tailscale bridge=bridge-tailscale disabled=no comment="Tailscale transit attachment"
    } else={
        :if ([/interface bridge port get $existing bridge] != "bridge-tailscale") do={ :error "Tailscale VETH already belongs to another bridge" }
        /interface bridge port set $existing interface=veth-tailscale bridge=bridge-tailscale disabled=no comment="Tailscale transit attachment"
    }
}

:do {
    :local existing [/ip address find where address="172.31.255.1/30" and interface="bridge-tailscale"]
    :if ([:len $existing] = 0) do={
        /ip address add address=172.31.255.1/30 network=172.31.255.0 interface=bridge-tailscale disabled=no comment="Tailscale transit gateway"
    } else={
        /ip address set $existing address=172.31.255.1/30 network=172.31.255.0 interface=bridge-tailscale disabled=no comment="Tailscale transit gateway"
    }
}

:do {
    :local existing [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="10.40.0.0/24"]
    :if ([:len $existing] = 0) do={ :set existing [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="10.40.0.0/25"] }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=TAILSCALE-SUBNETS address=10.40.0.0/24 disabled=no comment="Kubernetes services"
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={ :error "Tailscale subnet entry must be static" }
        /ip firewall address-list set $existing list=TAILSCALE-SUBNETS address=10.40.0.0/24 disabled=no comment="Kubernetes services"
    }
}

:do {
    :local existing [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="192.168.40.0/24"]
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=TAILSCALE-SUBNETS address=192.168.40.0/24 disabled=no comment="Home Cloud VLAN"
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={ :error "Tailscale subnet entry must be static" }
        /ip firewall address-list set $existing list=TAILSCALE-SUBNETS address=192.168.40.0/24 disabled=no comment="Home Cloud VLAN"
    }
}

:do {
    :local existing [/ip firewall address-list find where list="TAILSCALE-SUBNETS" and address="192.168.100.0/24"]
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=TAILSCALE-SUBNETS address=192.168.100.0/24 disabled=no comment="Home VLAN"
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={ :error "Tailscale subnet entry must be static" }
        /ip firewall address-list set $existing list=TAILSCALE-SUBNETS address=192.168.100.0/24 disabled=no comment="Home VLAN"
    }
}

:do {
    :local existing [/ip firewall filter find where comment="Tailscale transit DNS UDP"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input action=accept in-interface=bridge-tailscale src-address=172.31.255.2 protocol=udp dst-port=53 dst-address=172.31.255.1 disabled=no log=no log-prefix="" comment="Tailscale transit DNS UDP"
    } else={
        /ip firewall filter set $existing !src-address-list !dst-address-list !in-interface-list !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=bridge-tailscale src-address=172.31.255.2 protocol=udp dst-port=53 dst-address=172.31.255.1 disabled=no log=no log-prefix="" comment="Tailscale transit DNS UDP"
    }
}

:do {
    :local existing [/ip firewall filter find where comment="Tailscale transit DNS TCP"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input action=accept in-interface=bridge-tailscale src-address=172.31.255.2 protocol=tcp dst-port=53 dst-address=172.31.255.1 disabled=no log=no log-prefix="" comment="Tailscale transit DNS TCP"
    } else={
        /ip firewall filter set $existing !src-address-list !dst-address-list !in-interface-list !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=bridge-tailscale src-address=172.31.255.2 protocol=tcp dst-port=53 dst-address=172.31.255.1 disabled=no log=no log-prefix="" comment="Tailscale transit DNS TCP"
    }
}

:do {
    :local existing [/ip firewall filter find where comment="Tailscale advertised router access"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input action=accept in-interface=bridge-tailscale src-address=172.31.255.2 dst-address-list=TAILSCALE-SUBNETS disabled=no log=no log-prefix="" comment="Tailscale advertised router access"
    } else={
        /ip firewall filter set $existing !src-address-list !dst-address !in-interface-list !out-interface !out-interface-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=bridge-tailscale src-address=172.31.255.2 dst-address-list=TAILSCALE-SUBNETS disabled=no log=no log-prefix="" comment="Tailscale advertised router access"
    }
}

:do {
    :local existing [/ip firewall filter find where comment="Tailscale advertised subnet access"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward action=accept in-interface=bridge-tailscale src-address=172.31.255.2 dst-address-list=TAILSCALE-SUBNETS disabled=no log=no log-prefix="" comment="Tailscale advertised subnet access"
    } else={
        /ip firewall filter set $existing !src-address-list !dst-address !in-interface-list !out-interface !out-interface-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=bridge-tailscale src-address=172.31.255.2 dst-address-list=TAILSCALE-SUBNETS disabled=no log=no log-prefix="" comment="Tailscale advertised subnet access"
    }
}

:do {
    :local existing [/ip firewall filter find where comment="Tailscale container Internet"]
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward action=accept in-interface=bridge-tailscale src-address=172.31.255.2 out-interface-list=WAN disabled=no log=no log-prefix="" comment="Tailscale container Internet"
    } else={
        /ip firewall filter set $existing !src-address-list !dst-address !dst-address-list !in-interface-list !out-interface !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=bridge-tailscale src-address=172.31.255.2 out-interface-list=WAN disabled=no log=no log-prefix="" comment="Tailscale container Internet"
    }
}

:do {
    :local rule [/ip firewall filter find where comment="Tailscale transit DNS UDP"]
    :local deny [/ip firewall filter find where comment="input default deny"]
    /ip firewall filter move $rule destination=$deny
}

:do {
    :local rule [/ip firewall filter find where comment="Tailscale transit DNS TCP"]
    :local deny [/ip firewall filter find where comment="input default deny"]
    /ip firewall filter move $rule destination=$deny
}

:do {
    :local rule [/ip firewall filter find where comment="Tailscale advertised router access"]
    :local deny [/ip firewall filter find where comment="input default deny"]
    /ip firewall filter move $rule destination=$deny
}

:do {
    :local rule [/ip firewall filter find where comment="Tailscale advertised subnet access"]
    :local deny [/ip firewall filter find where comment="forward default deny"]
    /ip firewall filter move $rule destination=$deny
}

:do {
    :local rule [/ip firewall filter find where comment="Tailscale container Internet"]
    :local deny [/ip firewall filter find where comment="forward default deny"]
    /ip firewall filter move $rule destination=$deny
}

