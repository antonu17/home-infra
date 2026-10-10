# Refuse renamed/missing physical ports instead of creating dangling references.
:do {
    :local port [/interface ethernet find where default-name="ether1"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port ether1" }
    :if ([/interface ethernet get $port name] != "ether1") do={ :error "Physical port ether1 was renamed; reconcile names first" }
}
:do {
    :local port [/interface ethernet find where default-name="ether2"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port ether2" }
    :if ([/interface ethernet get $port name] != "ether2") do={ :error "Physical port ether2 was renamed; reconcile names first" }
}
:do {
    :local port [/interface ethernet find where default-name="ether3"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port ether3" }
    :if ([/interface ethernet get $port name] != "ether3") do={ :error "Physical port ether3 was renamed; reconcile names first" }
}
:do {
    :local port [/interface ethernet find where default-name="ether4"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port ether4" }
    :if ([/interface ethernet get $port name] != "ether4") do={ :error "Physical port ether4 was renamed; reconcile names first" }
}
:do {
    :local port [/interface ethernet find where default-name="ether5"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port ether5" }
    :if ([/interface ethernet get $port name] != "ether5") do={ :error "Physical port ether5 was renamed; reconcile names first" }
}
:do {
    :local port [/interface ethernet find where default-name="ether6"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port ether6" }
    :if ([/interface ethernet get $port name] != "ether6") do={ :error "Physical port ether6 was renamed; reconcile names first" }
}
:do {
    :local port [/interface ethernet find where default-name="ether7"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port ether7" }
    :if ([/interface ethernet get $port name] != "ether7") do={ :error "Physical port ether7 was renamed; reconcile names first" }
}
:do {
    :local port [/interface ethernet find where default-name="ether8"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port ether8" }
    :if ([/interface ethernet get $port name] != "ether8") do={ :error "Physical port ether8 was renamed; reconcile names first" }
}
:do {
    :local port [/interface ethernet find where default-name="sfp-sfpplus1"]
    :if ([:len $port] != 1) do={ :error "Missing/ambiguous physical port sfp-sfpplus1" }
    :if ([/interface ethernet get $port name] != "sfp-sfpplus1") do={ :error "Physical port sfp-sfpplus1 was renamed; reconcile names first" }
}

# Physical names must still match their default-name; see README.
# Keep stable names; preserve MTU, MAC, negotiation, PoE and WAN DHCP settings.
/interface ethernet
set [find where default-name="ether1"] comment="Synology syno1 member 1"
set [find where default-name="ether2"] comment="Synology syno1 member 2"
set [find where default-name="ether3"] comment="TV - IoT access VLAN300"
set [find where default-name="ether4"] comment="Denis - Home access VLAN100"
set [find where default-name="ether5"] comment="worker-03 - Cloud access VLAN400"
set [find where default-name="ether6"] comment="worker-02 - Cloud access VLAN400"
set [find where default-name="ether7"] comment="Aruba - native VLAN1 tagged VLAN100,200,300"
set [find where default-name="ether8"] comment="Anton - Home access VLAN100"
set [find where default-name="sfp-sfpplus1"] comment="Fritz!Box - routed WAN"
