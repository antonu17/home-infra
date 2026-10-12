# IPv4 multicast between VLAN100, VLAN300 and VLAN400

Prepared at the operator's request on 2026-10-12; not imported or live-validated.
File18 retains the ssdp-pim instance name but broadens its firewall policy to
all IPv4 multicast groups, IP protocols and ports, in all six directions between
vlan100-trusted, vlan300-iot and vlan400-home-cloud. No source-address whitelist
is applied. File09 preserves these permissions ahead of connection-state and
unicast isolation rules when reapplied.

PIM-SM copies traffic to interfaces with interested receivers learned through
IGMP; it does not flood arbitrary groups without subscriptions. This is a
single router with directly attached sources and receivers, so the existing
configuration does not require another PIM router or static RP. IPv6 multicast
is outside this change. The local control range 224.0.0.0/24 cannot be routed;
native mDNS repeater remains independent. Membership, sender behavior and device
subnet checks still matter even when firewall permits all multicast.

TTL=1 multicast entering the three interfaces is raised to2 to permit one routed
hop, across all IPv4 multicast groups. IGMP membership packets are excluded
from TTL rewriting. Larger TTL and unicast TTL are unchanged.
No NAT or bridge merging is added. Original sender IP remains visible.

Previous SSDP-only multicast filters and TTL objects are removed by exact owned
comment. SSDP unicast reply exceptions from IoT/Cloud toHome (UDP source1900)
are retained, as is existing general unicast policy. These reply exceptions are
stateless. Multicast boundary drops remain below the six permits, so this change
does not authorize multicast forwarding to WAN, Guest or Management.

## Operator application

Save a private backup/export and a private copy of current PIM, filter and mangle
settings. Keep an independent management session. Upload the two reviewed files.
Check syntax first on the installed RouterOS version:

```routeros
/import file-name=09-firewall-filter.rsc verbose=yes dry-run=yes
/import file-name=18-ssdp-pim.rsc verbose=yes dry-run=yes
```

If both pass, apply:

```routeros
/import file-name=09-firewall-filter.rsc
/import file-name=18-ssdp-pim.rsc
```

File18 briefly disables/re-enables its PIM instance. Stop on any import error;
imports are not atomic. Syntax dry-run does not prove runtime acceptance.

## Verification

```routeros
/routing pimsm instance print detail where name="ssdp-pim"
/routing pimsm interface print detail
/routing pimsm uib-g print
/routing pimsm uib-sg print
/ip firewall filter print stats where comment~"multicast|SSDP unicast"
/ip firewall mangle print stats where comment~"multicast TTL"
```

Expect three participating interfaces, six unrestricted multicast forward
permissions ahead of boundary and unicast denies, and three multicast input
permissions. Verify membership and packet delivery with captures; table entries
alone are insufficient. Reboot Samsung in VLAN300 and separately check discovery
and playback. Verify LG/iPhone and Home100 discovery still work. Test additional
multicast groups with receivers subscribed on both sides. Confirm Guest and
Management remain excluded and ordinary IoT-toHome initiation remains denied.

## Recovery

To restore the previous narrow policy, use the privately saved previous file18
and file09, first removing the nine broad rules by the exact comments below and
the three broad TTL rules, then importing the previous files. Do not use an old
Git version blindly: the working tree contained uncommitted accepted changes.

Broad input comments: Home multicast input, IoT multicast input, Cloud multicast input.
Broad forward comments: Home multicast to IoT, Home multicast to Cloud,
IoT multicast to Home, IoT multicast to Cloud, Cloud multicast to Home,
Cloud multicast to IoT. TTL comments: Home multicast TTL one hop,
IoT multicast TTL one hop, Cloud multicast TTL one hop.


## Samsung SSDP source-subnet workaround

Operator confirmed2026-10-12: UE43RU7099UXZG discovers Pulsar locally in400
but fails across100/300 while iPhone/LG work. Corrected all-port capture shows
four NAS MediaServer replies from ephemeral UDP ports reaching Samsung's wired
MAC. Samsung sends no description GET until replies are source-NATed to its
local gateway. Source NAT works on Ethernet and Wi-Fi; Ethernet playback and
seeking were confirmed. Exact firmware check remains inferred, not documented.
Earlier port1900 captures missed these replies; absence of a captured reply was
not evidence that NAS did not send one. TTL experiment did not restore discovery.

Static IoT leases preserve192.168.30.107 (Wi-Fi8C:79:F5:A5:C6:E8) and
192.168.30.110 (Ethernet00:C3:F4:8B:7C:92). Static entries in
SSDP-SUBNET-CLIENTS select only these receivers. NAT matches NAS192.168.40.5,
outvlan300-iot, UDP destination3942, and translates source to192.168.30.1.
Do not match source1900: libupnp uses ephemeral response source ports. This
preserves the NAS LOCATION and HTTP/media traffic. The destination port3942
was observed on both interfaces; it is not a guaranteed fixed SSDP client port.
If firmware changes it, capture all UDP and update this narrow rule after review.
Other list entries must be in VLAN300; other VLAN gateways need separate rules.

File10 owns leases;07 owns list entries;08 owns permanent NAT. For the existing
router use19-samsung-ssdp.rsc, which applies only these objects and adopts the
working TEMP Samsung SSDP source test rule. It refuses conflicting identities
or IP reservations and removes the failed TEMP Samsung SSDP TTL test. Save a
private backup and copy of the previous rule/leases/list first. Operator-run:

```routeros
/import file-name=19-samsung-ssdp.rsc verbose=yes dry-run=yes
/import file-name=19-samsung-ssdp.rsc
/ip dhcp-server lease print detail where comment~"Samsung TV"
/ip firewall address-list print detail where list="SSDP-SUBNET-CLIENTS"
/ip firewall nat print stats where comment="Pulsar SSDP replies to subnet-sensitive clients"
```

Expect both leases static, both addresses in the list, one NAT rule before
other NAT rules and no duplicate TEMP source test. Reboot/reconnect each TV
interface separately and verify discovery, playback and seeking. Fresh response
flows exercise changed NAT; do not clear global connection tracking. If an import
fails, stop: imports are not atomic. Prepared permanent configuration is not yet
operator-confirmed. Core07/08/10 reimports reconcile the same owned objects.
For rollback restore the privately saved temporary rule and DHCP/list state;
disabling permanent NAT alone intentionally removes the Samsung discovery workaround.

Sources: [MikroTik PIM-SM](https://help.mikrotik.com/docs/spaces/ROS/pages/61767728/PIM-SM),
[IANA multicast address scope](https://www.iana.org/assignments/multicast-addresses).
