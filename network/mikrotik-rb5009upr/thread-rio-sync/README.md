# Thread RIO sync

Receives ICMPv6 RA on VLAN300 and reconciles ULA /64 routes in the RB5009 main
table. Router Lifetime is independent of RIO Route Lifetime. The allowlist in
sync.py maps the tado and HomePod addresses to distances 10 and 20 respectively.
Linux validates ICMPv6 checksums on the raw ICMPv6 socket.

## Build and run

Build an ARM64 image from this directory.

```sh
sh build.sh /tmp/thread-rio-sync.tar
```

Load the image via RouterOS Containers. Assign a dedicated VETH as an untagged
VLAN300 bridge port with PVID 300 and include it in the VLAN300 bridge VLAN
membership. The process needs IPv6 and CAP_NET_RAW. Set RIO_INTERFACE if its
container interface differs from veth-thread-rio. Start with RIO_APPLY unset and verify
that the log shows the prefix currently advertised by each border router.

## Enable reconciliation

Set ROS_URL to the RB5009 HTTPS origin, ROS_USER and ROS_PASSWORD to the
dedicated REST account, and RIO_APPLY=1. The container must trust the server
certificate. For a private CA, mount the CA bundle and set SSL_CERT_FILE.
Limit REST reachability to the container's source IP. RouterOS route writes
require the write policy, which grants more access than just IPv6 routes.
Run a single writer. Verify route installation and Matter connectivity before
removing any overlapping static routes with lower distance.

## Rollback

Stop the container and list its routes with
`/ipv6 route print detail where comment~"^thread-rio-sync/v1 "`.
Disable only the listed controller routes and restore any manual routes that
were retired. Existing manual routes have separate comments.

Leases use monotonic time. After restart, a 30-minute recovery window allows
border routers to renew advertisements. After that window, controller-owned
routes absent from current leases are deleted. This bounds stale routes after
a process restart for the observed 1800-second RIO lifetime. A missed or blocked
RA stream can therefore expire routes. Stopping the container leaves installed
routes until the service runs again. Only one writer may run.

## RouterOS deployment

The reconciler is ../26-thread-rio-container.rsc. It creates veth-thread-rio,
an access port on bridge with PVID 300, the container, observation-mode environment
and a source/destination-scoped HTTPS input rule. Dynamic PVID membership preserves
the existing static VLAN300 row, including across file04 imports.
The container runs privileged for its raw socket. This grants broad container
capabilities. The image uses the Python 3.13 Alpine tag and should be built and
retained as a versioned local archive.

### Preflight

Run on RB5009 and review privately.

```routeros
/system resource print
/system package print
/system device-mode print
/ip pool print detail
/ip dhcp-server lease print where address=192.168.30.9
/ip arp print where address=192.168.30.9
/interface bridge vlan print detail
/ip service print detail where name=www-ssl
```

The installer allocates 192.168.30.9/24 with gateway 192.168.30.1. Confirm this
address is unused and outside every DHCP pool before import. Empty ARP and lease
outputs alone do not prove it is unused. Adjust endpoint/source together in the
installer if needed. Existing www-ssl must have a valid certificate and its address
allowlist must admit the container. Keep existing service settings and management
access when extending that allowlist. Container package and device-mode must
already be enabled. The listener needs IPv6 link-local addressing inside veth-thread-rio.

### Build and upload

From the repository root, run locally.

```sh
sh network/mikrotik-rb5009upr/thread-rio-sync/build.sh /tmp/thread-rio-sync.tar
scp /tmp/thread-rio-sync.tar network/mikrotik-rb5009upr/26-thread-rio-container.rsc admin@192.168.100.1:
```

If RouterOS exposes a flash directory, move the two uploads there and use
flash/26-thread-rio-container.rsc below. The installer selects flash/ automatically
for the image and container root when that directory exists.

### Install and observe — live changes

```routeros
/import file-name=26-thread-rio-container.rsc verbose=yes dry-run
/import file-name=26-thread-rio-container.rsc
/container print
```

Wait for extraction to finish before starting.

```routeros
/container start [find where name="thread-rio-sync"]
/log print where topics~"container"
/interface bridge vlan print detail where bridge=bridge
```

Verify dynamic untagged membership includes veth-thread-rio in VLAN300.
Allow at least four minutes for RA. Logs must show current prefixes.
If the raw socket or IPv6 membership fails, stop here and inspect container
capabilities and veth-thread-rio IPv6 support.

### Credentials and HTTPS

Create a dedicated REST account through WinBox with a unique password, source
address restriction 192.168.30.9/32 and a group with read,write,api,rest-api policies.
These permissions include writes beyond routes. Store credentials only on the
router. In WinBox Containers → Envs, add ROS_URL, ROS_USER and ROS_PASSWORD to
thread-rio-env. Use an HTTPS hostname matching the router certificate. Configure
container DNS to resolve that hostname via an existing permitted resolver.

For a private CA, place its public PEM bundle on persistent router storage, create
a container mount list mapping that directory to /ca, attach it to this container,
and set SSL_CERT_FILE=/ca/router-ca.pem in thread-rio-env. The PEM bundle contains
public CA certificates only. Never mount the router certificate private key.
Avoid printing environment lists or exporting their values.

Stop the container before changing its environment or mounts. After credentials,
DNS and certificate trust are configured, enable writes and restart.

```routeros
/container stop [find where name="thread-rio-sync"]
```

Wait until stopped.

```routeros
/container envs set [find where list="thread-rio-env" and key="RIO_APPLY"] value=1
/container set [find where name="thread-rio-sync"] start-on-boot=yes
/container start [find where name="thread-rio-sync"]
/ipv6 route print detail where comment~"^thread-rio-sync/v1 "
```

Confirm current prefixes, scoped link-local gateways and distances 10/20.
Verify all Matter nodes reconnect. Existing manual distance-1 routes remain
preferred. Retire them individually only after accepting automated coverage.

### Update

Stop the container and wait for stopped state. Retain its environment and mounts.
Build and upload a new versioned archive. Remove only the stopped container record,
then create its replacement with the same interface, envlist, mountlists and runtime
settings, using a new versioned root-dir. Retain the old root and image until
acceptance. Repeat file26 imports preserve the installed image, versioned root directory, mounts, credentials, RIO_APPLY and boot policy. Image replacement uses the explicit update procedure.

### Rollback — live changes

Stop the container and disable boot startup.

```routeros
/container stop [find where name="thread-rio-sync"]
/container set [find where name="thread-rio-sync"] start-on-boot=no
/ipv6 route print detail where comment~"^thread-rio-sync/v1 "
```

Restore the required manual prefix routes before disabling controller routes.
After reviewing the selected objects, disable only controller-owned routes.

```routeros
/ipv6 route disable [find where comment~"^thread-rio-sync/v1 "]
/ip firewall filter disable [find where comment="Thread RIO HTTPS"]
/interface bridge port disable [find where interface="veth-thread-rio"]
```

Retain container root, environment and image for inspection. No disk deletion is
needed. Import is not transactional. After a partial failure, inspect and reconcile
the exact named objects before retrying.

The build normalizes exporter blobs into sequential legacy Docker archive layout.
Each uncompressed layer is checked against the image configuration diff_id.

## Confirmed runtime and source validation

On 2026-11-05 the RB5009 extracted a legacy Docker archive, started Python on
veth-thread-rio, received the tado RIO and created its fd97:72fc:f25f:1::/64 route
through HTTPS REST. The account required read,write,api,rest-api policies.
VLAN300 ULA restoration enabled successful ping replies from a Thread node.
Matter application recovery and HomePod operation remain unconfirmed.

Later source fixes (restart cleanup and route reconciliation) require a new build
and manual deployment. Validate with `python3 -m unittest discover -s
network/mikrotik-rb5009upr/thread-rio-sync -p 'test_*.py'` from repository root.

File26 normalizes RIO_INTERFACE to veth-thread-rio. For legacy duplicate
RIO_APPLY entries, any enabled value 1 preserves apply mode; otherwise observation
mode 0 is selected. To select observation explicitly, retain one enabled value 0.
Identical credential duplicates are collapsed; conflicting credential values stop
preflight without printing their values.

File26 owns the public REST settings ROS_URL=https://192.168.30.1,
ROS_USER=thread-rio and SSL_CERT_FILE=/ca/ca.crt. Existing public duplicates
are reconciled to these values. ROS_PASSWORD remains router-local; differing
password duplicates require selecting the valid password privately.
