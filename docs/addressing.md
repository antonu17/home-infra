# Network addressing plan

This document records current allocations and explicitly reserved space.
The Home Cloud implementation was reconciled with the repository and operator
handoff on 2026-10-01; no live router discovery was performed. Inventory/API
automation remains planned, not an existing source of truth.

## VLAN summary

| VLAN | Name | Subnet | Gateway | DHCP range | Notes |
|---:|---|---|---|---|---|
| 1 | Management | `192.168.88.0/24` | `192.168.88.1` | None | Existing router and infrastructure management |
| 100 | Home | `192.168.100.0/24` | `192.168.100.1` | `192.168.100.50-254` | Trusted household network; DNS `192.168.100.2` |
| 200 | Guest | `192.168.200.0/24` | `192.168.200.1` | `192.168.200.2-254` | Guest Wi-Fi |
| 300 | IoT | `192.168.30.0/24` | `192.168.30.1` | To be finalized | TV, printer and smart devices |
| 400 | Home Cloud | `192.168.40.0/24` | `192.168.40.1` | `192.168.40.100-199` | Talos, Kubernetes and RouterOS-native PXE |

## VLAN 400 — Home Cloud

| Range | Intended use |
|---|---|
| `192.168.40.1` | RB5009 gateway, DNS resolver, DHCP and TFTP server |
| `192.168.40.2-9` | Reserved network infrastructure |
| `192.168.40.10` | Reserved for a future inventory/API service; currently unused |
| `192.168.40.11-19` | Reserved supporting infrastructure |
| `192.168.40.20` | Kubernetes API virtual IP (`k8s.home.antonu.org`) |
| `192.168.40.21` | First Talos control-plane node (`talos-cp-01`) |
| `192.168.40.22` | Second Talos control-plane node (`talos-cp-02`) |
| `192.168.40.23` | Third Talos control-plane node (`talos-cp-03`) |
| `192.168.40.24-29` | Additional Talos control-plane reservations |
| `192.168.40.30-39` | Unused historical LB reservation; service IPs now use `10.40.0.0/24` |
| `192.168.40.40` | `talos-worker-01`, Synology VMM worker, DHCP reservation |
| `192.168.40.41-99` | Reserved additional VM or physical nodes |
| `192.168.40.100-199` | Dynamic DHCP and machine discovery pool |
| `192.168.40.200-254` | Unallocated expansion space |

RouterOS is the sole DHCP authority. Its native TFTP server supplies only the
small iPXE bootstrap and scripts. Large operating-system artifacts are served
by the local Image Factory and registry, not stored on the router.

The checked-in iPXE menu still uses HTTP to the local factory; see the explicit
configuration drift in [PXE](pxe.md). VLAN 400 is implemented; Raspberry Pi
migration to it remains future work. Aruba/ether7 does not need VLAN 400.

## Service names

| Name | Address | Current purpose |
|---|---|---|
| `pulsar.home.antonu.org` | `192.168.100.5` | Synology DSM; CSI API access over hostname-based HTTPS/443 |
| `talos.home.antonu.org` | `192.168.100.5` | Self-hosted Image Factory, HTTPS |
| `registry.home.antonu.org` | `192.168.100.5` | OCI registry for promoted Talos installers, HTTPS |
| `k8s.home.antonu.org` | `192.168.40.20` | Kubernetes API VIP, TCP/6443 |
| `argocd.home.antonu.org` | `10.40.0.10` | Prepared Gateway reservation; HTTPRoute → ExternalDNS after staged activation |

The NAS services remain on VLAN 100, reached by routing from VLAN 400. Only
the VMM guests are on the tagged Home Cloud network. Ensure each client DNS
resolver serves these names; do not assume one RouterOS static record also
updates Pi-hole. The registry DNS deployment is operator-reported, not captured
in the existing RouterOS DNS scripts.

Talos management uses the real control-plane endpoints `.21`, `.22`, `.23`
(TCP/50000), not the Kubernetes VIP. As reported on 2026-10-02, Cilium LB-IPAM
uses `10.40.0.0/24`. All four nodes (ASN 65001) peer with RB5009
`192.168.40.1` (ASN 65000), advertising allocated Service VIPs as /32 routes.
This is routed service space, not a new VLAN/subnet interface on the router.
No permanent BGP /24 aggregate is introduced. See [GitOps](gitops.md) for the
prepared Gateway's stable VIP, DNS and separate Tailscale prerequisites.
