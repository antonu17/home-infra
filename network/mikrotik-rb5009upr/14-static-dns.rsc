# Static infrastructure DNS; ExternalDNS owns Gateway HTTPRoute names separately.
# Key: exact name. Validate all records before updating any of them.
# No resolver/upstream settings, DHCP options or TXT ownership records are changed.

:do {
    :local existing [/ip dns static find where name="pulsar.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: pulsar.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-pulsar.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: pulsar.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: pulsar.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="pihole.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: pihole.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-pihole.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: pihole.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: pihole.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="vault.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: vault.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-vault.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: vault.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: vault.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="talos.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: talos.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-talos.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: talos.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: talos.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="registry.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: registry.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-registry.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: registry.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: registry.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="k8s.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: k8s.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-k8s.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: k8s.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: k8s.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="router.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: router.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-router.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: router.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: router.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="aruba.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: aruba.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-aruba.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: aruba.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: aruba.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="printer.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: printer.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-printer.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: printer.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: printer.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="3dprinter.home.antonu.org"]
    :if ([:len $existing] > 1) do={ :error "Duplicate DNS name: 3dprinter.home.antonu.org" }
    :if ([:len [/ip dns static find where name="external-dns-3dprinter.home.antonu.org" and type="TXT"]] > 0) do={ :error "ExternalDNS ownership marker exists: 3dprinter.home.antonu.org" }
    :if ([:len $existing] = 1) do={
        :if ([/ip dns static get $existing type] != "A") do={ :error "Conflicting DNS record type: 3dprinter.home.antonu.org" }
    }
}

:do {
    :local existing [/ip dns static find where name="pulsar.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="pulsar.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology DSM"
    } else={
        /ip dns static set $existing name="pulsar.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology DSM" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="pihole.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="pihole.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology Pi-hole"
    } else={
        /ip dns static set $existing name="pihole.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology Pi-hole" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="vault.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="vault.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology Vault"
    } else={
        /ip dns static set $existing name="vault.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology Vault" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="talos.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="talos.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology Talos Image Factory"
    } else={
        /ip dns static set $existing name="talos.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology Talos Image Factory" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="registry.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="registry.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology OCI registry"
    } else={
        /ip dns static set $existing name="registry.home.antonu.org" type=A address=192.168.40.5 ttl=5m match-subdomain=no disabled=no comment="Synology OCI registry" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="k8s.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="k8s.home.antonu.org" type=A address=192.168.40.20 ttl=5m match-subdomain=no disabled=no comment="Kubernetes API VIP"
    } else={
        /ip dns static set $existing name="k8s.home.antonu.org" type=A address=192.168.40.20 ttl=5m match-subdomain=no disabled=no comment="Kubernetes API VIP" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="router.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="router.home.antonu.org" type=A address=192.168.88.1 ttl=5m match-subdomain=no disabled=no comment="MikroTik router"
    } else={
        /ip dns static set $existing name="router.home.antonu.org" type=A address=192.168.88.1 ttl=5m match-subdomain=no disabled=no comment="MikroTik router" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="aruba.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="aruba.home.antonu.org" type=A address=192.168.88.3 ttl=5m match-subdomain=no disabled=no comment="Aruba AP management"
    } else={
        /ip dns static set $existing name="aruba.home.antonu.org" type=A address=192.168.88.3 ttl=5m match-subdomain=no disabled=no comment="Aruba AP management" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="printer.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="printer.home.antonu.org" type=A address=192.168.30.3 ttl=5m match-subdomain=no disabled=no comment="IoT printer"
    } else={
        /ip dns static set $existing name="printer.home.antonu.org" type=A address=192.168.30.3 ttl=5m match-subdomain=no disabled=no comment="IoT printer" regexp=""
    }
}

:do {
    :local existing [/ip dns static find where name="3dprinter.home.antonu.org"]
    :if ([:len $existing] = 0) do={
        /ip dns static add name="3dprinter.home.antonu.org" type=A address=192.168.30.4 ttl=5m match-subdomain=no disabled=no comment="Bambu P2S 3D printer"
    } else={
        /ip dns static set $existing name="3dprinter.home.antonu.org" type=A address=192.168.30.4 ttl=5m match-subdomain=no disabled=no comment="Bambu P2S 3D printer" regexp=""
    }
}
