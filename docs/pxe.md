# RouterOS-native PXE bootstrap

The RB5009 is the DHCP authority and native TFTP server for VLAN 400. No
provisioner VM, RouterOS container, proxy-DHCP service or second DHCP server is
required.

This setup supports x86-64 UEFI clients with Secure Boot disabled. The menu
can boot Talos Linux 1.14.1 into RAM-only maintenance mode. Talos kernel and
initramfs images are loaded from version-pinned HTTPS URLs rather than stored
on the router.

## Files

| File | Purpose |
|---|---|
| `snponly-x86_64.efi` | Official iPXE x86-64 UEFI chainloader |
| `autoexec.ipxe` | Prevents self-chainloading and transfers control to the menu |
| `boot.ipxe` | Local-mirror Talos boot, factory fallback and diagnostics menu |
| `SHA256SUMS` | Recorded checksum of the downloaded iPXE binary |
| `talos/schematic.yaml` | Reproducible Talos Image Factory schematic |

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

## 5. Boot Talos in maintenance mode

Deploy the Synology mirror described in `docs/talos-mirror.md` first. After
the mirror health and asset checks pass, replace only
`flash/pxe/boot.ipxe` on the RB5009. No DHCP or TFTP rule change is needed.
Restart the test VM or reload the menu and select:

```text
Talos v1.14.1 maintenance (Synology mirror)
```

The local entry retrieves the kernel and initramfs from:

```text
http://talos.home.antonu.org/v1.14.1/
```

The menu also retains this version-pinned public Image Factory script as a
recovery fallback:

```text
https://factory.talos.dev/pxe/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba/v1.14.1/metal-amd64
```

The schematic ID was generated from `talos/schematic.yaml`. This initial
schematic contains no extra extensions and is suitable for discovering the
Synology VMM test machine. VLAN 400 must have working DNS and outbound HTTPS.

Talos starts from RAM and enters maintenance mode because no machine
configuration is supplied. Merely selecting this menu item does not install
Talos or alter the VM disk. Disk installation begins only after a machine
configuration is explicitly applied.

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
It is not a dynamic inventory or general HTTP artifact server. The next step
is to inspect the Talos maintenance-mode node, then decide whether to register
it with Omni or apply a locally generated machine configuration.
