# Fresh Pi-hole on RB5009

This package configures a fresh Pi-hole container on the router. RouterOS
remains the DHCP-advertised resolver and local DNS authority.

## Configuration

| File | Configuration |
| --- | --- |
| `20-pihole-network.rsc` | `bridge-pihole`, `veth-pihole`, gateway, `PIHOLE-UPSTREAMS`, local-network classification, scoped DNS rules and disabled gateway DNAT |
| `21-pihole-container.rsc` | `pihole`, `pihole-env`, `pihole-data` mount; pull upstream image once, reconcile settings on later imports |
| `23-pihole-tls.rsc` | Dedicated NAS-only SSH delivery user, renewal script and HTTPS verification access |
| `pihole/prepare-dns.rsc` | Independent RouterOS upstream `1.1.1.1`, no DoH, no WAN peer DNS |
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
`FTLCONF_ntp_ipv6_active`. No container UDP123 access is required. RouterOS NTP
configuration is outside this package; verify its synchronization and system
time before relying on DNSSEC or certificate validity.

## Preflight (read-only)

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

## Upload configuration

Upload files09,14,20,21,22 and both `pihole/prepare-dns.rsc` and
`pihole/rollback-dns.rsc` to RouterOS as `prepare-dns.rsc` and `rollback-dns.rsc`.
The router downloads the official image directly; no local Docker build,
image export or image upload is required.

Before file21, verify that the router resolves Docker Hub and can reach its
registry, authentication endpoint and image-layer download endpoints over
HTTPS. Check `/container/config print` privately: registry credentials and
other container settings are shared. Finish any in-progress container pulls
before importing file21.

## Import and start (live changes)

Preparing RouterOS upstream temporarily restores unfiltered gateway DNS until
DNAT is enabled. Reapplying file21 stops Pi-hole; active DNAT clients lose DNS
during that restart. Use a maintenance window or run rollback-dns.rsc first.
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
/import file-name=prepare-dns.rsc verbose=yes dry-run
/import file-name=prepare-dns.rsc
# For an existing container: stop and wait for the S flag before file21.
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
[TLS and renewal](tls.md). Use `pihole.home.antonu.org` for trusted HTTPS.

## Verification and DNAT cutover

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

## Rollback and maintenance (live changes)

For immediate DNS rollback independent of Synology, upload and import the
reviewed `pihole/rollback-dns.rsc`. It first probes public DNS, disables the eight
gateway DNAT rules and WAN peer DNS, then explicitly selects `1.1.1.1` with no DoH. This restores
unfiltered recursion while preserving local RouterOS records:

```routeros
/import file-name=rollback-dns.rsc verbose=yes dry-run
/import file-name=rollback-dns.rsc
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

## TLS

[TLS and renewal](tls.md) integrates the existing Synology `~/.acme.sh` ECC
wildcard certificate with Pi-hole. File21 sets `80r,443s` and the persistent
`/etc/pihole/tls.pem` bundle.

## References and validation limits

- [MikroTik container guide](https://help.mikrotik.com/docs/spaces/ROS/pages/84901929/Container)
- [RouterOS DNS](https://help.mikrotik.com/docs/spaces/ROS/pages/37748767/DNS)
- [Pi-hole Docker configuration](https://docs.pi-hole.net/docker/)
- [Pi-hole query database and log settings](https://docs.pi-hole.net/ftldns/configfile/)
- [Pi-hole environment settings](https://docs.pi-hole.net/docker/configuration/)
- [Pinned release](https://github.com/pi-hole/docker-pi-hole/releases/tag/2026.09.0)

DNS and TLS operation were confirmed on 2026-10-12 before this topology change.
DNAT and conditional forwarding require live acceptance; offline checks do
not validate RouterOS runtime syntax, packet flow or effective conditional forwarding.
