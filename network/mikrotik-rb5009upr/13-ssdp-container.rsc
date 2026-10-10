# Import the reviewed ARM64 archive from internal flash; never repull or auto-start.
# Stop an existing relay before updating attachments/arguments. Build/upload first. Re-imports preserve the same container and root filesystem.
:if ([:len [/system package find where name="container" and disabled=no]] != 1) do={ :error "Container package is required" }
:if ([/system device-mode get container] != true) do={ :error "Container device mode is required" }
:foreach iface in={"veth-ssdp-home";"veth-ssdp-iot";"veth-ssdp-cloud"} do={
    :if ([:len [/interface veth find where name=$iface]] != 1) do={ :error "Import 12-ssdp-network first" }
}
:do {
    :local prefix ""
    :if ([:len [/file find where name="flash" and type="directory"]] = 1) do={ :set prefix "flash/" }
    :local archive ($prefix . "ssdp-relay.tar")
    :local root ($prefix . "containers/ssdp-relay")
    :local existing [/container find where name="ssdp-relay"]
    :if ([:len $existing] > 1) do={ :error "Duplicate ssdp-relay container" }
    :if ([:len $existing] = 0) do={
        :if ([:len [/file find where name=$archive]] != 1) do={ :error "Upload ARM64 ssdp-relay.tar to persistent internal storage first" }
        :if ([/system resource get free-hdd-space] < 134217728) do={ :error "Keep at least 128MiB free before extracting relay" }
        /container add name=ssdp-relay file=$archive interface=veth-ssdp-home,veth-ssdp-iot,veth-ssdp-cloud root-dir=$root dns=192.168.40.1 entrypoint=python3,/app/multicast-relay.py cmd=--foreground,--wait,--noMDNS,--noSonosDiscovery,--noRemoteRelay,--interfaces,veth-ssdp-home,veth-ssdp-iot,veth-ssdp-cloud start-on-boot=yes logging=no restart-policy=on-failure memory-high=33554432 memory-max=67108864 comment="SSDP discovery Home IoT and Cloud"
    } else={
        :local existingRoot [/container get $existing root-dir]
        :if (($existingRoot != $root) && ($existingRoot != ("/" . $root))) do={ :error "Existing relay uses another root directory; review instead of overwriting" }
        :local ifaces [/container get $existing interface]
        :if (([:len $ifaces] != 2) && ([:len $ifaces] != 3)) do={ :error "Expected existing two- or three-interface relay" }
        :local haveIot false
        :local haveCloud false
        :foreach iface in=$ifaces do={
            :if ($iface = "veth-ssdp-iot") do={ :set haveIot true }
            :if ($iface = "veth-ssdp-cloud") do={ :set haveCloud true }
            :if (($iface != "veth-ssdp-iot") && ($iface != "veth-ssdp-cloud") && ($iface != "veth-ssdp-home")) do={ :error "Unexpected relay interface" }
        }
        :if (($haveIot = false) || ($haveCloud = false)) do={ :error "Existing relay must contain IoT and Cloud attachments" }
        /container set $existing interface=veth-ssdp-home,veth-ssdp-iot,veth-ssdp-cloud entrypoint=python3,/app/multicast-relay.py cmd=--foreground,--wait,--noMDNS,--noSonosDiscovery,--noRemoteRelay,--interfaces,veth-ssdp-home,veth-ssdp-iot,veth-ssdp-cloud start-on-boot=yes logging=no restart-policy=on-failure memory-high=33554432 memory-max=67108864 comment="SSDP discovery Home IoT and Cloud"
    }
}
