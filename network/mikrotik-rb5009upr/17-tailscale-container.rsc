:do {
# OPTIONAL: upload ARM64 tailscale-home.tar, import16, then import this file.
# Repeat imports validate an existing running container without stopping it.
:if ([:len [/system package find where name="container" and disabled=no]] != 1) do={ :error "Container package required" }
:if ([/system device-mode get container] != true) do={ :error "Container device mode required" }
:if ([:len [/interface veth find where name="veth-tailscale"]] != 1) do={ :error "Import file16 first" }
:local prefix ""
:if ([:len [/file find where name="flash" and type="directory"]] = 1) do={ :set prefix "flash/" }
:local root ($prefix . "containers/tailscale-home")
:local state ($prefix . "containers/tailscale-state")
:local existing [/container find where name="tailscale-home"]
:if ([:len $existing] > 1) do={ :error "Duplicate tailscale-home container" }
:local mount [/container mounts find where list="tailscale-state"]
:if ([:len $mount] > 1) do={ :error "Duplicate tailscale-state mount" }
:if ([:len $mount] = 1) do={
    :if ([/container mounts get $mount dst] != "/var/lib/tailscale") do={ :error "Unexpected Tailscale state mount destination" }
    :local source [/container mounts get $mount src]
    :if (($source != $state) && ($source != ("/" . $state))) do={ :error "Unexpected Tailscale state mount source" }
}
:if ([:len $existing] = 0) do={
    :if ([:len [/file find where name=($prefix . "tailscale-home.tar")]] != 1) do={ :error "Upload tailscale-home.tar first" }
    :if ([/system resource get free-hdd-space] < 268435456) do={ :error "Keep 256MiB free before Tailscale extraction" }
} else={
    :if ([/container get $existing interface] != "veth-tailscale") do={ :error "Unexpected existing Tailscale interface" }
    :if ([/container get $existing mountlists] != "tailscale-state") do={ :error "Unexpected existing Tailscale mounts; preserve state" }
    :local existingRoot [/container get $existing root-dir]
    :if (($existingRoot != $root) && ($existingRoot != ("/" . $root))) do={ :error "Unexpected container root; preserve identity/state" }
}
:local preserveRunning false
# Preserve live Tailscale sessions and identity on an unchanged repeat import.
:if ([:len $existing] = 1) do={
    :local live false
    :foreach match in=[/container find where running] do={ :if ([:tostr $match] = [:tostr $existing]) do={ :set live true } }
    :foreach match in=[/container find where healthy] do={ :if ([:tostr $match] = [:tostr $existing]) do={ :set live true } }
    :if ($live = true) do={
        :if ([:len $mount] != 1) do={ :error "Tailscale state mount missing" }
        :if ([/container get $existing dns] != "172.31.255.1") do={ :error "Tailscale DNS drift; stop before reconciliation" }
        :put "Tailscale running configuration preserved"
        :set preserveRunning true
    }
    :local stopped false
    :foreach match in=[/container find where stopped] do={ :if ([:tostr $match] = [:tostr $existing]) do={ :set stopped true } }
    :if (($stopped != true) && ($preserveRunning != true)) do={ :error "Wait for Tailscale extraction or state transition" }
}
:if ($preserveRunning != true) do={
:if ([:len $mount] = 0) do={
    /container mounts add list=tailscale-state src=$state dst=/var/lib/tailscale
}
:if ([:len $existing] = 0) do={
    /container add name=tailscale-home file=($prefix . "tailscale-home.tar") interface=veth-tailscale root-dir=$root mountlists=tailscale-state dns=172.31.255.1 privileged=yes user=0:0 start-on-boot=yes logging=no restart-policy=on-failure memory-high=134217728 memory-max=268435456 comment="Home Tailscale subnet router"
} else={
    /container set $existing interface=veth-tailscale mountlists=tailscale-state dns=172.31.255.1 privileged=yes user=0:0 start-on-boot=yes logging=no restart-policy=on-failure memory-high=134217728 memory-max=268435456 comment="Home Tailscale subnet router"
}
}
}
