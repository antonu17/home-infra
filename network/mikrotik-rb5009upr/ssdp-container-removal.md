# Retire SSDP container on RB5009

2026-10-11: operator confirmed PIM-SM discovery and playback and requested relay
removal. Local sources12/13, ssdp-relay build directory/archive, and file04 relay
VETH membership are retired. Router cleanup below has not been performed by the
agent or confirmed by the operator. PIM file18, firewall09 and native mDNS remain.

## Preflight (operator, read-only)

Save a private router backup/export and ssdp-relay settings, including root-dir,
before cleanup. Keep an independent management session. Confirm PIM works with
ssdp-relay stopped. Upload updated04-vlans.rsc. Dry-run must pass before changes.
Review all container interface/root-dir references privately: no other container
may reference the three VETHs or the relay root directory. If it does, stop here.

```routeros
/routing pimsm instance print detail where name="ssdp-pim"
/container print detail where name="ssdp-relay"
/container print
/interface veth print detail where name="veth-ssdp-home"
/interface veth print detail where name="veth-ssdp-iot"
/interface veth print detail where name="veth-ssdp-cloud"
/interface bridge vlan print detail
/import file-name=04-vlans.rsc verbose=yes dry-run
```

Before running the next block, exactly one ssdp-relay must exist and be stopped
(flag S). Inspect only the other containers' interface/root-dir fields privately
in WinBox; do not paste credential-bearing exports. Updated04 matches the physical
membership: Home ether4/ether8, IoT ether3, Cloud syno1/ether5/ether6. Stop if live
physical membership differs; do not overwrite custom live changes blindly.

## DESTRUCTIVE — remove exact legacy container and networking (operator-run)

Removing ssdp-relay retires the immediate relay rollback path. Confirm the backup
and acceptance above. If it is not stopped, first stop it and wait until flag S:

```routeros
/container set [find where name="ssdp-relay"] start-on-boot=no
/container stop [find where name="ssdp-relay"]
/container print detail where name="ssdp-relay"
```

Only after stopped is confirmed, run sequentially and stop at any error:

```routeros
/container remove [find where name="ssdp-relay"]
```

Confirm the container deletion has completed (no deleting entry) before removing
its attachments:

```routeros
/container print where name="ssdp-relay"
```

```routeros
/interface bridge port remove [find where interface="veth-ssdp-home"]
/interface bridge port remove [find where interface="veth-ssdp-iot"]
/interface bridge port remove [find where interface="veth-ssdp-cloud"]
/interface veth remove [find where name="veth-ssdp-home"]
/interface veth remove [find where name="veth-ssdp-iot"]
/interface veth remove [find where name="veth-ssdp-cloud"]
/import file-name=04-vlans.rsc
```

File04 reconciles the VLAN table without relay VETHs. No change to PIM, TTL,
firewall, native mDNS, DHCP scopes, physical uplinks or another container is needed.
Keep the RouterOS container package/device mode: Tailscale uses it independently.

## Verification / stop point (operator, read-only)

```routeros
/container print where name="ssdp-relay"
/interface veth print where name~"^veth-ssdp-"
/interface bridge port print where interface~"^veth-ssdp-"
/interface bridge vlan print detail
/routing pimsm instance print detail where name="ssdp-pim"
/routing pimsm uib-sg print
/system resource print
```

Expect no legacy container/VETH/bridge-port entries and no relay members in the
VLAN table. Refresh DLNA discovery and play/seek media on VLAN100 and300 again.
Confirm unrelated containers remain operational. Stop if acceptance regresses;
do not disable PIM or delete additional files as a workaround.

## DESTRUCTIVE — delete exact leftover storage (operator-run)

After verification, remove any remaining extracted relay filesystem and uploaded
archive from WinBox Files. Use the actual root-dir saved in preflight; the legacy
source used `flash/containers/ssdp-relay` and `flash/ssdp-relay.tar` when flash
exists, otherwise `containers/ssdp-relay` and `ssdp-relay.tar`. Container removal
may already have removed its filesystem; if absent, skip it. Verify no other
container references this directory or a mount within it before deleting.

Delete only the exact relay directory and archive, plus obsolete uploaded
`12-ssdp-network.rsc` and `13-ssdp-container.rsc` files if present. Never delete
`flash`, the parent `containers` directory, shared layers or Tailscale storage.
If the path differs from the saved setting, or deletion fails, stop and inspect
that exact object. WinBox Files Remove is documented by
[MikroTik](https://manual.mikrotik.com/docs/system-information-and-utilities/files/).

DHCP scopes do not change. Dynamic stale VETH leases can expire normally.
No new cleanup script is in the normal import sequence; this is a one-time task.

## Recovery

After container removal, recovery requires the private backup or rebuilding and
redeploying the legacy relay from Git history with separately reviewed commands.
There is no immediate restart rollback. Do not run legacy relay and PIM together.
Native PIM source and existing NAS unicast permissions are kept throughout.
