# RouterOS PXE assets

Moved here from the former `mikrotik/pxe/` directory on 2026-10-10. The existing `ipxe.efi` binary and iPXE scripts are preserved. This repository move does not change
router storage: uploaded boot files still live under `flash/pxe/`.

See [the PXE runbook](../../../docs/pxe.md). Common DHCP is owned by
[`10-dhcp.rsc`](../10-dhcp.rsc); current firewall allowances are in
[`09-firewall-filter.rsc`](../09-firewall-filter.rsc).

`routeros.rsc` is a **legacy bootstrap reference**, excluded from the numbered
idempotent imports. It unconditionally adds TFTP mappings. Its requested boot
filename `ipxe-x86_64.efi` matches common DHCP and maps to the physical file
`flash/pxe/ipxe.efi`. Check existing live mappings before using this reference;
repeated imports would add duplicate mappings.

`files/` contains the existing EFI binary, checksum, `autoexec.ipxe` and
`boot.ipxe`. The menu uses current schematic IDs over HTTP and includes a
**DESTRUCTIVE system-wipe entry**; never make that entry the default.
No router upload, import or provisioning has been performed by the agent.
