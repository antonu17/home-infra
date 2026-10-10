# VLAN and gateway objects use existing names and the documented addressing.
# Refuse a differently named interface already owning the same bridge/VLAN.

:foreach row in=[/interface vlan find where interface="bridge" and vlan-id=1] do={
    :if ([/interface vlan get $row name] != "vlan1-mgmt") do={ :error "VLAN1 already has another interface name; reconcile references first" }
}

:do {
    :local existing [/interface vlan find where name="vlan1-mgmt"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface vlan object: name=vlan1-mgmt" }
    :if ([:len $existing] = 0) do={
        /interface vlan add name=vlan1-mgmt interface=bridge vlan-id=1 disabled=no comment="Management routed interface"
    } else={
        /interface vlan set $existing name=vlan1-mgmt interface=bridge vlan-id=1 disabled=no comment="Management routed interface"
    }
}

:foreach row in=[/ip address find where address~"^192[.]168[.]88[.]1/"] do={
    :if (([/ip address get $row address] != "192.168.88.1/24") || ([/ip address get $row interface] != "vlan1-mgmt")) do={
        :error "Gateway 192.168.88.1 has an unexpected prefix/interface; no address change made"
    }
}

:do {
    :local existing [/ip address find where address="192.168.88.1/24" and interface="vlan1-mgmt"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip address object: address=192.168.88.1/24 and interface=vlan1-mgmt" }
    :if ([:len $existing] = 0) do={
        /ip address add address=192.168.88.1/24 interface=vlan1-mgmt network=192.168.88.0 disabled=no comment="Management gateway"
    } else={
        /ip address set $existing address=192.168.88.1/24 interface=vlan1-mgmt network=192.168.88.0 disabled=no comment="Management gateway"
    }
}

:foreach row in=[/interface vlan find where interface="bridge" and vlan-id=100] do={
    :if ([/interface vlan get $row name] != "vlan100-trusted") do={ :error "VLAN100 already has another interface name; reconcile references first" }
}

:do {
    :local existing [/interface vlan find where name="vlan100-trusted"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface vlan object: name=vlan100-trusted" }
    :if ([:len $existing] = 0) do={
        /interface vlan add name=vlan100-trusted interface=bridge vlan-id=100 disabled=no comment="Home routed interface"
    } else={
        /interface vlan set $existing name=vlan100-trusted interface=bridge vlan-id=100 disabled=no comment="Home routed interface"
    }
}

:foreach row in=[/ip address find where address~"^192[.]168[.]100[.]1/"] do={
    :if (([/ip address get $row address] != "192.168.100.1/24") || ([/ip address get $row interface] != "vlan100-trusted")) do={
        :error "Gateway 192.168.100.1 has an unexpected prefix/interface; no address change made"
    }
}

:do {
    :local existing [/ip address find where address="192.168.100.1/24" and interface="vlan100-trusted"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip address object: address=192.168.100.1/24 and interface=vlan100-trusted" }
    :if ([:len $existing] = 0) do={
        /ip address add address=192.168.100.1/24 interface=vlan100-trusted network=192.168.100.0 disabled=no comment="Home gateway"
    } else={
        /ip address set $existing address=192.168.100.1/24 interface=vlan100-trusted network=192.168.100.0 disabled=no comment="Home gateway"
    }
}

:foreach row in=[/interface vlan find where interface="bridge" and vlan-id=200] do={
    :if ([/interface vlan get $row name] != "vlan200-guest") do={ :error "VLAN200 already has another interface name; reconcile references first" }
}

:do {
    :local existing [/interface vlan find where name="vlan200-guest"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface vlan object: name=vlan200-guest" }
    :if ([:len $existing] = 0) do={
        /interface vlan add name=vlan200-guest interface=bridge vlan-id=200 disabled=no comment="Guests routed interface"
    } else={
        /interface vlan set $existing name=vlan200-guest interface=bridge vlan-id=200 disabled=no comment="Guests routed interface"
    }
}

:foreach row in=[/ip address find where address~"^192[.]168[.]200[.]1/"] do={
    :if (([/ip address get $row address] != "192.168.200.1/24") || ([/ip address get $row interface] != "vlan200-guest")) do={
        :error "Gateway 192.168.200.1 has an unexpected prefix/interface; no address change made"
    }
}

:do {
    :local existing [/ip address find where address="192.168.200.1/24" and interface="vlan200-guest"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip address object: address=192.168.200.1/24 and interface=vlan200-guest" }
    :if ([:len $existing] = 0) do={
        /ip address add address=192.168.200.1/24 interface=vlan200-guest network=192.168.200.0 disabled=no comment="Guests gateway"
    } else={
        /ip address set $existing address=192.168.200.1/24 interface=vlan200-guest network=192.168.200.0 disabled=no comment="Guests gateway"
    }
}

:foreach row in=[/interface vlan find where interface="bridge" and vlan-id=300] do={
    :if ([/interface vlan get $row name] != "vlan300-iot") do={ :error "VLAN300 already has another interface name; reconcile references first" }
}

:do {
    :local existing [/interface vlan find where name="vlan300-iot"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface vlan object: name=vlan300-iot" }
    :if ([:len $existing] = 0) do={
        /interface vlan add name=vlan300-iot interface=bridge vlan-id=300 disabled=no comment="IoT routed interface"
    } else={
        /interface vlan set $existing name=vlan300-iot interface=bridge vlan-id=300 disabled=no comment="IoT routed interface"
    }
}

:foreach row in=[/ip address find where address~"^192[.]168[.]30[.]1/"] do={
    :if (([/ip address get $row address] != "192.168.30.1/24") || ([/ip address get $row interface] != "vlan300-iot")) do={
        :error "Gateway 192.168.30.1 has an unexpected prefix/interface; no address change made"
    }
}

:do {
    :local existing [/ip address find where address="192.168.30.1/24" and interface="vlan300-iot"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip address object: address=192.168.30.1/24 and interface=vlan300-iot" }
    :if ([:len $existing] = 0) do={
        /ip address add address=192.168.30.1/24 interface=vlan300-iot network=192.168.30.0 disabled=no comment="IoT gateway"
    } else={
        /ip address set $existing address=192.168.30.1/24 interface=vlan300-iot network=192.168.30.0 disabled=no comment="IoT gateway"
    }
}

:foreach row in=[/interface vlan find where interface="bridge" and vlan-id=400] do={
    :if ([/interface vlan get $row name] != "vlan400-home-cloud") do={ :error "VLAN400 already has another interface name; reconcile references first" }
}

:do {
    :local existing [/interface vlan find where name="vlan400-home-cloud"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /interface vlan object: name=vlan400-home-cloud" }
    :if ([:len $existing] = 0) do={
        /interface vlan add name=vlan400-home-cloud interface=bridge vlan-id=400 disabled=no comment="Home Cloud routed interface"
    } else={
        /interface vlan set $existing name=vlan400-home-cloud interface=bridge vlan-id=400 disabled=no comment="Home Cloud routed interface"
    }
}

:foreach row in=[/ip address find where address~"^192[.]168[.]40[.]1/"] do={
    :if (([/ip address get $row address] != "192.168.40.1/24") || ([/ip address get $row interface] != "vlan400-home-cloud")) do={
        :error "Gateway 192.168.40.1 has an unexpected prefix/interface; no address change made"
    }
}

:do {
    :local existing [/ip address find where address="192.168.40.1/24" and interface="vlan400-home-cloud"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip address object: address=192.168.40.1/24 and interface=vlan400-home-cloud" }
    :if ([:len $existing] = 0) do={
        /ip address add address=192.168.40.1/24 interface=vlan400-home-cloud network=192.168.40.0 disabled=no comment="Home Cloud gateway"
    } else={
        /ip address set $existing address=192.168.40.1/24 interface=vlan400-home-cloud network=192.168.40.0 disabled=no comment="Home Cloud gateway"
    }
}

# BGP service space 10.40.0.0/24 has no router address or VLAN interface.
