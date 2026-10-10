# Common IPv4 DHCP. Names, networks, DNS, domain, PXE and original reservations
# come from the operator export dated 2026-10-10 (RouterOS7.24.4).
# Pool ranges were not included: preserve existing pools, create missing pools
# using the documented plan below. Reconcile ranges with /ip pool export.
# No scopes for VLAN1/500. Only the exact former printer lease may be retired.
# No DNS records or WAN DHCP changes; printer identities supplied 2026-10-10.

# Preflight every managed identity before changing DHCP objects.
:if ([/ip dns get allow-remote-requests] != true) do={ :error "Router DNS must already serve clients; DHCP does not enable it" }

:do {
    :local vlan [/interface vlan find where name="vlan100-trusted"]
    :if ([:len $vlan] != 1) do={ :error "Missing/ambiguous vlan100-trusted; apply addressing first" }
    :if ([/interface vlan get $vlan vlan-id] != 100) do={ :error "Unexpected VLAN ID on vlan100-trusted" }
    :if ([:len [/ip address find where interface="vlan100-trusted" and address="192.168.100.1/24" and disabled=no]] != 1) do={ :error "Missing 192.168.100.1/24 gateway" }
    :local named [/ip dhcp-server find where name="dhcp1"]
    :local attached [/ip dhcp-server find where interface="vlan100-trusted"]
    :if (([:len $named] > 1) || ([:len $attached] > 1)) do={ :error "Duplicate DHCP server for VLAN100" }
    :foreach row in=$named do={
        :if ([/ip dhcp-server get $row interface] != "vlan100-trusted") do={ :error "dhcp1 is bound to another interface" }
    }
    :foreach row in=$attached do={
        :if ([/ip dhcp-server get $row name] != "dhcp1") do={ :error "VLAN100 DHCP has a different name; reconcile source without breaking leases" }
    }
    :if ([:len [/ip pool find where name="dhcp_pool1"]] > 1) do={ :error "Duplicate dhcp_pool1" }
    :if ([:len [/ip dhcp-server network find where address="192.168.100.0/24"]] > 1) do={ :error "Duplicate VLAN100 DHCP network" }
}

:do {
    :local vlan [/interface vlan find where name="vlan200-guest"]
    :if ([:len $vlan] != 1) do={ :error "Missing/ambiguous vlan200-guest; apply addressing first" }
    :if ([/interface vlan get $vlan vlan-id] != 200) do={ :error "Unexpected VLAN ID on vlan200-guest" }
    :if ([:len [/ip address find where interface="vlan200-guest" and address="192.168.200.1/24" and disabled=no]] != 1) do={ :error "Missing 192.168.200.1/24 gateway" }
    :local named [/ip dhcp-server find where name="dhcp2"]
    :local attached [/ip dhcp-server find where interface="vlan200-guest"]
    :if (([:len $named] > 1) || ([:len $attached] > 1)) do={ :error "Duplicate DHCP server for VLAN200" }
    :foreach row in=$named do={
        :if ([/ip dhcp-server get $row interface] != "vlan200-guest") do={ :error "dhcp2 is bound to another interface" }
    }
    :foreach row in=$attached do={
        :if ([/ip dhcp-server get $row name] != "dhcp2") do={ :error "VLAN200 DHCP has a different name; reconcile source without breaking leases" }
    }
    :if ([:len [/ip pool find where name="dhcp_pool2"]] > 1) do={ :error "Duplicate dhcp_pool2" }
    :if ([:len [/ip dhcp-server network find where address="192.168.200.0/24"]] > 1) do={ :error "Duplicate VLAN200 DHCP network" }
}

:do {
    :local vlan [/interface vlan find where name="vlan300-iot"]
    :if ([:len $vlan] != 1) do={ :error "Missing/ambiguous vlan300-iot; apply addressing first" }
    :if ([/interface vlan get $vlan vlan-id] != 300) do={ :error "Unexpected VLAN ID on vlan300-iot" }
    :if ([:len [/ip address find where interface="vlan300-iot" and address="192.168.30.1/24" and disabled=no]] != 1) do={ :error "Missing 192.168.30.1/24 gateway" }
    :local named [/ip dhcp-server find where name="dhcp300-iot"]
    :local attached [/ip dhcp-server find where interface="vlan300-iot"]
    :if (([:len $named] > 1) || ([:len $attached] > 1)) do={ :error "Duplicate DHCP server for VLAN300" }
    :foreach row in=$named do={
        :if ([/ip dhcp-server get $row interface] != "vlan300-iot") do={ :error "dhcp300-iot is bound to another interface" }
    }
    :foreach row in=$attached do={
        :if ([/ip dhcp-server get $row name] != "dhcp300-iot") do={ :error "VLAN300 DHCP has a different name; reconcile source without breaking leases" }
    }
    :if ([:len [/ip pool find where name="pool300-iot"]] > 1) do={ :error "Duplicate pool300-iot" }
    :if ([:len [/ip dhcp-server network find where address="192.168.30.0/24"]] > 1) do={ :error "Duplicate VLAN300 DHCP network" }
}

:do {
    :local vlan [/interface vlan find where name="vlan400-home-cloud"]
    :if ([:len $vlan] != 1) do={ :error "Missing/ambiguous vlan400-home-cloud; apply addressing first" }
    :if ([/interface vlan get $vlan vlan-id] != 400) do={ :error "Unexpected VLAN ID on vlan400-home-cloud" }
    :if ([:len [/ip address find where interface="vlan400-home-cloud" and address="192.168.40.1/24" and disabled=no]] != 1) do={ :error "Missing 192.168.40.1/24 gateway" }
    :local named [/ip dhcp-server find where name="dhcp400-home-cloud"]
    :local attached [/ip dhcp-server find where interface="vlan400-home-cloud"]
    :if (([:len $named] > 1) || ([:len $attached] > 1)) do={ :error "Duplicate DHCP server for VLAN400" }
    :foreach row in=$named do={
        :if ([/ip dhcp-server get $row interface] != "vlan400-home-cloud") do={ :error "dhcp400-home-cloud is bound to another interface" }
    }
    :foreach row in=$attached do={
        :if ([/ip dhcp-server get $row name] != "dhcp400-home-cloud") do={ :error "VLAN400 DHCP has a different name; reconcile source without breaking leases" }
    }
    :if ([:len [/ip pool find where name="pool400-home-cloud"]] > 1) do={ :error "Duplicate pool400-home-cloud" }
    :if ([:len [/ip dhcp-server network find where address="192.168.40.0/24"]] > 1) do={ :error "Duplicate VLAN400 DHCP network" }
}

:do {
    :if ([:len [/ip dhcp-server lease find where server="dhcp300-iot" and mac-address="40:23:43:D9:F3:90"]] > 1) do={ :error "Duplicate printer IoT leases" }
    :if ([:len [/ip dhcp-server lease find where server="dhcp1" and mac-address="40:23:43:D9:F3:90"]] > 1) do={ :error "Duplicate former printer Home leases" }
    :foreach row in=[/ip dhcp-server lease find where mac-address="40:23:43:D9:F3:90"] do={
        :local server [/ip dhcp-server lease get $row server]
        :if (($server != "dhcp300-iot") && ($server != "dhcp1")) do={ :error "Printer lease belongs to an unexpected server" }
        :if (($server = "dhcp1") && ([/ip dhcp-server lease get $row address] != "192.168.100.26")) do={ :error "Former Home printer address differs; review before moving lease" }
    }
    :foreach row in=[/ip dhcp-server lease find where address="192.168.30.3"] do={
        :if (([/ip dhcp-server lease get $row mac-address] != "40:23:43:D9:F3:90") || ([/ip dhcp-server lease get $row server] != "dhcp300-iot")) do={ :error "192.168.30.3 is reserved for another client/server" }
    }
}

# Bambu P2S: confirmed Wi-Fi identity; stop rather than move an unrelated lease.
:do {
    :if ([:len [/ip dhcp-server lease find where mac-address="EC:B5:0A:86:6F:30"]] > 1) do={ :error "Multiple Bambu P2S leases; reconcile first" }
    :foreach row in=[/ip dhcp-server lease find where mac-address="EC:B5:0A:86:6F:30"] do={
        :if ([/ip dhcp-server lease get $row server] != "dhcp300-iot") do={ :error "Bambu P2S lease belongs to another server; connect to IoT SSID and reconcile first" }
    }
    :foreach row in=[/ip dhcp-server lease find where address="192.168.30.4"] do={
        :if (([/ip dhcp-server lease get $row mac-address] != "EC:B5:0A:86:6F:30") || ([/ip dhcp-server lease get $row server] != "dhcp300-iot")) do={ :error "192.168.30.4 is reserved for another client/server" }
    }
}

:do {
    :if ([:len [/ip dhcp-server lease find where server="dhcp400-home-cloud" and mac-address="02:11:32:28:5A:95"]] > 1) do={ :error "Multiple leases for 02:11:32:28:5A:95 on dhcp400-home-cloud" }
    :foreach row in=[/ip dhcp-server lease find where address="192.168.40.21"] do={
        :if (([/ip dhcp-server lease get $row mac-address] != "02:11:32:28:5A:95") || ([/ip dhcp-server lease get $row server] != "dhcp400-home-cloud")) do={ :error "Lease address 192.168.40.21 already assigned to another client/server" }
    }
}

:do {
    :if ([:len [/ip dhcp-server lease find where server="dhcp400-home-cloud" and mac-address="02:11:32:2E:F4:1B"]] > 1) do={ :error "Multiple leases for 02:11:32:2E:F4:1B on dhcp400-home-cloud" }
    :foreach row in=[/ip dhcp-server lease find where address="192.168.40.40"] do={
        :if (([/ip dhcp-server lease get $row mac-address] != "02:11:32:2E:F4:1B") || ([/ip dhcp-server lease get $row server] != "dhcp400-home-cloud")) do={ :error "Lease address 192.168.40.40 already assigned to another client/server" }
    }
}

:do {
    :if ([:len [/ip dhcp-server lease find where server="dhcp400-home-cloud" and mac-address="DC:A6:32:2F:57:C3"]] > 1) do={ :error "Multiple leases for DC:A6:32:2F:57:C3 on dhcp400-home-cloud" }
    :foreach row in=[/ip dhcp-server lease find where address="192.168.40.41"] do={
        :if (([/ip dhcp-server lease get $row mac-address] != "DC:A6:32:2F:57:C3") || ([/ip dhcp-server lease get $row server] != "dhcp400-home-cloud")) do={ :error "Lease address 192.168.40.41 already assigned to another client/server" }
    }
}

:do {
    :if ([:len [/ip dhcp-server lease find where server="dhcp400-home-cloud" and mac-address="2C:CF:67:1B:D6:FE"]] > 1) do={ :error "Multiple leases for 2C:CF:67:1B:D6:FE on dhcp400-home-cloud" }
    :foreach row in=[/ip dhcp-server lease find where address="192.168.40.42"] do={
        :if (([/ip dhcp-server lease get $row mac-address] != "2C:CF:67:1B:D6:FE") || ([/ip dhcp-server lease get $row server] != "dhcp400-home-cloud")) do={ :error "Lease address 192.168.40.42 already assigned to another client/server" }
    }
}

# VLAN100
:do {
    :local pool [/ip pool find where name="dhcp_pool1"]
    :if ([:len $pool] = 0) do={
        /ip pool add name=dhcp_pool1 ranges=192.168.100.50-192.168.100.254
    }
    # Existing ranges are deliberately unchanged pending the actual pool export.
    :local network [/ip dhcp-server network find where address="192.168.100.0/24"]
    :if ([:len $network] = 0) do={
        /ip dhcp-server network add address=192.168.100.0/24 gateway=192.168.100.1 dns-server=192.168.100.1 netmask=24 domain=home.antonu.org comment="Home DHCP network"
    } else={
        /ip dhcp-server network set $network address=192.168.100.0/24 gateway=192.168.100.1 dns-server=192.168.100.1 netmask=24 domain=home.antonu.org comment="Home DHCP network"
    }
    :local server [/ip dhcp-server find where name="dhcp1"]
    :if ([:len $server] = 0) do={
        /ip dhcp-server add name=dhcp1 interface=vlan100-trusted address-pool=dhcp_pool1 lease-time=30m disabled=no comment="Home DHCP"
    } else={
        /ip dhcp-server set $server name=dhcp1 interface=vlan100-trusted address-pool=dhcp_pool1 lease-time=30m disabled=no comment="Home DHCP"
    }
}

# VLAN200
:do {
    :local pool [/ip pool find where name="dhcp_pool2"]
    :if ([:len $pool] = 0) do={
        /ip pool add name=dhcp_pool2 ranges=192.168.200.2-192.168.200.254
    }
    # Existing ranges are deliberately unchanged pending the actual pool export.
    :local network [/ip dhcp-server network find where address="192.168.200.0/24"]
    :if ([:len $network] = 0) do={
        /ip dhcp-server network add address=192.168.200.0/24 gateway=192.168.200.1 dns-server=192.168.200.1 netmask=24 comment="Guests DHCP network"
    } else={
        /ip dhcp-server network set $network address=192.168.200.0/24 gateway=192.168.200.1 dns-server=192.168.200.1 netmask=24 comment="Guests DHCP network"
    }
    :local server [/ip dhcp-server find where name="dhcp2"]
    :if ([:len $server] = 0) do={
        /ip dhcp-server add name=dhcp2 interface=vlan200-guest address-pool=dhcp_pool2 lease-time=30m disabled=no comment="Guests DHCP"
    } else={
        /ip dhcp-server set $server name=dhcp2 interface=vlan200-guest address-pool=dhcp_pool2 lease-time=30m disabled=no comment="Guests DHCP"
    }
}

# VLAN300
:do {
    :local pool [/ip pool find where name="pool300-iot"]
    :if ([:len $pool] = 0) do={
        /ip pool add name=pool300-iot ranges=192.168.30.100-192.168.30.199
    }
    # Existing ranges are deliberately unchanged pending the actual pool export.
    :local network [/ip dhcp-server network find where address="192.168.30.0/24"]
    :if ([:len $network] = 0) do={
        /ip dhcp-server network add address=192.168.30.0/24 gateway=192.168.30.1 dns-server=192.168.30.1 netmask=24 comment="IoT DHCP network"
    } else={
        /ip dhcp-server network set $network address=192.168.30.0/24 gateway=192.168.30.1 dns-server=192.168.30.1 netmask=24 comment="IoT DHCP network"
    }
    :local server [/ip dhcp-server find where name="dhcp300-iot"]
    :if ([:len $server] = 0) do={
        /ip dhcp-server add name=dhcp300-iot interface=vlan300-iot address-pool=pool300-iot lease-time=1d disabled=no comment="IoT DHCP"
    } else={
        /ip dhcp-server set $server name=dhcp300-iot interface=vlan300-iot address-pool=pool300-iot lease-time=1d disabled=no comment="IoT DHCP"
    }
}

# VLAN400
:do {
    :local pool [/ip pool find where name="pool400-home-cloud"]
    :if ([:len $pool] = 0) do={
        /ip pool add name=pool400-home-cloud ranges=192.168.40.100-192.168.40.199
    }
    # Existing ranges are deliberately unchanged pending the actual pool export.
    :local network [/ip dhcp-server network find where address="192.168.40.0/24"]
    :if ([:len $network] = 0) do={
        /ip dhcp-server network add address=192.168.40.0/24 gateway=192.168.40.1 dns-server=192.168.40.1 netmask=24 next-server=192.168.40.1 boot-file-name=ipxe-x86_64.efi comment="Home Cloud DHCP network"
    } else={
        /ip dhcp-server network set $network address=192.168.40.0/24 gateway=192.168.40.1 dns-server=192.168.40.1 netmask=24 next-server=192.168.40.1 boot-file-name=ipxe-x86_64.efi comment="Home Cloud DHCP network"
    }
    :local server [/ip dhcp-server find where name="dhcp400-home-cloud"]
    :if ([:len $server] = 0) do={
        /ip dhcp-server add name=dhcp400-home-cloud interface=vlan400-home-cloud address-pool=pool400-home-cloud lease-time=1h disabled=no comment="Home Cloud DHCP"
    } else={
        /ip dhcp-server set $server name=dhcp400-home-cloud interface=vlan400-home-cloud address-pool=pool400-home-cloud lease-time=1h disabled=no comment="Home Cloud DHCP"
    }
}

# DISRUPTIVE: printer moves from Home .100.26 to IoT .30.3; reconnect to IoT SSID.
:do {
    :local existing [/ip dhcp-server lease find where server="dhcp300-iot" and mac-address="40:23:43:D9:F3:90"]
    :local former [/ip dhcp-server lease find where server="dhcp1" and mac-address="40:23:43:D9:F3:90" and address="192.168.100.26"]
    :if (([:len $existing] = 0) && ([:len $former] = 1)) do={
        :set existing $former
        :set former [:toarray ""]
    }
    :if ([:len $existing] = 0) do={
        /ip dhcp-server lease add server=dhcp300-iot address=192.168.30.3 mac-address=40:23:43:D9:F3:90 client-id="" disabled=no comment="Wi-Fi printer - IoT"
    } else={
        :if ([/ip dhcp-server lease get $existing dynamic] = true) do={
            /ip dhcp-server lease make-static $existing
        }
        /ip dhcp-server lease set $existing server=dhcp300-iot address=192.168.30.3 mac-address=40:23:43:D9:F3:90 client-id="" disabled=no comment="Wi-Fi printer - IoT"
    }
    # If an IoT lease already existed, retire only the exact former Home lease.
    :if ([:len $former] = 1) do={ /ip dhcp-server lease remove $former }
}

:do {
    :local existing [/ip dhcp-server lease find where server="dhcp400-home-cloud" and mac-address="02:11:32:28:5A:95"]
    :if ([:len $existing] = 0) do={
        /ip dhcp-server lease add server=dhcp400-home-cloud address=192.168.40.21 mac-address=02:11:32:28:5A:95 client-id="" disabled=no comment="talos-cp-01"
    } else={
        :if ([/ip dhcp-server lease get $existing dynamic] = true) do={
            /ip dhcp-server lease make-static $existing
        }
        /ip dhcp-server lease set $existing server=dhcp400-home-cloud address=192.168.40.21 mac-address=02:11:32:28:5A:95 client-id="" disabled=no comment="talos-cp-01"
    }
}

:do {
    :local existing [/ip dhcp-server lease find where server="dhcp400-home-cloud" and mac-address="02:11:32:2E:F4:1B"]
    :if ([:len $existing] = 0) do={
        /ip dhcp-server lease add server=dhcp400-home-cloud address=192.168.40.40 mac-address=02:11:32:2E:F4:1B client-id="" disabled=no comment="talos-worker-01"
    } else={
        :if ([/ip dhcp-server lease get $existing dynamic] = true) do={
            /ip dhcp-server lease make-static $existing
        }
        /ip dhcp-server lease set $existing server=dhcp400-home-cloud address=192.168.40.40 mac-address=02:11:32:2E:F4:1B client-id="" disabled=no comment="talos-worker-01"
    }
}

:do {
    :local existing [/ip dhcp-server lease find where server="dhcp400-home-cloud" and mac-address="DC:A6:32:2F:57:C3"]
    :if ([:len $existing] = 0) do={
        /ip dhcp-server lease add server=dhcp400-home-cloud address=192.168.40.41 mac-address=DC:A6:32:2F:57:C3 client-id="" disabled=no comment="talos-worker-02"
    } else={
        :if ([/ip dhcp-server lease get $existing dynamic] = true) do={
            /ip dhcp-server lease make-static $existing
        }
        /ip dhcp-server lease set $existing server=dhcp400-home-cloud address=192.168.40.41 mac-address=DC:A6:32:2F:57:C3 client-id="" disabled=no comment="talos-worker-02"
    }
}

:do {
    :local existing [/ip dhcp-server lease find where server="dhcp400-home-cloud" and mac-address="2C:CF:67:1B:D6:FE"]
    :if ([:len $existing] = 0) do={
        /ip dhcp-server lease add server=dhcp400-home-cloud address=192.168.40.42 mac-address=2C:CF:67:1B:D6:FE client-id="" disabled=no comment="talos-worker-03"
    } else={
        :if ([/ip dhcp-server lease get $existing dynamic] = true) do={
            /ip dhcp-server lease make-static $existing
        }
        /ip dhcp-server lease set $existing server=dhcp400-home-cloud address=192.168.40.42 mac-address=2C:CF:67:1B:D6:FE client-id="" disabled=no comment="talos-worker-03"
    }
}

# Reconnect the Bambu P2S to the IoT SSID to obtain its reserved address.
:do {
    :local existing [/ip dhcp-server lease find where server="dhcp300-iot" and mac-address="EC:B5:0A:86:6F:30"]
    :if ([:len $existing] = 0) do={
        /ip dhcp-server lease add server=dhcp300-iot address=192.168.30.4 mac-address=EC:B5:0A:86:6F:30 client-id="" disabled=no comment="3dprinter"
    } else={
        :if ([/ip dhcp-server lease get $existing dynamic] = true) do={
            /ip dhcp-server lease make-static $existing
        }
        /ip dhcp-server lease set $existing server=dhcp300-iot address=192.168.30.4 mac-address=EC:B5:0A:86:6F:30 client-id="" disabled=no comment="3dprinter"
    }
}
