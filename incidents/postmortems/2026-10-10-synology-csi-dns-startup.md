# Home Assistant and Matter storage mounts failed after CSI DNS startup failure

- Date: 2026-10-10; timezone: Europe/Berlin (CEST, UTC+02:00).
- Status: resolved; I verified that the affected services recovered.
- Administrator: Anton. Outage onset, recovery time and total duration are unknown.

## Service impact

`home-assistant/home-assistant-0` and `home-assistant/matter-server-0` could not
mount their persistent volumes and showed `0/1 Unknown`. The workloads
were unavailable, affecting my Home Assistant and Matter services.
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
  This is a known failure timestamp, not the proven service outage onset.
- The logs I examined showed repeated failed mounts from 20:58:18 through
  21:18:39 CEST. Requests correctly named `pulsar.home.antonu.org`.
- CSI controller and all three worker node plugins were running/ready. The
  affected plugin was `synology-csi-node-458jp` on `talos-worker-02` (`192.168.40.41`).
- Kubernetes showed both relevant VolumeAttachments as attached to worker-02.
  Controller attachment did not establish successful node staging/mounting.
- SAN Manager showed six healthy LUNs and four connected targets. The two affected
  targets were Ready without active connections.
- I verified that the problem was resolved. I did not record the exact recovery
  commands or restoration timestamp.

Affected identities:

| Workload | PV | CSI volume handle |
|---|---|---|
| Home Assistant | `pvc-65ec9714-8218-4320-b5b0-e486275b60b2` | `537fdeac-3950-4538-8117-25113b2cffa5` |
| Matter Server | `pvc-89f7f5ce-ca2f-4a38-a91c-585f61a8384e` | `45229bf4-be20-489c-a18f-63f96fee344f` |

## Recovery procedure proposed and confirmed outcome

My recovery plan was to verify hostname resolution from the affected CSI
container, expecting `192.168.40.5`, then recreate only worker-02's CSI DaemonSet
pod to retry DSM registration. Kubelet could then retry mounting automatically.
I subsequently verified recovery, but did not retain a command transcript or
post-recovery DNS results. The record therefore does not establish which exact
steps restored service.

No recommendation was made to delete/recreate PVCs, PVs, VolumeAttachments or
NAS LUNs. The AI assistant provided diagnostic assistance without making live
infrastructure changes.
The attempted curl diagnostic failed because curl was absent from the CSI image;
that was a tooling limitation, unrelated to the storage failure.

## Lessons and follow-up

- Running/ready CSI pods and `ATTACHED=true` do not prove working storage access.
- Inspect startup logs as well as recent mount retries. The recent 250-line excerpt
  repeated the symptom; filtering the earlier logs exposed failed DSM registration.
- Confirm DNS/DSM access and LUN existence before altering storage or firewall
  rules. Nodes and NAS use VLAN 400; bridged IP firewall was disabled, so no evidence
  supported a routed firewall change for this failure.
- For recurrence, capture the affected pod's resolver configuration, current DNS
  results, DSM registration errors and node placement before restarting it.
- Outstanding: identify the original DNS timeout cause and assess driver startup
  recovery/readiness behavior. No monitoring change or driver upgrade was deployed.

References: [repository CSI configuration](../../kubernetes/synology-csi/README.md),
[storage runbook](../../docs/talos-cluster.md), and
[driver v1.3.1 lookup before iSCSI login](https://github.com/SynologyOpenSource/synology-csi/blob/v1.3.1/pkg/driver/nodeserver.go#L252).

## Follow-up: 2026-10-22

I confirmed that recreating the CSI node pod after reboot restored DSM
registration. This later confirmation supplements the original incomplete
recovery transcript; the underlying DNS timeout cause remains unknown.

The repository adds a DNS/DSM API startup gate to the node DaemonSet overlay.
See the [configuration and acceptance procedure](../../kubernetes/synology-csi/README.md#node-startup-gate).
Deployment and reboot acceptance remain pending; no live changes were executed.
