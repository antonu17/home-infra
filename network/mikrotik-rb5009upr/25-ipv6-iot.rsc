# Home ULA allocation fdb5:841f:2eb7::/48; routed LANs use /64.
# Import after file05. Owns VLAN300/400 ULA and per-interface ND.
# Thread routes are owned by thread-rio-sync; no prefix routes are changed here.
:if ([:len [/interface vlan find where name="vlan300-iot" and vlan-id=300 and disabled=no]] != 1) do={
    :error "Missing or disabled VLAN300 interface"
}
:foreach row in=[/ipv6 address find where address="fdb5:841f:2eb7:300::1/64"] do={
    :if ([/ipv6 address get $row interface] != "vlan300-iot") do={
        :error "IoT ULA gateway belongs to another interface"
    }
}
:if ([:len [/ipv6 address find where address="fdb5:841f:2eb7:300::1/64" and interface="vlan300-iot"]] > 1) do={
    :error "Duplicate IoT ULA gateway"
}
:if ([:len [/ipv6 nd find where interface="vlan300-iot"]] > 1) do={
    :error "Duplicate VLAN300 ND profile"
}
:if ([:len [/interface vlan find where name="vlan400-home-cloud" and vlan-id=400 and disabled=no]] != 1) do={
    :error "Missing or disabled VLAN400 interface"
}
:foreach row in=[/ipv6 address find where address="fdb5:841f:2eb7:400::1/64"] do={
    :if ([/ipv6 address get $row interface] != "vlan400-home-cloud") do={
        :error "Home Cloud ULA gateway belongs to another interface"
    }
}
:if ([:len [/ipv6 address find where address="fdb5:841f:2eb7:400::1/64" and interface="vlan400-home-cloud"]] > 1) do={
    :error "Duplicate Home Cloud ULA gateway"
}
:if ([:len [/ipv6 nd find where interface="vlan400-home-cloud"]] > 1) do={
    :error "Duplicate VLAN400 ND profile"
}
:do {
    :local existing [/ipv6 address find where address="fdb5:841f:2eb7:300::1/64" and interface="vlan300-iot"]
    :if ([:len $existing] = 0) do={
        /ipv6 address add address=fdb5:841f:2eb7:300::1/64 interface=vlan300-iot advertise=yes disabled=no comment="VLAN300 IoT ULA"
    } else={
        /ipv6 address set $existing advertise=yes disabled=no comment="VLAN300 IoT ULA"
    }
}
:do {
    :local existing [/ipv6 nd find where interface="vlan300-iot"]
    :if ([:len $existing] = 0) do={
        /ipv6 nd add interface=vlan300-iot ra-interval=20s-1m ra-lifetime=30m advertise-dns=no managed-address-configuration=no other-configuration=no disabled=no
    } else={
        /ipv6 nd set $existing ra-interval=20s-1m ra-lifetime=30m advertise-dns=no managed-address-configuration=no other-configuration=no disabled=no
    }
}
:do {
    :local existing [/ipv6 address find where address="fdb5:841f:2eb7:400::1/64" and interface="vlan400-home-cloud"]
    :if ([:len $existing] = 0) do={
        /ipv6 address add address=fdb5:841f:2eb7:400::1/64 interface=vlan400-home-cloud advertise=yes disabled=no comment="VLAN400 Home Cloud ULA"
    } else={
        /ipv6 address set $existing advertise=yes disabled=no comment="VLAN400 Home Cloud ULA"
    }
}
:do {
    :local existing [/ipv6 nd find where interface="vlan400-home-cloud"]
    :if ([:len $existing] = 0) do={
        /ipv6 nd add interface=vlan400-home-cloud ra-interval=20s-1m ra-lifetime=30m advertise-dns=yes managed-address-configuration=no other-configuration=no disabled=no
    } else={
        /ipv6 nd set $existing ra-interval=20s-1m ra-lifetime=30m advertise-dns=yes managed-address-configuration=no other-configuration=no disabled=no
    }
}
