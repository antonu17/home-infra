# RouterOS 7.24.4: operator confirmed PIM-SM discovery/playback 2026-10-11.
# IPv4 SSDP only. Stop ssdp-relay and disable its start-on-boot before import.
# Legacy relay retired; see ssdp-container-removal.md. Native mDNS is independent.
# Import reviewed 09 first; 09 knows these optional firewall identities.
:foreach iface in={"vlan100-trusted";"vlan300-iot";"vlan400-home-cloud"} do={
    :if ([:len [/interface vlan find where name=$iface and disabled=no]] != 1) do={ :error "Missing SSDP VLAN interface" }
}
:if ([:len [/routing igmp-proxy interface find where disabled=no]] > 0) do={ :error "Review existing IGMP proxy before enabling PIM" }
:if ([:len [/routing pimsm instance find where name!="ssdp-pim" and disabled=no]] > 0) do={ :error "Review existing PIM instance" }
:if ([:len [/routing pimsm instance find where name="ssdp-pim"]] > 1) do={ :error "Duplicate SSDP PIM instance" }
:if ([:len [/routing pimsm interface-template find where instance="ssdp-pim"]] > 1) do={ :error "Duplicate SSDP PIM template" }
:if ([:len [/ip firewall filter find where comment="Home SSDP IGMP membership"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="Home SSDP multicast input"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="IoT SSDP IGMP membership"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="IoT SSDP multicast input"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="Cloud SSDP IGMP membership"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="Cloud SSDP multicast input"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="Home SSDP search to Cloud"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="NAS SSDP announcement to Home"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="IoT SSDP search to Cloud"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="NAS SSDP announcement to IoT"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="Home other routed multicast deny"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="IoT other routed multicast deny"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall filter find where comment="Cloud other routed multicast deny"]] > 1) do={ :error "Duplicate SSDP firewall identity" }
:if ([:len [/ip firewall mangle find where comment="Home SSDP TTL one hop"]] > 1) do={ :error "Duplicate SSDP TTL identity" }
:if ([:len [/ip firewall mangle find where comment="IoT SSDP TTL one hop"]] > 1) do={ :error "Duplicate SSDP TTL identity" }
:if ([:len [/ip firewall mangle find where comment="Cloud SSDP TTL one hop"]] > 1) do={ :error "Duplicate SSDP TTL identity" }
# Establish narrow forwarding policy before enabling multicast routing.
:do {
    :local rule [/ip firewall filter find where comment="Home SSDP IGMP membership"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="Home SSDP IGMP membership"; :set rule [/ip firewall filter find where comment="Home SSDP IGMP membership"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan100-trusted src-address=192.168.100.0/24 protocol=igmp dst-address=224.0.0.0/4 disabled=no log=no log-prefix="" comment="Home SSDP IGMP membership"
}
:do {
    :local rule [/ip firewall filter find where comment="Home SSDP multicast input"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="Home SSDP multicast input"; :set rule [/ip firewall filter find where comment="Home SSDP multicast input"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan100-trusted src-address=192.168.100.0/24 protocol=udp dst-address=239.255.255.250 dst-port=1900 disabled=no log=no log-prefix="" comment="Home SSDP multicast input"
}
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP IGMP membership"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="IoT SSDP IGMP membership"; :set rule [/ip firewall filter find where comment="IoT SSDP IGMP membership"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan300-iot src-address=192.168.30.0/24 protocol=igmp dst-address=224.0.0.0/4 disabled=no log=no log-prefix="" comment="IoT SSDP IGMP membership"
}
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP multicast input"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="IoT SSDP multicast input"; :set rule [/ip firewall filter find where comment="IoT SSDP multicast input"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan300-iot src-address=192.168.30.0/24 protocol=udp dst-address=239.255.255.250 dst-port=1900 disabled=no log=no log-prefix="" comment="IoT SSDP multicast input"
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud SSDP IGMP membership"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="Cloud SSDP IGMP membership"; :set rule [/ip firewall filter find where comment="Cloud SSDP IGMP membership"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan400-home-cloud src-address=192.168.40.0/24 protocol=igmp dst-address=224.0.0.0/4 disabled=no log=no log-prefix="" comment="Cloud SSDP IGMP membership"
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud SSDP multicast input"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="Cloud SSDP multicast input"; :set rule [/ip firewall filter find where comment="Cloud SSDP multicast input"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan400-home-cloud src-address=192.168.40.5 protocol=udp dst-address=239.255.255.250 dst-port=1900 disabled=no log=no log-prefix="" comment="Cloud SSDP multicast input"
}
:do {
    :local rule [/ip firewall filter find where comment="Home SSDP search to Cloud"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="Home SSDP search to Cloud"; :set rule [/ip firewall filter find where comment="Home SSDP search to Cloud"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan100-trusted src-address=192.168.100.0/24 out-interface=vlan400-home-cloud protocol=udp dst-address=239.255.255.250 dst-port=1900 disabled=no log=no log-prefix="" comment="Home SSDP search to Cloud"
}
:do {
    :local rule [/ip firewall filter find where comment="NAS SSDP announcement to Home"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="NAS SSDP announcement to Home"; :set rule [/ip firewall filter find where comment="NAS SSDP announcement to Home"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan400-home-cloud src-address=192.168.40.5 out-interface=vlan100-trusted protocol=udp dst-address=239.255.255.250 dst-port=1900 disabled=no log=no log-prefix="" comment="NAS SSDP announcement to Home"
}
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP search to Cloud"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="IoT SSDP search to Cloud"; :set rule [/ip firewall filter find where comment="IoT SSDP search to Cloud"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan300-iot src-address=192.168.30.0/24 out-interface=vlan400-home-cloud protocol=udp dst-address=239.255.255.250 dst-port=1900 disabled=no log=no log-prefix="" comment="IoT SSDP search to Cloud"
}
:do {
    :local rule [/ip firewall filter find where comment="NAS SSDP announcement to IoT"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="NAS SSDP announcement to IoT"; :set rule [/ip firewall filter find where comment="NAS SSDP announcement to IoT"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan400-home-cloud src-address=192.168.40.5 out-interface=vlan300-iot protocol=udp dst-address=239.255.255.250 dst-port=1900 disabled=no log=no log-prefix="" comment="NAS SSDP announcement to IoT"
}
:do {
    :local rule [/ip firewall filter find where comment="Home other routed multicast deny"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="Home other routed multicast deny"; :set rule [/ip firewall filter find where comment="Home other routed multicast deny"] }
    /ip firewall filter set $rule !src-address !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=drop in-interface=vlan100-trusted dst-address=224.0.0.0/4 disabled=no log=no log-prefix="" comment="Home other routed multicast deny"
}
:do {
    :local rule [/ip firewall filter find where comment="IoT other routed multicast deny"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="IoT other routed multicast deny"; :set rule [/ip firewall filter find where comment="IoT other routed multicast deny"] }
    /ip firewall filter set $rule !src-address !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=drop in-interface=vlan300-iot dst-address=224.0.0.0/4 disabled=no log=no log-prefix="" comment="IoT other routed multicast deny"
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud other routed multicast deny"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="Cloud other routed multicast deny"; :set rule [/ip firewall filter find where comment="Cloud other routed multicast deny"] }
    /ip firewall filter set $rule !src-address !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=drop in-interface=vlan400-home-cloud dst-address=224.0.0.0/4 disabled=no log=no log-prefix="" comment="Cloud other routed multicast deny"
}
# Put multicast policy before invalid/established and broad unicast accepts.
:do {
    :local rule [/ip firewall filter find where comment="Cloud other routed multicast deny"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT other routed multicast deny"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Home other routed multicast deny"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="NAS SSDP announcement to IoT"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP search to Cloud"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="NAS SSDP announcement to Home"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Home SSDP search to Cloud"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud SSDP multicast input"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud SSDP IGMP membership"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP multicast input"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP IGMP membership"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Home SSDP multicast input"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Home SSDP IGMP membership"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
# Raise only incoming SSDP with TTL=1 to 2; never change unicast/media TTL.
:do {
    :local rule [/ip firewall mangle find where comment="Home SSDP TTL one hop"]
    :if ([:len $rule] = 0) do={ /ip firewall mangle add chain=prerouting disabled=yes comment="Home SSDP TTL one hop"; :set rule [/ip firewall mangle find where comment="Home SSDP TTL one hop"] }
    /ip firewall mangle set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=prerouting action=change-ttl in-interface=vlan100-trusted src-address=192.168.100.0/24 protocol=udp dst-address=239.255.255.250 dst-port=1900 ttl=equal:1 new-ttl=set:2 passthrough=yes disabled=no comment="Home SSDP TTL one hop"
    :local first [:pick [/ip firewall mangle find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall mangle move $rule destination=$first }
}
:do {
    :local rule [/ip firewall mangle find where comment="IoT SSDP TTL one hop"]
    :if ([:len $rule] = 0) do={ /ip firewall mangle add chain=prerouting disabled=yes comment="IoT SSDP TTL one hop"; :set rule [/ip firewall mangle find where comment="IoT SSDP TTL one hop"] }
    /ip firewall mangle set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=prerouting action=change-ttl in-interface=vlan300-iot src-address=192.168.30.0/24 protocol=udp dst-address=239.255.255.250 dst-port=1900 ttl=equal:1 new-ttl=set:2 passthrough=yes disabled=no comment="IoT SSDP TTL one hop"
    :local first [:pick [/ip firewall mangle find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall mangle move $rule destination=$first }
}
:do {
    :local rule [/ip firewall mangle find where comment="Cloud SSDP TTL one hop"]
    :if ([:len $rule] = 0) do={ /ip firewall mangle add chain=prerouting disabled=yes comment="Cloud SSDP TTL one hop"; :set rule [/ip firewall mangle find where comment="Cloud SSDP TTL one hop"] }
    /ip firewall mangle set $rule !src-address-list !dst-address-list !out-interface !in-interface-list !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=prerouting action=change-ttl in-interface=vlan400-home-cloud src-address=192.168.40.5 protocol=udp dst-address=239.255.255.250 dst-port=1900 ttl=equal:1 new-ttl=set:2 passthrough=yes disabled=no comment="Cloud SSDP TTL one hop"
    :local first [:pick [/ip firewall mangle find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall mangle move $rule destination=$first }
}
# All sources and receivers are directly connected to this one router.
# MikroTik single-router example needs no static RP or PIM neighbor.
:do {
    :local obj [/routing pimsm instance find where name="ssdp-pim"]
    :if ([:len $obj] = 0) do={ /routing pimsm instance add name=ssdp-pim afi=ip vrf=main disabled=yes; :set obj [/routing pimsm instance find where name="ssdp-pim"] }
    /routing pimsm instance set $obj afi=ip vrf=main switch-to-spt=yes disabled=yes
}
:do {
    :local obj [/routing pimsm interface-template find where instance="ssdp-pim"]
    :if ([:len $obj] = 0) do={ /routing pimsm interface-template add instance=ssdp-pim interfaces=vlan100-trusted,vlan300-iot,vlan400-home-cloud disabled=yes; :set obj [/routing pimsm interface-template find where instance="ssdp-pim"] }
    /routing pimsm interface-template set $obj interfaces=vlan100-trusted,vlan300-iot,vlan400-home-cloud disabled=no
}
/routing pimsm instance enable [find where name="ssdp-pim"]
