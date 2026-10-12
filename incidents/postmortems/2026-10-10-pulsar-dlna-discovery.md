# Pulsar DLNA discovery unavailable across VLANs

- Date: 2026-10-10; timezone: Europe/Berlin (CEST, UTC+02:00).
- Status: resolved; I verified discovery on the TV and MacBook.
- Administrator: Anton. Incident start/end times and total duration were not recorded.

## Service impact

I could not find Pulsar's DLNA media server on the TV in IoT VLAN 300 or in VLC
on my MacBook in Home VLAN 100. This prevented discovery-based media access.
I did not record a separate playback verification. There was no evidence of
data loss or a wider NAS outage.

## Confirmed causes

There were two missing pieces:

1. The live RouterOS firewall lacked `NAS IoT access`. The SSDP relay repeated the
   TV's multicast search into Cloud VLAN 400 while preserving its source IP.
   Pulsar answered directly to the TV. Those unicast replies required inter-VLAN
   routing and an explicit firewall allowance; the multicast search through the
   relay did not establish the corresponding routed connection. Established/
   related filtering alone was insufficient for this path.
2. The original SSDP relay attached only VLAN 300 and VLAN 400. MacBook/VLAN 100
   searches were outside its coverage. The existing mDNS repeater did not supply
   DLNA's SSDP discovery.

Multicast path: TV/Mac -> SSDP `239.255.255.250:1900` -> relay -> Cloud -> Pulsar.
Reply path: Pulsar `192.168.40.5` -> routed unicast -> searching TV/Mac.

## Evidence and sequence

Exact event times were not captured; the order was:

- The container ran on ARM64 RouterOS 7.24.4. Its relay process was active, both
  original VETHs had DHCP addresses, and both joined the SSDP group.
- A sniffer on `syno1` saw Pulsar send UDP replies from port1900 to
  `192.168.30.100:1114`. This proved replies reached the router, not delivery
  to the TV.
- Bridge IP firewall settings were disabled as intended. A live lookup for
  `NAS IoT access` returned no rule; forward default-deny counters increased,
  although those counters alone could not attribute individual drops.
- The first corrective firewall import failed at line323: the generated command
  both unset and assigned `src-address`. After correction and successful import,
  I refreshed the TV sources and verified that Pulsar appeared.
- Home was then added as a third VETH/relay interface with an exact NAS-to-Home
  reply allowance. I also verified discovery on the MacBook.

## Recovery and final configuration

Source files: [VLAN table](../../network/mikrotik-rb5009upr/04-vlans.rsc),
[firewall](../../network/mikrotik-rb5009upr/09-firewall-filter.rsc),
historical `12-ssdp-network.rsc` VETH attachments, and
historical `13-ssdp-container.rsc` container definition (retired from the working tree).
After I verified native PIM-SM operation on 2026-10-11, the legacy source files
12/13 and build guide were retired. Historical source is recoverable from Git.
See [current PIM guide](../../network/mikrotik-rb5009upr/ssdp-pim.md).

The three attachments are Home VLAN 100, IoT VLAN 300 and Cloud VLAN 400. Guest and management are
excluded. SSDP discovery is mutual across those three VLANs; it is not restricted
to NAS advertisements. The existing image was reused for the Home extension.
Under the requested L3 policy, only NAS source `192.168.40.5` gets the reverse
Home/IoT allowances, but those allowances permit all protocols and unsolicited
NAS traffic, not merely SSDP replies.

## Contributing factors and accountability

During my investigation, the AI assistant incorrectly treated a rule prepared
in the repository as deployed and generated a conflicting unset/set command. Local structural checks did not
constitute RouterOS parser validation. Container running status was also
insufficient evidence of successful discovery.

Earlier restoration delays included omitted Alpine build headers, a legacy
netifaces/compiler compatibility error and an archive that RouterOS could not
read. These were corrected in the build recipe and direct Docker archive export;
they were separate from the missing live firewall rule.

## Follow-up

- Completed: Home relay attachment, NAS reply rules, duplicate unset/assignment
  checks, direct archive export/check instructions, and documented rollback.
- Required on future changes: verify live rule presence/order and inspect both
  multicast requests and routed replies; use RouterOS dry-run before import.
- Acceptance: verify discovery from Home and IoT, then actual media playback.
  Container readiness, NAS ping and web access do not replace these checks.
