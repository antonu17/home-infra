# Initial installation. Review address allocation before importing.
:do {
    :local endpoint "192.168.30.9/24"
    :local source "192.168.30.9"
    :local gateway "192.168.30.1"
    :local prefix ""
    :if ([:len [/file find where name="flash" and type="directory"]] = 1) do={ :set prefix "flash/" }
    :if ([:len [/system package find where name="container" and disabled=no]] != 1) do={ :error "Container package required" }
    :if ([/system device-mode get container] != true) do={ :error "Enable container device mode first" }
    :if ([/system resource get architecture-name] != "arm64") do={ :error "ARM64 image required" }
    :if ([/system resource get free-hdd-space] < 134217728) do={ :error "Keep 128MiB free for extraction" }
    :if ([:len [/interface bridge find where name="bridge" and vlan-filtering=yes]] != 1) do={ :error "Expected VLAN-filtering bridge" }
    :if ([:len [/interface vlan find where name="vlan300-iot" and vlan-id=300]] != 1) do={ :error "Expected VLAN300 interface" }
    :if ([:len [/interface find where name="veth-thread-rio"]] != 0) do={ :error "VETH exists; inspect partial/existing installation" }
    :if ([:len [/container find where name="thread-rio-sync"]] != 0) do={ :error "Container exists; use update procedure" }
    :if ([:len [/ip firewall filter find where comment="Thread RIO HTTPS"]] != 0) do={ :error "Firewall rule exists; inspect partial installation" }
    :local deny [/ip firewall filter find where comment="input default deny"]
    :if ([:len $deny] != 1) do={ :error "Expected one input default deny" }
    :if ([:len [/file find where name=($prefix . "thread-rio-sync.tar")]] != 1) do={ :error "Upload thread-rio-sync.tar first" }
    :if ([:len [/container envs find where list="thread-rio-env"]] != 0) do={ :error "Environment already exists; inspect partial installation" }
    :if ([:len [/ip address find where address=$endpoint]] != 0) do={ :error "Address already configured on router" }
    :if ([:len [/ip dhcp-server lease find where address=$source]] != 0) do={ :error "Address has DHCP lease; resolve allocation first" }
    # The access PVID creates dynamic untagged membership alongside the static VLAN300 row.
    /interface veth add name=veth-thread-rio address=$endpoint gateway=$gateway dhcp=no comment="Thread RIO listener"
    /interface bridge port add bridge=bridge interface=veth-thread-rio pvid=300 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged comment="Thread RIO VLAN300 attachment"
    /ip firewall filter add chain=input action=accept in-interface=vlan300-iot src-address=$source dst-address=$gateway protocol=tcp dst-port=443 place-before=$deny comment="Thread RIO HTTPS"
    /container envs add list=thread-rio-env key=RIO_INTERFACE value=veth-thread-rio
    /container envs add list=thread-rio-env key=RIO_APPLY value=0
    /container add name=thread-rio-sync file=($prefix . "thread-rio-sync.tar") interface=veth-thread-rio root-dir=($prefix . "containers/thread-rio-sync") envlist=thread-rio-env privileged=yes user=0:0 start-on-boot=no logging=yes restart-policy=on-failure memory-high=33554432 memory-max=67108864 comment="Thread RIO route controller"
}
