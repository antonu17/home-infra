# Native PXE TFTP. DHCP boot fields remain owned by 10-dhcp.rsc.
# Upload pxe/files first. No files are created, uploaded or deleted by this import.
# Key: descriptive comment; adopt one existing exact filename mapping if needed.

:local pxeRoot "pxe"
:if ([:len [/file find where name="flash" and type="directory"]] = 1) do={ :set pxeRoot "flash/pxe" }

# Validate every file and mapping before changing settings or rules.
:do {
    :local path ($pxeRoot . "/ipxe-x86_64.efi")
    :local file [/file find where name=$path]
    :if ([:len $file] != 1) do={ :error "Upload the PXE file to persistent storage first: ipxe-x86_64.efi" }
    :if ([/file get $file size] = 0) do={ :error "Empty PXE file: ipxe-x86_64.efi" }
    :if ([:len [/ip tftp find where comment="PXE x86-64 UEFI bootstrap" or req-filename="(ipxe-x86_64[.]efi)|(/ipxe-x86_64[.]efi)" or req-filename="^/?ipxe-x86_64[.]efi\$"]] > 1) do={ :error "Duplicate PXE TFTP mapping: ipxe-x86_64.efi; review exact rows first" }
}

:do {
    :local path ($pxeRoot . "/autoexec.ipxe")
    :local file [/file find where name=$path]
    :if ([:len $file] != 1) do={ :error "Upload the PXE file to persistent storage first: autoexec.ipxe" }
    :if ([/file get $file size] = 0) do={ :error "Empty PXE file: autoexec.ipxe" }
    :if ([:len [/ip tftp find where comment="PXE iPXE automatic startup" or req-filename="(autoexec[.]ipxe)|(/autoexec[.]ipxe)" or req-filename="^/?autoexec[.]ipxe\$"]] > 1) do={ :error "Duplicate PXE TFTP mapping: autoexec.ipxe; review exact rows first" }
}

:do {
    :local path ($pxeRoot . "/boot.ipxe")
    :local file [/file find where name=$path]
    :if ([:len $file] != 1) do={ :error "Upload the PXE file to persistent storage first: boot.ipxe" }
    :if ([/file get $file size] = 0) do={ :error "Empty PXE file: boot.ipxe" }
    :if ([:len [/ip tftp find where comment="PXE home-cloud boot menu" or req-filename="(boot[.]ipxe)|(/boot[.]ipxe)" or req-filename="^/?boot[.]ipxe\$"]] > 1) do={ :error "Duplicate PXE TFTP mapping: boot.ipxe; review exact rows first" }
}

/ip tftp settings set max-block-size=1468

:do {
    :local existing [/ip tftp find where comment="PXE x86-64 UEFI bootstrap" or req-filename="(ipxe-x86_64[.]efi)|(/ipxe-x86_64[.]efi)" or req-filename="^/?ipxe-x86_64[.]efi\$"]
    :if ([:len $existing] = 0) do={
        /ip tftp add ip-addresses=192.168.40.0/24 req-filename="^/?ipxe-x86_64[.]efi\$" real-filename=($pxeRoot . "/ipxe-x86_64.efi") allow=yes read-only=yes disabled=no comment="PXE x86-64 UEFI bootstrap"
    } else={
        /ip tftp set $existing ip-addresses=192.168.40.0/24 req-filename="^/?ipxe-x86_64[.]efi\$" real-filename=($pxeRoot . "/ipxe-x86_64.efi") allow=yes read-only=yes disabled=no comment="PXE x86-64 UEFI bootstrap"
    }
}

:do {
    :local existing [/ip tftp find where comment="PXE iPXE automatic startup" or req-filename="(autoexec[.]ipxe)|(/autoexec[.]ipxe)" or req-filename="^/?autoexec[.]ipxe\$"]
    :if ([:len $existing] = 0) do={
        /ip tftp add ip-addresses=192.168.40.0/24 req-filename="^/?autoexec[.]ipxe\$" real-filename=($pxeRoot . "/autoexec.ipxe") allow=yes read-only=yes disabled=no comment="PXE iPXE automatic startup"
    } else={
        /ip tftp set $existing ip-addresses=192.168.40.0/24 req-filename="^/?autoexec[.]ipxe\$" real-filename=($pxeRoot . "/autoexec.ipxe") allow=yes read-only=yes disabled=no comment="PXE iPXE automatic startup"
    }
}

:do {
    :local existing [/ip tftp find where comment="PXE home-cloud boot menu" or req-filename="(boot[.]ipxe)|(/boot[.]ipxe)" or req-filename="^/?boot[.]ipxe\$"]
    :if ([:len $existing] = 0) do={
        /ip tftp add ip-addresses=192.168.40.0/24 req-filename="^/?boot[.]ipxe\$" real-filename=($pxeRoot . "/boot.ipxe") allow=yes read-only=yes disabled=no comment="PXE home-cloud boot menu"
    } else={
        /ip tftp set $existing ip-addresses=192.168.40.0/24 req-filename="^/?boot[.]ipxe\$" real-filename=($pxeRoot . "/boot.ipxe") allow=yes read-only=yes disabled=no comment="PXE home-cloud boot menu"
    }
}

# TFTP is first-match: keep managed mappings ahead of unrelated older rules.
# Reverse moves to index 0 produce bootstrap, automatic startup, then menu.
:do {
    :local existing [:pick [/ip tftp find where comment="PXE home-cloud boot menu"] 0]
    :local first [:pick [/ip tftp find] 0]
    :if ($existing != $first) do={ /ip tftp move $existing $first }
}
:do {
    :local existing [:pick [/ip tftp find where comment="PXE iPXE automatic startup"] 0]
    :local first [:pick [/ip tftp find] 0]
    :if ($existing != $first) do={ /ip tftp move $existing $first }
}
:do {
    :local existing [:pick [/ip tftp find where comment="PXE x86-64 UEFI bootstrap"] 0]
    :local first [:pick [/ip tftp find] 0]
    :if ($existing != $first) do={ /ip tftp move $existing $first }
}
