# VLAN300 infrastructure ULA and SLAAC. Import after 05-addressing.rsc.
# Owns the verified Thread prefix routes; IPv6 firewall policy is separate.
# Preflight all owned identities before any mutation.
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
# Validate route identities before changing addresses or ND settings.
:foreach identity in={"Thread fd2f via tado VLAN300";"Thread fd2f via HomePod VLAN300"} do={
    :if ([:len [/ipv6 route find where comment=$identity]] > 1) do={
        :error "Duplicate managed Thread route comment"
    }
    :foreach row in=[/ipv6 route find where comment=$identity] do={
        :if (([/ipv6 route get $row dst-address] != "fd2f:feb4:bf84::/64") || ([/ipv6 route get $row routing-table] != "main")) do={
            :error "Managed Thread route has unexpected destination or table"
        }
    }
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
    :local existing [/ipv6 route find where comment="Thread fd2f via tado VLAN300"]
    :if ([:len $existing] = 0) do={
        /ipv6 route add dst-address=fd2f:feb4:bf84::/64 gateway=fe80::4a27:e2ff:fed2:9e08%vlan300-iot routing-table=main distance=1 check-gateway=none disabled=no comment="Thread fd2f via tado VLAN300"
    } else={
        /ipv6 route set $existing dst-address=fd2f:feb4:bf84::/64 gateway=fe80::4a27:e2ff:fed2:9e08%vlan300-iot routing-table=main distance=1 check-gateway=none disabled=no
    }
}

:do {
    :local existing [/ipv6 route find where comment="Thread fd2f via HomePod VLAN300"]
    :if ([:len $existing] = 0) do={
        /ipv6 route add dst-address=fd2f:feb4:bf84::/64 gateway=fe80::1821:9359:33fb:fa36%vlan300-iot routing-table=main distance=2 check-gateway=none disabled=no comment="Thread fd2f via HomePod VLAN300"
    } else={
        /ipv6 route set $existing dst-address=fd2f:feb4:bf84::/64 gateway=fe80::1821:9359:33fb:fa36%vlan300-iot routing-table=main distance=2 check-gateway=none disabled=no
    }
}

# Remove only retired/diagnostic routes by exact recorded identity.
/ipv6 route remove [find where comment="Thread via tado Bridge X" and dst-address="fd97:72fc:f25f:1::/64"]
/ipv6 route remove [find where comment="Thread via HomePod Mini" and dst-address="fd97:72fc:f25f:1::/64"]
/ipv6 route remove [find where comment="TEMP tado IPv6 diagnostic" and dst-address="fd2f:feb4:bf84:0:5e56:1089:1d24:fffb/128"]
/ipv6 route remove [find where comment="TEMP Thread via HomePod diagnostic" and dst-address="fd2f:feb4:bf84:0:d2f1:c87c:9d61:26a8/128"]
/ipv6 route remove [find where comment="TEMP Thread prefix via tado VLAN300" and dst-address="fd2f:feb4:bf84::/64"]
