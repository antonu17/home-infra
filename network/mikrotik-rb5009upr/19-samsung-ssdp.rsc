# Samsung UE43RU7099UXZG: operator-confirmed SSDP source-NAT workaround.
# Operator-run: preserve current IoT addresses and limit NAT to observed reply port3942.
:if ([:len [/ip dhcp-server find where name="dhcp300-iot" and disabled=no]] != 1) do={ :error "Missing IoT DHCP server" }
:if ([:len [/ip address find where interface="vlan300-iot" and address="192.168.30.1/24" and disabled=no]] != 1) do={ :error "Missing IoT gateway" }
:if ([:len [/ip dhcp-server lease find where server="dhcp300-iot" and mac-address="8C:79:F5:A5:C6:E8"]] > 1) do={ :error "Duplicate Samsung lease" }
:if ([:len [/ip dhcp-server lease find where server="dhcp300-iot" and address="192.168.30.107" and mac-address!="8C:79:F5:A5:C6:E8"]] > 0) do={ :error "Samsung reserved IP occupied by another MAC" }
:if ([:len [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.107"]] > 1) do={ :error "Duplicate Samsung SSDP list entry" }
:foreach row in=[/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.107"] do={ :if ([/ip firewall address-list get $row dynamic] = true) do={ :error "Samsung SSDP list entry must be static" } }
:if ([:len [/ip dhcp-server lease find where server="dhcp300-iot" and mac-address="00:C3:F4:8B:7C:92"]] > 1) do={ :error "Duplicate Samsung lease" }
:if ([:len [/ip dhcp-server lease find where server="dhcp300-iot" and address="192.168.30.110" and mac-address!="00:C3:F4:8B:7C:92"]] > 0) do={ :error "Samsung reserved IP occupied by another MAC" }
:if ([:len [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.110"]] > 1) do={ :error "Duplicate Samsung SSDP list entry" }
:foreach row in=[/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.110"] do={ :if ([/ip firewall address-list get $row dynamic] = true) do={ :error "Samsung SSDP list entry must be static" } }
:if (([:len [/ip firewall nat find where comment="TEMP Samsung SSDP source test"]] + [:len [/ip firewall nat find where comment="Pulsar SSDP replies to subnet-sensitive clients"]]) > 1) do={ :error "Ambiguous Samsung SSDP NAT identity" }
:do {
    :local row [/ip dhcp-server lease find where server="dhcp300-iot" and mac-address="8C:79:F5:A5:C6:E8"]
    :if ([:len $row] = 0) do={
        /ip dhcp-server lease add server=dhcp300-iot address=192.168.30.107 mac-address=8C:79:F5:A5:C6:E8 client-id="" disabled=no comment="Samsung TV Wi-Fi"
    } else={
        :if ([/ip dhcp-server lease get $row dynamic] = true) do={ /ip dhcp-server lease make-static $row }
        /ip dhcp-server lease set $row server=dhcp300-iot address=192.168.30.107 mac-address=8C:79:F5:A5:C6:E8 client-id="" disabled=no comment="Samsung TV Wi-Fi"
    }
}
:do {
    :local row [/ip dhcp-server lease find where server="dhcp300-iot" and mac-address="00:C3:F4:8B:7C:92"]
    :if ([:len $row] = 0) do={
        /ip dhcp-server lease add server=dhcp300-iot address=192.168.30.110 mac-address=00:C3:F4:8B:7C:92 client-id="" disabled=no comment="Samsung TV Ethernet"
    } else={
        :if ([/ip dhcp-server lease get $row dynamic] = true) do={ /ip dhcp-server lease make-static $row }
        /ip dhcp-server lease set $row server=dhcp300-iot address=192.168.30.110 mac-address=00:C3:F4:8B:7C:92 client-id="" disabled=no comment="Samsung TV Ethernet"
    }
}
:do {
    :local row [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.107"]
    :if ([:len $row] = 0) do={ /ip firewall address-list add list=SSDP-SUBNET-CLIENTS address=192.168.30.107 comment="Samsung TV Wi-Fi" } else={ /ip firewall address-list set $row list=SSDP-SUBNET-CLIENTS address=192.168.30.107 disabled=no comment="Samsung TV Wi-Fi" }
}
:do {
    :local row [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.110"]
    :if ([:len $row] = 0) do={ /ip firewall address-list add list=SSDP-SUBNET-CLIENTS address=192.168.30.110 comment="Samsung TV Ethernet" } else={ /ip firewall address-list set $row list=SSDP-SUBNET-CLIENTS address=192.168.30.110 disabled=no comment="Samsung TV Ethernet" }
}
# libupnp replies use ephemeral source ports: do not match UDP source1900.
:if ([:len [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and disabled=no]] = 0) do={ :error "Import Samsung SSDP client list first" }
:do {
    :local row [/ip firewall nat find where comment="TEMP Samsung SSDP source test" or comment="Pulsar SSDP replies to subnet-sensitive clients"]
    :if ([:len $row] = 0) do={ /ip firewall nat add chain=srcnat disabled=yes comment="Pulsar SSDP replies to subnet-sensitive clients"; :set row [/ip firewall nat find where comment="Pulsar SSDP replies to subnet-sensitive clients"] }
    /ip firewall nat set $row !dst-address !src-address-list !in-interface !in-interface-list !out-interface-list !src-port !connection-mark !ipsec-policy chain=srcnat action=src-nat src-address=192.168.40.5 dst-address-list=SSDP-SUBNET-CLIENTS out-interface=vlan300-iot protocol=udp dst-port=3942 to-addresses=192.168.30.1 disabled=no comment="Pulsar SSDP replies to subnet-sensitive clients"
    :local first [:pick [/ip firewall nat find where dynamic=no] 0]
    :if ($row != $first) do={ /ip firewall nat move $row destination=$first }
}

# Remove ineffective diagnostic TTL experiment by exact identity.
/ip firewall mangle remove [find where comment="TEMP Samsung SSDP TTL test"]
