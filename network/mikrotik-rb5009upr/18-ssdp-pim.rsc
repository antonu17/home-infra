# IPv4 multicast without group, protocol, port or source restrictions between VLAN100/300/400.
# Operator-run import; preserves existing PIM instance identity and unicast policy.
:foreach iface in={"vlan100-trusted";"vlan300-iot";"vlan400-home-cloud"} do={
    :if ([:len [/interface vlan find where name=$iface and disabled=no]] != 1) do={ :error "Missing SSDP VLAN interface" }
}
:if ([:len [/routing igmp-proxy interface find where disabled=no]] > 0) do={ :error "Review existing IGMP proxy before enabling PIM" }
:if ([:len [/routing pimsm instance find where name!="ssdp-pim" and disabled=no]] > 0) do={ :error "Review existing PIM instance" }
:if ([:len [/routing pimsm instance find where name="ssdp-pim"]] > 1) do={ :error "Duplicate SSDP PIM instance" }
:if ([:len [/routing pimsm interface-template find where instance="ssdp-pim"]] > 1) do={ :error "Duplicate SSDP PIM template" }
:if ([:len [/ip firewall filter find where comment="Home multicast input"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="IoT multicast input"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="Cloud multicast input"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="Home multicast to IoT"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="Home multicast to Cloud"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="IoT multicast to Home"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="IoT multicast to Cloud"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="Cloud multicast to Home"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="Cloud multicast to IoT"]] > 1) do={ :error "Duplicate multicast identity" }
:if ([:len [/ip firewall filter find where comment="Home multicast input"]] = 0) do={ /ip firewall filter add chain=input action=accept in-interface=vlan100-trusted dst-address=224.0.0.0/4 comment="Home multicast input" }
/ip firewall filter set [find where comment="Home multicast input"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan100-trusted dst-address=224.0.0.0/4 disabled=no
:if ([:len [/ip firewall filter find where comment="IoT multicast input"]] = 0) do={ /ip firewall filter add chain=input action=accept in-interface=vlan300-iot dst-address=224.0.0.0/4 comment="IoT multicast input" }
/ip firewall filter set [find where comment="IoT multicast input"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan300-iot dst-address=224.0.0.0/4 disabled=no
:if ([:len [/ip firewall filter find where comment="Cloud multicast input"]] = 0) do={ /ip firewall filter add chain=input action=accept in-interface=vlan400-home-cloud dst-address=224.0.0.0/4 comment="Cloud multicast input" }
/ip firewall filter set [find where comment="Cloud multicast input"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan400-home-cloud dst-address=224.0.0.0/4 disabled=no
:if ([:len [/ip firewall filter find where comment="Home multicast to IoT"]] = 0) do={ /ip firewall filter add chain=forward action=accept in-interface=vlan100-trusted out-interface=vlan300-iot dst-address=224.0.0.0/4 comment="Home multicast to IoT" }
/ip firewall filter set [find where comment="Home multicast to IoT"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan100-trusted out-interface=vlan300-iot dst-address=224.0.0.0/4 disabled=no
:if ([:len [/ip firewall filter find where comment="Home multicast to Cloud"]] = 0) do={ /ip firewall filter add chain=forward action=accept in-interface=vlan100-trusted out-interface=vlan400-home-cloud dst-address=224.0.0.0/4 comment="Home multicast to Cloud" }
/ip firewall filter set [find where comment="Home multicast to Cloud"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan100-trusted out-interface=vlan400-home-cloud dst-address=224.0.0.0/4 disabled=no
:if ([:len [/ip firewall filter find where comment="IoT multicast to Home"]] = 0) do={ /ip firewall filter add chain=forward action=accept in-interface=vlan300-iot out-interface=vlan100-trusted dst-address=224.0.0.0/4 comment="IoT multicast to Home" }
/ip firewall filter set [find where comment="IoT multicast to Home"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan300-iot out-interface=vlan100-trusted dst-address=224.0.0.0/4 disabled=no
:if ([:len [/ip firewall filter find where comment="IoT multicast to Cloud"]] = 0) do={ /ip firewall filter add chain=forward action=accept in-interface=vlan300-iot out-interface=vlan400-home-cloud dst-address=224.0.0.0/4 comment="IoT multicast to Cloud" }
/ip firewall filter set [find where comment="IoT multicast to Cloud"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan300-iot out-interface=vlan400-home-cloud dst-address=224.0.0.0/4 disabled=no
:if ([:len [/ip firewall filter find where comment="Cloud multicast to Home"]] = 0) do={ /ip firewall filter add chain=forward action=accept in-interface=vlan400-home-cloud out-interface=vlan100-trusted dst-address=224.0.0.0/4 comment="Cloud multicast to Home" }
/ip firewall filter set [find where comment="Cloud multicast to Home"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan400-home-cloud out-interface=vlan100-trusted dst-address=224.0.0.0/4 disabled=no
:if ([:len [/ip firewall filter find where comment="Cloud multicast to IoT"]] = 0) do={ /ip firewall filter add chain=forward action=accept in-interface=vlan400-home-cloud out-interface=vlan300-iot dst-address=224.0.0.0/4 comment="Cloud multicast to IoT" }
/ip firewall filter set [find where comment="Cloud multicast to IoT"] !src-address !src-address-list !dst-address-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !in-interface-list !out-interface-list !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan400-home-cloud out-interface=vlan300-iot dst-address=224.0.0.0/4 disabled=no
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
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP unicast response to Home"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=forward disabled=yes comment="IoT SSDP unicast response to Home"; :set rule [/ip firewall filter find where comment="IoT SSDP unicast response to Home"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !in-interface-list !out-interface-list !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan300-iot src-address=192.168.30.0/24 out-interface=vlan100-trusted dst-address=192.168.100.0/24 protocol=udp src-port=1900 disabled=no log=no log-prefix="" comment="IoT SSDP unicast response to Home"
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud SSDP unicast response to Home"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=forward disabled=yes comment="Cloud SSDP unicast response to Home"; :set rule [/ip firewall filter find where comment="Cloud SSDP unicast response to Home"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !in-interface-list !out-interface-list !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface=vlan400-home-cloud src-address=192.168.40.0/24 out-interface=vlan100-trusted dst-address=192.168.100.0/24 protocol=udp src-port=1900 disabled=no log=no log-prefix="" comment="Cloud SSDP unicast response to Home"
}
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
    :local rule [/ip firewall filter find where comment="Cloud SSDP unicast response to Home"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP unicast response to Home"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
/ip firewall filter remove [find where comment="Cloud SSDP IGMP membership"]
/ip firewall mangle remove [find where comment="Cloud SSDP TTL one hop"]
/ip firewall filter remove [find where comment="Cloud SSDP announcement to Home"]
/ip firewall filter remove [find where comment="Cloud SSDP announcement to IoT"]
/ip firewall filter remove [find where comment="Cloud SSDP multicast input"]
/ip firewall filter remove [find where comment="Home SSDP IGMP membership"]
/ip firewall mangle remove [find where comment="Home SSDP TTL one hop"]
/ip firewall filter remove [find where comment="Home SSDP multicast input"]
/ip firewall filter remove [find where comment="Home SSDP search to Cloud"]
/ip firewall filter remove [find where comment="Home SSDP search to IoT"]
/ip firewall filter remove [find where comment="IoT SSDP IGMP membership"]
/ip firewall mangle remove [find where comment="IoT SSDP TTL one hop"]
/ip firewall filter remove [find where comment="IoT SSDP announcement to Home"]
/ip firewall filter remove [find where comment="IoT SSDP multicast input"]
/ip firewall filter remove [find where comment="IoT SSDP search to Cloud"]
/ip firewall filter remove [find where comment="NAS SSDP announcement to Home"]
/ip firewall filter remove [find where comment="NAS SSDP announcement to IoT"]
:if ([:len [/ip firewall mangle find where comment="Home multicast TTL one hop"]] > 1) do={ :error "Duplicate multicast TTL identity" }
:if ([:len [/ip firewall mangle find where comment="Home multicast TTL one hop"]] = 0) do={ /ip firewall mangle add chain=prerouting action=change-ttl in-interface=vlan100-trusted dst-address=224.0.0.0/4 protocol=!igmp ttl=equal:1 new-ttl=set:2 passthrough=yes comment="Home multicast TTL one hop" }
/ip firewall mangle set [find where comment="Home multicast TTL one hop"] chain=prerouting action=change-ttl in-interface=vlan100-trusted dst-address=224.0.0.0/4 protocol=!igmp ttl=equal:1 new-ttl=set:2 passthrough=yes disabled=no
:if ([:len [/ip firewall mangle find where comment="IoT multicast TTL one hop"]] > 1) do={ :error "Duplicate multicast TTL identity" }
:if ([:len [/ip firewall mangle find where comment="IoT multicast TTL one hop"]] = 0) do={ /ip firewall mangle add chain=prerouting action=change-ttl in-interface=vlan300-iot dst-address=224.0.0.0/4 protocol=!igmp ttl=equal:1 new-ttl=set:2 passthrough=yes comment="IoT multicast TTL one hop" }
/ip firewall mangle set [find where comment="IoT multicast TTL one hop"] chain=prerouting action=change-ttl in-interface=vlan300-iot dst-address=224.0.0.0/4 protocol=!igmp ttl=equal:1 new-ttl=set:2 passthrough=yes disabled=no
:if ([:len [/ip firewall mangle find where comment="Cloud multicast TTL one hop"]] > 1) do={ :error "Duplicate multicast TTL identity" }
:if ([:len [/ip firewall mangle find where comment="Cloud multicast TTL one hop"]] = 0) do={ /ip firewall mangle add chain=prerouting action=change-ttl in-interface=vlan400-home-cloud dst-address=224.0.0.0/4 protocol=!igmp ttl=equal:1 new-ttl=set:2 passthrough=yes comment="Cloud multicast TTL one hop" }
/ip firewall mangle set [find where comment="Cloud multicast TTL one hop"] chain=prerouting action=change-ttl in-interface=vlan400-home-cloud dst-address=224.0.0.0/4 protocol=!igmp ttl=equal:1 new-ttl=set:2 passthrough=yes disabled=no
:do {
    :local rule [/ip firewall filter find where comment="Cloud SSDP unicast response to Home"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT SSDP unicast response to Home"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Home multicast input"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT multicast input"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud multicast input"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Home multicast to IoT"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Home multicast to Cloud"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT multicast to Home"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="IoT multicast to Cloud"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud multicast to Home"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
}
:do {
    :local rule [/ip firewall filter find where comment="Cloud multicast to IoT"]
    :local first [:pick [/ip firewall filter find where dynamic=no] 0]
    :if ($rule != $first) do={ /ip firewall filter move $rule destination=$first }
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
