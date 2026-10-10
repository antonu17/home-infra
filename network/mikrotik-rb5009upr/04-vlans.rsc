# Static VLAN rows are keyed by bridge + single VLAN ID, not comments.
# Dynamic PVID/CPU rows are never selected. Disable only the saved combined100/200
# row; refuse other ranges/IDs rather than silently retaining overlapping tables.
:foreach row in=[/interface bridge vlan find where bridge="bridge" and dynamic=no] do={
    :local vids [:tostr [/interface bridge vlan get $row vlan-ids]]
    :if (($vids = "100;200") || ($vids = "100,200")) do={
        /interface bridge vlan disable $row
    } else={
        :if (($vids != "1") && ($vids != "100") && ($vids != "200") && ($vids != "300") && ($vids != "400")) do={
            :error "Unexpected static VLAN ID/range on bridge; reconcile it before importing"
        }
    }
}

:do {
    :local existing [:toarray ""]
    :foreach row in=[/interface bridge vlan find where bridge="bridge" and dynamic=no] do={
        :if ([:tostr [/interface bridge vlan get $row vlan-ids]] = "1") do={ :set existing ($existing, $row) }
    }
    :if ([:len $existing] > 1) do={ :error "Duplicate static VLAN1 on bridge" }
    :if ([:len $existing] = 0) do={
        /interface bridge vlan add bridge=bridge vlan-ids=1 tagged=bridge untagged="ether7" disabled=no comment="VLAN1 Aruba management"
    } else={
        /interface bridge vlan set $existing bridge=bridge vlan-ids=1 tagged=bridge untagged="ether7" disabled=no comment="VLAN1 Aruba management"
    }
}

:do {
    :local untagged "ether4,ether8"
    :if ([:len [/system package find where name="container" and disabled=no]] = 1) do={
        :if ([:len [/interface veth find where name="veth-ssdp-home"]] = 1) do={ :set untagged "ether4,ether8,veth-ssdp-home" }
    }
    :local existing [:toarray ""]
    :foreach row in=[/interface bridge vlan find where bridge="bridge" and dynamic=no] do={
        :if ([:tostr [/interface bridge vlan get $row vlan-ids]] = "100") do={ :set existing ($existing, $row) }
    }
    :if ([:len $existing] > 1) do={ :error "Duplicate static VLAN100 on bridge" }
    :if ([:len $existing] = 0) do={
        /interface bridge vlan add bridge=bridge vlan-ids=100 tagged=bridge,ether7 untagged=$untagged disabled=no comment="VLAN100 Home"
    } else={
        /interface bridge vlan set $existing bridge=bridge vlan-ids=100 tagged=bridge,ether7 untagged=$untagged disabled=no comment="VLAN100 Home"
    }
}

:do {
    :local existing [:toarray ""]
    :foreach row in=[/interface bridge vlan find where bridge="bridge" and dynamic=no] do={
        :if ([:tostr [/interface bridge vlan get $row vlan-ids]] = "200") do={ :set existing ($existing, $row) }
    }
    :if ([:len $existing] > 1) do={ :error "Duplicate static VLAN200 on bridge" }
    :if ([:len $existing] = 0) do={
        /interface bridge vlan add bridge=bridge vlan-ids=200 tagged=bridge,ether7 untagged="" disabled=no comment="VLAN200 Guests"
    } else={
        /interface bridge vlan set $existing bridge=bridge vlan-ids=200 tagged=bridge,ether7 untagged="" disabled=no comment="VLAN200 Guests"
    }
}

:do {
    :local untagged "ether3"
    :if ([:len [/system package find where name="container" and disabled=no]] = 1) do={
        :if ([:len [/interface veth find where name="veth-ssdp-iot"]] = 1) do={ :set untagged "ether3,veth-ssdp-iot" }
    }
    :local existing [:toarray ""]
    :foreach row in=[/interface bridge vlan find where bridge="bridge" and dynamic=no] do={
        :if ([:tostr [/interface bridge vlan get $row vlan-ids]] = "300") do={ :set existing ($existing, $row) }
    }
    :if ([:len $existing] > 1) do={ :error "Duplicate static VLAN300 on bridge" }
    :if ([:len $existing] = 0) do={
        /interface bridge vlan add bridge=bridge vlan-ids=300 tagged=bridge,ether7 untagged=$untagged disabled=no comment="VLAN300 IoT"
    } else={
        /interface bridge vlan set $existing bridge=bridge vlan-ids=300 tagged=bridge,ether7 untagged=$untagged disabled=no comment="VLAN300 IoT"
    }
}

:do {
    :local untagged "syno1,ether5,ether6"
    :if ([:len [/system package find where name="container" and disabled=no]] = 1) do={
        :if ([:len [/interface veth find where name="veth-ssdp-cloud"]] = 1) do={ :set untagged "syno1,ether5,ether6,veth-ssdp-cloud" }
    }
    :local existing [:toarray ""]
    :foreach row in=[/interface bridge vlan find where bridge="bridge" and dynamic=no] do={
        :if ([:tostr [/interface bridge vlan get $row vlan-ids]] = "400") do={ :set existing ($existing, $row) }
    }
    :if ([:len $existing] > 1) do={ :error "Duplicate static VLAN400 on bridge" }
    :if ([:len $existing] = 0) do={
        /interface bridge vlan add bridge=bridge vlan-ids=400 tagged=bridge untagged=$untagged disabled=no comment="VLAN400 Cloud"
    } else={
        /interface bridge vlan set $existing bridge=bridge vlan-ids=400 tagged=bridge untagged=$untagged disabled=no comment="VLAN400 Cloud"
    }
}

# VLAN500 is not implemented. VLAN1 CPU is tagged for existing vlan1-mgmt.
