# SSDP relay on RB5009 internal storage

Prepared 2026-10-10 for ARM64 RouterOS 7.24.4. The operator confirmed matching
container package installed, device-mode container=yes and chose internal storage.
No router change, container build or container execution was performed by the agent.

## Layout

One container `ssdp-relay`, three DHCP-enabled VETH access ports in the existing
bridge: `veth-ssdp-home` PVID 100, `veth-ssdp-iot` PVID 300, and
`veth-ssdp-cloud` PVID 400. Addresses come from the existing scopes; no static
address, new subnet, DHCP option or NAT is added.

The operator confirmed RouterOS exposes the original interfaces by their VETH
names inside the container. Source13 therefore explicitly starts the existing
relay program on all three named interfaces with `--wait` for DHCP. This works
with the already-installed image; the old two-subnet wrapper is bypassed.
The repository wrapper also recognizes all three networks for future builds.

The relay repeats only SSDP 239.255.255.250 UDP 1900 between Home, IoT and Cloud.
Discovery is mutual across these three VLANs, not filtered to the NAS alone.
Guest and VLAN1 are excluded. mDNS and Sonos-specific broadcasts are disabled
in this process; native RouterOS mDNS remains in `11-mdns.rsc`. Discovery does
not itself authorize connections to other advertised services.

Original source IPs are preserved. NAS unicast M-SEARCH responses use the normal
routed path to the searching client; the relay search does not establish that
connection in RouterOS. Source09 permits exact NAS source `192.168.40.5` from
CLOUD to HOME `192.168.100.0/24` and IOT `192.168.30.0/24`, as well as the
existing Home/IoT-to-NAS paths. In keeping with the requested L3 policy, both
NAS reverse allowances permit all protocols and unsolicited NAS connections,
not just SSDP replies. No other Cloud host receives this permission.
Synology and Aruba physical uplinks are unchanged. The relay is not configured
as a Linux bridge or IP router.

## Extend the existing working relay to Home

Operator confirmed TV discovery worked after importing the missing NAS/IoT
firewall rules on 2026-10-10. Mac/VLAN100 discovery was not covered by that
original two-interface deployment. This extension is prepared, not live-tested.

Upload updated `04-vlans.rsc`, `09-firewall-filter.rsc`, `12-ssdp-network.rsc`, and
`13-ssdp-container.rsc`. No image rebuild, upload, container deletion or directory
replacement is required. Save a private export/backup and the existing container
settings before proceeding. Stop only the relay before changing its interfaces;
SSDP discovery briefly pauses while ordinary routed connections continue.

Operator-run changes:

```routeros
/container stop [find where name="ssdp-relay"]
```

Confirm it is stopped with `/container print detail where name="ssdp-relay"`,
then import in order:

```routeros
/import 04-vlans.rsc
/import 09-firewall-filter.rsc
/import 12-ssdp-network.rsc
/import 13-ssdp-container.rsc
/container start [find where name="ssdp-relay"]
```

Read-only checks:

```routeros
/container print detail where name="ssdp-relay"
/interface veth print detail where name~"^veth-ssdp-"
/ip firewall filter print stats where comment="NAS Home access"
```

Expect three attachments, including a Home DHCP address in `192.168.100.0/24`.
In the container shell, `ps` must show all three names in the relay command and
`cat /proc/net/igmp` must show SSDP group `FAFFFFEF` on all three interfaces.
Quit/reopen VLC and select Universal Plug'n'Play under Local Network; confirm
Pulsar appears and test actual playback. Retest TV discovery too.
If both work, the extension is accepted; a running status alone is insufficient.

To revert this extension without deleting the image (operator-run):

```routeros
/container stop [find where name="ssdp-relay"]
/container set [find where name="ssdp-relay"] interface=veth-ssdp-iot,veth-ssdp-cloud entrypoint=python3,/app/multicast-relay.py cmd=--foreground,--wait,--noMDNS,--noSonosDiscovery,--noRemoteRelay,--interfaces,veth-ssdp-iot,veth-ssdp-cloud
/ip firewall filter disable [find where comment="NAS Home access"]
/interface bridge port disable [find where interface="veth-ssdp-home"]
/container start [find where name="ssdp-relay"]
```

Reapplying the new sources restores Home discovery; preserve the previous source
revision separately if reverting the desired configuration too.

Root filesystem: `containers/ssdp-relay`; archive: `ssdp-relay.tar`, both in internal storage.
If Files contains an existing `flash` directory, the script prefixes both paths
with `flash/`; upload the archive there instead. Do not create a `flash` directory
yourself. Confirm the persistent storage layout with `/file print where type="directory"`
before upload. `13-ssdp-container.rsc`
requires 128MiB free before extraction; monitor space after extraction too.
Logging is disabled and no writable persistent application volume is required.
Memory high/max are 32/64MiB. Reimports retain container identity/root filesystem;
they do not build, repull or replace an image. Image upgrades are separately
reviewed stop/remove/recreate operations on this exact container.

The Python base is pinned by digest; relay revision and GPL license are pinned
and SHA256-checked. netifaces 0.11.0 is hash-pinned and compiled in a build stage.
The upstream self-contained interface helper is legacy Python 2 code and is not
used. The build stage includes `linux-headers` for netifaces (`linux/tipc.h`); compiler
and kernel headers are excluded from the runtime stage. Build-stage Alpine compiler packages are resolved from the pinned base's
repositories, and pip resolves build-isolation tooling for netifaces. These build dependencies are not a byte-for-byte reproducibility guarantee.

The pinned netifaces release initializes a musl `msghdr` integer padding field
with `NULL`. Newer GCC treats this as an error. Its build alone uses
`CFLAGS="-Wno-error=int-conversion"` to retain the warning and compile the legacy
code; other compiler errors remain fatal. This setting is not a runtime variable.
See [GCC porting guidance](https://gcc.gnu.org/gcc-14/porting_to.html).

## Build locally, manually

Use a local Docker engine. Inspect `docker context inspect` privately and confirm
it is your local engine before issuing builds; never use a remote Docker context.
Commands below are operator-run. Build downloads public base/dependency/source
artifacts, but does not push to a registry or contact home infrastructure.

```sh
cd /Users/anton/projects/home-infra/network/mikrotik-rb5009upr/ssdp-relay
docker buildx build --platform linux/arm64 --provenance=false --sbom=false \
  -t home-infra/ssdp-relay:461d1c9 \
  --output type=docker,dest=ssdp-relay.tar .
# Continue only after the build succeeds.
python3 - <<'PYCHECK'
import json, tarfile
with tarfile.open('ssdp-relay.tar') as archive:
    manifest = json.load(archive.extractfile('manifest.json'))
    assert len(manifest) == 1, 'Expected one image'
    image = manifest[0]
    config = json.load(archive.extractfile(image['Config']))
    assert config['architecture'] == 'arm64' and config['os'] == 'linux'
    assert image['Layers'] and all(layer in archive.getnames() for layer in image['Layers'])
    assert config['config']['Entrypoint'] == ['python3', '/app/entrypoint.py']
print('Docker archive manifest, config, layers and ARM64 entrypoint verified')
PYCHECK
```

Export directly using the Docker image exporter; do not substitute the filesystem
`type=tar` exporter or `docker export`. This bypasses image-store archive format
variation. The archive check must pass before uploading. See
[Docker exporters](https://docs.docker.com/build/exporters/oci-docker/).

Expected architecture: arm64. Retain the produced archive checksum
privately. Upload the archive via WinBox as `ssdp-relay.tar` in Files (inside `flash/` if that existing directory is present). Build output
archives are ignored in this directory; they are not configuration source.
Do not run this relay container on the Mac host to test real interfaces.

## Manual import and first start

Privately save the router export/backup first. Preview `12-ssdp-network.rsc` and `13-ssdp-container.rsc` with RouterOS import
dry-run on the actual 7.24.4 installation. These are structurally reviewed but
not validated by a RouterOS parser or runtime here. Confirm the core VLAN table
and IoT/Cloud DHCP servers exist and there are no differently named containers
already using these VETHs/root directory. Do not import while changing an
existing running relay's interfaces; stop that relay first.

Upload updated `04-vlans.rsc` / `09-firewall-filter.rsc` and new `12-ssdp-network.rsc` / `13-ssdp-container.rsc`. `04-vlans.rsc` keeps optional VETH membership on future
reimports once `12-ssdp-network.rsc` has created it. Files `03`, `05`, `06`, `07`, `10` need no changes for this relay.

```routeros
/import 04-vlans.rsc
/import 09-firewall-filter.rsc
/import 12-ssdp-network.rsc
/import 13-ssdp-container.rsc
/container print detail where name="ssdp-relay"
```

Wait for extraction to finish without an error before starting. First start is
manual; start-on-boot is configured for subsequent boots. Start only the named
container:

```routeros
/container start [find where name="ssdp-relay"]
```

Read-only checks:

```routeros
/container print detail where name="ssdp-relay"
/interface veth print detail where name~"^veth-ssdp-"
/interface bridge port print detail where interface~"^veth-ssdp-"
/interface bridge vlan print detail
/ip dhcp-server lease print detail where server="dhcp300-iot"
/ip dhcp-server lease print detail where server="dhcp400-home-cloud"
/ip firewall filter print stats where comment="NAS Home access"
/ip firewall filter print stats where comment="IoT NAS access"
/ip firewall filter print stats where comment="NAS IoT access"
/system resource print
```

VETHs should show running and have one .100.x, one .30.x and one .40.x DHCP address. The
container should remain running, within its memory limit, with flash space left.
If it exits, inspect `/container/log print` on 7.24 or temporarily enable logging
for this exact container; inspect privately because discovery logs identify
local devices. Raw sockets must work in the RouterOS container runtime. No
privileged host access is configured; do not enable it blindly if socket creation
fails. Runtime capability/three-interface behavior still needs confirmation; the original two-interface TV discovery was operator-confirmed.

Open the TV's media-server browser, refresh and confirm Synology appears; test
actual playback. Verify Synology Media Server is enabled, media indexed and DSM
firewall allows the TV subnet. AP multicast filtering can affect Wi-Fi IoT clients.
If NAS callbacks reach an address outside IoT, this policy does not authorize them.
No blanket Cloud-subnet-to-Home or Cloud-subnet-to-IoT allowance is introduced.

## Recover a failed image extraction

Operator reported `download/extract error: no config found in manifest` on
2026-10-10. This identifies an unreadable image configuration; the old archive
format/contents have not been inspected. Rebuild using the direct Docker exporter
above and pass its archive check. Replace the uploaded `ssdp-relay.tar` in the
same persistent location (`flash/ssdp-relay.tar` on this router).

**DESTRUCTIVE — exact failed container only:** after confirming that exactly one
`ssdp-relay` exists and its flag is `F` (not running), remove that failed object.
This discards its failed import metadata; VETHs, physical ports and VLANs stay.
Do not delete a root directory or remove another container as a workaround.

```routeros
/container print detail where name="ssdp-relay"
/container remove [find where name="ssdp-relay"]
/import 13-ssdp-container.rsc
/container print detail where name="ssdp-relay"
```

If extraction succeeds, start using the first-start command above. If a leftover
root directory blocks recreation, stop and inspect the exact error before any
filesystem deletion. Reimporting13 alone does not recreate a failed existing
container or replace its image.

## Rollback

To stop only SSDP discovery (manual, reversible):

```routeros
/container stop [find where name="ssdp-relay"]
/container set [find where name="ssdp-relay"] start-on-boot=no
```

Do not reapply `13-ssdp-container.rsc` while keeping it disabled, since `13-ssdp-container.rsc` restores start-on-boot=yes.
For complete removal, first stop it, then remove the exact named container and
VETH bridge ports/interfaces after private review. **DESTRUCTIVE:** removing
`ssdp-relay` and its directory deletes its extracted filesystem; never use a
broad remove or delete the parent containers directory. Remove optional
VETHs before reimporting `04-vlans.rsc` so it removes their VLAN membership. No physical port
needs a PVID change. Retire only `NAS Home access`/`NAS IoT access`/`IoT NAS access` if removing NAS
cross-VLAN permissions too; native mDNS remains independent.

## Sources

- [RouterOS 7.24 container CLI: multiple interface argument](https://manual.mikrotik.com/docs/7.24/cli-reference/container/).
- [RouterOS 7.24 VETH DHCP support](https://manual.mikrotik.com/docs/7.24/containers/veth/).
- [Pinned relay source](https://github.com/alsmith/multicast-relay/tree/461d1c97f3aaf0ab9f8996e1a8f24c6b8204d6b4), GPL-3.0.

- [RouterOS persistent file storage](https://manual.mikrotik.com/docs/system-information-and-utilities/files/).
