:if ([:len [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.107"]] > 1) do={ :error "Duplicate Samsung SSDP list entry" }
:foreach row in=[/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.107"] do={ :if ([/ip firewall address-list get $row dynamic] = true) do={ :error "Samsung SSDP list entry must be static" } }
:if ([:len [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.110"]] > 1) do={ :error "Duplicate Samsung SSDP list entry" }
:foreach row in=[/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.110"] do={ :if ([/ip firewall address-list get $row dynamic] = true) do={ :error "Samsung SSDP list entry must be static" } }
# Static entries keyed by list + address; no fictional printer/HA/remote IPs.
# No timeout on add means permanent; refuse dynamic matches rather than changing
# their lifetime. Clear comments with an explicit empty string, not !comment.

:do {
    :local existing [/ip firewall address-list find where list="LOCAL-NETWORKS" and address="192.168.88.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=LOCAL-NETWORKS and address=192.168.88.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=LOCAL-NETWORKS address=192.168.88.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=LOCAL-NETWORKS address=192.168.88.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="LOCAL-NETWORKS" and address="192.168.100.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=LOCAL-NETWORKS and address=192.168.100.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=LOCAL-NETWORKS address=192.168.100.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=LOCAL-NETWORKS address=192.168.100.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="LOCAL-NETWORKS" and address="192.168.200.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=LOCAL-NETWORKS and address=192.168.200.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=LOCAL-NETWORKS address=192.168.200.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=LOCAL-NETWORKS address=192.168.200.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="LOCAL-NETWORKS" and address="192.168.30.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=LOCAL-NETWORKS and address=192.168.30.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=LOCAL-NETWORKS address=192.168.30.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=LOCAL-NETWORKS address=192.168.30.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="LOCAL-NETWORKS" and address="192.168.40.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=LOCAL-NETWORKS and address=192.168.40.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=LOCAL-NETWORKS address=192.168.40.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=LOCAL-NETWORKS address=192.168.40.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="LOCAL-NETWORKS" and address="10.40.0.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=LOCAL-NETWORKS and address=10.40.0.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=LOCAL-NETWORKS address=10.40.0.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=LOCAL-NETWORKS address=10.40.0.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="MGMT-NETWORKS" and address="192.168.88.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=MGMT-NETWORKS and address=192.168.88.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=MGMT-NETWORKS address=192.168.88.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=MGMT-NETWORKS address=192.168.88.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="HOME-NETWORKS" and address="192.168.100.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=HOME-NETWORKS and address=192.168.100.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=HOME-NETWORKS address=192.168.100.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=HOME-NETWORKS address=192.168.100.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="GUEST-NETWORKS" and address="192.168.200.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=GUEST-NETWORKS and address=192.168.200.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=GUEST-NETWORKS address=192.168.200.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=GUEST-NETWORKS address=192.168.200.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="IOT-NETWORKS" and address="192.168.30.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=IOT-NETWORKS and address=192.168.30.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=IOT-NETWORKS address=192.168.30.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=IOT-NETWORKS address=192.168.30.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="CLOUD-NETWORKS" and address="192.168.40.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=CLOUD-NETWORKS and address=192.168.40.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=CLOUD-NETWORKS address=192.168.40.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=CLOUD-NETWORKS address=192.168.40.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="CLOUD-NETWORKS" and address="10.40.0.0/24"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=CLOUD-NETWORKS and address=10.40.0.0/24" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=CLOUD-NETWORKS address=10.40.0.0/24 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=CLOUD-NETWORKS address=10.40.0.0/24 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="BGP-PEERS" and address="192.168.40.21"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=BGP-PEERS and address=192.168.40.21" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=BGP-PEERS address=192.168.40.21 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=BGP-PEERS address=192.168.40.21 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="BGP-PEERS" and address="192.168.40.41"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=BGP-PEERS and address=192.168.40.41" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=BGP-PEERS address=192.168.40.41 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=BGP-PEERS address=192.168.40.41 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="BGP-PEERS" and address="192.168.40.42"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=BGP-PEERS and address=192.168.40.42" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=BGP-PEERS address=192.168.40.42 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=BGP-PEERS address=192.168.40.42 disabled=no
    }
}

:do {
    :local existing [/ip firewall address-list find where list="BGP-PEERS" and address="192.168.40.40"]
    :if ([:len $existing] > 1) do={ :error "Duplicate /ip firewall address-list object: list=BGP-PEERS and address=192.168.40.40" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=BGP-PEERS address=192.168.40.40 disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Managed address-list entry is dynamic; reconcile it as a static entry first"
        }
        /ip firewall address-list set $existing comment="" list=BGP-PEERS address=192.168.40.40 disabled=no
    }
}

# Add exact verified static addresses here using the same upsert blocks:
# PRINTERS: VLAN300 printer inventory; no Guest access.
# INFRA-MGMT: verified infrastructure /32s (HTTPS management).
# EXTERNALDNS-EGRESS: measured REST workload source /32s, current HTTP80.
# REMOTE-MGMT-SOURCES: authorized remote sources as actually seen by RouterOS.
# Remote ingress membership must also be supplied in 06-interface-lists.rsc.
# Add any other routed internal prefixes to LOCAL-NETWORKS before Internet allows.

# Retired peers confirmed by operator on 2026-10-10; remove only these static entries.
/ip firewall address-list remove [find where list="BGP-PEERS" and address="192.168.40.22" and dynamic=no]
/ip firewall address-list remove [find where list="BGP-PEERS" and address="192.168.40.23" and dynamic=no]

# Aruba admin endpoint confirmed by operator; used by Home HTTPS management rule.
:do {
    :local existing [/ip firewall address-list find where list="INFRA-MGMT" and address="192.168.88.3"]
    :if ([:len $existing] > 1) do={ :error "Duplicate Aruba infrastructure management address" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=INFRA-MGMT address=192.168.88.3 comment="Aruba HTTPS management" disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={ :error "Aruba management address must be static" }
        /ip firewall address-list set $existing list=INFRA-MGMT address=192.168.88.3 comment="Aruba HTTPS management" disabled=no
    }
}

# Operator-confirmed Wi-Fi printer reservation in VLAN300; no Guest access.
:do {
    :local existing [/ip firewall address-list find where list="PRINTERS" and address="192.168.30.3"]
    :if ([:len $existing] > 1) do={ :error "Duplicate printer address-list entry" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=PRINTERS address=192.168.30.3 comment="Wi-Fi printer - IoT" disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={ :error "Printer address-list entry must be static" }
        /ip firewall address-list set $existing list=PRINTERS address=192.168.30.3 comment="Wi-Fi printer - IoT" disabled=no
    }
}

# ExternalDNS may run on any current worker; .40.42 was observed on 2026-10-10.
# The operator authorizes all three worker sources for rescheduling resilience.
# Node sources are shared by SNATed workloads, not per-Pod identities.
:do {
    :local existing [/ip firewall address-list find where list="EXTERNALDNS-EGRESS" and address="192.168.40.40"]
    :if ([:len $existing] > 1) do={ :error "Duplicate ExternalDNS worker-01 egress entry" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=EXTERNALDNS-EGRESS address=192.168.40.40 disabled=no comment="ExternalDNS worker-01 egress"
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={ :error "ExternalDNS egress entry must be static" }
        /ip firewall address-list set $existing list=EXTERNALDNS-EGRESS address=192.168.40.40 disabled=no comment="ExternalDNS worker-01 egress"
    }
}

:do {
    :local existing [/ip firewall address-list find where list="EXTERNALDNS-EGRESS" and address="192.168.40.41"]
    :if ([:len $existing] > 1) do={ :error "Duplicate ExternalDNS worker-02 egress entry" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=EXTERNALDNS-EGRESS address=192.168.40.41 disabled=no comment="ExternalDNS worker-02 egress"
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={ :error "ExternalDNS egress entry must be static" }
        /ip firewall address-list set $existing list=EXTERNALDNS-EGRESS address=192.168.40.41 disabled=no comment="ExternalDNS worker-02 egress"
    }
}

:do {
    :local existing [/ip firewall address-list find where list="EXTERNALDNS-EGRESS" and address="192.168.40.42"]
    :if ([:len $existing] > 1) do={ :error "Duplicate ExternalDNS worker-03 egress entry" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=EXTERNALDNS-EGRESS address=192.168.40.42 disabled=no comment="ExternalDNS worker-03 egress"
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={ :error "ExternalDNS egress entry must be static" }
        /ip firewall address-list set $existing list=EXTERNALDNS-EGRESS address=192.168.40.42 disabled=no comment="ExternalDNS worker-03 egress"
    }
}

# Exact superseded HA-specific entries; full Cloud-to-IoT uses network lists.
/ip firewall address-list remove [find where list="HA-EGRESS" and address="192.168.40.41" and dynamic=no]
/ip firewall address-list remove [find where list="HA-IOT" and address="192.168.30.3" and dynamic=no]
/ip firewall address-list remove [find where list="HA-IOT" and address="192.168.30.0/24" and dynamic=no]

# Samsung SSDP source-subnet compatibility workaround.
:do {
    :local row [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.107"]
    :if ([:len $row] = 0) do={ /ip firewall address-list add list=SSDP-SUBNET-CLIENTS address=192.168.30.107 comment="Samsung TV Wi-Fi" } else={ /ip firewall address-list set $row list=SSDP-SUBNET-CLIENTS address=192.168.30.107 disabled=no comment="Samsung TV Wi-Fi" }
}
:do {
    :local row [/ip firewall address-list find where list="SSDP-SUBNET-CLIENTS" and address="192.168.30.110"]
    :if ([:len $row] = 0) do={ /ip firewall address-list add list=SSDP-SUBNET-CLIENTS address=192.168.30.110 comment="Samsung TV Ethernet" } else={ /ip firewall address-list set $row list=SSDP-SUBNET-CLIENTS address=192.168.30.110 disabled=no comment="Samsung TV Ethernet" }
}
