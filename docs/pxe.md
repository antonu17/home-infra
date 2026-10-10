# RouterOS-native PXE bootstrap

The RB5009 is the DHCP authority and native TFTP server for VLAN 400. No
provisioner VM, RouterOS container, proxy-DHCP service or second DHCP server is
required for PXE. The separate SSDP discovery container is unrelated to provisioning.

This setup supports x86-64 UEFI clients with Secure Boot disabled. The menu
boots Talos Linux 1.14.2 artifacts from the local Image Factory rather than
storing them on the router. A blank node enters maintenance; an installed node
can discover existing disk state/configuration. PXE is not a guarantee of a
clean maintenance environment. Installed VMs normally continue to local boot.

## Current flow and repository drift

UEFI PXE -> MikroTik DHCP/TFTP -> iPXE -> local Image Factory kernel/initramfs
-> Talos -> local OCI installer registry -> installed node disk.

The checked-in `network/mikrotik-rb5009upr/pxe/files/boot.ipxe` uses HTTP to the local factory
in three entries (AMD64 normal, Pi 4 ARM64, AMD64 wipe). Its AMD64 normal
schematic is already the current iSCSI-enabled
`c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac`;
the Pi 4 entry uses `f47e6cd2634c7a96988861031bcc4144468a1e3aef82cca4f5b5ca3fffef778a`.
The factory/registry handoff reports HTTPS service endpoints; the repository
iPXE menu uses HTTP. An HTTPS menu change requires separate iPXE TLS testing.
No live menu upload or current client boot test was supplied during this audit.

The 2026-10-10 DHCP export and common DHCP source name `ipxe-x86_64.efi`.
The repository TFTP source maps that requested name to the existing physical
binary `flash/pxe/ipxe-x86_64.efi`. Uploading a file alone does not create this mapping;
verify the live TFTP configuration before booting a client.

Operator confirmed on 2026-10-10 that no PXE boot-file changes are known.
Repository changes do not change live files or settings, and the updated
mapping has not been applied or boot-tested by the agent.

## Files

| File | Purpose |
|---|---|
| `autoexec.ipxe` | Prevents self-chainloading and transfers control to the menu |
| `boot.ipxe` | Current AMD64 normal/wipe and Pi 4 ARM64 maintenance entries; HTTP transport |
| `ipxe-x86_64.efi` | Existing EFI bootstrap binary, served as `ipxe-x86_64.efi` |
| `SHA256SUMS` | Recorded checksum of the existing `ipxe-x86_64.efi` binary |
| `talos/image-factory/schematic-amd64.yaml` | Current reproducible normal schematic |
| `talos/image-factory/schematic-amd64-wipe.yaml` | Destructive system-wipe schematic |

The existing `ipxe-x86_64.efi` binary is preserved; its build/download provenance
is not established by the repository. Its checksum verifies file integrity,
not boot compatibility.

## 1. Determine persistent RouterOS storage

Run:

```routeros
/file print
```

If a `flash` directory exists, files outside it are held in RAM and disappear
after reboot. Create the persistent directory:

```routeros
/file add name=/flash/pxe type=directory
```

Upload the contents of `network/mikrotik-rb5009upr/pxe/files/` into `flash/pxe/` using WinBox,
WebFig, SFTP or SCP. Keep `.rsc` configuration files outside the served directory.

If `/file print` does not show a `flash` directory, determine the persistent
root for this device. `15-pxe.rsc` selects `flash/pxe/` when `flash` exists,
otherwise `pxe/`; review this selection against `/file print` before importing.

Verify:

```routeros
/file print detail where name~"pxe"
```

The existing `ipxe-x86_64.efi` binary is `1163776` bytes. The SHA-256 recorded in this repository
is:

```text
3b6285d2a1f8f184e86336a840c5e974780badfda06224acd5d3cf10a721ad81
```

## 2. Idempotent PXE configuration

[`15-pxe.rsc`](../network/mikrotik-rb5009upr/15-pxe.rsc) is the numbered
RouterOS TFTP source. The former nested script has been removed.
DHCP boot fields have one owner: `10-dhcp.rsc` preserves next-server
`192.168.40.1` and boot filename `ipxe-x86_64.efi`.
No DHCP scope, option or reservation is modified by file15.

The file validates all three uploaded files are present and non-empty before
changing anything. TFTP rules use stable descriptive comments. A unique old
filename expression can be adopted even without its current comment; matching
both an old row and a managed row is a duplicate and stops the import.
Review duplicates manually rather than deleting arbitrary rules.

| Requested filename (optional leading slash) | Physical file | Stable comment |
|---|---|---|
| `ipxe-x86_64.efi` | `ipxe-x86_64.efi` | PXE x86-64 UEFI bootstrap |
| `autoexec.ipxe` | `autoexec.ipxe` | PXE iPXE automatic startup |
| `boot.ipxe` | `boot.ipxe` | PXE home-cloud boot menu |

All managed rules restrict clients to `192.168.40.0/24`, are enabled/read-only,
and use anchored expressions such as `^/?boot[.]ipxe$`. `ip-addresses` is the
full RouterOS property name. `max-block-size=1468` preserves the existing
fragmentation-avoidance setting. See [MikroTik TFTP documentation](https://manual.mikrotik.com/docs/cli-reference/ip/tftp/)
and [block-size guidance](https://help.mikrotik.com/docs/spaces/ROS/pages/131366922/TFTP).

TFTP uses the first matching rule. The import puts the three managed rules
first in bootstrap/startup/menu order on every import. Other rules are retained:
these three mappings do **not** eliminate access allowed by unrelated broad
rules for other filenames or client networks. Inspect those separately. No
catch-all allow/deny, broad removal or additional firewall rule is introduced.

Operator-run, after uploading/checking the files and recording current TFTP
rule properties/order and the global block-size setting privately:

```routeros
/ip tftp print detail
/ip tftp settings print
/file print detail where name~"pxe"
/import file-name=15-pxe.rsc verbose=yes dry-run=yes
/import file-name=15-pxe.rsc verbose=yes
```

If common DHCP is already imported, only file15 needs reapplication for this
TFTP change. For full configuration, follow the alphabetical numbered imports;
file15 requires uploaded assets but has no dependency on SSDP containers.
Missing files or duplicate identities stop before any configuration mutation.
Imports are not atomic; a runtime failure after preflight can leave partial
updates. Fix the error and re-import to reconcile the same objects.

Rollback: restore the three rows' recorded previous properties and positions,
remove only managed rows that were newly added, and restore the previous
`max-block-size` value. Uploaded assets are never altered by the script.
DHCP rollback is unnecessary for a file15-only import because it does not
modify DHCP. Do not remove all TFTP rules. No live import or PXE boot test has
been performed by the agent.

## 3. Verify RouterOS

```routeros
/ip tftp print detail
/ip tftp settings print
/ip dhcp-server network print detail where address="192.168.40.0/24"
```

Current preserved DHCP values (operator export 2026-10-10):

```text
next-server=192.168.40.1
boot-file-name=ipxe-x86_64.efi
```

The numbered firewall uses explicit `Cloud DNS and native TFTP` input rules
for UDP/53,69 and TCP/53, plus established/related handling for replies.
`LAN` membership alone is not an input permission. Confirm these rules precede
the input drop and test negotiated TFTP transfers.

## 4. Test

Create a disposable Synology VMM test VM with:

- UEFI firmware and Secure Boot disabled;
- an `e1000` virtual NIC on the VLAN 400 external virtual switch;
- network first in the boot order;
- a blank or disposable disk.

It should receive an address from `192.168.40.100-199`, download
the configured `ipxe-x86_64.efi` (verify the live mapping), automatically retrieve `autoexec.ipxe`, and display the
Home Cloud Network Boot menu.

Useful RouterOS observations during the test:

```routeros
/ip dhcp-server lease print detail where server=dhcp400-home-cloud
/ip tftp print detail
/log print follow where topics~"tftp|dhcp"
```

The TFTP rule hit counters should increase.

## 5. Boot and provision Talos

Use the [local factory/registry pipeline](talos-mirror.md). The intended normal
PXE script for the current schematic/version is:

```text
https://talos.home.antonu.org/pxe/c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac/v1.14.2/metal-amd64
```

The current menu labels include `Talos v1.14.2 maintenance (Image Factory)`,
`Talos v1.14.2 Raspberry Pi 4 maintenance (Image Factory)`, and
`Talos v1.14.2 WIPE SYSTEM DISK`. The ARM64 iPXE menu entry does not prove
the Pi firmware can reach or boot this x86-64 EFI chainloader. It no longer has the previously documented
public-factory fallback. Local boot is the default after ten seconds.

For a blank/disposable VM: boot the normal entry, inspect disks and identity,
then apply a reviewed node configuration using the **existing cluster secrets**
and local installer reference. See [Talos cluster](talos-cluster.md). Merely
changing the boot artifact does not upgrade an installed system image.

### Destructive clean reprovisioning

Existing Talos disk state may be reused even after PXE booting new assets.
The separate wipe schematic has `talos.experimental.wipe=system` and ID:

```text
9acd4f2454d4969f5351e85d824eb5d27f8124b56d281d8a03c924fa1a7cfd2f
```

It was successfully used for clean reprovisioning. **DESTRUCTIVE: selecting the wipe menu
entry erases the selected node system disk**, unlike ordinary maintenance boot: confirm the exact
VM/node and system disk, preserve required backups, and plan control-plane
membership changes first. Never use it to add an extension to an existing
cluster. Use a rolling `talosctl upgrade --image` instead. Keep wipe separate
from the normal schematic and never make it the default menu choice.

### `boot.ipxe` is denied after `autoexec.ipxe` succeeds

An explicit URL such as `tftp://192.168.40.1/boot.ipxe` requests the TFTP
filename `/boot.ipxe`, including its leading slash. The supplied RouterOS
rules accept both `boot.ipxe` and `/boot.ipxe`. Re-import `15-pxe.rsc` to reconcile the exact anchored filename expressions,
including the optional leading slash. Inspect rule hits and firewall counters
if transfer still fails; do not add a wildcard TFTP mapping.

## Scope and next step

Native RouterOS TFTP is intentionally limited to the small bootstrap files.
It is not a dynamic inventory or general HTTP artifact server. The current
cluster uses locally generated Talos machine configurations with persistent
secrets; Omni/inventory automation is not deployed. The Pi workers already
joined VLAN400 and Kubernetes. The Pi 4 ARM64 menu entry exists, but verified Raspberry Pi firmware
network boot remains outside this x86-64 UEFI chainloader runbook; Quantum's SD/NVMe boot is covered by [its history](quantum-talos-build-history.md).

Operator file inventory on 2026-10-10 confirms `flash/pxe/ipxe-x86_64.efi`,
`autoexec.ipxe` and `boot.ipxe` already exist. File15 and the repository binary
name now match this layout. The displayed EFI size agrees with the repository
size, but the live binary checksum has not been verified. The router's uploaded
`SHA256SUMS` still references a removed bootstrap binary; replace that checksum
file from the repository during the next asset upload. File15 does not use it.
