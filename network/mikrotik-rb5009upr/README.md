# MikroTik RB5009UPr+S+IN — idempotent RouterOS configuration

Repository-prepared 2026-10-09. Operator reports all files imported on 2026-10-10.
The agent has not changed or inspected the live router. The `.rsc` files
apply the agreed **target** to an existing RouterOS 7 configuration. Importing
unchanged files again updates the same objects instead of adding copies.
There are no custom firewall chains, jump rules, comment prefixes, observation
mode or manual default-deny activation stages.

## How repeat imports work

Each object has a stable key:

| Object | Key / behavior |
|---|---|
| Physical ports | `default-name`; names must match references, comments updated |
| Bond, bridge, VLAN interfaces, interface lists | `name`; add if absent, otherwise set |
| Bridge ports | `interface`; add if absent, otherwise set bridge/PVID/frame types |
| Static bridge VLAN rows | `bridge` + exact single VLAN ID; dynamic rows ignored |
| Router addresses | exact address/prefix + interface; conflicting gateways rejected |
| Interface-list members | `list` + `interface` |
| Firewall address entries | `list` + `address`; keep static entries permanent and enabled; reject dynamic matches |
| Firewall filter rules | unique descriptive `comment`; update properties and order |
| WAN masquerade | `WAN Internet masquerade`; also adopt the old `defconf: masquerade` comment |

Every add is inside an absent-object check. Multiple matches stop with an error;
these files do not delete arbitrary duplicates to guess which one you wanted.
Correct a duplicate privately by reviewing the affected object or its source key,
then rerun. Existing single objects keep their IDs. Comments are identity keys for
filter/NAT rules: change a rule's conditions in Git, keep its comment stable.
Changing a comment creates another identity. The old rule is not automatically
removed; with the managed rules restored to the top, old input/forward rules sit
below terminal denies. Remove retired rules only by their exact reviewed identity.

The filter sets managed selectors and clears omitted common selectors (addresses,
interfaces, protocol/ports, connection state/marks, IPsec, routing marks, limits,
time) so an old value does not silently restrict a changed rule.
Do not add other conditions manually to managed rules; source is authoritative.
The desired managed rule block is moved before other static rules in deterministic order on
**every** import. Built-in dynamic rules, such as FastTrack counter rows, remain
untouched above the static rules. Other static filter rules are preserved below
the managed block; output is untouched.
Final input/forward denies are enabled automatically at the end. While assembling
rule order their managed drops are disabled briefly; imports are **not atomic**.
A disconnect or error can leave a partial application. Rerun after resolving the
error; there is no transaction or automatic rollback framework.

This is scoped reconciliation, not a reset of the entire router. Unrelated objects
are retained. Deleted source entries are not generally pruned automatically.
The exact stale WAN/ether8 and LAN/bridge members are removed; the saved combined
static VLAN100/200 row is disabled and replaced with single-VID rows. Unexpected
static VLAN IDs/ranges on this bridge stop the import, including VLAN500. No broad
`remove [find]`, reset, reboot, BGP or remote-service command is included.
Static infrastructure DNS is reconciled separately by `14-static-dns.rsc`.
Common DHCP configuration covers Home, Guests, IoT and Cloud; WAN DHCP is untouched.
Repeated import does not accumulate objects, but it can still interrupt traffic
when changing desired values. Existing established/FastTracked sessions can retain
previous permissions until expiry; idempotency is not a connection-tracking reset.

## Descriptive comments

Managed bridge/ports, VLAN interfaces, gateway addresses, interface lists and
members, DHCP servers/networks and WAN masquerade have descriptive comments on
both creation and update. Names and natural keys are unchanged. NAT accepts its
factory or new comment as the same identity and rejects duplicates before changes.

To refresh comments on an already imported configuration, upload the updated
files and re-import `03-bridge.rsc`, `05-addressing.rsc`, `06-interface-lists.rsc`,
`08-firewall-nat.rsc` and `10-dhcp.rsc` in that order. These files reconcile their
settings as well as comments; review them before import.

Retained obsolete filter rules can still have `defconf` comments. They are not
managed rules and stay below the managed terminal denies. Do not rename them to
managed rule comments: comments are filter identity keys. Inventory remaining
factory comments with these read-only commands, then review exact objects before
any removal or extension of configuration ownership:

```routeros
/interface bridge print detail where comment~"defconf"
/interface bridge port print detail where comment~"defconf"
/interface list print detail where comment~"defconf"
/ip address print detail where comment~"defconf"
/ip firewall filter print detail where comment~"defconf"
/ip firewall nat print detail where comment~"defconf"
```

## Files and import order

Upload the reviewed files into one RouterOS directory, then run these commands
**yourself** from that directory. The agent does not execute them. Import files
individually, in alphabetical filename order (numeric prefixes encode dependencies); stop immediately on an error:

```routeros
/import file-name=01-interfaces.rsc
/import file-name=02-bonding.rsc
/import file-name=03-bridge.rsc
/import file-name=04-vlans.rsc
/import file-name=05-addressing.rsc
/import file-name=06-interface-lists.rsc
/import file-name=07-address-lists.rsc
/import file-name=08-firewall-nat.rsc
/import file-name=09-firewall-filter.rsc
/import file-name=10-dhcp.rsc
/import file-name=11-mdns.rsc
# SSDP files 12/13 have separate prerequisites documented below.
/import file-name=14-static-dns.rsc
```

The same order is used on every reapplication; no separate first-run procedure.
On the actual installed version, syntax-check each file first, e.g.:

```routeros
/import file-name=09-firewall-filter.rsc verbose=yes dry-run=yes
```

The saved export reports 7.24.4; RouterOS 7.16+ supports import dry-run. Check the
live version rather than upgrading for this package. Dry-run catches syntax,
not connectivity or semantic compatibility. Before first application, privately
retain the current export/encrypted backup and confirm the prerequisites below.
Use local Home IP access to 192.168.100.1 via ether4/8; Safe Mode is optional router
protection, not part of the configuration. Do not rely on a NAS-hosted remote path
for applying disruptive network changes.

## PXE assets and legacy reference

PXE files now live in [`pxe/`](pxe/README.md) within this router package. The
move changes repository paths only; router files remain under `flash/pxe/`.
Do not include nested `pxe/routeros.rsc` in the numbered imports: it is a legacy
non-idempotent bootstrap that unconditionally adds TFTP mappings.
See [the PXE runbook](../../docs/pxe.md) before any upload or import.

## Target interfaces and VLANs

| Interface | Device | PVID | Accepted tagged ingress |
|---|---|---:|---|
| sfp-sfpplus1 | Fritz!Box copper SFP+ WAN | — | Not a bridge member |
| ether1 + ether2 | Synology bond slaves | — | Not individual bridge members |
| syno1 | Synology NAS + VMs, IEEE802.3ad | 400 | None |
| ether3 | TV | 300 | None |
| ether4 | Denis Home | 100 | None |
| ether5 | worker-03 | 400 | None |
| ether6 | worker-02 | 400 | None |
| ether7 | Aruba | 1 | 100,200,300 |
| ether8 | Anton Home | 100 | None |

One bridge, ingress filtering, hardware offload requested on bridge ports.
Access ports, including syno1, admit untagged/priority-tagged frames only;
ether7 admits both kinds. NAS and VMM traffic on syno1 must be untagged;
remove VLAN400 tagging on that uplink. VLAN400 egress on syno1 is untagged.
Keep existing bridge MAC/protocol-mode and existing bond hash/LACP monitoring
settings. Bond mode/slaves converge to 802.3ad and ether1/2, based on the export;
DSM must match. WAN and bond-slave bridge memberships cause an explicit error.
Existing `use-ip-firewall=yes` also stops: this design uses routed IP filtering.
The physical naming check rejects renamed ports instead of silently creating
invalid references. No physical link/MTU/transceiver/PoE settings are changed.

| VLAN | Tagged | Untagged | Routed interface | Router IP |
|---:|---|---|---|---|
| 1 | bridge | ether7 | vlan1-mgmt | 192.168.88.1/24 |
| 100 | bridge,ether7 | ether4,ether8 | vlan100-trusted | 192.168.100.1/24 |
| 200 | bridge,ether7 | none | vlan200-guest | 192.168.200.1/24 |
| 300 | bridge,ether7 | ether3 | vlan300-iot | 192.168.30.1/24 |
| 400 | bridge | syno1,ether5,ether6 | vlan400-home-cloud | 192.168.40.1/24 |

VLAN1 uses a tagged CPU because the export already has `vlan1-mgmt`; ether7 is
native/untagged toward Aruba. The bridge CPU admits tagged frames only, avoiding
implicit untagged bridge management. If live management is directly on bridge,
this model needs adjustment before applying; do not create a duplicate gateway.
VLAN interfaces with an existing alternate name are rejected for the same reason.
VLAN500 is absent. The BGP LB pool 10.40.0.0/24 is routed service space, with no VLAN
or router address. Validate actual H flags; requested L2 offload is not proof of
routing throughput or L3 firewall bypass.

LAN contains five routed interfaces. WAN includes sfp-sfpplus1; ether8 is removed
from WAN. HOME/GUEST/IOT/CLOUD/MGMT contain their matching routed VLAN interfaces.
MGMT represents infrastructure VLAN1, while HOME is the router administrator zone.
REMOTE is an empty list for a verified existing remote ingress, not a guessed
Tailscale interface. Arbitrary extra members/include/exclude settings are retained
and must be audited because they can change classifications.

Address lists cover the five subnets, LB pool and known BGP peers. LOCAL-NETWORKS
includes service space so a missing BGP route cannot authorize it through a WAN
allow. BGP-PEERS contains 192.168.40.21,.40,.41,.42. The operator confirmed .22/.23
retired on 2026-10-10; only their exact static BGP-PEERS entries are removed.
INFRA-MGMT contains operator-confirmed Aruba 192.168.88.3 for unrestricted Home access.
No printer, HA or remote address is invented. Add verified addresses to the source before use.

## Firewall behavior

**Current policy (2026-10-10): L3 forwarding.** Allowed routed paths use source
networks, destination addresses/lists and VLAN interfaces, without protocol or
port restrictions. The protocol/port-specific descriptions elsewhere below
record earlier policy and are superseded by the L3 section at the end.
Input rules for router services and mDNS remain separate and scoped.

Rules live directly in built-in `input` and `forward` chains.

Input: established/related, invalid drop, Home router management TCP 22/80/443/8291
and ICMP, internal DHCP UDP 68->67 (including source 0.0.0.0), zone-scoped DNS,
Cloud TFTP 69, known-peer BGP 179, scoped current ExternalDNS HTTP 80, authorized
remote management, then deny. An allow does not enable a RouterOS service;
existing service ports/address restrictions remain authoritative. Add exact
required infrastructure router services if inventory establishes them.

Forward: invalid drop, optional WAN FastTrack, established/related, Home->IoT,
Home->LB HTTP(S), API VIP 6443, known Talos nodes 50000, selected infrastructure
HTTPS, measured HA->selected IoT HTTPS 443, documented
NAS/DNS dependencies, zone Internet access, authorized remote Cloud web access,
Cloud->LB web access, then deny. Other Guest/IoT/Cloud cross-zone initiation is
denied. MGMT has no blanket initiation allow; add verified management tuples only.
Guest->Home DNS 53 is an intentional narrow exception for the documented resolver.
Home printing is included in Home->IoT; no Guest unrestricted IoT access.
Use additional printing protocols only after device requirements are confirmed.
No generic dstnat accept; existing published WAN services require exact rules.
No untracked acceptance; review any current raw notrack rules before application.
Same-VLAN Cloud/NAS/VM traffic is switched and does not pass this routed filter.

WAN masquerade is adopted in place using its known existing comment. A second
WAN-list masquerade with a different identity stops that file. Other NAT rules
are preserved and need review for internal SNAT; no internal/LB NAT is introduced.
The existing broad FastTrack remains below the managed block and cannot bypass
its terminal deny. A restricted established LAN->WAN FastTrack rule is present
but disabled in source until main-table routes, mangle/connection marks, IPsec,
queues/VRFs and Tailscale compatibility are verified. Enable it by changing its
`disabled` value on its single set command, then reimport.
No-mark alone does not prove main-table routing. Internal and LB flows use normal
connection tracking. Existing cached flows need expiry or a separately reviewed
exact-flow removal before testing changed isolation.

## Common DHCP

`10-dhcp.rsc` reproduces the operator-provided DHCP export from
2026-10-10 06:55:47, RouterOS7.24.4. It updates the existing servers by their
current names and refuses conflicting interface bindings. Networks are keyed by
subnet, reservations by server + MAC; duplicates and conflicting reserved IPs
stop before DHCP changes. Matching dynamic leases are made static before updating
reservations. Unrelated reservations/options are retained. The exact former printer Home
reservation is moved or retired as described below.

| VLAN | Existing server | Pool | Gateway and DNS | Lease time |
|---:|---|---|---|---|
| 100 Home | dhcp1 | dhcp_pool1 | 192.168.100.1 | 30m (RouterOS default made explicit) |
| 200 Guests | dhcp2 | dhcp_pool2 | 192.168.200.1 | 30m (RouterOS default made explicit) |
| 300 IoT | dhcp300-iot | pool300-iot | 192.168.30.1 | 1d |
| 400 Cloud | dhcp400-home-cloud | pool400-home-cloud | 192.168.40.1 | 1h |

Home keeps the DHCP domain `home.antonu.org`. This is DHCP option15, not a DNS
record or static hostname. All four scopes advertise their router as DNS, as in
the supplied current export; the older Home resolver `.100.2` documentation is
superseded for DHCP clients. Existing router resolver/upstream settings are not
changed; the script requires router DNS to be available already. No VLAN1/500
DHCP server is created. The existing firewall already permits DHCP and zone DNS.

**Pool ranges were absent from the supplied export.** Existing pool ranges are
preserved. Only a missing pool is created using documented fallback ranges:
Home `.100.50–254`, Guests `.200.2–254`, IoT `.30.100–199`, Cloud `.40.100–199`.
These are not claimed to be discovered live ranges. Provide `/ip pool export`
to reconcile them into explicit desired ranges. Confirm fallback ranges have no
static-address conflicts before importing against a missing pool. Until current
ranges are confirmed, reconciliation of existing pool ranges remains intentionally
outside this file; repeated imports neither recreate nor overwrite those pools.

Reservations retained from the current export:

| Address | MAC | Server | Known purpose |
|---|---|---|---|
| 192.168.30.3 | 40:23:43:D9:F3:90 | dhcp300-iot | Wi-Fi printer; MAC matching, replaces former Home .100.26 reservation |
| 192.168.40.21 | 02:11:32:28:5A:95 | dhcp400-home-cloud | talos-cp-01 |
| 192.168.40.40 | 02:11:32:2E:F4:1B | dhcp400-home-cloud | talos-worker-01 |
| 192.168.40.41 | DC:A6:32:2F:57:C3 | dhcp400-home-cloud | talos-worker-02 |
| 192.168.40.42 | 2C:CF:67:1B:D6:FE | dhcp400-home-cloud | talos-worker-03 |

No invented reservations for NAS `.40.5`, API VIP `.40.20`, or CP `.22/.23`.
The NAS address remains static DSM configuration, outside this DHCP file.

Cloud keeps the exact live-export PXE values: `next-server=192.168.40.1` and
`boot-file-name=ipxe-x86_64.efi`. The PXE reference maps that requested name to
`flash/pxe/ipxe.efi`; verify the live file and mapping. This DHCP change does not
rewrite TFTP mappings/files or substitute another boot filename.
Home/Guest lease times were omitted by the export; the documented RouterOS default
30m is made explicit. Other unmentioned server/network/lease options are retained.

Operator checks (read-only):

```routeros
/ip pool export
/ip dhcp-server export
/ip dhcp-server print detail
/ip dhcp-server network print detail
/ip dhcp-server lease print detail
```

Syntax-check the uploaded `10-dhcp.rsc` with verbose dry-run before import.
After applying, verify a fresh DHCP exchange on each used VLAN, the gateway/DNS
and Home domain, the five reservations, Cloud PXE and stable object counts after
a repeat import. DHCP export proves configuration, not that offers reach clients.
Keep this common file as the only DHCP source; the old IoT-only file is replaced.

## Required real values — edit Git, then reimport

Empty exception lists make their enabled rules match nobody. Fill these with
actual static addresses using the same `list + address` add-or-set pattern already
in 07-address-lists.rsc; keep those values in Git rather than adding them manually:

| List | Required evidence |
|---|---|
| PRINTERS | Printer inventory /32s in VLAN300; no Guest access grant |
| INFRA-MGMT | Aruba 192.168.88.3; current rule additionally pins this exact IP and allows all protocols/ports from Home |
| HA-EGRESS | Source /32 seen at RouterOS, not HA's Gateway VIP |
| HA-IOT | Exact devices using the configured HTTPS 443 integration |
| EXTERNALDNS-EGRESS | Observed REST workload source /32; current endpoint HTTP 80 |
| REMOTE-MGMT-SOURCES | Authorized source /32s actually seen at RouterOS |
| REMOTE interface list | Actual ingress of existing routed remote access |

For example, replace the placeholder privately and put this complete block in
07-address-lists.rsc (do not paste a literal placeholder into the router):

```routeros
:do {
    :local existing [/ip firewall address-list find where list="PRINTERS" and address="<VERIFIED-PRINTER-IP>"]
    :if ([:len $existing] > 1) do={ :error "Duplicate printer entry" }
    :if ([:len $existing] = 0) do={
        /ip firewall address-list add list=PRINTERS address=<VERIFIED-PRINTER-IP> disabled=no
    } else={
        :if ([/ip firewall address-list get $existing dynamic] = true) do={
            :error "Printer entry must be static"
        }
        /ip firewall address-list set $existing list=PRINTERS address=<VERIFIED-PRINTER-IP> disabled=no
    }
}
```

Use canonical host addresses without `/32` in the key if RouterOS stores them
that way; use canonical CIDRs for subnets. Avoid different textual keys for the
same address. Do not add broad Home/Cloud/IoT source trust as a substitute for
missing service inventory. Duplicate handling is an error, not automatic removal.

Cilium values do not explicitly establish effective masquerading/routing options.
HA/REST traffic may appear as node or Pod addresses; measure it. A shared node
source authorizes other workloads on that node to the same destination/ports.
Per-workload egress isolation would need a separate Cilium policy task. Routed
Pod sources require existing return routes; no Pod routing/SNAT is added here.
Additional HA ports/callbacks need separate measured source/destination rules.
WAN DHCP, BGP peers and other
services remain unchanged. Common IPv4 DHCP is configured by 10-dhcp.rsc. The remote lists do not configure Tailscale routes,
grants or underlay. If remote traffic is SNATed into Home, it may already match
Home policy; verify the actual path rather than assuming that source preservation.
Preserve any required IPsec/tunnel underlay rules with explicit verified matches
in this same source before the terminal denies. Never allow all 100.64.0.0/10.

## Current evidence and prerequisites

The historical `../../rb5009-config.rsc` records 7.24.4, LACP syno1, VLAN1/100/200,
Home gateways, WAN DHCP and masquerade. It predates implemented300/400 and BGP;
its combined CPU-incomplete VLAN table and WAN/ether8 membership differ from the
target. `../../docs/addressing.md` confirms all gateways, known nodes and LB pool;
`../../docs/pxe.md` confirms RouterOS DHCP/TFTP and vlan400-home-cloud.
`../../kubernetes/cilium/values.yaml` and `manifests/` describe Cilium 1.20.2,
AS 65001 -> router AS 65000, with routed service /32 advertisements. Physical
worker addresses are now documented from the supplied DHCP export: worker-02
`.40.41`, worker-03 `.40.42`; BGP configuration is not inferred from those leases.

**DISRUPTIVE:** applying target PVID400 to syno1 changes the NAS/VM uplink.
DSM bond must already use LACP, and NAS/VMM/guest traffic must be untagged VLAN400.
The NAS target is **192.168.40.5/24**, gateway **192.168.40.1**, assigned by the
operator on 2026-10-09. It replaces the previously documented 192.168.100.5 in
VLAN100; the move has not been verified live. Confirm `.40.5` has no conflicting
allocation, and resolve CSI/iSCSI, registry/Image Factory, certificates and DNS
dependencies in their own scope before applying this target. No compatibility NAT or second Home subnet
is invented. Exact NAS/DNS forward exceptions retain documented existing endpoints
for any still-valid routed dependencies, but cannot make an absent old address work.
The current filter still references old NAS `.100.5`; those rules are historical
compatibility allowances, not the new target address. After the move, Cloud nodes
reach NAS `.40.5` directly at L2. Home-to-NAS forward rules now allow only `.40.5` TCP80/443 (web/reverse proxy),
TCP8081 (documented Pi-hole admin UI), and ICMP diagnostics. Vault backend8200
remains private; use its HTTPS reverse proxy. These rules do not configure the
NAS address or services. Other DSM/SSH/SMB ports need separately verified
exceptions if required.
Home DHCP now advertises router DNS 192.168.100.1, per the current export.
Any still-used legacy resolver at .100.2 must be verified separately; moving a
former DNS device from ether5 requires resolving its actual dependencies externally. This repository task does not
change DSM/VMM, service addresses, WAN DHCP or Kubernetes resources.
Static infrastructure DNS records are managed by `14-static-dns.rsc`.

**DISRUPTIVE:** ether3 becomes IoT, ether5/6 become Cloud and terminal denies
replace implicit inter-VLAN trust. Verify those are the agreed connected devices
and existing DHCP/provisioning settings support their target networks. Keep Home
management 192.168.100.1 and access ports 4/8. This package supplies target state,
not a coordinated endpoint migration or rollback procedure.

The input/forward policy here is IPv4. The export also contains IPv6 rules.
Active routed IPv6 needs a matching reviewed policy before claiming isolation;
do not disable IPv6 speculatively. MAC WinBox/server, neighbor discovery and
RoMON bypass IPv4 input: confirm existing access restrictions separately.
Unknown current remote paths/services cannot be preserved automatically by an
idempotent IPv4 target. Resolve the exception inputs before using final denies.

## Operator read-only checks

Privately inspect current state without publishing full exports, secrets, users,
certificate private keys or credential-bearing container environment settings:

```routeros
/system resource print
/interface ethernet print detail
/interface bonding print detail
/interface bonding monitor syno1 once
/interface bridge print detail
/interface bridge settings print
/interface bridge port print detail
/interface bridge vlan print detail
/interface vlan print detail
/interface list print detail
/interface list member print detail
/ip address print detail
/ip service print detail
/ip firewall filter print detail
/ip firewall filter print stats
/ip firewall address-list print detail
/ip firewall nat print detail
/ip firewall mangle print detail
/ip firewall raw print detail
/routing rule print detail
/routing bgp session print detail
/ip route print detail where dst-address~"10.40."
/ip dhcp-server print detail
/ip dhcp-server network print detail
/ip tftp print detail
/ipv6 address print detail
/ipv6 route print detail
/ipv6 firewall filter print detail
```

After applying, verify fresh IP management from ether4/8 and authorized remote
access, Home/Guest/IoT/Cloud Internet, DHCP and both DNS transports, disposable PXE,
all BGP peers, API/Talos/Gateway/registry/CSI/iSCSI round trips and Aruba Wi-Fi.
Check new Guest/IoT/Cloud forbidden flows against known listening services and
deny counters; an absent listener or old established session is not firewall proof.
Require correct tagged CPU entries, PVIDs, H flags, /32 LB routes through Cloud,
no VLAN500, no bridge WAN/slaves and no internal NAT. Router ping alone does not
test forwarding. Reimport unchanged files and privately compare static object
counts, IDs, configured fields and rule order; volatile counters/uptime/conntrack
are not desired-state differences. No application traffic is tested by the agent.

## Local validation

Checked native add-or-set structure, stable keys, enabled final defaults, rule
ordering, port/PVID/VLAN/CPU mapping, gateway/list references and scope boundaries.
No local RouterOS parser/emulator or live import was run; reimport behavior must
still be verified with RouterOS dry-run and the operator's count/order comparison.
Unrelated repository changes are preserved. No commit, push or live action.

Official references:
[RouterOS scripting / set and unset](https://help.mikrotik.com/docs/spaces/ROS/pages/47579229/Scripting),
[bridge VLAN table](https://help.mikrotik.com/docs/spaces/ROS/pages/28606465/Bridge+VLAN+Table),
[bonding](https://help.mikrotik.com/docs/spaces/ROS/pages/8323193/Bonding),
[connection tracking / FastTrack](https://help.mikrotik.com/docs/spaces/ROS/pages/130220087/Connection+tracking),
[Cilium masquerading](https://docs.cilium.io/en/stable/network/concepts/masquerading/).

## Printer Wi-Fi VLAN300 and Aruba administration

Prepared 2026-10-10: ether7 now carries tagged VLAN300 in addition to 100/200,
while Aruba management remains native/untagged VLAN1, PVID1. VLAN300 remains
untagged on ether3; no VLAN300 router addressing/DHCP change is needed.
The previously empty INFRA-MGMT list now contains Aruba 192.168.88.3. Its Home
forward rule pins that exact address and permits all protocols/ports from Home; Guests,
IoT and Cloud remain denied. TCP4343 is the operator-observed WebUI redirect.

Upload the updated files and import them manually:

```routeros
/import 01-interfaces.rsc
/import 03-bridge.rsc
/import 04-vlans.rsc
/import 07-address-lists.rsc
/import 09-firewall-filter.rsc
```

**DESTRUCTIVE (scoped address-list cleanup):** 07 removes only static BGP-PEERS
entries 192.168.40.22 and192.168.40.23, confirmed retired by the operator. It does
not change BGP connections. Other object updates retain their natural keys.
Verify Home HTTPS access to https://192.168.88.3/ before changing Wi-Fi.
Aruba must retain 192.168.88.3/24 and return routing through 192.168.88.1; the
operator confirmed that HTTPS443 redirects to https://192.168.88.3:4343/.

Manual Aruba procedure (not executed by the agent):

1. Save the current Aruba settings privately. Preserve native management VLAN1
   and existing Home/Guest SSID assignments 100/200.
2. Configure a dedicated IoT SSID (the topology proposes `Neutron IoT`) using
   **Network assigned** client IP assignment and **Static VLAN 300**. RouterOS
   supplies DHCP; do not enable AP-assigned DHCP/NAT or a captive portal.
   Menu labels depend on the installed Instant firmware, not present in Git.
3. If an explicit AP uplink allowed-VLAN list exists, add 300 while retaining
   native 1 and tagged 100/200. Do not change management to tagged300.
4. Test the IoT SSID with a spare client first. Confirm a 192.168.30.x/24 lease,
   gateway/DNS 192.168.30.1 and the expected Internet/zone restrictions.
5. **DISRUPTIVE to printer connectivity:** move the printer to the IoT SSID;
   renew its lease. It should obtain 192.168.30.x. Changing an existing shared
   Home SSID to VLAN300 would move every client on that SSID; use a separate SSID.
6. Operator confirmed the printer now uses `192.168.30.3` (2026-10-10).
   Verify Home printing using its supported protocol; model/protocol support is
   not recorded yet.
7. Guests must not print or discover the printer. The updated 09 retires the
   old `Guest IPP printers` exception; Guest-to-IoT reaches default deny. Keep
   Guest excluded from mDNS/SSDP. Verify denied direct Guest access to the printer
   and other IoT devices, independently of discovery.

Rollback: reconnect the printer to its original SSID/settings. To retire the IoT
SSID after reconnecting all affected clients, restore only its saved Aruba
settings. To undo the trunk extension in Git, change the two VLAN300 add/set
branches back to `tagged=bridge` and re-import 04; ether3 remains IoT. Removing
that tag interrupts all Wi-Fi VLAN300 clients, so reconnect them first. Do not
restore retired BGP peers as part of printer rollback.

Reference: [Aruba Instant8.11 user guide, IP/VLAN assignment](https://www.arubanetworks.com/techdocs/Aruba-Instant-8.x-Books/811/Aruba-Instant-8.11.0.0-User-Guide.pdf).
This is guidance for manual review, not confirmation of the installed firmware.

### Printer reservation confirmed 2026-10-10

Wi-Fi MAC `40:23:43:D9:F3:90` is reserved as `192.168.30.3` on
`dhcp300-iot`, outside the dynamic .30.100–199 pool, and added to PRINTERS.
The operator confirmed the live printer address on 2026-10-10; model/printing
protocols remain unverified. Guests are not authorized to print. Home access
is covered by Home-to-IoT; the updated 09 removes the former Guest exception.

07/10 own the reservation/inventory and are already imported. For the newly
clarified no-Guest-printing policy, upload and re-import **09-firewall-filter.rsc**
only. The script removes the exact former managed Guest printer exception.
Existing tracked connections may retain earlier acceptance until expiry; this
change does not flush connection tracking. Verify new Guest connections are denied.

**DISRUPTIVE / scoped deletion:** 10 adopts the exact former Home reservation
192.168.100.26 for this MAC in place if there is no IoT lease. If an IoT lease
already exists, it updates that lease and removes only the exact former Home
reservation. Repeated imports keep one target reservation. The old client-id
constraint is cleared so the static reservation matches the Wi-Fi MAC. Other
servers for this MAC or conflicting target addresses stop the import.

Read-only verification:

```routeros
/ip dhcp-server lease print detail where mac-address="40:23:43:D9:F3:90"
/ip firewall address-list print where list="PRINTERS"
```

Confirm address 192.168.30.3, server dhcp300-iot and bound status after reconnecting.
Rollback requires moving this same lease back to dhcp1/address 192.168.100.26 and
restoring its former client-id, then reconnecting to the former SSID. First revert
this desired reservation in Git, otherwise the next import moves it to IoT again.
No DNS record is created; IPv4 mDNS discovery is prepared separately in11.

### Aruba SSH and HTTPS redirect (2026-10-10)

The operator confirmed a successful TCP443/TLS connection with HTTP302 redirect
onto TCP4343. The Home infrastructure rule now allows TCP22/443/4343 with both
`dst-address=192.168.88.3` and `dst-address-list=INFRA-MGMT`, preserving its
existing comment/identity. No other management destination is opened. Re-import
only09 after uploading the updated file. SSH must also be enabled on the AP;
RouterOS does not configure the AP service. The later full-access change below also permits ICMP.

Operator-run client checks:

```sh
nc -vz -G 3 192.168.88.3 22
nc -vz -G 3 192.168.88.3 4343
ssh admin@192.168.88.3
```

Open https://192.168.88.3:4343/ for the WebUI. The supplied TLS output shows an
untrusted certificate whose subject is securelogin.arubanetworks.com rather than
the IP address; firewall permissions do not resolve that browser warning.

### Full Home access to Aruba (2026-10-10)

At the operator's request, Home has unrestricted routed access to Aruba
192.168.88.3: all IP protocols and ports, including ICMP. The existing rule retains
its identity and exact destination, HOME ingress/Home source network, MGMT egress
and INFRA-MGMT destination membership. Its update explicitly clears protocol and
destination-port selectors left by the previous restricted rule. Guests, IoT and
Cloud receive no new access; other VLAN1 destinations remain unchanged.
Upload and re-import09 only. No per-Mac address restriction is introduced:
this authorizes the existing Home administrator zone as requested.

## mDNS discovery across Home, IoT and Home Cloud

Requested2026-10-10: `11-mdns.rsc` sets native RouterOS IPv4 mDNS repetition on
vlan100-trusted, vlan300-iot and vlan400-home-cloud. Source09 has three input
rules accepting UDP5353 to224.0.0.251 only on those interfaces and from their
respective directly connected subnets. Guest/VLAN1/WAN are excluded. No forward
multicast rule, SSDP, DNS record, NAT or bridge IP firewall is added. Existing
unicast DNS upstreams and DHCP settings are untouched.

The repeater is bidirectional among all three VLANs: IoT and Cloud also discover
Home and one another. RouterOS does not provide directional/service-type filters
through this interface list. Existing inter-VLAN service permissions still apply;
seeing a service does not open its advertised port. Native repetition supports
IPv4 only; IPv6 mDNS and the separate IPv6 segmentation findings remain unresolved.

Upload the updated09 and new11, then manually apply:

```routeros
/import 09-firewall-filter.rsc
/import 11-mdns.rsc
```

Read-only check on RouterOS:

```routeros
/ip dns print
/ip firewall filter print stats where comment~"mDNS discovery"
```

On the Home Mac, browse the service types your devices actually advertise, e.g.:

```sh
dns-sd -B _ipp._tcp local.
dns-sd -B _ipps._tcp local.
dns-sd -B _http._tcp local.
```

Stop browsing with Ctrl-C. Resolve a discovered instance using
`dns-sd -L "<instance name>" _ipp._tcp local.` and test its advertised destination
under the existing access rules. AP multicast/SSID-role filtering and device
advertisement settings can still suppress discovery; the router repeater cannot
make a silent device advertise. Cluster Pods do not automatically advertise onto
VLAN400 merely because their nodes are there.

Rollback: set `mdns-repeat-ifaces=""` under `/ip dns` manually to stop repetition,
then reflect that disabled desired state in11 before importing again. This property
replaces the entire repeater interface list; retain its previous value privately
if mDNS repetition was separately configured after the last export. The new input
rules can be disabled in source09 when removing this feature.

Reference: [MikroTik DNS/mDNS documentation](https://help.mikrotik.com/docs/spaces/ROS/pages/37748767/DNS).
The router locally receives/repeats mDNS, so allowances belong in input, not forward.

### Synology DSM HTTPS access (2026-10-10)

The Home NAS web rule now includes TCP5001 to192.168.40.5 for direct DSM HTTPS,
in addition to80/443/8081. Its existing comment identity and Home-only source,
Cloud egress and exact NAS destination remain unchanged. Re-import09 only after
uploading the updated file. This does not enable DSM on the NAS or open other
NAS protocols. Test from Home with `nc -vz pulsar.home.antonu.org 5001` and open
https://pulsar.home.antonu.org:5001/.

## L3 forwarding policy (2026-10-10)

At the operator's request, managed forward accept rules now clear protocol,
source/destination port, TCP flag and ICMP-type selectors. Existing source and
destination addresses/lists, VLAN ingress/egress classification, established/
related handling and final deny remain. This permits all IP protocols/ports
**only on an already authorized network or host path**. It does not grant
unrestricted access between every VLAN or to the router itself.

In particular:

- Home has full access to NAS192.168.40.5 and Aruba192.168.88.3, Home-to-IoT,
  the Kubernetes service pool10.40.0.0/24, API VIP and known cluster nodes.
- Guest retains Internet access and has no access to the printer
  (192.168.30.3), other IoT devices or Home/Cloud/management destinations.
  Guest is excluded from printer/multicast discovery.
- HA exceptions remain limited to listed HA-EGRESS sources and HA-IOT
  destinations but no longer restrict service ports. Empty lists still match
  nothing. Remote service paths likewise retain existing source/destination scope.
- Historical Cloud-to-.100.5 and resolver-.100.2 paths retain their exact
  destinations but now permit all ports/protocols. Confirm/remove retired paths
  separately. No broader Cloud initiation to Home/IoT/management is introduced.
- IPv4 input protections, WAN NAT, disabled FastTrack and mDNS repetition are
  unchanged. Existing IPv6 and MAC-management audit gaps remain unresolved.

The full NAS rule adopts its old `Home NAS web services` identity and renames it
`Home NAS access` in place. Duplicate old/new identities stop the import. The
redundant `Home NAS diagnostics` rule is retired only after the full rules are
ordered and terminal denies enabled.

Upload/re-import09 only. **Scoped deletion:** this import removes exactly the
obsolete managed filter rule with comment `Home NAS diagnostics`; it is replaced
by full access to the same NAS, including ICMP. The import changes forwarding
permissions on every existing allowed path as described above.

Synology Drive sync uses TCP6690, documented by
[Synology's service port reference](https://kb.synology.com/en-global/DSM/tutorial/What_network_ports_are_used_by_Synology_services).
No separate6690 exception is needed under full Home-to-NAS access. Client check:

```sh
nc -vz pulsar.home.antonu.org 6690
```

A failure after import requires checking hostname resolution, NAS service health
and DSM's own firewall. The router rule does not enable or configure NAS services.

## IoT TV access to Synology DLNA (2026-10-10)

Source09 now permits IoT192.168.30.0/24 to NAS192.168.40.5 on all protocols and
ports, as requested under L3 forwarding. This includes NAS administration as
well as media service access. It does not allow IoT initiation to other Cloud
hosts, Home or VLAN1. Established/related replies remain permitted. Re-import09
only to apply this path. No NAT or broad Cloud-to-IoT initiation rule is added.

**SSDP discovery is not yet configured.** DLNA uses SSDP239.255.255.250 UDP1900,
not the mDNS group/port. Existing11 already repeats mDNS among100/300/400.
Opening firewall ports alone cannot repeat SSDP. An SSDP relay must handle
M-SEARCH requests, multicast announcements and unicast discovery responses on
both IoT and Cloud. IGMP proxy alone is not a bidirectional SSDP reflector and
has only one upstream interface; no misleading IGMP configuration is provided.

Relay deployment is pending the operator's host choice and interface inventory.
Use an existing Linux host/VM with two actual L2 VLAN attachments, or a reviewed
RouterOS container with container support, persistent storage and a veth on each
VLAN. Preserve existing Synology untagged400 uplink; do not invent a tagged300
DSM interface or silently extend its bond trunk. No Kubernetes/NAS resources,
container privileges, addresses or images have been invented here.

A candidate implementation is
[alsmith/multicast-relay](https://github.com/alsmith/multicast-relay), which handles
SSDP unicast answers as well as multicast. Pin/review its source and configure
only SSDP between the two verified interfaces, leaving mDNS to RouterOS and
excluding Guest/management; Home was subsequently added as documented below. Concrete installation and
idempotent network configuration require the selected host's actual interfaces.

Verify Synology Media Server is running and has media indexed, that DSM's own
firewall permits the TV subnet, and that the TV sees/plays it once the relay is
configured. Playback permission does not prove discovery. No live tests or
configuration changes have been performed by the agent.

## SSDP relay implementation prepared (2026-10-10)

The pending SSDP host choice is resolved: RB5009 internal storage, with matching
RouterOS/container7.24.4 and device-mode container=yes confirmed by the operator.
See [the relay build/import/rollback guide](ssdp-relay/README.md). Source12 creates
three VETH access attachments for Home/IoT/Cloud with existing DHCP; source13 imports a reviewed ARM64
archive into persistent internal storage under `containers/ssdp-relay` (prefixed
with `flash/` when that existing storage directory is present). Source04 preserves these optional bridge
VLAN members on future imports. Source09 permits both IoT-to-NAS and the exact
NAS-to-IoT and NAS-to-Home reverse paths required for SSDP unicast responses under the requested
L3 policy. Native mDNS11 is unchanged. No Synology uplink change is required.

Build/archive creation and router imports/start remain manual. This is not a
claim of agent-performed live testing. The operator confirmed TV discovery after
importing the NAS/IoT firewall rules; the new Home extension awaits validation.
Full alphabetical application, after building/uploading the archive, continues
with12 then13 after11. First container start remains a separate manual step.

The existing image can be extended to VLAN100 without a rebuild: source13 sets
explicit relay entrypoint/arguments for all three VETHs. Stop the relay before
reapplying04/09/12/13, then start it; see the linked extension/rollback procedure.

## Static infrastructure DNS

`14-static-dns.rsc` owns exact A records for `pulsar`, `pihole`, `vault`,
`talos` and `registry` under `home.antonu.org`, all pointing to `192.168.40.5`.
`k8s.home.antonu.org` points to the Kubernetes API VIP `192.168.40.20`.
`router` points to `192.168.88.1`, `aruba` to `192.168.88.3`,
`printer` to `192.168.30.3` and `3dprinter` to `192.168.30.4`.
`10-dhcp.rsc` reserves `192.168.30.4` for Bambu P2S Wi-Fi MAC
`EC:B5:0A:86:6F:30`, with lease comment `3dprinter`. The address is outside
the dynamic IoT pool. Existing IoT leases are adopted and made static;
duplicates, leases on another server or an occupied target address stop the
import. Reconnect the printer to the IoT SSID after importing DHCP.
These are infrastructure names outside the current Gateway HTTPRoute catalog.
No wildcard, ExternalDNS TXT marker, resolver upstream or DNS service setting
is created or changed. Current TTL is explicitly 5 minutes.

The file validates all ten names before changing records, rejects duplicates,
non-A records and matching ExternalDNS TXT ownership markers, then adds missing
records or updates existing A records by exact name. Re-importing updates the
same objects. Other names are untouched. DNS static A syntax follows the
[MikroTik DNS documentation](https://help.mikrotik.com/docs/spaces/ROS/pages/37748767/DNS).

Operator-run, after reviewing existing records and saving their old values:

```routeros
/ip dns static print detail where name~"home[.]antonu[.]org"
/import file-name=14-static-dns.rsc verbose=yes dry-run=yes
/import file-name=14-static-dns.rsc
:put [:resolve "pulsar.home.antonu.org" server=192.168.100.1]
:put [:resolve "talos.home.antonu.org" server=192.168.100.1]
:put [:resolve "k8s.home.antonu.org" server=192.168.100.1]
```

For a DNS-only update, import only this file. Include it after the existing
numbered files for a complete configuration. Clients may cache older answers
until their previous TTL expires. Rollback: restore the recorded properties of
previous A records and remove only the exact names newly added by this import.
Do not remove all static DNS records or ExternalDNS ownership TXT entries.
The agent has not imported or tested this configuration on the live router.
