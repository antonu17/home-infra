# Home Tailscale on RB5009

Prepared configuration, not deployed or tested on the router. Synology Tailscale
was shut down by the operator on 2026-10-11; no parallel migration is required.
The desired subnet router advertises:

- `10.40.0.0/24` — Kubernetes services
- `192.168.40.0/24` — Home Cloud VLAN
- `192.168.100.0/24` — Home VLAN

Exit-node advertising is enabled in the desired configuration. No Guest, IoT or infrastructure-management
subnet is advertised. Tailnet route approval and access policy remain operator-owned.

## Design and ownership

`16-tailscale-network.rsc` owns an isolated bridge, VETH, gateway, three address-list
entries and five firewall rules. `17-tailscale-container.rsc` owns the container
and persistent state mount. File09 preserves their position before default deny
when later re-imported; it does not create them. Names/comments identify objects
for add-or-update reconciliation. Duplicate identities and unexpected scope stop
imports. Re-importing preserves identity and does not replace the container image.
File16 adopts a single previous services `/25` entry as `/24` in place; if both
exist, it stops for review. Reconcile Tailscale preferences with the command below
and approve the new `/24` route in the admin console.
Stop this container before reapplying files16/17; imports are not transactional.

Proposed new transit allocation (must be confirmed unused before import):

| Object | Address / attachment |
| --- | --- |
| `bridge-tailscale` | `172.31.255.1/30` |
| `veth-tailscale` | `172.31.255.2/30`, gateway `.1` |
| `tailscale-home` | VETH only; no physical ports |
| `TAILSCALE-SUBNETS` | The exact three advertised networks above |

The bridge is separate from the VLAN-aware LAN bridge and is not a member of
LAN/REMOTE lists. Kernel-mode Tailscale handles all IP protocols, including ICMP,
SMB and storage traffic. Its subnet-route SNAT makes authenticated client traffic
arrive at RouterOS from `172.31.255.2`; the firewall allows that source to the three
advertised networks and their router addresses. Tailnet grants/ACLs must restrict
who can use these routes: RouterOS cannot distinguish clients after this SNAT.
No internal RouterOS NAT or `100.64.0.0/10` return route is needed.

The container can use the router transit address for UDP/TCP DNS and reach WAN.
Existing WAN masquerading covers its Internet traffic. No new WAN port-forward,
BGP, DHCP, DNS-record, Cilium or Synology configuration is introduced. The LAN-to-WAN FastTrack rule excludes this transit bridge because it is not in
LAN. Tailscale subnet and exit-node traffic retains normal RouterOS processing. No broad Cloud-to-router access is added.

The image uses `ghcr.io/tailscale/tailscale:v1.102.5`, locked to its published
Linux/ARM64 digest, and a small daemon wrapper. The ARM64 digest was verified in
[the official package listing](https://github.com/tailscale/tailscale/pkgs/container/tailscale/1293199828?tag=v1.102.5).
A GitHub source release does not establish that the matching container tag exists;
the originally selected Docker Hub `v1.104.1` tag failed to resolve.
Persistent state lives in `flash/containers/tailscale-state` on this router; extraction
uses `flash/containers/tailscale-home`. State contains credentials: keep it out of Git
and preserve it when replacing an image. Internal flash is used as requested.

## 1. Read-only preflight

Use local Home access to `192.168.100.1`, not this new VPN path. Save an export and
backup privately using your existing backup procedure. Check these on RouterOS:

```routeros
/system resource print
/system package print
/system device-mode print
/ip address print
/ip route print detail
/interface print
/ip firewall nat print detail
/ip firewall filter print stats where comment~"default deny"
/ip dns print
/file print detail where name="flash"
```

Confirm container package/device mode (previously confirmed for SSDP), DNS remote
requests enabled, existing WAN masquerading, both terminal deny rules, and at least
256MiB free before extraction. Check all LAN, WAN, VPN and tailnet routes: the
proposed `172.31.255.0/30` must not overlap another network. If it overlaps, change
its addresses consistently in files16/17 and this runbook before importing.

Kernel operation requires `/dev/net/tun` and networking privileges. File17 requests
`privileged=yes` and root. Do not accept a userspace fallback as equivalent to a
full subnet router. RouterOS 7.24.4 is the actual target; current online CLI docs
are newer. Dry-run verifies syntax on the installed version, but does not prove
TUN or runtime networking works. Stop at any failed acceptance check below.

## 2. Build and upload (operator-run local changes)

Run from the repository root, after confirming your Docker builder is local.
No registry push is needed. The Docker exporter produces a single ARM64 Docker
archive, avoiding an OCI image index that RouterOS may reject.

```sh
mkdir -p .private/tailscale
docker buildx build --platform linux/arm64 --provenance=false --sbom=false \
  --output type=docker,dest=.private/tailscale/tailscale-home.tar \
  -t home-infra/tailscale-home:1.102.5 \
  network/mikrotik-rb5009upr/tailscale &&
tar -tf .private/tailscale/tailscale-home.tar
```

The archive must contain `manifest.json`, with a referenced image configuration
and layers. Upload it manually to `flash/tailscale-home.tar`, and upload revised
files09,16,17 to the router. Do not put archives or identity backups in Git.
No build was run by the agent.

## 3. Prepare RouterOS (operator-run changes)

In Safe Mode, dry-run before each actual import. This adds isolated objects; it
does not rearrange physical LAN ports. If updating an existing instance, stop
`tailscale-home` first and wait until stopped. Do not stop the SSDP container.

```routeros
/import file-name=09-firewall-filter.rsc verbose=yes dry-run
/import file-name=09-firewall-filter.rsc
/import file-name=16-tailscale-network.rsc verbose=yes dry-run
/import file-name=16-tailscale-network.rsc
/import file-name=17-tailscale-container.rsc verbose=yes dry-run
/import file-name=17-tailscale-container.rsc
/container print detail where name="tailscale-home"
/interface veth print detail where name="veth-tailscale"
/ip firewall filter print detail where comment~"^Tailscale "
```

Wait for extraction to finish without failure. Confirm Linux/ARM64 image metadata,
state mount, transit addresses, and all five rules before their respective terminal
deny. File09 also reconciles its existing rules, so review its diff before import.
Once satisfied, exit Safe Mode to retain these changes, then start only this container:

```routeros
/container start [find where name="tailscale-home"]
/container shell [find where name="tailscale-home"]
```

Inside the container, read-only checks:

```sh
ls -l /dev/net/tun
ip -4 addr
ip -4 route
cat /proc/sys/net/ipv4/ip_forward
tailscale version
```

Expect TUN, transit `.2/30`, default route through `.1` and forwarding `1`.
If it stops immediately, inspect its startup output locally; missing TUN or failed
sysctls are blockers, not reasons to switch to a partial proxy. Logging defaults
to off to avoid leaving authentication URLs in the router log.

## 4. Authenticate and approve routes (operator-run changes)

Inside the container:

```sh
tailscale up --hostname=home-rb5009 --accept-dns=false --accept-routes=false \
  --advertise-routes=10.40.0.0/24,192.168.40.0/24,192.168.100.0/24 \
  --snat-subnet-routes=true --advertise-exit-node=true
```

Open the displayed login URL privately and authenticate with your existing tailnet.
No auth key is embedded in the repository. In the Tailscale admin console, approve
exactly the three routes on `home-rb5009` and review existing grants/ACLs for intended
users. Existing Synology approvals do not automatically approve the replacement.
Review node key expiry for this unattended router using your normal tailnet policy.

Preferences persist in the state mount. For repeatable reconciliation after login,
run inside the container:

```sh
sh /usr/local/bin/configure-tailscale
```

This restores the three routes, enables exit-node advertising, and disables DNS
acceptance and route acceptance. It does not log out or create a new identity. The daemon
reuses its persisted preferences on boot; no startup authentication is required.
Keep existing tailnet DNS settings initially. If the tailnet uses a home resolver,
verify its address is reachable through one of the advertised routes. Container
`--accept-dns=false` prevents rewriting its underlay resolver configuration.

## 5. Acceptance checks

Inside the container:

```sh
tailscale status
tailscale netcheck
ip -4 addr show tailscale0
```

From an authorized client on cellular/external Wi-Fi with Tailscale enabled, test
router Home address `192.168.100.1`, NAS `192.168.40.5` and a Gateway service such
as `ha.home.antonu.org` (`10.40.0.10`). Check DNS and a real service connection,
not only ping. Verify an unauthorized tailnet client cannot use the routes.
Do not publish status output containing private device/user details.

On RouterOS, inspect traffic counters while testing:

```routeros
/ip firewall filter print stats where comment~"^Tailscale "
/container print detail where name="tailscale-home"
```

Then repeat the iPhone Home-Wi-Fi test with Tailscale enabled and disabled.
The earlier delay disappeared when the iPhone disabled Tailscale; its precise
cause was not established. Moving the subnet router does not prove the delay is
fixed. Check whether the client uses a direct or relayed connection, its selected
exit node and tailnet DNS settings if latency remains. Verify identity and routes
survive a later planned container restart; no router reboot is required for setup.

## Exit-node approval and acceptance

Exit-node advertising is enabled by both initial login and the checked-in
reconciliation script. In the admin console, approve exit-node use on
`home-rb5009` as well as its three subnet routes. Review tailnet permissions,
select this exit node on a test client, and test Internet, DNS and home services.
Advertising does not automatically select it on clients.

Verify both IPv4 and IPv6 Internet connectivity. The prepared transit has IPv4
only; IPv6 exit connectivity is not established by this configuration and remains
an acceptance gap. Advertising alone does not supply IPv6 Internet connectivity.
The container-WAN rule and existing WAN masquerade support IPv4 exit traffic.
Measure throughput and router CPU/memory; no performance guarantee is made.

If already authenticated with exit advertising disabled, run inside the container:

```sh
tailscale set --advertise-exit-node=true
```

No rebuild is needed for that live preference change. Rebuild the image later to
include the updated reconciliation script. To temporarily withdraw advertising,
use `tailscale set --advertise-exit-node=false`; the reconciliation script restores
it to true. Clients must stop selecting this exit node before disabling it.

## Rollback and image replacement

Operator-run rollback disables only this new container and its rules:

```routeros
/container set [find where name="tailscale-home"] start-on-boot=no
/container stop [find where name="tailscale-home"]
/ip firewall filter disable [find where comment="Tailscale transit DNS UDP"]
/ip firewall filter disable [find where comment="Tailscale transit DNS TCP"]
/ip firewall filter disable [find where comment="Tailscale advertised router access"]
/ip firewall filter disable [find where comment="Tailscale advertised subnet access"]
/ip firewall filter disable [find where comment="Tailscale container Internet"]
```

Re-enable Synology's existing Tailscale service manually if needed; its installation
method is not documented here. Preserve `tailscale-state` and the mounted state
files. Do not delete identity or remove the tailnet device to troubleshoot routing.
Re-importing files16/17 enables their managed objects again. For image upgrades,
stop the container, privately back up persistent state, and explicitly replace
only its disposable image/root while retaining the same state mount; file17 does
not perform destructive image replacement on re-import.

## References and validation limits

- [Tailscale kernel and userspace routing](https://tailscale.com/docs/reference/kernel-vs-userspace-routers)
- [Container parameters and state](https://tailscale.com/docs/features/containers/docker/docker-params)
- [Subnet routers and route approvals](https://tailscale.com/docs/features/subnet-routers)
- [Exit nodes](https://tailscale.com/docs/features/exit-nodes)
- [RouterOS container documentation](https://help.mikrotik.com/docs/spaces/ROS/pages/84901929/Container)
- [Current RouterOS container CLI reference](https://manual.mikrotik.com/docs/cli-reference/container/)

Local review covers shell syntax, object identity, route scope and firewall ordering.
No image build, RouterOS parser execution, container startup, route approval or
live connectivity test was performed by the agent.
