# Network addressing plan

This document records the intended IPv4 allocation. Device discovery and the
desired-state inventory will become authoritative once the network reconciler
is implemented.

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
| `192.168.40.30-39` | Reserved load-balancer virtual IPs |
| `192.168.40.40-99` | Static or DHCP-reserved physical nodes |
| `192.168.40.100-199` | Dynamic DHCP and machine discovery pool |
| `192.168.40.200-254` | Unallocated expansion space |

RouterOS is the sole DHCP authority. Its native TFTP server supplies only the
small iPXE bootstrap and scripts. Large operating-system artifacts are loaded
from version-pinned HTTPS sources.
