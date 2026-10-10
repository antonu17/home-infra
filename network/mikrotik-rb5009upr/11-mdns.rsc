# IPv4 mDNS discovery between Home, IoT and Home Cloud, requested 2026-10-10.
# Apply 09 input allowances first. Repeating this set does not create objects.
# Guest and infrastructure management VLANs are intentionally excluded.
:foreach iface in={"vlan100-trusted";"vlan300-iot";"vlan400-home-cloud"} do={
    :if ([:len [/interface vlan find where name=$iface and disabled=no]] != 1) do={
        :error "Missing or disabled mDNS VLAN interface"
    }
}
/ip dns set mdns-repeat-ifaces=vlan100-trusted,vlan300-iot,vlan400-home-cloud
