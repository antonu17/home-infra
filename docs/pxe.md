# RouterOS-native PXE bootstrap

The RB5009 is the DHCP authority and native TFTP server for VLAN 400. No
provisioner VM, RouterOS container, proxy-DHCP service or second DHCP server is
required.

This setup supports x86-64 UEFI clients with Secure Boot disabled. The menu
boots Talos Linux 1.14.2 artifacts from the local Image Factory rather than
storing them on the router. A blank node enters maintenance; an installed node
can discover existing disk state/configuration. PXE is not a guarantee of a
clean maintenance environment. Installed VMs normally continue to local boot.

## Current flow and repository drift

UEFI PXE -> MikroTik DHCP/TFTP -> iPXE -> local Image Factory kernel/initramfs
-> Talos -> local OCI installer registry -> installed node disk.

The factory and registry are deployed with HTTPS, but the checked-in
`mikrotik/pxe/files/boot.ipxe` still uses `http://talos.home.antonu.org` in both
entries. Its normal entry also still contains the obsolete extension-free
schematic `376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba`.
This is configuration drift, **not the current normal provisioning schematic**.
Do not upload that menu unchanged expecting the current iSCSI-enabled boot.

The normal source of truth is `talos/image-factory/schematic-amd64.yaml` with
derived ID `c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac`.
Review/update the menu scheme and ID separately, test iPXE TLS, then upload it.
This documentation-only change does not modify router files or live services.

## Files

| File | Purpose |
|---|---|
| `snponly-x86_64.efi` | Official iPXE x86-64 UEFI chainloader |
| `autoexec.ipxe` | Prevents self-chainloading and transfers control to the menu |
| `boot.ipxe` | Local Image Factory normal/wipe boot and diagnostics menu; drift noted above |
| `SHA256SUMS` | Recorded checksum of the downloaded iPXE binary |
| `talos/image-factory/schematic-amd64.yaml` | Current reproducible normal schematic |
| `talos/image-factory/schematic-amd64-wipe.yaml` | Destructive system-wipe schematic |

The binary was downloaded from:

```text
https://boot.ipxe.org/x86_64-efi/snponly.efi
```

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

Upload the contents of `mikrotik/pxe/files/` into `flash/pxe/` using WinBox,
WebFig, SFTP or SCP. Do not upload `routeros.rsc` into the served directory.

If `/file print` does not show a `flash` directory, determine the persistent
root for this device and adjust every `real-filename` in `routeros.rsc` before
importing it.

Verify:

```routeros
/file print detail where name~"pxe"
```

The EFI binary should be `305664` bytes. The SHA-256 recorded in this repository
is:

```text
c84cbd76d925b947f776bf4fd0c25936ea818a5b9dc92bc4fd77efb9156948c0
```

## 2. Review and import the configuration

Read `mikrotik/pxe/routeros.rsc` before importing it. It:

- limits TFTP clients to `192.168.40.0/24`;
- permits only three exact filenames;
- accepts each permitted filename with or without the leading slash used by
  explicit iPXE TFTP URLs;
- makes every TFTP mapping read-only;
- limits negotiated TFTP blocks to 1468 bytes;
- sets the VLAN 400 DHCP `next-server` to `192.168.40.1`;
- sets the initial boot filename to `snponly-x86_64.efi`.

Import only after the file paths have been verified:

```routeros
/import file-name=routeros.rsc verbose=yes dry-run=yes
/import file-name=routeros.rsc verbose=yes
```

Alternatively, paste the reviewed commands section by section.

## 3. Verify RouterOS

```routeros
/ip tftp print detail
/ip tftp settings print
/ip dhcp-server network print detail where address="192.168.40.0/24"
```

Expected DHCP values:

```text
next-server=192.168.40.1
boot-file-name=snponly-x86_64.efi
```

The current firewall classifies `vlan400-home-cloud` as `LAN`, so TFTP input to
the router is permitted by the existing policy. When security zones replace
the generic `LAN` classification, explicitly allow UDP/69 from the CLOUD zone
to the router.

## 4. Test

Create a disposable Synology VMM test VM with:

- UEFI firmware and Secure Boot disabled;
- an `e1000` virtual NIC on the VLAN 400 external virtual switch;
- network first in the boot order;
- a blank or disposable disk.

It should receive an address from `192.168.40.100-199`, download
`snponly-x86_64.efi`, automatically retrieve `autoexec.ipxe`, and display the
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

The current menu labels are `Talos v1.14.2 maintenance (Image Factory)` and
`Talos v1.14.2 WIPE SYSTEM DISK`. It no longer has the previously documented
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

It was successfully used for clean reprovisioning. **Selecting the wipe menu
entry is destructive**, unlike ordinary maintenance boot: confirm the exact
VM/node and system disk, preserve required backups, and plan control-plane
membership changes first. Never use it to add an extension to an existing
cluster. Use a rolling `talosctl upgrade --image` instead. Keep wipe separate
from the normal schematic and never make it the default menu choice.

### `boot.ipxe` is denied after `autoexec.ipxe` succeeds

An explicit URL such as `tftp://192.168.40.1/boot.ipxe` requests the TFTP
filename `/boot.ipxe`, including its leading slash. The supplied RouterOS
rules accept both `boot.ipxe` and `/boot.ipxe`. If an older rule was already
installed, update it in place:

```routeros
/ip tftp set [find where comment="PXE home-cloud boot menu"] req-filename="(boot[.]ipxe)|(/boot[.]ipxe)"
```

## Scope and next step

Native RouterOS TFTP is intentionally limited to the small bootstrap files.
It is not a dynamic inventory or general HTTP artifact server. The current
cluster uses locally generated Talos machine configurations with persistent
secrets; Omni/inventory automation is not deployed. Raspberry Pi network boot
and migration remain future work, not covered by this x86-64 UEFI runbook.
