# Network addressing plan

This document records current allocations and explicitly reserved space.
Reconciled with repository source and operator evidence on 2026-10-10;
no live infrastructure queries were performed by the agent. Inventory/API
automation remains planned, not an existing source of truth.

Synology `pulsar` is now `192.168.40.5/24` in VLAN400 (Home Cloud),
gateway `192.168.40.1`: operator DNS, packet capture and DSM access confirmed
the move on 2026-10-10. Its former VLAN100 address was `192.168.100.5`.

## VLAN summary

| VLAN | Name | Subnet | Gateway | DHCP range | Notes |
|---:|---|---|---|---|---|
| 1 | Management | `192.168.88.0/24` | `192.168.88.1` | None | Existing router and infrastructure management |
| 100 | Home | `192.168.100.0/24` | `192.168.100.1` | `192.168.100.50-254` | Trusted household network; DHCP DNS `192.168.100.1` (2026-10-10 export) |
| 200 | Guest | `192.168.200.0/24` | `192.168.200.1` | `192.168.200.2-254` | Guest Wi-Fi |
| 300 | IoT | `192.168.30.0/24` | `192.168.30.1` | `192.168.30.100-199` | TV, printer and smart devices; router DNS `.30.1` |
| 400 | Home Cloud | `192.168.40.0/24` | `192.168.40.1` | `192.168.40.100-199` | Talos, Kubernetes and RouterOS-native PXE |

## VLAN 400 — Home Cloud

| Range | Intended use |
|---|---|
| `192.168.40.1` | RB5009 gateway, DNS resolver, DHCP and TFTP server |
| `192.168.40.2-4` | Reserved network infrastructure |
| `192.168.40.5` | Synology NAS (`pulsar`), observed live 2026-10-10 |
| `192.168.40.6-9` | Reserved network infrastructure |
| `192.168.40.10` | Reserved for a future inventory/API service; currently unused |
| `192.168.40.11-19` | Reserved supporting infrastructure |
| `192.168.40.20` | Kubernetes API virtual IP (`k8s.home.antonu.org`) |
| `192.168.40.21` | First Talos control-plane node (`talos-cp-01`) |
| `192.168.40.22` | Retired node address; no current peer (operator confirmed 2026-10-10) |
| `192.168.40.23` | Retired node address; no current peer (operator confirmed 2026-10-10) |
| `192.168.40.24-29` | Additional Talos control-plane reservations |
| `192.168.40.30-39` | Unused historical LB reservation; service IPs now use `10.40.0.0/24` |
| `192.168.40.40` | `talos-worker-01`, Synology VMM worker, DHCP reservation |
| `192.168.40.41` | `talos-worker-02`, physical worker, DHCP reservation |
| `192.168.40.42` | `talos-worker-03`, physical worker, DHCP reservation |
| `192.168.40.43-99` | Reserved additional VM or physical nodes |
| `192.168.40.100-199` | Dynamic DHCP and machine discovery pool |
| `192.168.40.200-254` | Unallocated expansion space |

RouterOS is the sole DHCP authority. Its native TFTP server supplies only the
small iPXE bootstrap and scripts. Large operating-system artifacts are served
by the local Image Factory and registry, not stored on the router.

The checked-in iPXE menu still uses HTTP to the local factory; see the explicit
configuration drift in [PXE](pxe.md). Both physical Raspberry Pi workers are
already in VLAN400 at `.41` and `.42`. Aruba/ether7 does not need VLAN400.

## Service names

| Name | Address / target | Purpose |
|---|---|---|
| `pulsar.home.antonu.org` | `192.168.40.5` | Synology DSM; CSI API access over hostname-based HTTPS/443 |
| `talos.home.antonu.org` | `192.168.40.5` | Self-hosted Image Factory, HTTPS |
| `registry.home.antonu.org` | `192.168.40.5` | OCI registry for promoted Talos installers, HTTPS |
| `k8s.home.antonu.org` | `192.168.40.20` | Kubernetes API VIP, TCP/6443 |
| `argocd.home.antonu.org` | `10.40.0.10` | Repository Gateway VIP; current DNS reconciliation is failing (see ExternalDNS guide) |

The implemented uplink places NAS management, storage, services and VMM guests on untagged
VLAN400 through `syno1`, an access port accepting no VLAN-tagged frames.
NAS/VMM traffic on this uplink must be untagged in both directions.
NAS-to-node traffic then stays within Home Cloud; Home
clients reach the NAS through routed firewall policy. Previously, NAS services
used VLAN100 while VMM guests used tagged VLAN400. DNS records, CSI/iSCSI target
references, service bindings and certificates must be checked separately for the
new address; this documentation does not change them or confirm live DNS values.
The 2026-10-10 DHCP export advertises router `192.168.100.1` as Home DNS,
superseding the older `.100.2` DHCP setting. The NAS move does not transfer
either resolver address; any remaining `.100.2` service is not established by
the DHCP export. The old RouterOS DNS scripts still contain the previous
NAS address and must not be treated as current target configuration.

Talos management currently uses the real control-plane endpoint `.21`
(the operator confirmed `.22`/`.23` retired on 2026-10-10)
(TCP/50000), not the Kubernetes VIP. As reported on 2026-10-02, Cilium LB-IPAM
uses `10.40.0.0/24`. All four nodes (ASN 65001) peer with RB5009
`192.168.40.1` (ASN 65000), advertising allocated Service VIPs as /32 routes.
This is routed service space, not a new VLAN/subnet interface on the router.
No permanent BGP /24 aggregate is introduced. See [GitOps](gitops.md) for the
deployed Gateway's configured stable VIP, DNS and separate Tailscale prerequisites.

## Common DHCP — operator export 2026-10-10

`network/mikrotik-rb5009upr/10-dhcp.rsc` now covers Home100, Guests200, IoT300
and Cloud400, retaining server names `dhcp1`, `dhcp2`, `dhcp300-iot` and
`dhcp400-home-cloud`. Each scope advertises its `.1` gateway as DNS. Home also
advertises DHCP domain `home.antonu.org`; no DNS record is created. Cloud retains
next-server `192.168.40.1` and boot filename `ipxe-x86_64.efi` from the supplied
export, despite the older PXE guide naming a different file.

The supplied export contained Home `.100.26` (now identified as the printer),
CP `.40.21`, and workers `.40.40`, `.40.41`, `.40.42`. The common file preserves
the node reservations and moves only that exact printer identity to IoT `.30.3`. Other leases are preserved. The export omits
pool ranges: the table above records planned/fallback ranges, not confirmed live
pool values. Existing pools are left unchanged until `/ip pool export` is supplied;
missing pools use the documented ranges. No VLAN1/500 DHCP is activated. Configuration
is operator-reported; DHCP delivery and PXE functionality have not been tested here.

## Aruba and printer Wi-Fi follow-up (2026-10-10)

Aruba management is `192.168.88.3/24` on native VLAN1, gateway `192.168.88.1`.
RouterOS policy permits Home full L3 access to this exact IP, including SSH and
the observed HTTPS redirect from 443 to 4343. Ether7 is configured for
native1/tagged100,200,300 membership; VLAN300 is for the printer/IoT SSID, not AP
management. The operator confirmed the printer is now `192.168.30.3` on
2026-10-10. This confirms the address, not every AP configuration detail or
printing protocol. No DNS record is created.

Printer reservation confirmed by operator 2026-10-10: Wi-Fi MAC
`40:23:43:D9:F3:90` → `192.168.30.3/24`, gateway/DNS `192.168.30.1`,
server `dhcp300-iot`. The configuration replaces its former Home reservation
`192.168.100.26` and adds the exact address to `PRINTERS`. The operator clarified on 2026-10-10 that Guests must not print. The updated
firewall source retires the former `Guest IPP printers` allow rule; Guest→IoT
is denied, including this printer. Home printing remains covered by Home→IoT.
Guest discovery remains excluded; the reported absence of discovery is expected
for mDNS-based discovery. Direct printing is not authorized from Guest.

## Discovery and incident references

IPv4 mDNS uses the RouterOS native repeater across VLAN100/300/400. SSDP uses
the separate ARM64 `ssdp-relay` container with one VETH in each of those VLANs.
Guests and Management are excluded. The operator confirmed Pulsar DLNA discovery
on both the TV and Mac after the firewall and relay interface fixes. NAS-to-Home
and NAS-to-IoT exceptions allow all protocols from the exact NAS IP; they do not
open the whole Cloud subnet. Discovery success does not establish every playback
or IPv6 path. See the [DLNA postmortem](../incidents/postmortems/2026-10-10-pulsar-dlna-discovery.md).

The numbered, idempotent router source is
[network/mikrotik-rb5009upr](../network/mikrotik-rb5009upr/README.md).
VLAN500 remains inactive. Application DNS records belong to ExternalDNS;
its current crash loop is recorded in [ExternalDNS](external-dns.md).
