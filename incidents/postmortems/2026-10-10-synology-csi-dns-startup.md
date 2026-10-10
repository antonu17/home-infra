# Home Assistant and Matter storage mounts failed after CSI DNS startup failure

- Date: 2026-10-10; timezone: Europe/Berlin (CEST, UTC+02:00).
- Status: resolved; recovery confirmed by the operator.
- Customer: Anton. Outage onset, recovery time and total duration are unknown.

## Customer impact

`home-assistant/home-assistant-0` and `home-assistant/matter-server-0` could not
mount their persistent volumes and were reported `0/1 Unknown`. The workloads
were unavailable, affecting the customer's Home Assistant and Matter services.
No evidence establishes data loss or the full effect on individual devices.

## Confirmed failure and remaining uncertainty

Worker-02's CSI plugin failed DSM registration during startup because DNS
resolution of `pulsar.home.antonu.org` timed out. Subsequent `NodeStageVolume`
requests reported `Volume[...] is not found` before iSCSI login.

The LUNs were present and healthy. The error described failure to find them
through the driver's DSM lookup, not proof that the storage had been deleted.

The DNS timeout's underlying cause is unresolved. The available evidence does
not identify MikroTik filtering, CoreDNS, Cilium, NAS migration or an upstream
resolver as its cause. Whether DNS remained unavailable until recovery is also
not documented. Do not turn a hypothesis into a recorded root cause.

## Evidence and timeline

- 19:02:34 CEST (17:02:34Z): worker-02's plugin logged `Failed to add DSM` /
  `Failed to login to DSM` followed by `lookup pulsar.home.antonu.org: i/o timeout`.
  This is a known failure timestamp, not the proven customer outage onset.
- The supplied log excerpt showed repeated failed mounts from 20:58:18 through
  21:18:39 CEST. Requests correctly named `pulsar.home.antonu.org`.
- CSI controller and all three worker node plugins were running/ready. The
  affected plugin was `synology-csi-node-458jp` on `talos-worker-02` (`192.168.40.41`).
- Kubernetes showed both relevant VolumeAttachments as attached to worker-02.
  Controller attachment did not establish successful node staging/mounting.
- SAN Manager showed six healthy LUNs and four connected targets. The two affected
  targets were Ready without active connections.
- The operator subsequently reported `problem solved`. Exact recovery commands
  and the recovery timestamp were not supplied.

Affected identities:

| Workload | PV | CSI volume handle |
|---|---|---|
| Home Assistant | `pvc-65ec9714-8218-4320-b5b0-e486275b60b2` | `537fdeac-3950-4538-8117-25113b2cffa5` |
| Matter Server | `pvc-89f7f5ce-ca2f-4a38-a91c-585f61a8384e` | `45229bf4-be20-489c-a18f-63f96fee344f` |

## Recovery procedure proposed and confirmed outcome

The proposed procedure was to verify hostname resolution from the affected CSI
container, expecting `192.168.40.5`, then recreate only worker-02's CSI DaemonSet
pod to retry DSM registration. Kubelet could then retry mounting automatically.
The operator confirmed recovery afterward; execution of those exact steps and
post-recovery DNS results were not independently captured.

No recommendation was made to delete/recreate PVCs, PVs, VolumeAttachments or
NAS LUNs. No infrastructure mutation was executed by the agent.
The attempted curl diagnostic failed because curl was absent from the CSI image;
that was a tooling limitation, unrelated to the storage failure.

## Lessons and follow-up

- Running/ready CSI pods and `ATTACHED=true` do not prove working storage access.
- Inspect startup logs as well as recent mount retries. The recent250-line excerpt
  repeated the symptom; filtering the earlier logs exposed failed DSM registration.
- Confirm DNS/DSM access and LUN existence before altering storage or firewall
  rules. Nodes and NAS use VLAN400; bridged IP firewall was disabled, so no evidence
  supported a routed firewall change for this failure.
- For recurrence, capture the affected pod's resolver configuration, current DNS
  results, DSM registration errors and node placement before restarting it.
- Outstanding: identify the original DNS timeout cause and assess driver startup
  recovery/readiness behavior. No monitoring change or driver upgrade was deployed.

References: [repository CSI configuration](../../kubernetes/synology-csi/README.md),
[storage runbook](../../docs/talos-cluster.md), and
[driver v1.3.1 lookup before iSCSI login](https://github.com/SynologyOpenSource/synology-csi/blob/v1.3.1/pkg/driver/nodeserver.go#L252).
