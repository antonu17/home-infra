# RouterOS7.24.4: SSDP container attachments, DHCP on existing Home/IoT/Cloud scopes.
# Apply 04 first; reimports preserve identities and do not change physical uplinks.
:if ([:len [/system package find where name="container" and disabled=no]] != 1) do={ :error "Container package is required" }
:if ([/system device-mode get container] != true) do={ :error "Container device mode is required" }



:do {
    :local row [/interface bridge vlan find where bridge="bridge" and vlan-ids=100 and dynamic=no]
    :if ([:len $row] != 1) do={ :error "Apply the single-100 VLAN table first" }
    :local existing [/interface veth find where name="veth-ssdp-home"]
    :if ([:len $existing] > 1) do={ :error "Duplicate SSDP VETH" }
    :if ([:len $existing] = 0) do={
        :if ([:len [/interface find where name="veth-ssdp-home"]] != 0) do={ :error "SSDP name belongs to a non-VETH interface" }
        /interface veth add name=veth-ssdp-home dhcp=yes disabled=no comment="SSDP relay VLAN100"
    } else={
        :if ([/interface veth get $existing dhcp] != true) do={ :error "Existing SSDP VETH must use DHCP; stop relay before changing networking" }
        /interface veth set $existing disabled=no comment="SSDP relay VLAN100"
    }
    :local port [/interface bridge port find where interface="veth-ssdp-home"]
    :if ([:len $port] > 1) do={ :error "Duplicate SSDP bridge port" }
    :if ([:len $port] = 0) do={
        /interface bridge port add bridge=bridge interface=veth-ssdp-home pvid=100 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes disabled=no comment="SSDP relay VLAN100"
    } else={
        /interface bridge port set $port bridge=bridge interface=veth-ssdp-home pvid=100 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes disabled=no comment="SSDP relay VLAN100"
    }
    /interface bridge vlan set $row untagged=ether4,ether8,veth-ssdp-home
}

:do {
    :local row [/interface bridge vlan find where bridge="bridge" and vlan-ids=300 and dynamic=no]
    :if ([:len $row] != 1) do={ :error "Apply the single-300 VLAN table first" }
    :local existing [/interface veth find where name="veth-ssdp-iot"]
    :if ([:len $existing] > 1) do={ :error "Duplicate SSDP VETH" }
    :if ([:len $existing] = 0) do={
        :if ([:len [/interface find where name="veth-ssdp-iot"]] != 0) do={ :error "SSDP name belongs to a non-VETH interface" }
        /interface veth add name=veth-ssdp-iot dhcp=yes disabled=no comment="SSDP relay VLAN300"
    } else={
        :if ([/interface veth get $existing dhcp] != true) do={ :error "Existing SSDP VETH must use DHCP; stop relay before changing networking" }
        /interface veth set $existing disabled=no comment="SSDP relay VLAN300"
    }
    :local port [/interface bridge port find where interface="veth-ssdp-iot"]
    :if ([:len $port] > 1) do={ :error "Duplicate SSDP bridge port" }
    :if ([:len $port] = 0) do={
        /interface bridge port add bridge=bridge interface=veth-ssdp-iot pvid=300 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes disabled=no comment="SSDP relay VLAN300"
    } else={
        /interface bridge port set $port bridge=bridge interface=veth-ssdp-iot pvid=300 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes disabled=no comment="SSDP relay VLAN300"
    }
    /interface bridge vlan set $row untagged=ether3,veth-ssdp-iot
}

:do {
    :local row [/interface bridge vlan find where bridge="bridge" and vlan-ids=400 and dynamic=no]
    :if ([:len $row] != 1) do={ :error "Apply the single-400 VLAN table first" }
    :local existing [/interface veth find where name="veth-ssdp-cloud"]
    :if ([:len $existing] > 1) do={ :error "Duplicate SSDP VETH" }
    :if ([:len $existing] = 0) do={
        :if ([:len [/interface find where name="veth-ssdp-cloud"]] != 0) do={ :error "SSDP name belongs to a non-VETH interface" }
        /interface veth add name=veth-ssdp-cloud dhcp=yes disabled=no comment="SSDP relay VLAN400"
    } else={
        :if ([/interface veth get $existing dhcp] != true) do={ :error "Existing SSDP VETH must use DHCP; stop relay before changing networking" }
        /interface veth set $existing disabled=no comment="SSDP relay VLAN400"
    }
    :local port [/interface bridge port find where interface="veth-ssdp-cloud"]
    :if ([:len $port] > 1) do={ :error "Duplicate SSDP bridge port" }
    :if ([:len $port] = 0) do={
        /interface bridge port add bridge=bridge interface=veth-ssdp-cloud pvid=400 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes disabled=no comment="SSDP relay VLAN400"
    } else={
        /interface bridge port set $port bridge=bridge interface=veth-ssdp-cloud pvid=400 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes disabled=no comment="SSDP relay VLAN400"
    }
    /interface bridge vlan set $row untagged=syno1,ether5,ether6,veth-ssdp-cloud
}
