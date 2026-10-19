# FlightAware feed stopped after USB-controller failure and PiAware capability denial

- Date: 2026-10-19; timezone: Europe/Berlin (CEST, UTC+02:00).
- Status: resolved; I verified sustained message forwarding to FlightAware.
- Administrator: Anton. Exact feed outage onset and total duration were not recorded.

## Service impact

The ADS-B receiver stopped forwarding aircraft data to FlightAware. The workload
initially lost its decoder when `talos-worker-02` failed, then remained unable to
forward after node recovery because PiAware's `faup1090` helper exited on every
connection attempt. The PiAware process itself stayed running, so the original
process-only probe did not expose the forwarding failure.

The worker failure also interrupted Home Assistant and Matter. Their persistent
volumes were not lost. This postmortem covers the ADS-B/FlightAware path; the
recurring CSI startup behavior is documented separately in the
[CSI DNS startup incident](2026-10-10-synology-csi-dns-startup.md).

## Infrastructure

The Nooelec NESDR SMArt v5 and the 480 GB Talos system disk are USB devices on a
Raspberry Pi 4. Both depend on its VIA VL805/806 xHCI controller. The ADS-B pod is
pinned to `talos-worker-02` because that node owns the receiver. It runs
`dump1090-fa`, PiAware and `fr24feed` as separate containers sharing the pod
network namespace.

PiAware reads the Beast feed from `127.0.0.1:30005`. Its `faup1090` helper starts
as root and uses FlightAware's `droproot` helper to switch to `nobody` before
processing data.

## Evidence and timeline

The earliest confirmed platform failure was 04:43 CEST. Earlier FlightAware feed
availability was not retained, so this timestamp is not treated as the exact
outage onset.

| Time (CEST) | Observation | What it establishes |
|---|---|---|
| 04:43:25 | USB device `3-1.4` disconnected and attempted to re-enumerate | A high-speed USB device was unstable immediately before controller failure |
| 04:43:34 | Raspberry Pi firmware transactions timed out; hwmon could not read throttling state and the ARM clock query failed | The fault was wider than one userspace container |
| 04:43:40 | VL805 xHCI reported `Host halt failed`, `host controller not responding` and `HC died` | The shared USB host controller failed |
| 04:43:40–04:43:41 | USB system disk `/dev/sda` disconnected with writes in flight; XFS on `/dev/sda4` reported metadata/log I/O errors and shut down | Loss of the USB controller removed Talos EPHEMERAL storage mounted at `/var` |
| 04:44:10 | Kubernetes marked worker-02 `NotReady` with `container runtime is down` | Kubelet could no longer use containerd state under `/var/lib` |
| Approximately 09:10 | A graceful Talos reboot stopped pods and cleanly unmounted both Synology LUNs, but stalled while finalizing the missing system-disk volumes | Normal shutdown could not complete while `/dev/sda` was absent |
| 09:21 | Worker-02 returned `Ready`; `/dev/sda` and XFS were available and the ADS-B pod became `3/3 Running` | Reboot recovered the controller and system disk |
| 09:21–09:24 | PiAware authenticated to FlightAware, but every `faup1090` attempt failed `setgroups(nobody,65534): Operation not permitted`, exited 45 and reported zero received/sent messages | Node recovery did not restore the FlightAware feed; the remaining fault was container privilege configuration |
| 09:29 | Worker-02's CSI node pod was recreated after DNS recovered; DSM registration succeeded and Home Assistant/Matter remounted their existing volumes | Collateral storage workloads recovered without deleting storage objects |
| 09:46 | Argo deployed commit `55e4d82`; the new ADS-B pod started with `SETGID` and `SETUID` | The declarative PiAware fix became live |
| 09:47–11:17 | PiAware counters increased from 5 to 1,461 received messages, with the same counts sent to FlightAware | Sustained end-to-end forwarding was restored |

Before the controller failure, USB device `3-1.4` had repeatedly disconnected and
re-enumerated, including descriptor errors `-71`. Its relationship to the
RTL-SDR is inferred from dump1090 restart timing and the node's attached hardware;
the failed controller no longer exposed a descriptor during diagnosis. After
reboot, dump1090 identified the expected Nooelec receiver and produced current
aircraft JSON.

## Causes and contributing factors

Two independent failures formed the outage:

1. **Confirmed platform failure:** the Raspberry Pi's VL805 xHCI controller
   stopped responding. This disconnected the USB Talos system disk, caused XFS
   to shut down `/var`, and made containerd unusable. The physical trigger is not
   established. Candidate causes include Pi power, USB power/cabling, the SSD
   enclosure, the repeatedly reconnecting receiver, or a controller/firmware
   defect. No retained evidence selects one of them.
2. **Confirmed workload defect:** the PiAware container dropped all Linux
   capabilities. `faup1090` requires `SETGID` and `SETUID` to switch to `nobody`;
   without them it exited before reading the Beast stream. The existing liveness
   check only required the parent `piaware` process, allowing an authenticated but
   non-forwarding feeder to report healthy.

The permission warnings for `/var/cache/piaware` did not cause the forwarding
failure. The decisive error was `droproot` failing `setgroups`, followed by
`faup1090` exit 45 and zero sent messages.

## Recovery and permanent configuration

The completed reboot restored `/dev/sda`, XFS, containerd, kubelet and the USB
receiver. Whether the final reboot transition completed from the requested Talos
sequence or additional physical intervention was not recorded. No filesystem
repair, reinstall, wipe or storage-object deletion was performed.

[The ADS-B Deployment](../../kubernetes/apps/adsb/deployment.yaml) now grants the
PiAware container only `SETGID` and `SETUID` in addition to dropping all other
capabilities. Startup, readiness and liveness probes require both `piaware` and
`faup1090`. The configuration remains Argo-owned and was deployed through commit
`55e4d82`.

Validation established:

- worker-02 was `Ready`, with `/dev/sda` present over USB;
- no new xHCI, XFS or block I/O errors appeared after reboot;
- the ADS-B pod was `3/3 Running` with no container restarts;
- dump1090 opened the expected receiver and produced aircraft data;
- PiAware established an encrypted FlightAware session without the `setgroups`
  failure; and
- received and sent message counters increased together for at least 90 minutes.

## Prevention and follow-up

| Action | Status / acceptance |
|---|---|
| Grant only `SETGID` and `SETUID` to PiAware | Deployed and forwarding verified |
| Require `faup1090` in startup/readiness/liveness probes | Deployed; pod reports Ready with helper running |
| Verify forwarding by increasing received/sent counters rather than process state | Added to the ADS-B runbook and used for acceptance |
| Inspect Pi power supply, USB cabling, SSD enclosure and RTL-SDR connection | Pending; controller-failure trigger remains unknown |
| Monitor worker readiness, xHCI failure and repeated USB re-enumeration | Pending |
| Reassess USB power/isolation if disconnects recur | Pending; a powered hub may reduce device power load but does not create an independent controller failure domain |
| Improve Synology CSI startup recovery after transient DNS failure | Pending; tracked by the existing CSI incident |

## Evidence retention

Evidence consists of Kubernetes state/events and logs, Talos service, block-device,
volume and kernel output, the rendered ADS-B manifest, and post-sync PiAware
counters. Secret payloads and raw credential-bearing configuration remain outside
Git. The physical USB failure cause and exact outage boundaries were not inferred
from the successful recovery.
