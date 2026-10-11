# Native SSDP routing on RB5009

Prepared 2026-10-11 for RouterOS 7.24.4. Not applied or tested on the router.
The existing relay deployment is operator-confirmed historically; it remains the rollback path.

## Scope and operation

PIM-SM means Protocol Independent Multicast, Sparse Mode. IGMP reports identify
receivers on each directly connected VLAN. RouterOS builds multicast forwarding
state for each source and group, and copies packets to interested interfaces.
Protocol Independent means PIM uses the existing unicast routing information
instead of requiring a particular unicast routing protocol. Sparse Mode delivers
to interested branches rather than flooding every network.

This is a single-router design, based on MikroTik's directly connected example:
no separate rendezvous point (RP) or neighboring PIM router is required here.
PIM is enabled only on vlan100-trusted, vlan300-iot and vlan400-home-cloud, in
main VRF, IPv4 only. It learns groups generally, but the forwarding firewall
permits only the SSDP paths below and drops other routed multicast entering
these three interfaces. mDNS remains the independent native DNS repeater.

| Source | Destination | Purpose |
|---|---|---|
| Home 192.168.100.0/24 | 239.255.255.250 UDP1900, out VLAN400 | Client searches |
| IoT 192.168.30.0/24 | 239.255.255.250 UDP1900, out VLAN400 | Client searches |
| NAS 192.168.40.5, VLAN400 | 239.255.255.250 UDP1900, out VLAN100/300 | Announcements |
| Each participating subnet | Router, IGMP to multicast addresses | Membership reports |
| Same SSDP sources | Router, SSDP group UDP1900 | Local multicast reception |

VLAN100↔300 multicast, other Cloud senders, Guests and Management are excluded.
Requests reach all SSDP listeners in VLAN400; the group cannot address the NAS
alone. Only the NAS is authorized to send routed SSDP back. This replaces the
old mutual three-VLAN relay with a server/client policy.

Only SSDP packets arriving with TTL=1 are raised to 2 before routing. This allows
one routed hop; packets with larger TTL and all other traffic are unchanged.
No NAT, UPnP port mapping, bridge changes, address changes or static subscriptions
are introduced. WAN-only FastTrack does not match these paths.

NAS unicast answers and DLNA HTTP/media use the existing file09 unicast policy:
Home↔NAS, Cloud→IoT, and the explicit all-IoT→NAS exception. Do not retire these
permissions merely because discovery is routed. TCP/UDP playback must be tested.

## Preflight and review (operator, read-only)

Save a private router backup/export and existing ssdp-relay settings. Keep an
independent management session, preferably RouterOS Safe Mode. Upload reviewed
09-firewall-filter.rsc and 18-ssdp-pim.rsc. Do not import all numbered files:
12/13 are the alternative container configuration.

```routeros
/system resource print
/routing pimsm instance print detail
/routing pimsm interface-template print detail
/routing igmp-proxy interface print detail
/interface vlan print detail
/interface bridge print detail where name="bridge"
/interface bridge settings print
/ip firewall filter print detail
/ip firewall mangle print detail
/ip firewall raw print detail
/container print detail where name="ssdp-relay"
/import file-name=09-firewall-filter.rsc verbose=yes dry-run
/import file-name=18-ssdp-pim.rsc verbose=yes dry-run
```

Stop if dry-run fails, another active PIM instance or IGMP proxy exists, or
unreviewed raw/mangle rules could intercept SSDP/IGMP. Scripts are not atomic.
Dry-run is syntax validation, not proof of runtime parameter support. No agent
has run these checks. File18 refuses another active instance/proxy and duplicate
owned identities, but does not replace review of the full live configuration.

The server must join 239.255.255.250 in VLAN400. Clients need membership in that
group to receive multicast announcements. Inspect incoming IGMP and SSDP with a
short filtered packet capture if membership is missing. Check AP filtering and
bridge/switch snooping before changing them; this source does not enable snooping.
Do not add static memberships to mask a problem without separate review.

## Change (operator-run)

Stop and disable auto-start for the exact existing relay before PIM is enabled,
so only one delivery path is active. Keep its image, filesystem and VETHs.

```routeros
/container stop [find where name="ssdp-relay"]
/container set [find where name="ssdp-relay"] start-on-boot=no
/container print detail where name="ssdp-relay"
```

Confirm the container is stopped. Then:

```routeros
/import file-name=09-firewall-filter.rsc
/import file-name=18-ssdp-pim.rsc
```

Stop on any error; inspect the exact failing line and roll back below. Do not
reimport 13-ssdp-container.rsc in PIM mode: it restores relay start-on-boot.
For later reapplications, 09 preserves optional PIM firewall rule ordering;
18 owns PIM and TTL settings. Reimporting18 temporarily disables its instance
while updating, briefly interrupting discovery.

## Readiness and acceptance (operator, read-only)

```routeros
/routing pimsm instance print detail where name="ssdp-pim"
/routing pimsm interface print detail
/routing pimsm uib-g print
/routing pimsm uib-sg print
/ip firewall filter print stats where comment~"SSDP|other routed multicast"
/ip firewall mangle print stats where comment~"SSDP TTL"
/container print detail where name="ssdp-relay"
```

Expect the IPv4 instance enabled, all three interfaces participating, and SSDP
group/source state after a fresh client search. No PIM neighbors is normal on
this one-router topology. Group state alone does not prove packet delivery.

1. Refresh the DLNA browser on a VLAN100 player and a VLAN300 TV. Both must see
   Pulsar. Trigger fresh searches instead of relying on a cached server entry.
2. Verify requests leave toward VLAN400 and NAS unicast replies reach the original
   client. Packet captures should show the original source address throughout.
3. Play media from each VLAN, including seeking. Record discovery and playback
   separately. Confirm NOTIFY from the NAS reaches subscribed clients.
4. Verify routed SSDP does not cross between VLAN100/300 or into Guests/Management;
   other routed multicast must not bypass the deny rules. Same-VLAN multicast is
   unaffected. Check native mDNS independently.
5. Confirm relay remains stopped and start-on-boot=no before accepting migration.

If discovery is missing, distinguish absent IGMP membership, TTL, firewall drops
and device subnet restrictions. A successful PIM setup cannot guarantee every
DLNA implementation accepts cross-subnet discovery. Roll back if acceptance fails.
Keep the dormant VETHs: removing them is a separate reviewed cleanup, and would
require updating 04/12/13. Do not run container cleanup during this migration.

## Rollback (operator-run, reversible)

Disable PIM before restarting the relay. Disable only the three owned TTL rules;
file09 multicast filter rules can remain because the old relay delivers across
VETHs at L2 and the bridge IP firewall is disabled in this design. Unicast policy
and native mDNS are untouched.

```routeros
/routing pimsm instance disable [find where name="ssdp-pim"]
/ip firewall mangle disable [find where comment="Home SSDP TTL one hop"]
/ip firewall mangle disable [find where comment="IoT SSDP TTL one hop"]
/ip firewall mangle disable [find where comment="Cloud SSDP TTL one hop"]
/container set [find where name="ssdp-relay"] start-on-boot=yes
/container start [find where name="ssdp-relay"]
```

Confirm PIM disabled, relay running, and fresh discovery/playback in both client
VLANs. Do not reimport18 while keeping PIM disabled; it reenables the instance
and TTL rules. Existing custom live settings need the saved private backup if
restoration beyond these scoped objects is necessary.

## Sources

- [MikroTik single-router PIM-SM example](https://help.mikrotik.com/docs/spaces/ROS/pages/61767728/PIM-SM)
- [PIM interface templates](https://manual.mikrotik.com/docs/cli-reference/routing/pimsm/interface-template/)
- [PIM instance](https://manual.mikrotik.com/docs/cli-reference/routing/pimsm/instance/)
- [Mangle TTL actions](https://manual.mikrotik.com/docs/cli-reference/ip/firewall/mangle/)

The current CLI manual displays a newer RouterOS version; installed 7.24.4
syntax/runtime checks remain mandatory. Offline inspection is not a router test.
