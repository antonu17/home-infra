# Native SSDP routing on RB5009

Operator confirmed discovery and playback with native PIM-SM on 2026-10-11,
after the file18 unset/assignment syntax fix. Agent live verification was not
performed. Legacy relay sources are retired. See [container removal](ssdp-container-removal.md).

2026-10-12: expansion to clients100→servers300 and all SSDP servers in400
is prepared, not live-tested. The earlier100/300→NAS400 paths were operator-
confirmed. Three required client→server paths are100→400,300→400,100→300.

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
| Cloud 192.168.40.0/24, VLAN400 | 239.255.255.250 UDP1900, out VLAN100/300 | Announcements |
| Home 192.168.100.0/24 | 239.255.255.250 UDP1900, out VLAN300 | Searches for IoT servers |
| IoT 192.168.30.0/24 | 239.255.255.250 UDP1900, out VLAN100 | IoT announcements |
| IoT 192.168.30.0/24 | Home 192.168.100.0/24, UDP source1900 | Unicast discovery replies |
| Each participating subnet | Router, IGMP to multicast addresses | Membership reports |
| Same SSDP sources | Router, SSDP group UDP1900 | Local multicast reception |

Only the requested three client/server paths are enabled. Other Cloud senders
may now advertise SSDP too. Guests and Management remain excluded. These rules
match group/UDP port, not SSDP message contents: IoT→Home multicast may also
carry M-SEARCH even though reverse client discovery is not an intended scenario.
PIM membership and application behavior determine delivery.

The IoT→Home unicast exception accepts UDP with source port1900 to Home clients,
before invalid/established and the IoT-to-Home deny. It is not tied to a prior
M-SEARCH transaction: any IoT sender can send UDP from1900 to Home. It does not
allow arbitrary TCP or other UDP source ports. This is the native stateless
firewall compromise; packet inspection/proxying would be needed to track requests.

Only SSDP packets arriving with TTL=1 are raised to 2 before routing. This allows
one routed hop; packets with larger TTL and all other traffic are unchanged.
No NAT, UPnP port mapping, bridge changes, address changes or static subscriptions
are introduced. WAN-only FastTrack does not match these paths.

Cloud→Home unicast SSDP replies still require permission. Existing NAS→Home
policy covers192.168.40.5; other Cloud providers are covered by their narrow
UDP source1900 exception added in file18. Cloud→IoT and Home→IoT already have
unicast permission in09. Existing Home/IoT→NAS access remains. Discovery does
not authorize HTTP/media/control to every server in400: non-NAS services need
their own reviewed unicast policy. Servers replying from other UDP source ports
need a separately scoped rule; do not broaden IoT→Home by default.

## Preflight and review (operator, read-only)

Save a private router backup/export and current PIM/firewall settings. Keep an
independent management session, preferably RouterOS Safe Mode. Upload reviewed
09-firewall-filter.rsc and 18-ssdp-pim.rsc. Historical12/13 are retired.

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
has run these checks. The operator subsequently confirmed successful operation. File18 refuses another active instance/proxy and duplicate
owned identities, but does not replace review of the full live configuration.

The server must join 239.255.255.250 in VLAN400. Clients need membership in that
group to receive multicast announcements. Inspect incoming IGMP and SSDP with a
short filtered packet capture if membership is missing. Check AP filtering and
bridge/switch snooping before changing them; this source does not enable snooping.
Do not add static memberships to mask a problem without separate review.

## Change (operator-run)

Import reviewed09 then18. If the old relay still exists, keep it stopped;
this update does not recreate it. File18 adopts the former NAS announcement
identities as Cloud announcement identities without duplicate rules.

```routeros
/import file-name=09-firewall-filter.rsc
/import file-name=18-ssdp-pim.rsc
```

Stop on any error; inspect the exact failing line and roll back below. Historical13 is retired and must not be reimported: it restores relay start-on-boot.
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
4. Verify a Home100 client discovers an IoT300 SSDP server, receives its unicast
   reply, and uses its advertised HTTP/control endpoint. Check IoT announcements
   reach Home subscribers. Also test a non-NAS400 provider if one exists.
5. Verify Guests/Management remain excluded and general IoT→Home initiation denied;
   other routed multicast must not bypass the deny rules. Same-VLAN multicast is
   unaffected. Check native mDNS independently.
6. Confirm no relay is running. Record the three requested paths separately.

If discovery is missing, distinguish absent IGMP membership, TTL, firewall drops
and device subnet restrictions. A successful PIM setup cannot guarantee every
DLNA implementation accepts cross-subnet discovery. Roll back if acceptance fails.
The operator accepted PIM and requested removal of the dormant container/VETHs.
File04 is updated; historical12/13 and the relay build directory are retired.
Follow [cleanup](ssdp-container-removal.md) after acceptance.

## Roll back the 2026-10-12 expansion (operator-run)

Disable only the four new exceptions and restore the four Cloud source scopes:

```routeros
/ip firewall filter disable [find where comment="Home SSDP search to IoT"]
/ip firewall filter disable [find where comment="IoT SSDP announcement to Home"]
/ip firewall filter disable [find where comment="IoT SSDP unicast response to Home"]
/ip firewall filter disable [find where comment="Cloud SSDP unicast response to Home"]
/ip firewall filter set [find where comment="Cloud SSDP announcement to Home"] src-address=192.168.40.5
/ip firewall filter set [find where comment="Cloud SSDP announcement to IoT"] src-address=192.168.40.5
/ip firewall filter set [find where comment="Cloud SSDP multicast input"] src-address=192.168.40.5
/ip firewall mangle set [find where comment="Cloud SSDP TTL one hop"] src-address=192.168.40.5
```

Verify the previously confirmed Home/IoT→NAS400 discovery/playback still works.
No container restart or PIM disable is needed. Reimporting the new18 reenables
and broadens these rules; do not reimport it while retaining rollback settings.

## Recovery after relay retirement

Before container removal, the old relay could be restarted after disabling
ssdp-pim and the three owned TTL rules. After removal, immediate container
rollback is unavailable. Save a private router backup and relay settings before
cleanup. Restore legacy sources from Git history only if a separate reviewed
recovery requires rebuilding/redeploying the relay; do not enable it concurrently
with PIM. PIM/TTL can be disabled by exact identity for diagnosis, but disabling
them stops cross-VLAN SSDP. Existing unicast and native mDNS remain independent.

## Sources

- [MikroTik single-router PIM-SM example](https://help.mikrotik.com/docs/spaces/ROS/pages/61767728/PIM-SM)
- [PIM interface templates](https://manual.mikrotik.com/docs/cli-reference/routing/pimsm/interface-template/)
- [PIM instance](https://manual.mikrotik.com/docs/cli-reference/routing/pimsm/instance/)
- [Mangle TTL actions](https://manual.mikrotik.com/docs/cli-reference/ip/firewall/mangle/)

The current CLI manual displays a newer RouterOS version; installed 7.24.4
syntax/runtime checks remain mandatory. Offline inspection is not a router test.
