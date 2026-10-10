# RouterOS PXE assets

`files/` contains the existing `ipxe-x86_64.efi` binary, its checksum, `autoexec.ipxe`
and `boot.ipxe`. Upload these assets manually to persistent `flash/pxe/` storage
(or `pxe/` when the router has no `flash` directory).

[`15-pxe.rsc`](../15-pxe.rsc) owns native TFTP settings and idempotent mappings.
[`10-dhcp.rsc`](../10-dhcp.rsc) owns DHCP, including the Cloud boot filename
`ipxe-x86_64.efi` and next-server `192.168.40.1`.
[`09-firewall-filter.rsc`](../09-firewall-filter.rsc) owns firewall allowances.
[`14-static-dns.rsc`](../14-static-dns.rsc) owns Image Factory/registry names.
There is no separate nested RouterOS import script.

The requested name `ipxe-x86_64.efi` maps to physical file `ipxe-x86_64.efi`.
The menu uses current schematic IDs over HTTP and includes a
**DESTRUCTIVE system-wipe entry**; never make that entry the default.
See [the PXE runbook](../../../docs/pxe.md) for prerequisites, imports,
verification and rollback. No upload, import or boot test was executed by the agent.
