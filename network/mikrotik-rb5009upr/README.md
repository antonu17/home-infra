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
| PXE TFTP mappings | descriptive `comment`; adopt a unique previous filename mapping |
| Static DNS records | exact `name`; reject duplicates and ownership conflicts |
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
Final input/forward denies are enabled automatically at the end. Existing deny
rules retain their enabled state during updates; only newly created deny rules
start disabled until ordering is complete. Imports are **not atomic**.
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
# SSDP PIM-SM follows core configuration; legacy files12/13 are retired.
/import file-name=14-static-dns.rsc
# Requires the three uploaded PXE files; see the PXE runbook.
/import file-name=15-pxe.rsc
/import file-name=18-ssdp-pim.rsc
```

The same order is used on every reapplication; no separate first-run procedure.
On the actual installed version, syntax-check each file first, e.g.:

```routeros
/import file-name=09-firewall-filter.rsc verbose=yes dry-run
```

The saved export reports 7.24.4; RouterOS 7.16+ supports import dry-run. Check the
live version rather than upgrading for this package. Dry-run catches syntax,
not connectivity or semantic compatibility. Before first application, privately
retain the current export/encrypted backup and confirm the prerequisites below.
Use local Home IP access to 192.168.100.1 via ether4/8; Safe Mode is optional router
protection, not part of the configuration. Do not rely on a NAS-hosted remote path
for applying disruptive network changes.

## PXE configuration and assets

[`15-pxe.rsc`](15-pxe.rsc) reconciles native TFTP settings and three read-only
VLAN400 mappings. It validates the uploaded assets before any mutation,
adopts unique previous mappings and restores deterministic first-match order.
DHCP remains owned exclusively by `10-dhcp.rsc`; no DHCP settings are duplicated.
Assets remain under [`pxe/files/`](pxe/README.md). There is no nested import script.
See [the PXE runbook](../../docs/pxe.md) for storage, prerequisites, verification,
existing-rule limitations and rollback before importing file15.

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

Forward: invalid drop, WAN FastTrack, established/related, Home->IoT,
Home->LB HTTP(S), API VIP 6443, known Talos nodes 50000, selected infrastructure
HTTPS, verified HA->entire IoT subnet L3 access, documented
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
`WAN FastTrack` is enabled for established/related, unmarked connections arriving
from LAN and leaving WAN, with no connection mark, no outbound IPsec policy,
and destinations outside LOCAL-NETWORKS. It is ordered after invalid drop and
before established/related acceptance. Initial connections still pass the normal
Internet policy; FastTrack does not grant new inter-VLAN access. The unsupported `hw-offload` parameter is omitted for this router. No hardware
acceleration claim is made. The routing-mark selector is cleared: ordinary traffic
has no explicit routing mark; main-table compatibility rests on the confirmed
absence of policy routing and additional VRFs.
File09 adopts the former `verified main-table WAN FastTrack` identity in place.

The operator supplied empty routing rules, mangle, simple queues and queue trees,
and only the main VRF on 2026-10-11. This supports enabling the scoped WAN rule;
it is not a live throughput test. Review FastTrack if adding policy routing,
IPsec, queues or VRFs later. Internal/LB traffic cannot match LAN-to-WAN scope.
Tailscale transit is not in LAN and is excluded, including exit-node traffic.
BGP sessions use input/output chains and are unaffected. Established acceptance
remains immediately after FastTrack for non-accelerated packets.

Operator-run update after uploading the revised file09:

```routeros
/import file-name=09-firewall-filter.rsc verbose=yes dry-run
/import file-name=09-firewall-filter.rsc
/ip firewall filter print stats where comment="WAN FastTrack"
/ip firewall filter print where disabled
```

Generate normal Internet traffic from Home while checking counters. Stop sniffer
or torch sessions during performance checks because they can inhibit FastTrack.
For rollback, disable only `/ip firewall filter disable [find where comment="WAN FastTrack"]`;
change the source too before importing again. Already FastTracked connections can
retain acceleration until expiration; no blanket conntrack flush is prescribed.

## Common DHCP

`10-dhcp.rsc` reproduces the operator-provided DHCP export from
2026-10-10 06:55:47, RouterOS7.24.4. It updates the existing servers by their
current names and refuses conflicting interface bindings. Networks are keyed by
subnet, reservations by server + MAC; duplicates and conflicting reserved IPs
stop before DHCP changes. Matching dynamic leases are made static before updating
reservations. Unrelated reservations/options are retained. The exact former printer Home
reservation is moved or retired as described below.

| VLAN | Server | Pool | Gateway and DNS | Lease time |
|---:|---|---|---|---|
| 100 Home | dhcp100-home | pool100-home | 192.168.100.1 | 30m (RouterOS default made explicit) |
| 200 Guests | dhcp200-guest | pool200-guest | 192.168.200.1 | 30m (RouterOS default made explicit) |
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
`flash/pxe/ipxe-x86_64.efi`; verify the live file and mapping. This DHCP change does not
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
| EXTERNALDNS-EGRESS | Workers .40.40/.40.41/.40.42 for rescheduling; .42 observed; router HTTP80 only |
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
HA-EGRESS sources have full L3 access to `192.168.30.0/24`, without protocol or
port restrictions. File07 adopts the former printer-only destination in place.
Printer polling was observed as `.40.41` to `.30.3` UDP161 on 2026-10-11.
Other worker sources remain unapproved; recheck egress if HA is rescheduled.
Device-initiated callbacks require separate review.
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
TCP8081 (historical allowance; no NAS Pi-hole is assumed), and ICMP diagnostics. Vault backend8200
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
Rollback requires moving this same lease back to dhcp100-home/address 192.168.100.26 and
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
- HA access uses listed HA-EGRESS sources and the complete HA-IOT subnet
  destinations but no longer restrict service ports. Empty lists still match
  nothing. Remote service paths likewise retain existing source/destination scope.
- Historical Cloud-to-.100.5 and resolver-.100.2 paths retain their exact
  destinations but now permit all ports/protocols. Confirm/remove retired paths
  separately. No broader Cloud initiation to Home/IoT/management is introduced.
- IPv4 input protections, WAN NAT and mDNS repetition are
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

SSDP now uses native IPv4 PIM-SM between Home100/IoT300 and Cloud400. The operator
confirmed discovery and playback on 2026-10-11. See [PIM configuration](ssdp-pim.md)
and [retired container cleanup](ssdp-container-removal.md). The earlier ARM64
relay implementation and files12/13 were removed from the working tree at the
operator's request. Historical DLNA incident evidence remains in the postmortem.

## Static infrastructure DNS

`14-static-dns.rsc` owns exact A records for `pulsar`, `pihole`, `vault`,
`talos` and `registry` under `home.antonu.org`. NAS services point to
`192.168.40.5`; `pihole` points to the prepared router container `172.31.254.2`.
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
/import file-name=14-static-dns.rsc verbose=yes dry-run
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

## DHCP server and pool names

File10 adopts `dhcp1` as `dhcp100-home`, `dhcp2` as `dhcp200-guest`,
`dhcp_pool1` as `pool100-home` and `dhcp_pool2` as `pool200-guest`.
IoT stays `dhcp300-iot`/`pool300-iot`; Cloud stays
`dhcp400-home-cloud`/`pool400-home-cloud`.

Renames update existing objects instead of creating replacements. Existing
pool ranges and next-pool chains are preserved; DHCP pool references and static
lease server references are explicitly rebound. Dynamic leases are not converted
or deleted by the rename. Review bound leases after import. Both old/new names
existing simultaneously, unexpected server interfaces or ambiguous identities
stop before renaming. No DHCP service restart or lease removal is used for naming.
Lease scripts or external automation containing literal old names need operator
review; the repository does not rewrite unknown scripts on the router.

Operator-run naming update after saving current server/pool/lease state privately:

```routeros
/import file-name=10-dhcp.rsc verbose=yes dry-run
/import file-name=10-dhcp.rsc
/ip dhcp-server print detail
/ip pool print detail
/ip dhcp-server lease print
```

Rollback naming only: rename the same server/pool objects back to the old names
and rebind their recorded pool/static lease references; preserve ranges and lease
addresses. Do not re-import the new source afterward unless restoring the new
names. The entire file10 also reconciles its existing DHCP settings/reservations;
this is not a name-only live command. No live validation was performed by the agent.

## Optional Tailscale subnet router

[The Tailscale runbook](tailscale/README.md) owns the optional addition in files
`16-tailscale-network.rsc` and `17-tailscale-container.rsc`. Synology Tailscale was
shut down by the operator on 2026-10-11; the replacement remains prepared, not
confirmed deployed. It advertises Kubernetes services `10.40.0.0/24`, `192.168.40.0/24` and
`192.168.100.0/24`, with exit-node advertising enabled. File09 integrates
ordering of its optional rules. Confirm the proposed transit allocation, build
and upload the image, then follow that runbook; these two optional files are not
part of an unconditional import sequence. No physical LAN or BGP changes are needed.

## Home / Home Cloud to IoT policy (2026-10-11)

The operator superseded the HA-specific exception: Home `192.168.100.0/24`
and Home Cloud `192.168.40.0/24` can initiate any IP protocol/port to IoT
`192.168.30.0/24`. Home Assistant can reschedule among Cloud workers without
changing source exceptions. File09 adds `Home Cloud to IoT access` and explicit
IoT-to-Home/Cloud drops after established/related acceptance. File07 retires only
the exact previous managed HA entries; file09 removes the exact previous HA, NAS-to-IoT and
IoT-to-NAS exceptions. Replies to authorized connections continue working.
Old tracked connections can survive until expiration; no conntrack flush is run.

Multiple TVs have dynamic addresses. `IoT Synology DLNA access` permits all
IoT `192.168.30.0/24` sources to initiate connections to Synology `192.168.40.5`
before the IoT-to-Cloud drop, with all IP protocols/ports as requested for L3
policy. This includes other NAS services. Other Home/Cloud destinations remain
blocked for IoT initiation; established/related replies continue working.
File09 adopts the former TV-only rule in place. No TV source-IP list is needed.
SSDP/mDNS configuration stays unchanged; discovery and media access are distinct.

Upload and re-import file07 followed by file09. Verify Home and Cloud connections
to IoT succeed and fresh IoT-to-Home/Cloud connections fail except the authorized NAS path. No live tests were run.
This section supersedes earlier HA-specific and IoT-to-NAS policy descriptions.

Superseded firewall rules are removed by exact managed comment/action/chain,
rather than kept as disabled entries. `IoT NAS access` is replaced by active
`IoT Synology DLNA access`; `NAS IoT access` and the former HA rules are replaced
by active `Home Cloud to IoT access`. No blanket disabled-rule deletion is used.

## Native SSDP PIM-SM

Operator confirmed discovery and playback on 2026-10-11 after correcting conflicting
unset/assignment syntax in file18. The agent did not perform live checks.
[PIM configuration and checks](ssdp-pim.md); [container removal](ssdp-container-removal.md).

File18 now permits all routed IPv4 multicast between VLAN100/300/400 in all
six directions without group, protocol, port or source-address restrictions.
TTL=1 multicast is raised to2 for one hop; IGMP membership still controls delivery.
Native mDNS is independent; local224.0.0.0/24 and IPv6 are not routed by this change.
The broadening requested2026-10-12 is prepared, not deployed or validated.
File09 preserves optional broad rule ordering. Existing unicast isolation and
SSDP reply exceptions remain. See the PIM runbook for operator import and recovery.

## Samsung DLNA compatibility

File19 applies the confirmed SSDP source-NAT workaround with static Wi-Fi/Ethernet
IoT leases and SSDP-SUBNET-CLIENTS. Core07/08/10 own the same persistent objects.
Use19 for the existing router to avoid reapplying unrelated DHCP settings.
See [PIM runbook](ssdp-pim.md) for evidence, destination-port limitation and checks.

## Router-local Pi-hole

This package configures a fresh Pi-hole container on the router. RouterOS
remains the DHCP-advertised resolver and local DNS authority.

### Configuration

| File | Configuration |
| --- | --- |
| `20-pihole-network.rsc` | `bridge-pihole`, `veth-pihole`, gateway, `PIHOLE-UPSTREAMS`, local-network classification, scoped DNS rules and disabled gateway DNAT |
| `21-pihole-container.rsc` | `pihole`, `pihole-env`, `pihole-data` mount; pull upstream image once, reconcile settings on later imports |
| `23-pihole-tls.rsc` | Dedicated NAS-only SSH delivery user, renewal script and HTTPS verification access |
| `20-pihole-prepare-dns.rsc` | Independent RouterOS upstream `1.1.1.1`, no DoH, no WAN peer DNS |
| `22-pihole-dns.rsc` | Readiness-gated gateway DNAT activation; DHCP unchanged |
| `08-firewall-nat.rsc` | Preserve optional DNS DNAT ordering and enabled state on core re-import |
| `09-firewall-filter.rsc` | Preserve optional Pi-hole rules before default deny on core re-import |
| `14-static-dns.rsc` | `pihole.home.antonu.org` A record `172.31.254.2` |
| `10-dhcp.rsc` | Existing router `.1` DNS address in each VLAN; unchanged |

The isolated container subnet is `172.31.254.0/30`: router `.1`, Pi-hole `.2`.
It is separate from Tailscale and the VLAN bridge; no physical ports or
LAN/REMOTE membership. Verify no LAN/WAN/VPN route overlaps before importing.
DHCP keeps advertising the per-VLAN router address. File22 enables UDP/TCP53
DNAT from Home100, Guest200, IoT300 and Cloud400 to `172.31.254.2`:

```text
192.168.100.50 → 192.168.100.1:53
192.168.100.50 → 172.31.254.2:53  (DNAT)
```

The source address stays intact. Pi-hole returns through `172.31.254.1` and
connection tracking reverses DNAT; the client sees its original router resolver.
No internal SNAT is needed. Pi-hole rate limiting is 1000 queries per 60 seconds
per source IP. Loopback health checks and router-originated queries still appear
as localhost or the router; Cilium node-SNAT can aggregate Kubernetes Pod clients.

Pi-hole resolves public names through `1.1.1.1`. RouterOS also uses `1.1.1.1`,
independently of Pi-hole, and retains file14 infrastructure records. Pi-hole
conditionally forwards `home.antonu.org` and local PTR zones to RouterOS at
`172.31.254.1`; ExternalDNS continues managing application records on RouterOS.
RouterOS never forwards back to Pi-hole. Its transit address is outside the DNAT
matches, preventing conditional-forwarding loops. Application record ownership and storage stay on RouterOS.

| Path | Protocol / port | Policy |
| --- | --- | --- |
| Home/Guest/IoT/Cloud → own VLAN gateway | UDP/TCP53 | DNAT to Pi-hole, source preserved |
| Home/Guest/IoT/Cloud → Pi-hole | UDP/TCP53 forward | Scoped interface and source subnet |
| Home → Pi-hole | TCP80/443 | Administration |
| Pi-hole → `172.31.254.1` | UDP/TCP53 input | Infrastructure and reverse DNS |
| Pi-hole → `1.1.1.1` via WAN | UDP/TCP53 forward | Public upstream |
| Pi-hole → WAN outside LOCAL-NETWORKS | TCP80/443 forward | Blocklist/image-related HTTPS downloads |

Existing WAN masquerade covers container Internet egress. Administration remains
blocked from Guest/IoT and other Cloud sources; NAS TLS verification retains its
existing exception. DNAT does not intercept public DNS destinations, DoH, IPv6,
Management or VPN traffic. Those paths retain their existing policy. Traffic from
router applications bypasses DNAT and uses RouterOS DNS. No automatic fallback
changes client blocking when Pi-hole fails.

File21 pulls the upstream `pihole/pihole:2026.09.0` image directly from Docker
Hub using `remote-image`. RouterOS selects ARM64 for this router. On first
installation, file21 sets the shared container registry to
`https://registry-1.docker.io` and extraction directory to
`flash/containers/pihole-tmp`. Later pulls for other containers use these
shared settings too. Re-importing file21 preserves the installed image and data;
it does not repull or upgrade the container.

Storage uses built-in flash:
`flash/containers/pihole` is disposable image root;
`flash/volumes/pihole` persists `/etc/pihole` databases/configuration.
If the router exposes a `flash` directory, file21 stores files beneath it; otherwise it uses
`containers/pihole`, `volumes/pihole` and `containers/pihole-tmp` in the persistent root.
Check the filesystem paths before upload.
No `/etc/dnsmasq.d` mount is needed for fresh Pi-hole v6.
The container has a 256MiB soft and 384MiB hard memory limit; inspect combined
usage with other containers before acceptance. On-disk query history is disabled
(`FTLCONF_database_maxDBdays=0`) and dnsmasq text logs go to `/dev/null` to reduce
flash writes. Recent in-memory query reporting remains available while running;
query history does not survive a restart. Gravity/configuration still persist.
The admin password persists in Pi-hole configuration; no password is
stored in Git or managed environment. Logging is off to keep generated secrets
out of RouterOS logs. Protect private backups of the persistent Pi-hole data directory.

Pi-hole uses the RouterOS host clock. Its NTP client and IPv4/IPv6 NTP servers
are disabled through `FTLCONF_ntp_sync_active`, `FTLCONF_ntp_ipv4_active` and
`FTLCONF_ntp_ipv6_active`. No container UDP123 access is required. A synchronized host clock is a
prerequisite; RouterOS configuration belongs to [System time](#system-time).

### Preflight (read-only)

Retain a current export and encrypted router backup privately. Use local Home
access to `192.168.100.1`. Check the prerequisites:

```routeros
/system resource print
/system clock print
/system ntp client print
/system package print
/system device-mode print
/file print detail where name="flash"
/ip address print
/ip route print detail
/interface list member print
/ip firewall filter print stats where comment~"default deny"
/ip firewall filter print detail where chain="output"
/ip firewall nat print detail
/ip dns print
/ip dhcp-client print detail
/ipv6 dhcp-client print detail
```

Require ARM64, installed container package, enabled container device mode,
existing WAN masquerade and core established/default-deny rules. Read internal
`free-hdd-space` from `/system resource print`; account for Tailscale, PXE and
other existing files. File21 requires at least 64MiB free on every import and
256MiB free before the initial pull. The initial threshold is a conservative
minimum, not a measured peak: downloading, extraction and gravity updates
need additional headroom according to the image and blocklist sizes. Check free
space after extraction and retain at least 64MiB. Stop if the download or
extraction fails; do not switch DNS until the container passes verification.
No existing files or containers are deleted automatically.
Do not format storage as part of this deployment.
If container mode/package is missing, stop: enabling mode requires physical
confirmation and package installation can require maintenance. Those changes
are prerequisites, not automatically included here.

Verify the container subnet is unused, including broader covering routes.
Review raw/mangle/output policy and any existing published DNS/HTTP rules;
these imports do not reconcile unrelated rules. WAN peer DNS must come from
`sfp-sfpplus1` only; file22 rejects other enabled DHCP peer-DNS sources.
Resolve any other DNS sources (including VPN/PPP) in their declarative owner
before cutover; dynamic DNS must not leave a bypass resolver. This IPv4 configuration leaves IPv6 RDNSS/DHCPv6 unchanged. Check that clients
do not receive an alternate IPv6 resolver that bypasses Pi-hole.

Review files09,14,20,21,22 and their diff before upload. They are scoped
reconciliation, not transactional imports. File14's Pi-hole A record changes
the Pi-hole frontend address.

### Upload configuration

Upload files09,14,20,21,22 and `20-pihole-prepare-dns.rsc` to RouterOS.
The router downloads the official image directly; no local Docker build,
image export or image upload is required.

Before file21, verify that the router resolves Docker Hub and can reach its
registry, authentication endpoint and image-layer download endpoints over
HTTPS. Check `/container/config print` privately: registry credentials and
other container settings are shared. Finish any in-progress container pulls
before importing file21.

### Import and start (live changes)

Preparing RouterOS upstream temporarily restores unfiltered gateway DNS until
DNAT is enabled. Reapplying file21 stops Pi-hole; active DNAT clients lose DNS
during that restart. Use a maintenance window or disable gateway DNAT first
using the rollback commands below.
Preparation does not activate or disable existing DNAT rules.

Import after the core configuration. On RouterOS7.24.4, dry-run each import
before applying it; stop on the first error. Dry-run is a syntax check,
not proof that package properties or runtime networking work.
If reapplying, stop only `pihole` and wait for the `S` (STOPPED) flag before file21.
File21 preserves data and refuses an unexpected interface, root or mount. Runtime errors include
the failing stage. File21 checks native `stopped`, `running` and `healthy` flags.
Other states block reconciliation. File22 gates cutover on successful Pi-hole
DNS resolution rather than container flags. Inspect state with:

```routeros
/container print detail where name="pihole"
```


```routeros
/import file-name=09-firewall-filter.rsc verbose=yes dry-run
/import file-name=09-firewall-filter.rsc
/import file-name=20-pihole-network.rsc verbose=yes dry-run
/import file-name=20-pihole-network.rsc
/import file-name=20-pihole-prepare-dns.rsc verbose=yes dry-run
/import file-name=20-pihole-prepare-dns.rsc
## For an existing container: stop and wait for the S flag before file21.
/container stop [find where name="pihole"]
/container print detail where name="pihole"
/import file-name=21-pihole-container.rsc verbose=yes dry-run
/import file-name=21-pihole-container.rsc
/container print detail where name="pihole"
```

Wait until the download and extraction complete and the `S` (STOPPED) flag is present, then:

```routeros
/container start [find where name="pihole"]
/container print detail where name="pihole"
/container shell [find where name="pihole"]
```

Inside the container, verify effective settings. Set the admin password only on
first installation or for deliberate rotation:

```sh
pihole status
pihole setpassword
printenv FTLCONF_dns_upstreams FTLCONF_dns_listeningMode
pihole-FTL --config dns.upstreams
pihole-FTL --config dns.listeningMode
pihole-FTL --config dns.revServers
```

Expected environment values are `1.1.1.1` and `ALL`. Effective
upstreams must contain only `1.1.1.1`, with listening mode `ALL`.
File21 attaches `pihole-env` through `envlists` and enables each managed entry.
Environment changes take effect on the next container start. If effective
upstreams remain Google defaults, or environment values are missing, stop
before DNS cutover and check the environment-list attachment.
Check the admin UI at
`http://172.31.254.2/admin/` from Home100 and confirm gravity loaded a non-empty
blocklist, blocking enabled and no startup errors. HTTP redirects to HTTPS. The initial
certificate is self-signed; install the wildcard certificate as described in
[TLS and renewal](pihole-tls/README.md). Use `pihole.home.antonu.org` for trusted HTTPS.

### Verification and DNAT cutover

From a Home computer, before file22:

```sh
dig @172.31.254.2 example.com A
dig +tcp @172.31.254.2 example.com A
dig @172.31.254.2 doubleclick.net A
```

Require successful UDP and TCP recursion and a Pi-hole-blocked query visible
in its query log (choose a domain actually present in the installed blocklist
if that example is not listed). A running container alone is insufficient.
On RouterOS also check `:put [:resolve "example.com" server=172.31.254.2]`.
An error stops deployment before upstream DNS changes. Confirm router output
is allowed and input established replies are accepted.

Before file22, verify UDP/TCP public and local answers directly from Pi-hole:

```sh
dig @172.31.254.2 pulsar.home.antonu.org A
dig +tcp @172.31.254.2 k8s.home.antonu.org A
dig @172.31.254.2 pihole.home.antonu.org A
```

Require `.40.5`, `.40.20` and `.254.2` respectively. Inspect effective
`dns.revServers` inside Pi-hole if these fail. File22 requires the independent
RouterOS upstream and successful public, NAS and API VIP DNS probes before
enabling the eight gateway DNAT rules. Initial file20 imports leave them disabled;
repeat imports preserve their enabled state. Imports are not transactional.

After these checks pass, apply the DNS configuration:

```routeros
/import file-name=14-static-dns.rsc verbose=yes dry-run
/import file-name=14-static-dns.rsc
/import file-name=22-pihole-dns.rsc verbose=yes dry-run
/import file-name=22-pihole-dns.rsc
/ip dns print
```

Test UDP/TCP public, blocked and infrastructure names through each client VLAN's
usual router resolver. Pi-hole must show the originating client IP, not
`172.31.254.1`. Compare NAT/filter counters and confirm Guest/IoT admin access
remains denied. Existing tracked DNS connections keep their previous translation
until they expire; use fresh queries/connections rather than flushing the entire
connection table. DHCP leases, reservations, DNS option and PXE fields do not change.

Application DNS stays under ExternalDNS ownership on RouterOS. Verify an existing
HTTPRoute hostname through Pi-hole and through the VLAN gateway resolver; both
must return the RouterOS-managed A record. No provider, API credential or
Kubernetes policy change is required.

### Rollback and maintenance (live changes)

To restore unfiltered router DNS while preserving local records, probe the
public upstream before disabling the eight owned gateway DNAT rules:

```routeros
## One import block keeps local variables in scope across commands.
:do {
    # DNS rollback: unfiltered public DNS, independent of NAS.
    :local wan [/ip dhcp-client find where interface="sfp-sfpplus1"]
    :if ([:len $wan] > 1) do={ :error "Duplicate WAN DHCP clients" }
    :foreach identity in={"Pi-hole Home gateway DNS UDP";"Pi-hole Home gateway DNS TCP";"Pi-hole Guest gateway DNS UDP";"Pi-hole Guest gateway DNS TCP";"Pi-hole IoT gateway DNS UDP";"Pi-hole IoT gateway DNS TCP";"Pi-hole Cloud gateway DNS UDP";"Pi-hole Cloud gateway DNS TCP"} do={
        :if ([:len [/ip firewall nat find where comment=$identity]] > 1) do={ :error "Duplicate DNS NAT identity" }
    }
    :do {
        :local answer [:resolve "example.com" server=1.1.1.1]
        :if ([:len [:tostr $answer]] = 0) do={ :error "Empty public DNS answer" }
    } on-error={ :error "Public DNS probe failed; DNS settings unchanged" }
    :if ([:len $wan] = 1) do={ /ip dhcp-client set $wan use-peer-dns=no }
    /ip dns set servers=1.1.1.1 use-doh-server="" allow-remote-requests=yes
    # Stop gateway interception; DHCP still advertises the same router addresses.
    :foreach identity in={"Pi-hole Home gateway DNS UDP";"Pi-hole Home gateway DNS TCP";"Pi-hole Guest gateway DNS UDP";"Pi-hole Guest gateway DNS TCP";"Pi-hole IoT gateway DNS UDP";"Pi-hole IoT gateway DNS TCP";"Pi-hole Cloud gateway DNS UDP";"Pi-hole Cloud gateway DNS TCP"} do={
        :local row [/ip firewall nat find where comment=$identity]
        :if ([:len $row] > 1) do={ :error "Duplicate DNS NAT identity" }
        :if ([:len $row] = 1) do={ /ip firewall nat disable $row }
    }
    /ip dns cache flush
}
/ip dns print
```

Existing tracked DNS flows may still target Pi-hole until they expire. Verify
fresh UDP/TCP public and local DNS through the router before stopping Pi-hole.
Then, if required:

```routeros
/container set [find where name="pihole"] start-on-boot=no
/container stop [find where name="pihole"]
```

Preserve flash data, mount, bridge and firewall objects for recovery; no deletion
or formatting is needed. The Pi-hole static frontend record can remain while
stopped. File22 re-enables gateway DNAT on import, so don't re-import
it during rollback. File21 restores start-on-boot on import.
For an image upgrade, pin/review the new release in source and use a separately
reviewed container replacement procedure with a private `/etc/pihole` backup;
file21 deliberately does not remove/recreate containers or wipe persistent data.

### TLS

[TLS and renewal](pihole-tls/README.md) integrates the existing Synology `~/.acme.sh` ECC
wildcard certificate with Pi-hole. File21 sets `80r,443s` and the persistent
`/etc/pihole/tls.pem` bundle.

### References and validation limits

- [MikroTik container guide](https://help.mikrotik.com/docs/spaces/ROS/pages/84901929/Container)
- [RouterOS DNS](https://help.mikrotik.com/docs/spaces/ROS/pages/37748767/DNS)
- [Pi-hole Docker configuration](https://docs.pi-hole.net/docker/)
- [Pi-hole query database and log settings](https://docs.pi-hole.net/ftldns/configfile/)
- [Pi-hole environment settings](https://docs.pi-hole.net/docker/configuration/)
- [Pinned release](https://github.com/pi-hole/docker-pi-hole/releases/tag/2026.09.0)

DNS and TLS operation were confirmed on 2026-10-12 before this topology change.
DNAT and conditional forwarding require live acceptance; offline checks do
not validate RouterOS runtime syntax, packet flow or effective conditional forwarding.

## System time

`24-system-time.rsc` owns the RouterOS NTP client and timezone. It uses Cloudflare
anycast addresses `162.159.200.1` and `162.159.200.123` without a startup DNS
dependency, in the main VRF, and sets `Europe/Berlin` with autodetection disabled.
Containers share the host clock; Pi-hole NTP client/server remains disabled.
No NTP server, DHCP configuration or container firewall grant is added.
Router-originated UDP123 must reach these endpoints; established input rules
accept replies. Existing custom output policy must permit that path.

### Deployment and verification

Upload file24, review the diff and syntax-check before importing:

```routeros
/import file-name=24-system-time.rsc verbose=yes dry-run
/import file-name=24-system-time.rsc
/system ntp client print
/system clock print
```

Require `enabled: yes`, `status: synchronized` and the expected local time.
On 2026-10-12, Europe/Berlin uses UTC+02:00 and DST is active. Timezone changes
presentation; NTP corrects the underlying clock. Synchronization need not be
instantaneous. If it stays waiting, inspect the route, UDP123 output policy and
established reply traffic. Do not enable container NTP as a workaround.

### Rollback

Retain the prior clock/NTP settings privately before import. To restore the
2026-10-12 reported state (NTP disabled, no servers, autodetection enabled):

```routeros
/system ntp client set enabled=no servers=""
/system clock set time-zone-autodetect=yes time-zone-name=manual
```

Rollback stops synchronization; it does not rewind the corrected system time.
Live import and synchronization remain unverified.

- [RouterOS NTP](https://help.mikrotik.com/docs/spaces/ROS/pages/40992869/NTP)
- [Cloudflare time service](https://developers.cloudflare.com/time-services/ntp/usage/)
