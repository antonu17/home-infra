# One VLAN-aware bridge; retain an existing bridge MAC and protocol-mode.
# Applying the target changes syno1, ether3, ether5 and ether6 networks.

:if ([:len [/interface bridge port find where interface="sfp-sfpplus1"]] > 0) do={ :error "WAN is a bridge port; remove that exact membership after reviewing the live state" }
:if ([/interface bridge settings get use-ip-firewall] = true) do={ :error "Existing bridge IP firewall needs review; this design uses routed IP filtering" }

:do {
    :local existing [/interface bridge find where name="bridge"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bridge object: name=bridge" }
    :if ([:len $existing] = 0) do={
        /interface bridge add name=bridge frame-types=admit-only-vlan-tagged ingress-filtering=yes vlan-filtering=yes disabled=no comment="LAN VLAN-aware bridge"
    } else={
        /interface bridge set $existing name=bridge frame-types=admit-only-vlan-tagged ingress-filtering=yes vlan-filtering=yes disabled=no comment="LAN VLAN-aware bridge"
    }
}

:do {
    :local existing [/interface bridge port find where interface="ether4"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bridge port object: interface=ether4" }
    :if ([:len $existing] = 0) do={
        /interface bridge port add bridge=bridge interface=ether4 pvid=100 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="Denis - Home access VLAN100"
    } else={
        /interface bridge port set $existing bridge=bridge interface=ether4 pvid=100 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="Denis - Home access VLAN100"
    }
}

:do {
    :local existing [/interface bridge port find where interface="ether8"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bridge port object: interface=ether8" }
    :if ([:len $existing] = 0) do={
        /interface bridge port add bridge=bridge interface=ether8 pvid=100 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="Anton - Home access VLAN100"
    } else={
        /interface bridge port set $existing bridge=bridge interface=ether8 pvid=100 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="Anton - Home access VLAN100"
    }
}

:do {
    :local existing [/interface bridge port find where interface="ether7"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bridge port object: interface=ether7" }
    :if ([:len $existing] = 0) do={
        /interface bridge port add bridge=bridge interface=ether7 pvid=1 frame-types=admit-all ingress-filtering=yes hw=yes disabled=no comment="Aruba - native VLAN1 tagged VLAN100,200,300"
    } else={
        /interface bridge port set $existing bridge=bridge interface=ether7 pvid=1 frame-types=admit-all ingress-filtering=yes hw=yes disabled=no comment="Aruba - native VLAN1 tagged VLAN100,200,300"
    }
}

:do {
    :local existing [/interface bridge port find where interface="ether3"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bridge port object: interface=ether3" }
    :if ([:len $existing] = 0) do={
        /interface bridge port add bridge=bridge interface=ether3 pvid=300 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="TV - IoT access VLAN300"
    } else={
        /interface bridge port set $existing bridge=bridge interface=ether3 pvid=300 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="TV - IoT access VLAN300"
    }
}

:do {
    :local existing [/interface bridge port find where interface="ether5"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bridge port object: interface=ether5" }
    :if ([:len $existing] = 0) do={
        /interface bridge port add bridge=bridge interface=ether5 pvid=400 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="worker-03 - Home Cloud access VLAN400"
    } else={
        /interface bridge port set $existing bridge=bridge interface=ether5 pvid=400 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="worker-03 - Home Cloud access VLAN400"
    }
}

:do {
    :local existing [/interface bridge port find where interface="ether6"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bridge port object: interface=ether6" }
    :if ([:len $existing] = 0) do={
        /interface bridge port add bridge=bridge interface=ether6 pvid=400 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="worker-02 - Home Cloud access VLAN400"
    } else={
        /interface bridge port set $existing bridge=bridge interface=ether6 pvid=400 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="worker-02 - Home Cloud access VLAN400"
    }
}

:do {
    :local existing [/interface bridge port find where interface="syno1"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface bridge port object: interface=syno1" }
    :if ([:len $existing] = 0) do={
        /interface bridge port add bridge=bridge interface=syno1 pvid=400 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="Synology - Home Cloud access VLAN400"
    } else={
        /interface bridge port set $existing bridge=bridge interface=syno1 pvid=400 frame-types=admit-only-untagged-and-priority-tagged ingress-filtering=yes hw=yes disabled=no comment="Synology - Home Cloud access VLAN400"
    }
}

# syno1 is an access port: untagged ingress maps to VLAN400; egress is untagged.
# NAS and VMM must not send VLAN400-tagged frames on this uplink.
