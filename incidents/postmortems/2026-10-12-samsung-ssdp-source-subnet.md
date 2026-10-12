# Samsung DLNA discovery rejects cross-subnet SSDP responses

- Date: 2026-10-12; timezone: Europe/Berlin (CEST, UTC+02:00).
- Status: resolved through a source-NAT workaround.
- Administrator: Anton. Exact incident start/end and duration were not recorded.
- Device: Samsung UE43RU7099UXZG; software T-MSLDEUC-1500.9.

## Service impact

I could not find Pulsar in Samsung's DLNA source list outside the NAS subnet, preventing
normal discovery-based media access. LG, iPhone and a computer continued to
work across VLANs. No data loss, general NAS outage or wider Internet impact
was demonstrated. A transient LG discovery delay occurred earlier in the
investigation and cleared without a network configuration change; its cause
was not established and must not be attributed to this Samsung issue.

## Infrastructure and discovery workflow

Pulsar is a Synology NAS at `192.168.40.5` in Cloud VLAN 400
(`192.168.40.0/24`). Home VLAN 100 uses `192.168.100.0/24`; IoT VLAN 300 uses
`192.168.30.0/24`. A MikroTik RB5009 running RouterOS 7.24.4 routes IPv4
multicast with PIM-SM between these three VLANs. Native mDNS repeating is
separate from SSDP. IoT clients have unicast access to the NAS. Samsung uses
the `neutron iot` Wi-Fi network; Ethernet testing also bypassed Wi-Fi.

Samsung sends `M-SEARCH` to `239.255.255.250:1900` with the search target
`urn:schemas-upnp-org:device:MediaServer:1`, the header `MAN: "ssdp:discover"`
and `MX: 4`. The NAS sends a unicast `HTTP/1.1 200 OK` discovery response to
the searcher's UDP port 3942. Media Server advertises the description URL
`http://192.168.40.5:50001/desc/device.xml` in its `LOCATION` header. A client
accepting discovery should then fetch that description and browse or play media.

## Evidence and sequence

Exact wall-clock incident boundaries are unknown. The following order is
reconstructed from my tests and the captures collected during the investigation.

| Step | Observation | What it establishes |
|---|---|---|
| 1 | iPhone/LG discover Pulsar on IoT Wi-Fi; Samsung does not | Failure is client-specific; successful discovery by another client is not proof of identical packet handling |
| 2 | Samsung fails by Ethernet in VLAN 100; computer on that cable works | Failure is not confined to Aruba Wi-Fi |
| 3 | NAS capture sees Samsung VLAN 300 M-SEARCH on eth0 and ovs_bond0 | PIM delivers the request to the NAS; it does not prove delivery to the application or absence of a response |
| 4 | Media Server restriction is disabled; initial Device list empty | Device allow-list configuration did not explain the failure |
| 5 | NAS INPUT policy ACCEPT with no blocking input rules; SSDP group joined on ovs_bond0; `rp_filter` set to 0; correct return route | Inspected NAS firewall, membership and reverse-path checks did not identify a block |
| 6 | Samsung in VLAN 400 discovers Pulsar and appears in Device list; returning to VLAN 300 fails | Same-subnet discovery works; registration alone does not fix cross-subnet discovery |
| 7 | All routed IPv4 multicast permitted between VLANs 100, 300 and 400; Samsung still fails | Removing SSDP-only multicast firewall restrictions does not resolve this client issue |
| 8 | NAS announcement TTL artificially preserved as 4 across routing; Samsung still fails | Tested multicast-announcement TTL change does not restore discovery |
| 9 | Independent model review finds that libupnp response sockets need not use source port 1900 | Earlier capture filter excluded a possible reply path |
| 10 | Corrected all-port capture sees four NAS MediaServer:1 replies leave ether4 for the TV MAC; no TV TCP port 50001 follows | Router forwards valid replies toward Samsung, but Samsung does not proceed to description retrieval |
| 11 | Source-NAT only those replies to IoT gateway 192.168.30.1; Samsung discovers Pulsar | Changing response source address restores client acceptance without changing LOCATION or TTL |
| 12 | I verified Ethernet playback and seeking, switched to Wi-Fi, updated the rule for 192.168.30.107 and verified discovery again | Workaround restores useful service and works on both interfaces |
| 13 | I applied file 19 to reserve both addresses and configure the client list and permanent NAT rule | Import completed; I did not record a subsequent readback or fresh acceptance test |

The capture from my successful VLAN 400 test contained Samsung NOTIFY messages,
but no Samsung M-SEARCH or unicast replies. It does not establish how a local
M-SEARCH is answered. Samsung could have discovered the server from periodic
NAS advertisements. This limitation matters when comparing local and routed paths.

## Decisive packet evidence

In the corrected full capture, Pulsar sent four unicast responses:

```text
192.168.40.5:37404 -> 192.168.30.110:3942
192.168.40.5:41387 -> 192.168.30.110:3942
192.168.40.5:56946 -> 192.168.30.110:3942
192.168.40.5:55403 -> 192.168.30.110:3942
```

Each response advertised MediaServer:1 and the correct NAS description URL.
The router observed ingress from NAS and egress on vlan300-iot and ether4 to
Samsung Ethernet MAC 00:C3:F4:8B:7C:92. UDP checksums on egress were valid;
unicast TTL was 63. No Samsung connection to NAS TCP port 50001 appeared afterward.
Router egress alone does not prove application delivery, but restoration after
source-NAT strongly narrows the acceptance failure to source-address behavior.

The only NAS/TV HTTP exchange in that failing capture was the reverse direction:
NAS fetched Samsung's MediaRenderer endpoint /dmr on TCP port 9197 and received HTTP 401.
That is not the TV fetching the NAS MediaServer description, and is not evidence
of a failed DLNA login to Pulsar.

## Cause: established behavior versus inferred implementation

Established: Samsung accepts discovery after the NAS response source is changed
to an address on its local subnet. NAS LOCATION remains cross-subnet and usable;
playback and seeking work. Multicast routing, unicast forwarding and tested TTL
changes alone do not explain the restored behavior.

Most likely cause: this Samsung firmware applies a same-subnet acceptance check
to the SSDP response source. The exact internal comparison was not observed in
firmware source or documented for this model. Source-NAT also changes the visible
sender identity, so the precise implementation must remain an inference.
Do not claim that all Samsung televisions share this behavior or that DLNA
universally prohibits routed discovery.

## Diagnostic mistakes and contributing factors

During my investigation, the AI assistant configured a capture limited to
`udp port 1900` and incorrectly concluded that the NAS did not respond.
This was incorrect: discovery requests target port 1900, but Media Server replies here
use ephemeral source ports and target Samsung port 3942. Neither end of the reply
matches port 1900. The corrected capture directly disproved the no-response premise.
Upstream libupnp 1.12.1 creates a fresh response socket and sends without binding
source port 1900, consistent with observed behavior, but the wire capture is decisive.

The assistant also treated an iPhone response from NAS UDP port 1900 as DLNA response
proof. Its LOCATION used DSM port 5000, so it belonged to DSM discovery; the
DLNA endpoint is 50001. iPhone could learn the DLNA server from advertisements.

The first unrestricted capture used a 4 MiB scrolling buffer. By the time it was
saved, the available fragment lacked the reboot/search. That absence could not
support a no-response conclusion. The corrected capture used 64 MiB with scrolling
disabled, was saved promptly and contained the search and response sequence.

Repeated generic firewall, reverse-path, TTL and reboot checks prolonged the
investigation after working LG/iPhone paths were already known. These checks
provided some exclusions but did not replace a complete request/response trace.
An independent model review identified the omitted reply-port path.

Router captures repeat packets across physical, bridge and VLAN interfaces.
These copies were not proof of retransmissions. Hardware offload also limits
which physical-port copies appear; an absent copy on syno1 was not proof that
NAS failed to receive a routed multicast request.

## Recovery and permanent configuration

Temporary recovery source-NATed only NAS UDP responses destined to the observed
Samsung port 3942, outgoing vlan300-iot, to 192.168.30.1. This changes discovery
sender identity while leaving HTTP/media endpoints and traffic untouched.

Permanent ownership:

- [07-address-lists.rsc](../../network/mikrotik-rb5009upr/07-address-lists.rsc): static SSDP-SUBNET-CLIENTS entries for 192.168.30.107 and 192.168.30.110.
- [08-firewall-nat.rsc](../../network/mikrotik-rb5009upr/08-firewall-nat.rsc): NAS 192.168.40.5 -> listed clients, UDP destination port 3942, outgoing interface vlan300-iot, source NAT to 192.168.30.1.
- [10-dhcp.rsc](../../network/mikrotik-rb5009upr/10-dhcp.rsc): Wi-Fi 8C:79:F5:A5:C6:E8 -> 192.168.30.107 and Ethernet 00:C3:F4:8B:7C:92 -> 192.168.30.110.
- [19-samsung-ssdp.rsc](../../network/mikrotik-rb5009upr/19-samsung-ssdp.rsc): minimal idempotent import of the same objects, adopting the working temporary NAT rule.

I applied file 19. Other core files did not need to be reimported for this fix.
I had already removed the ineffective TTL experiment. The exact-identity
cleanup in file 19 is harmless when that rule is absent.

Limitations: destination port 3942 is observed, not guaranteed by SSDP. If it changes,
recapture and update the narrow rule; do not broadly NAT all NAS-to-IoT traffic.
The list is presently for VLAN 300 only. Moving a listed client to another VLAN
requires its own gateway/interface policy. IPv6 behavior was not investigated.

To undo only this workaround, disable the exact permanent NAT rule; Samsung
cross-subnet discovery is expected to fail again. Preserve working management
access and avoid restoring an entire router backup for this single exception.
DHCP/list rollback should use saved prior state if their removal is necessary.
See [operational runbook](../../network/mikrotik-rb5009upr/ssdp-pim.md).

## Prevention and follow-up

| Action | Owner | Status / acceptance |
|---|---|---|
| Reserve both MAC/IP pairs and use explicit client list | Administrator, with AI assistance | Configuration prepared and imported |
| Keep narrow source-NAT exception in core and minimal import | Administrator, with AI assistance | Completed in source |
| Verify permanent live leases, list, one NAT rule and both interfaces | Administrator | I have not recorded a post-import verification |
| Check discovery, playback and seeking separately | Administrator | Temporary Ethernet all confirmed; Wi-Fi discovery confirmed; permanent acceptance pending |
| Capture all UDP involving target client, not only port 1900 | Troubleshooting procedure | Documented requirement |
| Distinguish DSM port 5000 from DLNA port 50001 and client/server direction | Troubleshooting procedure | Documented requirement |
| Use adequate capture buffer and verify search exists before conclusions | Troubleshooting procedure | Documented requirement |
| Revalidate response port after Samsung firmware/network changes | Administrator | Ongoing operational requirement |

## Source and evidence retention

Evidence consists of my connectivity and playback tests, NAS tcpdump output,
read-only router inspection and router captures analysed during troubleshooting. Raw captures stay outside
Git; this document retains only the necessary packet facts. Exact service
restoration timestamps were not reconstructed from unrelated packet times.

Primary reference for the reply-socket behavior:
[upstream libupnp 1.12.1 ssdp_device.c](https://github.com/pupnp/pupnp/blob/release-1.12.1/upnp/src/ssdp/ssdp_device.c).
Upstream source is explanatory evidence; it does not establish an unmodified
Synology implementation. Observed ephemeral-port replies establish actual behavior.
