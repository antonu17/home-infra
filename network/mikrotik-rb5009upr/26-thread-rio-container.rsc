# Reconcile owned network objects; preserve existing image, root, mounts and credentials.
:do {
    :local prefix ""
    :if ([:len [/file find where name="flash" and type="directory"]] = 1) do={ :set prefix "flash/" }
    :if ([:len [/system package find where name="container" and disabled=no]] != 1) do={ :error "Container package required" }
    :if ([/system device-mode get container] != true) do={ :error "Container device mode required" }
    :if ([:len [/interface bridge find where name="bridge" and vlan-filtering=yes]] != 1) do={ :error "Expected VLAN-filtering bridge" }
    :if ([:len [/interface vlan find where name="vlan300-iot" and vlan-id=300 and disabled=no]] != 1) do={ :error "Expected VLAN300 interface" }
    :local instance [/container find where name="thread-rio-sync"]
    :local veth [/interface veth find where name="veth-thread-rio"]
    :local port [/interface bridge port find where interface="veth-thread-rio"]
    :local rule [/ip firewall filter find where comment="Thread RIO HTTPS"]
    :local deny [/ip firewall filter find where comment="input default deny"]
    :if (([:len $instance] > 1) || ([:len $veth] > 1) || ([:len $port] > 1) || ([:len $rule] > 1) || ([:len $deny] != 1)) do={ :error "Duplicate managed object or missing deny anchor" }
    :if ([:len [/interface find where name="veth-thread-rio"]] != [:len $veth]) do={ :error "VETH name belongs to another interface type" }
    :if ([:len $port] = 1) do={
        :if ([/interface bridge port get $port bridge] != "bridge") do={ :error "RIO VETH belongs to another bridge" }
    }
    :if ([:len $instance] = 1) do={
        :if ([/container get $instance interface] != "veth-thread-rio") do={ :error "Existing RIO container has unexpected interface" }
        :if ([/container get $instance envlist] != "thread-rio-env") do={ :error "Existing RIO container has unexpected environment" }
    } else={
        :if ([:len [/file find where name=($prefix . "thread-rio-sync.tar")]] != 1) do={ :error "Upload validated thread-rio-sync.tar first" }
        :if ([/system resource get architecture-name] != "arm64") do={ :error "ARM64 required" }
        :if ([/system resource get free-hdd-space] < 134217728) do={ :error "Keep 128MiB free for extraction" }
    }
    :if ([:len [/ip address find where address="192.168.30.9/24"]] != 0) do={ :error "Container IP is assigned to router" }
    :if ([:len [/ip dhcp-server lease find where address="192.168.30.9"]] != 0) do={ :error "Container IP has DHCP lease" }
    :if ([:len $veth] = 1) do={
        :if (([:tostr [/interface veth get $veth address]] != "192.168.30.9/24") || ([:tostr [/interface veth get $veth gateway]] != "192.168.30.1")) do={ :error "RIO VETH addressing drift; review before reconnecting container" }
    }
    # Preserve enabled apply mode across legacy 0/1 duplicates. Fresh installs observe.
    :local applyValue "0"
    :foreach row in=[/container envs find where list="thread-rio-env" and key="RIO_APPLY"] do={
        :local value [/container envs get $row value]
        :if (($value != "0") && ($value != "1")) do={ :error "RIO_APPLY must be 0 or 1" }
        :if (($value = "1") && ([/container envs get $row disabled] = false)) do={ :set applyValue "1" }
    }
    # Public settings are authoritative. Password values stay router-local.
    :local passwords [/container envs find where list="thread-rio-env" and key="ROS_PASSWORD"]
    :if ([:len $passwords] > 1) do={
        :local first [:pick $passwords 0]
        :foreach row in=$passwords do={
            :if ([/container envs get $row value] != [/container envs get $first value]) do={ :error "Conflicting ROS_PASSWORD entries; keep the valid password in WinBox before importing" }
        }
    }
    :local settings {"RIO_INTERFACE"="veth-thread-rio";"RIO_APPLY"=$applyValue;"ROS_URL"="https://192.168.30.1";"ROS_USER"="thread-rio";"SSL_CERT_FILE"="/ca/ca.crt"}
    :foreach key,value in=$settings do={
        :local rows [/container envs find where list="thread-rio-env" and key=$key]
        :if ([:len $rows] = 0) do={
            /container envs add list=thread-rio-env key=$key value=$value disabled=no
        } else={
            :local first [:pick $rows 0]
            /container envs set $first value=$value disabled=no
            :if ([:len $rows] > 1) do={
                :foreach row in=[:pick $rows 1 [:len $rows]] do={ /container envs remove $row }
            }
        }
    }
    :if ([:len $passwords] > 1) do={
        :foreach row in=[:pick $passwords 1 [:len $passwords]] do={ /container envs remove $row }
    }
    # Set only when drift exists, avoiding a VETH reconfiguration on unchanged imports.
    :if ([:len $veth] = 0) do={
        /interface veth add name=veth-thread-rio address=192.168.30.9/24 gateway=192.168.30.1 dhcp=no comment="Thread RIO listener"
    }
    :if ([:len $port] = 0) do={
        /interface bridge port add bridge=bridge interface=veth-thread-rio pvid=300 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged comment="Thread RIO VLAN300 attachment"
    } else={
        /interface bridge port set $port pvid=300 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=no
    }
    :if ([:len $rule] = 0) do={
        /ip firewall filter add chain=input action=accept in-interface=vlan300-iot src-address=192.168.30.9 dst-address=192.168.30.1 protocol=tcp dst-port=443 place-before=$deny comment="Thread RIO HTTPS"
    } else={
        /ip firewall filter set $rule chain=input action=accept in-interface=vlan300-iot src-address=192.168.30.9 dst-address=192.168.30.1 protocol=tcp dst-port=443 disabled=no
        /ip firewall filter move $rule destination=$deny
    }
    :if ([:len $instance] = 0) do={
        /container add name=thread-rio-sync file=($prefix . "thread-rio-sync.tar") interface=veth-thread-rio root-dir=($prefix . "containers/thread-rio-sync") envlist=thread-rio-env privileged=yes user=0:0 start-on-boot=no logging=yes restart-policy=on-failure memory-high=33554432 memory-max=67108864 comment="Thread RIO route controller"
    }
}
