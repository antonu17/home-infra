# Matter nodes unavailable after Thread border-router VLAN migration

- Investigation and recovery date: 2026-10-13, Europe/Berlin (CEST, UTC+02:00).
- Status: resolved for all seven Matter nodes through tado.
- Administrator: Anton. Exact outage start/end and duration were not recorded.
- Bridge X SSID migration was reported as the previous day; HomePod placement was
  initially uncertain and its move to IoT was confirmed during this investigation.
- Log timestamps are retained as emitted; their timezone was not established.

## Service impact

All seven commissioned Thread thermostats became unavailable in Home Assistant.
Local Matter control was interrupted. No data loss or loss of local heating
schedules was established. Existing fabric data and commissioned nodes were retained.

## Infrastructure

Matter Server runs with host networking on talos-worker-02 in VLAN400, using
`fdb5:841f:2eb7:400:dea6:32ff:fe2f:57c3/64`. MikroTik routes VLAN400 and IoT
VLAN300. Aruba carries IoT on tagged VLAN300 through ether7.
Tado Bridge X MAC is `48:27:E2:D2:9E:08`; its link-local next hop is
`fe80::4a27:e2ff:fed2:9e08%vlan300-iot`.
HomePod mini MAC is `40:ED:CF:5D:98:3B`; its confirmed new next hop is
`fe80::1821:9359:33fb:fa36%vlan300-iot`.

## Evidence and sequence

| Observation | Interpretation |
|---|---|
| HA WebSocket connected and Matter Server returned seven stored nodes | Controller API and stored node inventory existed; device reachability was separate |
| Repeated connection attempts to `fd2f:feb4:bf84:0:…:5540` and CASE timeouts | Operational IPv6 paths failed |
| Router had routes only for `fd97:72fc:f25f:1::/64`, via old VLAN100 next hops | Both destination coverage and interface association were stale |
| Changing old routes to VLAN300 did not recover nodes | Interface correction alone did not cover the actual device addresses |
| VLAN300 ULA/RA configured and read back; tado acquired a ULA | Infrastructure addressing and SLAAC worked |
| Worker reached router VLAN300 ULA; route lookup selected MikroTik with VLAN400 ULA source | Worker sent affected traffic to the router |
| Tado link-local ping returned 5/5; a /128 via tado returned 5/5 from worker | Next hop and bidirectional reachability to one Thread node worked |
| Node @1:4 resumed CASE, read 19 attributes, subscribed and became available | Application-level recovery confirmed for one node |
| Route expanded to `fd2f:feb4:bf84:0::/64`; all seven nodes connected | Correct prefix route restored the affected service |
| Old prefix routes disabled; service remained working | Old routes were unnecessary for current Matter nodes |
| HomePod moved to IoT; diagnostic /128 via its new next hop returned 5/5 | One Thread node reachable through HomePod; full standby behavior not tested |

## Cause

The effective route to the device IPv6 prefix was missing on MikroTik. Existing
static routes targeted a different prefix and originally referenced VLAN100 after
tado moved to VLAN300. The supplied main table would select the WAN default for
`fd2f:feb4:bf84:0:…`; no WAN packet capture was collected to prove transmission.
A narrow route through tado restored one node, and the covering /64 restored all
seven. This establishes the routing failure as the immediate cause.

Whether the Thread prefix changed during migration, or the old route was already
stale, was not established. Adding VLAN300 ULA supported consistent infrastructure
addressing but did not alone create the missing Thread route. IPv4 mDNS repetition
and IPv4 firewall allowances do not establish IPv6 reachability.

## Recovery and permanent configuration

[25-ipv6-iot.rsc](../../network/mikrotik-rb5009upr/25-ipv6-iot.rsc) owns:

- VLAN300 gateway `fdb5:841f:2eb7:300::1/64` and interface-specific RA/SLAAC.
- Thread prefix `fd2f:feb4:bf84:0::/64` through tado, distance 1.
- The same prefix through HomePod, distance 2, with no gateway health checking.
- Exact cleanup of retired prefix routes and temporary diagnostic routes.

[Network runbook](../../network/mikrotik-rb5009upr/README.md) contains import,
verification and rollback. Live primary recovery is confirmed. The final source
import, temporary-route cleanup and full HomePod standby acceptance have no
recorded final readback. No reboot, reset or recommissioning of thermostats was
required; Bridge X was power-cycled during diagnosis.

## Diagnostic mistakes and contributing factors

Several captures contained MLD or neighbor discovery rather than border-router
RA. Later RA packets were solely MikroTik ULA advertisements; they provided no
Thread Route Information. Absence in these captures did not prove absence on Wi-Fi.
Unicast visibility was verified with simultaneous ping and capture.

Aruba associated Thread peer addresses with the Bridge X client MAC. One such
address belonged to a thermostat in Matter logs; the client table was not proof
of the bridge's own IPv6 address. Link-local gateway identity came from neighbor
resolution and successful ping instead.

Ping to a link-local border-router address from VLAN400 cannot cross VLANs.
Specifying an interface in router ping does not install a route. Router ping
reported high apparent loss while worker responses took 0.7–2.8 seconds; those
results did not establish underlying packet-loss rate.

## Prevention and follow-up

| Action | Status / acceptance |
|---|---|
| Persist gateway, RA and current Thread routes | Prepared in file25; final import/readback pending |
| Validate node availability and subscriptions after border-router moves | Seven nodes recovered through tado |
| Verify all seven nodes through HomePod | Pending; only one node ping confirmed |
| Design and test health-based failover | Pending; distance alone is not failure detection |
| Review IPv6 isolation independently of IPv4 | Pending; current IPv6 policy does not establish IoT policy parity |
| Revalidate next-hop scope and device prefix after topology changes | Required; do not infer prefix change from SSID change |

## Evidence retention

Evidence comprises supplied router readbacks, worker route lookup, ping results,
Matter logs and locally analysed captures. Raw logs/captures and credential-bearing
fabric data remain outside Git. Exact outage timing was not inferred from unrelated
capture or server-start timestamps.
