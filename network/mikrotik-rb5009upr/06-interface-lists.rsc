# Classify routed interfaces; existing remote/Tailscale memberships are preserved.

:do {
    :local existing [/interface list find where name="WAN"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list object: name=WAN" }
    :if ([:len $existing] = 0) do={
        /interface list add name=WAN comment="Internet uplink"
    } else={
        /interface list set $existing name=WAN comment="Internet uplink"
    }
}

:do {
    :local existing [/interface list find where name="LAN"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list object: name=LAN" }
    :if ([:len $existing] = 0) do={
        /interface list add name=LAN comment="Internal routed networks"
    } else={
        /interface list set $existing name=LAN comment="Internal routed networks"
    }
}

:do {
    :local existing [/interface list find where name="MGMT"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list object: name=MGMT" }
    :if ([:len $existing] = 0) do={
        /interface list add name=MGMT comment="Infrastructure management VLAN1"
    } else={
        /interface list set $existing name=MGMT comment="Infrastructure management VLAN1"
    }
}

:do {
    :local existing [/interface list find where name="HOME"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list object: name=HOME" }
    :if ([:len $existing] = 0) do={
        /interface list add name=HOME comment="Home VLAN100"
    } else={
        /interface list set $existing name=HOME comment="Home VLAN100"
    }
}

:do {
    :local existing [/interface list find where name="GUEST"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list object: name=GUEST" }
    :if ([:len $existing] = 0) do={
        /interface list add name=GUEST comment="Guests VLAN200"
    } else={
        /interface list set $existing name=GUEST comment="Guests VLAN200"
    }
}

:do {
    :local existing [/interface list find where name="IOT"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list object: name=IOT" }
    :if ([:len $existing] = 0) do={
        /interface list add name=IOT comment="IoT VLAN300"
    } else={
        /interface list set $existing name=IOT comment="IoT VLAN300"
    }
}

:do {
    :local existing [/interface list find where name="CLOUD"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list object: name=CLOUD" }
    :if ([:len $existing] = 0) do={
        /interface list add name=CLOUD comment="Home Cloud VLAN400"
    } else={
        /interface list set $existing name=CLOUD comment="Home Cloud VLAN400"
    }
}

:do {
    :local existing [/interface list find where name="REMOTE"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list object: name=REMOTE" }
    :if ([:len $existing] = 0) do={
        /interface list add name=REMOTE comment="Authorized remote routed interfaces"
    } else={
        /interface list set $existing name=REMOTE comment="Authorized remote routed interfaces"
    }
}

:do {
    :local existing [/interface list member find where list="WAN" and interface="sfp-sfpplus1"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=WAN and interface=sfp-sfpplus1" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=WAN interface=sfp-sfpplus1 disabled=no comment="Internet uplink membership"
    } else={
        /interface list member set $existing list=WAN interface=sfp-sfpplus1 disabled=no comment="Internet uplink membership"
    }
}

:do {
    :local existing [/interface list member find where list="LAN" and interface="vlan1-mgmt"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=LAN and interface=vlan1-mgmt" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=LAN interface=vlan1-mgmt disabled=no comment="Management membership"
    } else={
        /interface list member set $existing list=LAN interface=vlan1-mgmt disabled=no comment="Management membership"
    }
}

:do {
    :local existing [/interface list member find where list="LAN" and interface="vlan100-trusted"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=LAN and interface=vlan100-trusted" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=LAN interface=vlan100-trusted disabled=no comment="Home membership"
    } else={
        /interface list member set $existing list=LAN interface=vlan100-trusted disabled=no comment="Home membership"
    }
}

:do {
    :local existing [/interface list member find where list="LAN" and interface="vlan200-guest"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=LAN and interface=vlan200-guest" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=LAN interface=vlan200-guest disabled=no comment="Guests membership"
    } else={
        /interface list member set $existing list=LAN interface=vlan200-guest disabled=no comment="Guests membership"
    }
}

:do {
    :local existing [/interface list member find where list="LAN" and interface="vlan300-iot"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=LAN and interface=vlan300-iot" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=LAN interface=vlan300-iot disabled=no comment="IoT membership"
    } else={
        /interface list member set $existing list=LAN interface=vlan300-iot disabled=no comment="IoT membership"
    }
}

:do {
    :local existing [/interface list member find where list="LAN" and interface="vlan400-home-cloud"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=LAN and interface=vlan400-home-cloud" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=LAN interface=vlan400-home-cloud disabled=no comment="Home Cloud membership"
    } else={
        /interface list member set $existing list=LAN interface=vlan400-home-cloud disabled=no comment="Home Cloud membership"
    }
}

:do {
    :local existing [/interface list member find where list="MGMT" and interface="vlan1-mgmt"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=MGMT and interface=vlan1-mgmt" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=MGMT interface=vlan1-mgmt disabled=no comment="Management membership"
    } else={
        /interface list member set $existing list=MGMT interface=vlan1-mgmt disabled=no comment="Management membership"
    }
}

:do {
    :local existing [/interface list member find where list="HOME" and interface="vlan100-trusted"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=HOME and interface=vlan100-trusted" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=HOME interface=vlan100-trusted disabled=no comment="Home membership"
    } else={
        /interface list member set $existing list=HOME interface=vlan100-trusted disabled=no comment="Home membership"
    }
}

:do {
    :local existing [/interface list member find where list="GUEST" and interface="vlan200-guest"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=GUEST and interface=vlan200-guest" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=GUEST interface=vlan200-guest disabled=no comment="Guests membership"
    } else={
        /interface list member set $existing list=GUEST interface=vlan200-guest disabled=no comment="Guests membership"
    }
}

:do {
    :local existing [/interface list member find where list="IOT" and interface="vlan300-iot"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=IOT and interface=vlan300-iot" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=IOT interface=vlan300-iot disabled=no comment="IoT membership"
    } else={
        /interface list member set $existing list=IOT interface=vlan300-iot disabled=no comment="IoT membership"
    }
}

:do {
    :local existing [/interface list member find where list="CLOUD" and interface="vlan400-home-cloud"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface list member object: list=CLOUD and interface=vlan400-home-cloud" }
    :if ([:len $existing] = 0) do={
        /interface list member add list=CLOUD interface=vlan400-home-cloud disabled=no comment="Home Cloud membership"
    } else={
        /interface list member set $existing list=CLOUD interface=vlan400-home-cloud disabled=no comment="Home Cloud membership"
    }
}

# These exact stale memberships are explicitly outside the target.
:do {
    :local stale [/interface list member find where list="WAN" and interface="ether8"]
    :if ([:len $stale] > 0) do={ /interface list member remove $stale }
}
:do {
    :local stale [/interface list member find where list="LAN" and interface="bridge"]
    :if ([:len $stale] > 0) do={ /interface list member remove $stale }
}
# REMOTE is deliberately empty until its actual routed ingress is known.
# Add the verified ingress using the same list+interface upsert pattern above.
# Audit other existing members and list include/exclude settings; this file
# does not delete arbitrary members or change service discovery settings.
