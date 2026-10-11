# ExternalDNS outage: router REST allow-list was empty

- Date: 2026-10-10; timezone: Europe/Berlin (CEST, UTC+02:00).
- Status: diagnosed; repository remediation prepared. Recovery unconfirmed.
- Customer: Anton. Outage onset, recovery time and total duration are unknown.

## Customer impact

ExternalDNS could not reconcile Kubernetes Gateway HTTPRoute names into
MikroTik DNS. Its controller and webhook were reported `0/2 CrashLoopBackOff`.
New or changed application DNS records could not be reliably published or
updated while reconciliation failed. Previously published records may have
continued resolving; no evidence establishes deletion of existing records,
a complete DNS outage, data loss or a specific application access failure.

Argo reported the Application Synced but Progressing. Resource synchronization
did not establish that the running DNS controller could reach its provider.

## Confirmed cause and limits of the diagnosis

The RouterOS input rule `ExternalDNS current HTTP REST` allows TCP80 to
`192.168.40.1` from Cloud interfaces only when the source belongs to
`EXTERNALDNS-EGRESS`. That address list was empty, so this allow rule could
never match. Its packet/byte counters were both zero. RouterOS `www` was
enabled on TCP80; the repository's Cilium policy allowed that exact IP/port.

A filtered router capture subsequently showed incoming TCP traffic from
worker-03 `192.168.40.42` to `192.168.40.1:80`, repeatedly using source port
45166. No return traffic appeared in the supplied excerpt. ExternalDNS Pod
`10.244.3.238` was scheduled on that worker. This establishes the router-visible
node source for this placement, consistent with node masquerading.

The missing allow-list entry is a confirmed firewall configuration defect and
matches the observed failure to connect. The repository has a terminal input
deny, but no supplied drop-counter or packet trace identifies the precise
live dropping rule. Post-fix success has not been supplied; credentials, user
address restrictions and subsequent provider errors remain unvalidated.
The exact time and change that introduced the empty-list condition are unknown.

## Failure path

ExternalDNS controller -> local webhook `127.0.0.1:8888/records` ->
MikroTik REST `192.168.40.1:80`.

The controller's timeout named the local webhook, masking the downstream
router connection as a possible cause. The webhook's startup logs stopped
after creating its MikroTik client. The packet capture then located traffic
at the router and revealed the source needed by the input rule.

Router REST is an **input-chain** service. Broadening inter-VLAN forward
rules would not repair this missing input permission. Binary RouterOS API
ports 8728/8729 are not the configured REST transport.

## Evidence and timeline

All clock times below are converted from supplied UTC log timestamps.
Packet-capture times are relative offsets, not wall-clock timestamps.

| Time / order | Evidence |
|---|---|
| 21:26:09 CEST (19:26:09Z) | Controller startup reported webhook provider `127.0.0.1:8888`. |
| 21:26:24 CEST (19:26:24Z) | Controller exited with `/records` request timeout while awaiting headers. This is a known failure time, not the outage onset. |
| Later operator check; wall-clock time unknown | `EXTERNALDNS-EGRESS` was empty; REST accept counter was 0; router HTTP service was enabled. |
| Later Pod status; wall-clock time unknown | `external-dns-68bd7748bc-xs2c5` was `0/2 CrashLoopBackOff`, 22 restarts, Pod IP `10.244.3.238`, node `talos-worker-03`. |
| 22:59:15 CEST (20:59:15Z) | Webhook v1.6.3 logged startup and MikroTik client creation; supplied excerpt showed no successful provider response. |
| First capture; wall-clock time unknown | Traffic was NAS `.40.5` to internet TCP80, not the router REST flow; it did not diagnose ExternalDNS. |
| Filtered capture; relative offsets 25.460–35.604s | Repeated inbound `.40.42:45166` -> `.40.1:80`, visible on ether5, bridge and VLAN400. Multiple interface rows represent observations of the same traffic, not separate connections. |
| After diagnosis; wall-clock time unknown | Source `.40.42` was added to repository configuration. Operator then authorized `.40.40` and `.40.41` as well to tolerate worker rescheduling. |
| End of available evidence | No successful post-change import, provider reconciliation or customer acceptance result was supplied. |

## Remediation

[`07-address-lists.rsc`](../../network/mikrotik-rb5009upr/07-address-lists.rsc)
now idempotently reconciles `EXTERNALDNS-EGRESS` entries for the three current
workers: `192.168.40.40`, `192.168.40.41` and `192.168.40.42`. The operator
explicitly approved this scheduling-resilient scope. Only `.42` was captured;
including the other workers assumes the same node-source behavior on them.

The existing file09 rule remains limited to Cloud ingress, TCP80 and exact
router destination `192.168.40.1`. No Cloud-subnet blanket permission, new
forward rule, Pod pinning, credentials change or Kubernetes manifest change
was made. Node-source permission is shared by other traffic masqueraded behind
those nodes; RouterOS cannot distinguish those Pods by the source IP alone.
Router API authentication and Cilium policy remain applicable.

The agent edited source/documentation only and ran local structural/whitespace
checks. It did not import the configuration, restart Pods or query live systems.

## Operator recovery and acceptance

Upload the reviewed updated file07, then perform these **operator-run** steps:

```routeros
/import file-name=07-address-lists.rsc
/ip firewall address-list print where list="EXTERNALDNS-EGRESS"
/ip firewall filter print stats where comment="ExternalDNS current HTTP REST"
```

No file09 import is required if its existing rule matches the documented source.
Allow normal container restart/backoff to retry, then inspect:

```sh
kubectl -n external-dns get pods -o wide
kubectl -n external-dns logs deployment/external-dns -c webhook --since=5m --tail=80
kubectl -n external-dns logs deployment/external-dns -c external-dns --since=5m --tail=80
```

Acceptance requires the REST accept counter to increase, both containers to
remain Ready without repeated failures, and a successful reconciliation cycle.
Verify a known existing Gateway HTTPRoute hostname against the intended router
resolver and expected Gateway VIP. Readiness or an increasing accept counter
alone does not prove correct DNS publication. Do not create a test record or
force reconciliation writes through a webhook GET as a read-only diagnostic.
Redact credentials and Authorization headers from any shared logs.

If requests still fail, correlate provider errors with RouterOS service/user
allowed-address restrictions, authentication and Cilium flow verdicts. Preserve
the known narrow rule instead of opening additional protocols speculatively.

Rollback: review and remove only the three exact `EXTERNALDNS-EGRESS` entries
introduced by this change, restoring any previous properties if they existed.
This restores the previous restriction and can reintroduce the outage. It does
not require removing DNS records, TXT ownership markers or resetting the firewall.

## Contributing factors and prevention

| Finding | Follow-up / acceptance | Status |
|---|---|---|
| An accept rule depended on an unpopulated list. | Keep required worker entries in reproducible file07, rather than a manual prerequisite. | Prepared in repository; live application unconfirmed |
| A single measured worker grant would fail after rescheduling. | Include all three current eligible workers; verify observed sources after worker or masquerading changes. | Prepared; operator-approved scope |
| Argo sync and health endpoints did not prove provider reconciliation. | Include a successful reconciliation and router-resolved hostname in post-network-change acceptance checks. | Documented; execution pending |
| Local webhook timeout obscured the downstream failure. | Collect both containers' logs and capture the exact REST destination before changing policy. | Used during diagnosis |
| Shared node SNAT limits workload-specific router filtering. | Document that node permissions are not per-Pod identity; revisit if networking or scheduling changes. | Documented |

The empty-list failure should be part of future firewall review: an allow rule
with a required address list is incomplete until that list has its intended
static members. Record the operator's actual recovery time and acceptance
results here before marking the incident resolved.
