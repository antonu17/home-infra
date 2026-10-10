# Built-in input/forward chains only. Natural comments are unique rule keys.
# Final denies are enabled. Fill actual remote/service exception lists first.
# WAN FastTrack is disabled until the main-table/mangle/IPsec/queue audit passes;
# set disabled=no on its source rule here after that audit, then reimport.
:if ([:len [/ip firewall filter find where comment="NAS Home access"]] > 1) do={ :error "Duplicate firewall comment: NAS Home access" }
:if ([:len [/ip firewall filter find where comment="NAS IoT access"]] > 1) do={ :error "Duplicate firewall comment: NAS IoT access" }
:if ([:len [/ip firewall filter find where comment="IoT NAS access"]] > 1) do={ :error "Duplicate firewall comment: IoT NAS access" }
:if ([:len [/ip firewall filter find where comment="Home mDNS discovery"]] > 1) do={ :error "Duplicate firewall comment: Home mDNS discovery" }
:if ([:len [/ip firewall filter find where comment="IoT mDNS discovery"]] > 1) do={ :error "Duplicate firewall comment: IoT mDNS discovery" }
:if ([:len [/ip firewall filter find where comment="Cloud mDNS discovery"]] > 1) do={ :error "Duplicate firewall comment: Cloud mDNS discovery" }
:if ([:len [/ip firewall filter find where comment="Home NAS access" or comment="Home NAS web services"]] > 1) do={ :error "Duplicate firewall comment: Home NAS access" }
:if ([:len [/ip firewall filter find where comment="input established related"]] > 1) do={ :error "Duplicate firewall comment: input established related" }
:if ([:len [/ip firewall filter find where comment="input invalid"]] > 1) do={ :error "Duplicate firewall comment: input invalid" }
:if ([:len [/ip firewall filter find where comment="Home router management"]] > 1) do={ :error "Duplicate firewall comment: Home router management" }
:if ([:len [/ip firewall filter find where comment="Home router diagnostics"]] > 1) do={ :error "Duplicate firewall comment: Home router diagnostics" }
:if ([:len [/ip firewall filter find where comment="DHCP client requests incl 0.0.0.0"]] > 1) do={ :error "Duplicate firewall comment: DHCP client requests incl 0.0.0.0" }
:if ([:len [/ip firewall filter find where comment="Home DNS UDP"]] > 1) do={ :error "Duplicate firewall comment: Home DNS UDP" }
:if ([:len [/ip firewall filter find where comment="Home DNS TCP"]] > 1) do={ :error "Duplicate firewall comment: Home DNS TCP" }
:if ([:len [/ip firewall filter find where comment="Guest DNS UDP"]] > 1) do={ :error "Duplicate firewall comment: Guest DNS UDP" }
:if ([:len [/ip firewall filter find where comment="Guest DNS TCP"]] > 1) do={ :error "Duplicate firewall comment: Guest DNS TCP" }
:if ([:len [/ip firewall filter find where comment="IoT DNS UDP"]] > 1) do={ :error "Duplicate firewall comment: IoT DNS UDP" }
:if ([:len [/ip firewall filter find where comment="IoT DNS TCP"]] > 1) do={ :error "Duplicate firewall comment: IoT DNS TCP" }
:if ([:len [/ip firewall filter find where comment="Cloud DNS and native TFTP"]] > 1) do={ :error "Duplicate firewall comment: Cloud DNS and native TFTP" }
:if ([:len [/ip firewall filter find where comment="Cloud DNS TCP"]] > 1) do={ :error "Duplicate firewall comment: Cloud DNS TCP" }
:if ([:len [/ip firewall filter find where comment="Cilium inbound BGP"]] > 1) do={ :error "Duplicate firewall comment: Cilium inbound BGP" }
:if ([:len [/ip firewall filter find where comment="Cilium router-initiated BGP return"]] > 1) do={ :error "Duplicate firewall comment: Cilium router-initiated BGP return" }
:if ([:len [/ip firewall filter find where comment="ExternalDNS current HTTP REST"]] > 1) do={ :error "Duplicate firewall comment: ExternalDNS current HTTP REST" }
:if ([:len [/ip firewall filter find where comment="Authorized remote router management"]] > 1) do={ :error "Duplicate firewall comment: Authorized remote router management" }
:if ([:len [/ip firewall filter find where comment="input default deny"]] > 1) do={ :error "Duplicate firewall comment: input default deny" }
:if ([:len [/ip firewall filter find where comment="forward invalid"]] > 1) do={ :error "Duplicate firewall comment: forward invalid" }
:if ([:len [/ip firewall filter find where comment="verified main-table WAN FastTrack"]] > 1) do={ :error "Duplicate firewall comment: verified main-table WAN FastTrack" }
:if ([:len [/ip firewall filter find where comment="forward established related"]] > 1) do={ :error "Duplicate firewall comment: forward established related" }
:if ([:len [/ip firewall filter find where comment="Home to IoT requested access"]] > 1) do={ :error "Duplicate firewall comment: Home to IoT requested access" }
:if ([:len [/ip firewall filter find where comment="Home to routed cloud web services"]] > 1) do={ :error "Duplicate firewall comment: Home to routed cloud web services" }
:if ([:len [/ip firewall filter find where comment="Home Kubernetes API VIP"]] > 1) do={ :error "Duplicate firewall comment: Home Kubernetes API VIP" }
:if ([:len [/ip firewall filter find where comment="Home Talos known nodes"]] > 1) do={ :error "Duplicate firewall comment: Home Talos known nodes" }
:if ([:len [/ip firewall filter find where comment="Home verified infrastructure management"]] > 1) do={ :error "Duplicate firewall comment: Home verified infrastructure management" }
:if ([:len [/ip firewall filter find where comment="Guest IPP printers"]] > 1) do={ :error "Duplicate firewall comment: Guest IPP printers" }
:if ([:len [/ip firewall filter find where comment="measured HA integration HTTPS"]] > 1) do={ :error "Duplicate firewall comment: measured HA integration HTTPS" }
:if ([:len [/ip firewall filter find where comment="NAS HTTPS and iSCSI"]] > 1) do={ :error "Duplicate firewall comment: NAS HTTPS and iSCSI" }
:if ([:len [/ip firewall filter find where comment="checked-in PXE HTTP factory"]] > 1) do={ :error "Duplicate firewall comment: checked-in PXE HTTP factory" }
:if ([:len [/ip firewall filter find where comment="existing Home resolver UDP"]] > 1) do={ :error "Duplicate firewall comment: existing Home resolver UDP" }
:if ([:len [/ip firewall filter find where comment="existing Home resolver TCP"]] > 1) do={ :error "Duplicate firewall comment: existing Home resolver TCP" }
:if ([:len [/ip firewall filter find where comment="Home Internet"]] > 1) do={ :error "Duplicate firewall comment: Home Internet" }
:if ([:len [/ip firewall filter find where comment="Guest Internet"]] > 1) do={ :error "Duplicate firewall comment: Guest Internet" }
:if ([:len [/ip firewall filter find where comment="IoT Internet requested baseline"]] > 1) do={ :error "Duplicate firewall comment: IoT Internet requested baseline" }
:if ([:len [/ip firewall filter find where comment="Cloud Internet"]] > 1) do={ :error "Duplicate firewall comment: Cloud Internet" }
:if ([:len [/ip firewall filter find where comment="Authorized remote cloud web services"]] > 1) do={ :error "Duplicate firewall comment: Authorized remote cloud web services" }
:if ([:len [/ip firewall filter find where comment="Cloud to routed cloud web services"]] > 1) do={ :error "Duplicate firewall comment: Cloud to routed cloud web services" }
:if ([:len [/ip firewall filter find where comment="forward default deny"]] > 1) do={ :error "Duplicate firewall comment: forward default deny" }

:do {
    :local existing [/ip firewall filter find where comment="input established related"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=input established related" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="input established related"
        :set existing [/ip firewall filter find where comment="input established related"]
    }
    /ip firewall filter set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept connection-state=established,related comment="input established related" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="input invalid"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=input invalid" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="input invalid"
        :set existing [/ip firewall filter find where comment="input invalid"]
    }
    /ip firewall filter set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=drop connection-state=invalid comment="input invalid" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home router management"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home router management" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Home router management"
        :set existing [/ip firewall filter find where comment="Home router management"]
    }
    /ip firewall filter set $existing !src-address !dst-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS protocol=tcp dst-port=22,80,443,8291 comment="Home router management" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home router diagnostics"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home router diagnostics" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Home router diagnostics"
        :set existing [/ip firewall filter find where comment="Home router diagnostics"]
    }
    /ip firewall filter set $existing !src-address !dst-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS protocol=icmp comment="Home router diagnostics" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="DHCP client requests incl 0.0.0.0"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=DHCP client requests incl 0.0.0.0" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="DHCP client requests incl 0.0.0.0"
        :set existing [/ip firewall filter find where comment="DHCP client requests incl 0.0.0.0"]
    }
    /ip firewall filter set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=LAN protocol=udp src-port=68 dst-port=67 comment="DHCP client requests incl 0.0.0.0" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home DNS UDP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home DNS UDP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Home DNS UDP"
        :set existing [/ip firewall filter find where comment="Home DNS UDP"]
    }
    /ip firewall filter set $existing !src-address !dst-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS protocol=udp dst-port=53 comment="Home DNS UDP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home DNS TCP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home DNS TCP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Home DNS TCP"
        :set existing [/ip firewall filter find where comment="Home DNS TCP"]
    }
    /ip firewall filter set $existing !src-address !dst-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS protocol=tcp dst-port=53 comment="Home DNS TCP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Guest DNS UDP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Guest DNS UDP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Guest DNS UDP"
        :set existing [/ip firewall filter find where comment="Guest DNS UDP"]
    }
    /ip firewall filter set $existing !src-address !dst-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=GUEST src-address-list=GUEST-NETWORKS protocol=udp dst-port=53 comment="Guest DNS UDP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Guest DNS TCP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Guest DNS TCP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Guest DNS TCP"
        :set existing [/ip firewall filter find where comment="Guest DNS TCP"]
    }
    /ip firewall filter set $existing !src-address !dst-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=GUEST src-address-list=GUEST-NETWORKS protocol=tcp dst-port=53 comment="Guest DNS TCP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="IoT DNS UDP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=IoT DNS UDP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="IoT DNS UDP"
        :set existing [/ip firewall filter find where comment="IoT DNS UDP"]
    }
    /ip firewall filter set $existing !src-address !dst-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=IOT src-address-list=IOT-NETWORKS protocol=udp dst-port=53 comment="IoT DNS UDP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="IoT DNS TCP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=IoT DNS TCP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="IoT DNS TCP"
        :set existing [/ip firewall filter find where comment="IoT DNS TCP"]
    }
    /ip firewall filter set $existing !src-address !dst-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=IOT src-address-list=IOT-NETWORKS protocol=tcp dst-port=53 comment="IoT DNS TCP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Cloud DNS and native TFTP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Cloud DNS and native TFTP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Cloud DNS and native TFTP"
        :set existing [/ip firewall filter find where comment="Cloud DNS and native TFTP"]
    }
    /ip firewall filter set $existing !dst-address !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=CLOUD src-address=192.168.40.0/24 protocol=udp dst-port=53,69 comment="Cloud DNS and native TFTP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Cloud DNS TCP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Cloud DNS TCP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Cloud DNS TCP"
        :set existing [/ip firewall filter find where comment="Cloud DNS TCP"]
    }
    /ip firewall filter set $existing !dst-address !src-address-list !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=CLOUD src-address=192.168.40.0/24 protocol=tcp dst-port=53 comment="Cloud DNS TCP" disabled=no log=no log-prefix=""
}


:do {
    :local existing [/ip firewall filter find where comment="Home mDNS discovery"]
    :if ([:len $existing] > 1) do={ :error "Duplicate firewall comment: Home mDNS discovery" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Home mDNS discovery"
        :set existing [/ip firewall filter find where comment="Home mDNS discovery"]
    }
    /ip firewall filter set $existing !src-address-list !dst-address-list !in-interface-list !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan100-trusted src-address=192.168.100.0/24 dst-address=224.0.0.251 protocol=udp dst-port=5353 comment="Home mDNS discovery" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="IoT mDNS discovery"]
    :if ([:len $existing] > 1) do={ :error "Duplicate firewall comment: IoT mDNS discovery" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="IoT mDNS discovery"
        :set existing [/ip firewall filter find where comment="IoT mDNS discovery"]
    }
    /ip firewall filter set $existing !src-address-list !dst-address-list !in-interface-list !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan300-iot src-address=192.168.30.0/24 dst-address=224.0.0.251 protocol=udp dst-port=5353 comment="IoT mDNS discovery" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Cloud mDNS discovery"]
    :if ([:len $existing] > 1) do={ :error "Duplicate firewall comment: Cloud mDNS discovery" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Cloud mDNS discovery"
        :set existing [/ip firewall filter find where comment="Cloud mDNS discovery"]
    }
    /ip firewall filter set $existing !src-address-list !dst-address-list !in-interface-list !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface=vlan400-home-cloud src-address=192.168.40.0/24 dst-address=224.0.0.251 protocol=udp dst-port=5353 comment="Cloud mDNS discovery" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Cilium inbound BGP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Cilium inbound BGP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Cilium inbound BGP"
        :set existing [/ip firewall filter find where comment="Cilium inbound BGP"]
    }
    /ip firewall filter set $existing !src-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=CLOUD src-address-list=BGP-PEERS dst-address=192.168.40.1 protocol=tcp dst-port=179 comment="Cilium inbound BGP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Cilium router-initiated BGP return"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Cilium router-initiated BGP return" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Cilium router-initiated BGP return"
        :set existing [/ip firewall filter find where comment="Cilium router-initiated BGP return"]
    }
    /ip firewall filter set $existing !src-address !dst-address-list !in-interface !out-interface !out-interface-list !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=CLOUD src-address-list=BGP-PEERS dst-address=192.168.40.1 protocol=tcp src-port=179 comment="Cilium router-initiated BGP return" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="ExternalDNS current HTTP REST"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=ExternalDNS current HTTP REST" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="ExternalDNS current HTTP REST"
        :set existing [/ip firewall filter find where comment="ExternalDNS current HTTP REST"]
    }
    /ip firewall filter set $existing !src-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept disabled=no in-interface-list=CLOUD src-address-list=EXTERNALDNS-EGRESS dst-address=192.168.40.1 protocol=tcp dst-port=80 comment="ExternalDNS current HTTP REST" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Authorized remote router management"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Authorized remote router management" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="Authorized remote router management"
        :set existing [/ip firewall filter find where comment="Authorized remote router management"]
    }
    /ip firewall filter set $existing !src-address !dst-address-list !in-interface !out-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=REMOTE src-address-list=REMOTE-MGMT-SOURCES dst-address=192.168.100.1 protocol=tcp dst-port=22,80,443,8291 disabled=no comment="Authorized remote router management" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="input default deny"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=input default deny" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=input disabled=yes comment="input default deny"
        :set existing [/ip firewall filter find where comment="input default deny"]
    }
    /ip firewall filter set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=drop disabled=yes comment="input default deny" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="forward invalid"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=forward invalid" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="forward invalid"
        :set existing [/ip firewall filter find where comment="forward invalid"]
    }
    /ip firewall filter set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=drop connection-state=invalid comment="forward invalid" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="verified main-table WAN FastTrack"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=verified main-table WAN FastTrack" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="verified main-table WAN FastTrack"
        :set existing [/ip firewall filter find where comment="verified main-table WAN FastTrack"]
    }
    /ip firewall filter set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !protocol !src-port !dst-port !connection-nat-state !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=fasttrack-connection disabled=yes connection-state=established,related in-interface-list=LAN out-interface-list=WAN connection-mark=no-mark ipsec-policy=out,none comment="verified main-table WAN FastTrack" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="forward established related"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=forward established related" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="forward established related"
        :set existing [/ip firewall filter find where comment="forward established related"]
    }
    /ip firewall filter set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept connection-state=established,related comment="forward established related" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home to IoT requested access"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home to IoT requested access" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Home to IoT requested access"
        :set existing [/ip firewall filter find where comment="Home to IoT requested access"]
    }
    /ip firewall filter set $existing !src-address !dst-address !in-interface !out-interface !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface-list=IOT dst-address-list=IOT-NETWORKS comment="Home to IoT requested access" disabled=no log=no log-prefix=""
}




# SSDP searches retain their original client source; NAS unicast answers need this path.
:do {
    :local existing [/ip firewall filter find where comment="NAS Home access"]
    :if ([:len $existing] > 1) do={ :error "Duplicate firewall comment: NAS Home access" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="NAS Home access"
        :set existing [/ip firewall filter find where comment="NAS Home access"]
    }
    /ip firewall filter set $existing !protocol !src-port !dst-port !tcp-flags !icmp-options !src-address-list !dst-address-list !in-interface !out-interface !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address=192.168.40.5 out-interface-list=HOME dst-address=192.168.100.0/24 disabled=no comment="NAS Home access" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="NAS IoT access"]
    :if ([:len $existing] > 1) do={ :error "Duplicate firewall comment: NAS IoT access" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="NAS IoT access"
        :set existing [/ip firewall filter find where comment="NAS IoT access"]
    }
    /ip firewall filter set $existing !protocol !src-port !dst-port !tcp-flags !icmp-options !src-address-list !dst-address-list !in-interface !out-interface !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address=192.168.40.5 out-interface-list=IOT dst-address=192.168.30.0/24 disabled=no comment="NAS IoT access" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="IoT NAS access"]
    :if ([:len $existing] > 1) do={ :error "Duplicate firewall comment: IoT NAS access" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="IoT NAS access"
        :set existing [/ip firewall filter find where comment="IoT NAS access"]
    }
    /ip firewall filter set $existing !protocol !src-port !dst-port !tcp-flags !icmp-options !src-address-list !dst-address-list !in-interface !out-interface !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !limit !dst-limit !time chain=forward action=accept in-interface-list=IOT src-address=192.168.30.0/24 out-interface-list=CLOUD dst-address=192.168.40.5 disabled=no comment="IoT NAS access" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home NAS access" or comment="Home NAS web services"]
    :if ([:len $existing] > 1) do={ :error "Duplicate firewall comment: Home NAS access" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Home NAS access"
        :set existing [/ip firewall filter find where comment="Home NAS access" or comment="Home NAS web services"]
    }
    /ip firewall filter set $existing !icmp-options !tcp-flags !dst-port !src-port !protocol chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface-list=CLOUD dst-address=192.168.40.5 disabled=no comment="Home NAS access"
}


:do {
    :local existing [/ip firewall filter find where comment="Home to routed cloud web services"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home to routed cloud web services" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Home to routed cloud web services"
        :set existing [/ip firewall filter find where comment="Home to routed cloud web services"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address !dst-address-list !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface-list=CLOUD dst-address=10.40.0.0/24 comment="Home to routed cloud web services" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home Kubernetes API VIP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home Kubernetes API VIP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Home Kubernetes API VIP"
        :set existing [/ip firewall filter find where comment="Home Kubernetes API VIP"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address !dst-address-list !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface-list=CLOUD dst-address=192.168.40.20 comment="Home Kubernetes API VIP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home Talos known nodes"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home Talos known nodes" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Home Talos known nodes"
        :set existing [/ip firewall filter find where comment="Home Talos known nodes"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address !dst-address !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface-list=CLOUD dst-address-list=BGP-PEERS comment="Home Talos known nodes" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home verified infrastructure management"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home verified infrastructure management" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Home verified infrastructure management"
        :set existing [/ip firewall filter find where comment="Home verified infrastructure management"]
    }
    /ip firewall filter set $existing !protocol !dst-port !src-address !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept disabled=no in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface-list=MGMT dst-address=192.168.88.3 dst-address-list=INFRA-MGMT comment="Home verified infrastructure management" log=no log-prefix=""
}


:do {
    :local existing [/ip firewall filter find where comment="measured HA integration HTTPS"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=measured HA integration HTTPS" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="measured HA integration HTTPS"
        :set existing [/ip firewall filter find where comment="measured HA integration HTTPS"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address !dst-address !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept disabled=no in-interface-list=CLOUD src-address-list=HA-EGRESS out-interface-list=IOT dst-address-list=HA-IOT comment="measured HA integration HTTPS" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="NAS HTTPS and iSCSI"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=NAS HTTPS and iSCSI" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="NAS HTTPS and iSCSI"
        :set existing [/ip firewall filter find where comment="NAS HTTPS and iSCSI"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address-list !dst-address-list !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address=192.168.40.0/24 out-interface-list=HOME dst-address=192.168.100.5 comment="NAS HTTPS and iSCSI" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="checked-in PXE HTTP factory"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=checked-in PXE HTTP factory" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="checked-in PXE HTTP factory"
        :set existing [/ip firewall filter find where comment="checked-in PXE HTTP factory"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address-list !dst-address-list !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address=192.168.40.0/24 out-interface-list=HOME dst-address=192.168.100.5 comment="checked-in PXE HTTP factory" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="existing Home resolver UDP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=existing Home resolver UDP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="existing Home resolver UDP"
        :set existing [/ip firewall filter find where comment="existing Home resolver UDP"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address !dst-address-list !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=LAN src-address-list=LOCAL-NETWORKS out-interface-list=HOME dst-address=192.168.100.2 comment="existing Home resolver UDP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="existing Home resolver TCP"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=existing Home resolver TCP" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="existing Home resolver TCP"
        :set existing [/ip firewall filter find where comment="existing Home resolver TCP"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address !dst-address-list !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=LAN src-address-list=LOCAL-NETWORKS out-interface-list=HOME dst-address=192.168.100.2 comment="existing Home resolver TCP" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Home Internet"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Home Internet" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Home Internet"
        :set existing [/ip firewall filter find where comment="Home Internet"]
    }
    /ip firewall filter set $existing !src-address !dst-address !in-interface !out-interface !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=HOME src-address-list=HOME-NETWORKS out-interface-list=WAN dst-address-list=!LOCAL-NETWORKS comment="Home Internet" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Guest Internet"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Guest Internet" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Guest Internet"
        :set existing [/ip firewall filter find where comment="Guest Internet"]
    }
    /ip firewall filter set $existing !src-address !dst-address !in-interface !out-interface !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=GUEST src-address-list=GUEST-NETWORKS out-interface-list=WAN dst-address-list=!LOCAL-NETWORKS comment="Guest Internet" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="IoT Internet requested baseline"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=IoT Internet requested baseline" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="IoT Internet requested baseline"
        :set existing [/ip firewall filter find where comment="IoT Internet requested baseline"]
    }
    /ip firewall filter set $existing !src-address !dst-address !in-interface !out-interface !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=IOT src-address-list=IOT-NETWORKS out-interface-list=WAN dst-address-list=!LOCAL-NETWORKS comment="IoT Internet requested baseline" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Cloud Internet"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Cloud Internet" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Cloud Internet"
        :set existing [/ip firewall filter find where comment="Cloud Internet"]
    }
    /ip firewall filter set $existing !src-address !dst-address !in-interface !out-interface !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address-list=CLOUD-NETWORKS out-interface-list=WAN dst-address-list=!LOCAL-NETWORKS comment="Cloud Internet" disabled=no log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Authorized remote cloud web services"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Authorized remote cloud web services" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Authorized remote cloud web services"
        :set existing [/ip firewall filter find where comment="Authorized remote cloud web services"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address !dst-address-list !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=REMOTE src-address-list=REMOTE-MGMT-SOURCES out-interface-list=CLOUD dst-address=10.40.0.0/24 disabled=no comment="Authorized remote cloud web services" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="Cloud to routed cloud web services"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=Cloud to routed cloud web services" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="Cloud to routed cloud web services"
        :set existing [/ip firewall filter find where comment="Cloud to routed cloud web services"]
    }
    /ip firewall filter set $existing !dst-port !protocol !src-address-list !dst-address-list !in-interface !out-interface !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address=192.168.40.0/24 out-interface-list=CLOUD dst-address=10.40.0.0/24 disabled=no comment="Cloud to routed cloud web services" log=no log-prefix=""
}

:do {
    :local existing [/ip firewall filter find where comment="forward default deny"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall filter object: comment=forward default deny" }
    :if ([:len $existing] = 0) do={
        /ip firewall filter add chain=forward disabled=yes comment="forward default deny"
        :set existing [/ip firewall filter find where comment="forward default deny"]
    }
    /ip firewall filter set $existing !src-address !dst-address !src-address-list !dst-address-list !in-interface !out-interface !in-interface-list !out-interface-list !protocol !src-port !dst-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=drop disabled=yes comment="forward default deny" log=no log-prefix=""
}

# Reverse moves order managed rules before other static rules.
# Built-in dynamic rules (including FastTrack counters) stay untouched.
:do {
    :foreach ruleComment in={
        "forward default deny";
        "Cloud to routed cloud web services";
        "Authorized remote cloud web services";
        "Cloud Internet";
        "IoT Internet requested baseline";
        "Guest Internet";
        "Home Internet";
        "existing Home resolver TCP";
        "existing Home resolver UDP";
        "checked-in PXE HTTP factory";
        "NAS HTTPS and iSCSI";
        "measured HA integration HTTPS";
        "Home verified infrastructure management";
        "Home Talos known nodes";
        "Home Kubernetes API VIP";
        "Home to routed cloud web services";
        "NAS Home access";
        "NAS IoT access";
        "IoT NAS access";
        "Home NAS access";
        "Home to IoT requested access";
        "forward established related";
        "verified main-table WAN FastTrack";
        "forward invalid";
        "input default deny";
        "Authorized remote router management";
        "ExternalDNS current HTTP REST";
        "Cilium router-initiated BGP return";
        "Cilium inbound BGP";
        "Cloud mDNS discovery";
        "IoT mDNS discovery";
        "Home mDNS discovery";
        "Cloud DNS TCP";
        "Cloud DNS and native TFTP";
        "IoT DNS TCP";
        "IoT DNS UDP";
        "Guest DNS TCP";
        "Guest DNS UDP";
        "Home DNS TCP";
        "Home DNS UDP";
        "DHCP client requests incl 0.0.0.0";
        "Home router diagnostics";
        "Home router management";
        "input invalid";
        "input established related"
    } do={
        :local rule [/ip firewall filter find where dynamic=no and comment=$ruleComment]
        :local first [:pick [/ip firewall filter find where dynamic=no] 0]
        :if ($rule != $first) do={
            /ip firewall filter move $rule destination=$first
        }
    }
}
# Other existing rules remain below this complete managed block. Terminal
# denies prevent old unconditional LAN accepts/FastTrack from bypassing policy.
# No jumps, custom chains, notrack acceptance, generic dstnat or internal NAT.

# Enable terminal denies only after all managed allows are in their final order.
/ip firewall filter enable [find where comment="input default deny"]
/ip firewall filter enable [find where comment="forward default deny"]

# Retire only the now-redundant managed NAS ICMP rule; full NAS L3 access includes ICMP.
/ip firewall filter remove [find where dynamic=no and comment="Home NAS diagnostics"]

# Operator policy 2026-10-10: Guests must not print. Retire only this former
# managed exception; Guest-to-IoT now reaches forward default deny. Idempotent.
/ip firewall filter remove [find where dynamic=no and comment="Guest IPP printers"]
