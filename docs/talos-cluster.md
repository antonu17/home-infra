# Talos home-cloud cluster

## Current architecture — operator evidence 2026-10-10

The operator supplied node, CSI and Argo status; the agent did not query live
infrastructure. All four nodes were Ready at Talos `v1.14.2`, Kubernetes
`v1.37.1`, kernel `6.18.54-talos`, containerd `2.3.6`.

| Component | Recorded state |
|---|---|
| Nodes | One control plane and three workers: two AMD64 Synology VMs and two ARM64 Raspberry Pis |
| Networking | Cilium `1.20.2`, eBPF kube-proxy replacement, no Flannel/kube-proxy |
| Storage | Synology CSI `v1.3.1`; controller on worker-01, node plugins on all three workers |
| Provisioning | RouterOS DHCP/TFTP, NAS-hosted Image Factory and installer registry |
| GitOps | Root `gitops`; Cilium, CSI, Argo, Gateway, cert-manager, ESO and workloads Synced/Healthy |
| Open issue | ExternalDNS Synced/Progressing; controller crash loop awaiting local webhook `/records` |

See [topology](network-topology.svg), [addressing](addressing.md),
[PXE](pxe.md), [Image Factory / registry](talos-mirror.md) and
[GitOps](gitops.md). There is **one etcd member, no control-plane redundancy**.
Control-plane VM and worker-01 share the NAS; the two physical workers add
compute independence, but their Synology LUNs still share the NAS failure domain.

## Addressing

| Purpose | Address | Platform / MAC |
|---|---|---|
| Kubernetes API VIP | `192.168.40.20` (`k8s.home.antonu.org`) | Owned by the current control plane |
| `talos-cp-01` | `192.168.40.21` | AMD64 VM / `02:11:32:28:5A:95` |
| `talos-worker-01` | `192.168.40.40` | AMD64 VM / `02:11:32:2E:F4:1B` |
| `talos-worker-02` | `192.168.40.41` | Pi 4 ARM64, ether6 / `DC:A6:32:2F:57:C3` |
| `talos-worker-03` | `192.168.40.42` | Quantum Pi 5 ARM64, ether5 / `2C:CF:67:1B:D6:FE` |

The original VM profiles were 2 vCPUs/4 GiB/34 GB for cp-01 and 8 GiB/34 GB
for worker-01, with `ens3` and `/dev/sda`. These are historical VM allocations,
not Raspberry Pi hardware profiles. All nodes use Home Cloud DHCP reservations.
The `.22`/`.23` nodes and BGP peers are retired; their patches no longer exist.

Kubernetes clients use `https://k8s.home.antonu.org:6443`. Talos management
uses `.40.21:50000`, **not the API VIP**. `-e` chooses the contacted endpoint;
`-n` chooses the target node. Explicitly specify both for maintenance.
Load `KUBECONFIG` and `TALOSCONFIG` through repository direnv; do not override them
with a second configuration path.

## Source configuration and secrets

| Path | Role |
|---|---|
| `talos/image-factory/schematic-amd64.yaml` | Normal schematic source, including iSCSI extension |
| `talos/image-factory/schematic-amd64.id` | Derived normal schematic ID |
| `talos/image-factory/schematic-amd64-wipe.{yaml,id}` | Separate destructive reprovisioning schematic |
| `talos/image-factory/schematic-rpi4.yaml` | Normal Raspberry Pi 4 schematic with iSCSI support |
| `talos/image-factory/schematic-rpi4-raspbee.{yaml,id}` | Raspberry Pi 4 schematic with the serial console removed for RaspBee II UART access |
| `talos/patches/cilium.yaml` | Delete Flannel document; set KubeProxyConfig enabled=false |
| `talos/patches/cp-01.yaml` | VM DHCP, API VIP and control-plane hostname |
| `talos/patches/worker-01.yaml` | Worker hostname |
| `talos/patches/worker-02.yaml` | Physical Raspberry Pi worker hostname and persistent hardware/workload labels |
| `talos/patches/worker-03.yaml` | Quantum hostname and storage/RaspBee labels |
| `talos/custom-rpi5/` | Custom AXI kernel and boot/installer lineage; stock upgrades can remove support |
| `talos/patches/worker-02-install.yaml`, `worker-03-install.yaml` | Destructive fresh-install disk selectors; not ordinary config/upgrade patches |
| `talos/secrets/home-cloud.yaml` | Persistent, sensitive cluster identity input |
| `talos/generated/` | Disposable generated configs and client credentials |
| `kubernetes/cilium/values.yaml` | Actual Cilium Helm settings |

`.gitignore` now excludes `talos/generated/`, `talos/secrets/`,
`.private/`. Deployment credentials now belong in Vault; see
[secret management](secret-management.md). Review staged changes
before committing; ignore rules do not remove already tracked secrets. Secret
contents were not inspected. Review archived configs/backups as sensitive too.

Back up persistent cluster secrets securely outside this NAS failure domain.
Disposable outputs are recoverable only when their source patches and secrets
are retained. Never generate a fresh identity for an existing cluster.

The original working identity was extracted **once** from an existing working
control-plane config:

```sh
# Historical recovery operation; set WORKING_CP_CONFIG to a private file first.
# Do not overwrite an existing secrets file.
talosctl gen secrets \
  --from-controlplane-config "${WORKING_CP_CONFIG:?Set the working control-plane config path}" \
  -o talos/secrets/home-cloud.yaml
```

Subsequent regeneration always uses `--with-secrets`. A regenerated talosconfig
was tested successfully against the existing cluster during implementation.

## Local configuration regeneration — no live changes

Run from the repository root with Talos CLI 1.14.2 and direnv loaded. Use the
existing persistent cluster secrets; never generate a new cluster identity.
This example generates **AMD64 VM configs only** into a new private directory.
Pi workers require their architecture-specific installer/disk choices; Quantum
requires its custom build and boot constraints. Do not apply its wipe patch
as an ordinary configuration update.

```sh
umask 077
test -s talos/secrets/home-cloud.yaml || exit 1
talosctl version --client
mkdir -p talos/generated
TALOS_REVIEW_DIR=$(mktemp -d "$PWD/talos/generated/review.XXXXXX")
mkdir "$TALOS_REVIEW_DIR/nodes"
SCHEMATIC=$(tr -d '\r\n' < talos/image-factory/schematic-amd64.id)
TALOS_INSTALLER="registry.home.antonu.org/talos/metal-installer/${SCHEMATIC}:v1.14.2"
talosctl gen config home-cloud https://k8s.home.antonu.org:6443 \
  --with-secrets talos/secrets/home-cloud.yaml \
  --talos-version v1.14.2 --kubernetes-version 1.37.1 \
  --install-disk /dev/sda --install-image "$TALOS_INSTALLER" \
  --config-patch-control-plane @talos/patches/cilium.yaml \
  --config-patch-worker @talos/patches/cilium.yaml \
  --output "$TALOS_REVIEW_DIR" --with-docs=false --with-examples=false \
  --with-cluster-discovery=false

talosctl machineconfig patch "$TALOS_REVIEW_DIR/controlplane.yaml" \
  --patch @talos/patches/cp-01.yaml --output "$TALOS_REVIEW_DIR/nodes/cp-01.yaml"
talosctl machineconfig patch "$TALOS_REVIEW_DIR/worker.yaml" \
  --patch @talos/patches/worker-01.yaml --output "$TALOS_REVIEW_DIR/nodes/worker-01.yaml"
talosctl validate --config "$TALOS_REVIEW_DIR/nodes/cp-01.yaml" --mode metal
talosctl validate --config "$TALOS_REVIEW_DIR/nodes/worker-01.yaml" --mode metal
```

These commands create sensitive local files. Review them privately against the
existing node configuration; generation is not permission to replace or apply it.
No `apply-config`, `bootstrap`, endpoint rewriting or kubeconfig replacement
belongs in this local regeneration sequence. For a genuinely fresh installation,
first review the exact node/disk and preserved identity, then use a separate
operator-run provisioning procedure. Never bootstrap an intact existing cluster.

## Talos 1.14 multi-document networking

Configs include separate `HostnameConfig`, `KubeNetworkConfig`,
`KubeProxyConfig`, `KubeFlannelCNIConfig` and `UnattendedInstallConfig`
documents. Preserve this structure and inspect the generated installer
document rather than assuming the old `machine.install.image` layout.

The committed Cilium patch contains these two documents:

```yaml
apiVersion: v1alpha1
kind: KubeFlannelCNIConfig
$patch: delete
---
apiVersion: v1alpha1
kind: KubeProxyConfig
enabled: false
```

`KubeProxyConfig.disabled: true` was invalid. Deleting that document alone did
not stop proxy deployment. The current source explicitly uses `enabled: false`;
the earlier `cluster.proxy.disabled` approach is historical.
Do not combine the old `cluster.network.cni.name: none` pattern with these
new network documents: that produced conflicts during implementation.
Each node patch supplies `HostnameConfig` with `auto: off`.

## Cilium

The current values configure Kubernetes IPAM, kube-proxy replacement and
KubePrism at `localhost:7445`. They disable automatic cgroup mounting, use
`/sys/fs/cgroup`, set `bpf.hostLegacyRouting: true`, and explicitly list
Talos-compatible capabilities. Keep the checked-in values authoritative.

Cilium is now Argo-owned: the operator reported `cilium` Synced/Healthy on
2026-10-10. Its source renders the pinned chart through Kustomize `helmCharts`
from `https://helm.cilium.io/`, plus local BGP/IPAM/Gateway resources. Review
Git changes and manually sync `cilium`; do not alternate Helm upgrades and direct
applies with Argo. Fresh-cluster bootstrap is covered in [GitOps](gitops.md).

Control-plane bootstrap preceded Cilium installation. Nodes/CoreDNS became
healthy after Cilium was installed. Read-only checks:

```sh
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
kubectl -n kube-system get daemonsets
```

Expect Cilium, healthy CoreDNS, and no Flannel or kube-proxy DaemonSets.
The operator reports working BGP on all four nodes (ASN 65001), peering with
RB5009 `.40.1` (ASN 65000), and LB-IPAM pool `10.40.0.0/24`. Allocated Service
VIPs are advertised as /32 routes. The Kubernetes API VIP is separate.
The [Cilium adoption guide](../kubernetes/cilium/README.md) retains the historical
handoff and rollback procedure. Adoption is complete according to the operator's
Argo list; Gateway API CRDs are now in the Cilium source, not a second owner.

## Machine configuration versus installed image

- `talosctl apply-config` changes machine configuration. For an uninstalled
  maintenance node, that configuration can initiate its first installation.
- `talosctl upgrade --image ...` changes an already-installed Talos image.
- Merely changing the installer reference and applying config does **not**
  upgrade an installed node or activate a new system extension.

Configs were regenerated with persistent secrets so future rebuilds use the
local iSCSI-enabled installer. Existing nodes received rolling image upgrades;
they were not wiped. The Talos version stayed `v1.14.2` while the schematic
composition changed.

## Image upgrades — operator-run maintenance

Preserve an independent etcd backup and workload backups first. Check node/DNS,
Cilium, CSI and storage health before maintenance. Upgrade one reviewed worker
at a time, verify recovery, then schedule cp-01 maintenance with an API/etcd
outage: there is no second control-plane endpoint or quorum redundancy.

This example affects **AMD64 worker-01 `192.168.40.40` only** and changes its
installed image/reboots it. Load repository direnv first; review the installer
and workload drain constraints before running.

```sh
: "${TALOSCONFIG:?Load the repository direnv environment}"
: "${KUBECONFIG:?Load the repository direnv environment}"
SCHEMATIC=$(tr -d '\r\n' < talos/image-factory/schematic-amd64.id)
INSTALLER="registry.home.antonu.org/talos/metal-installer/${SCHEMATIC}:v1.14.2"
talosctl -e 192.168.40.21 -n 192.168.40.40 upgrade --image "$INSTALLER" --wait
talosctl -e 192.168.40.21 -n 192.168.40.40 get extensions
kubectl get nodes -o wide
kubectl -n synology-csi get pods -o wide
```

Drain can block on workload constraints; investigate rather than bypassing it.
Do not use deprecated `--force`. Pi 4 needs an ARM64 installer; Quantum needs
its custom kernel/installer lineage and known-working boot media. Neither uses
this AMD64 example. Follow [Quantum history](quantum-talos-build-history.md)
before any worker-03 image change. Never target retired `.22` or `.23`.

A complete shutdown causes downtime; restoration depends on the original cp-01
etcd state and NAS availability. **Never run `talosctl bootstrap` again because
an initialized cluster was powered off.** State loss requires a reviewed recovery
procedure, not an automatic bootstrap.

## Current persistent storage

Synology DS923+ / DSM 7.4.1-90080, RAID10 backing pool, Btrfs Volume 3
(300 GB; about 254 GB free at initial setup) hosts the iSCSI LUNs.
Those capacity figures are historical, not live monitoring.

`kubernetes/synology-csi/kustomization.yaml` deploys the pinned
`synology/synology-csi:v1.3.1` controller and node plugin and includes
`storageclass.yaml` and the namespaced ESO resources. The controller is pinned
to `talos-worker-01`; the node DaemonSet selects nodes labeled
`storage.home.antonu.org/synology-iscsi=true` (three ready instances on workers
01/02/03 observed on 2026-10-10; cp-01 is not labeled). Extension installation alone does not broaden that selector.

| StorageClass setting | Current value |
|---|---|
| Name / driver | `synology-block` / `csi.san.synology.com` |
| DSM identifier | `pulsar.home.antonu.org` |
| Location / protocol | `/volume3` / iSCSI |
| Filesystem inside LUN | ext4 (NAS backing filesystem remains Btrfs) |
| FUA / Sync Cache | Enabled |
| Reclaim policy | Retain |
| Binding | WaitForFirstConsumer |
| Expansion | Allowed; not yet tested |
| Default class | No |

The CSI controller uses DSM HTTPS/443 for management; the node uses TCP/3260
for iSCSI data. CSI runs in Kubernetes; SAN Manager/LUNs run on the NAS.
A dedicated DSM administrative account is stored in `client-info-secret`.
It is not restricted to Volume 3. TLS verification remains enabled.

The account configuration was copied into Vault at
`home-cloud/synology-csi/client-info` on 2026-10-04, preserving the live
`client-info.yml` bytes. ESO synchronization is declared under
`kubernetes/synology-csi/external-secrets`, included in the full `synology-csi`
Argo Application alongside the driver and StorageClass. Terraform was reported
applied; the operator reported `synology-csi` Synced/Healthy on 2026-10-10.
Follow the
[CSI adoption guide](../kubernetes/synology-csi/README.md).
The target remains `synology-csi/client-info-secret`; do not delete or recreate it.
PVCs, PVs and NAS LUNs retain their existing owners.
Vault is NAS-hosted and ESO is cluster-hosted; their dependencies overlap.
Preserve the retained Kubernetes Secret during outages and do not prune it or delete storage to troubleshoot auth.

IP-based HTTPS requests received HTTP 403 from the NAS frontend. Switching
the configured host to `pulsar.home.antonu.org` fixed routing and both driver
logins. `tlsServerName` alone did not change the HTTP Host header. Hostname
use was subsequently verified through volume creation and mounting.

The node plugin uses root/privileged host access, `--chroot-dir=/host`,
`--iscsiadm-path=/usr/local/sbin/iscsiadm`, and `--multipath=false`.
The chroot executable test returned `iscsiadm version 2.1.13`.
Overlay patches remove broad Secret-reading RBAC; their positional rule
indices must be reviewed when replacing vendor manifests. Old upstream
sidecars remain pinned: provisioner 3.0.0, attacher 3.3.0, resizer 1.3.0,
registrar 2.3.0. Working tests are not a complete compatibility/security audit.

### Validated and outstanding tests

The 2 GiB claim in `storage-test.yaml` successfully provisioned, attached,
mounted and accepted writes. The original timestamp survived both pod
replacement and a controlled worker reboot plus pod recreation.
No evidence of data loss was observed in these tests.

The test is a standalone Pod, not a Deployment. Node shutdown marked it
terminal; it needed manual recreation. Its manifest omits `restartPolicy`
(default Always); this does not create a controller to replace terminal Pods.
`ReadWriteOnce` is a single-node access mode, not guaranteed single-pod fencing.

The test PVC/LUN is retained. Deleting a retained claim does not automatically
clean up NAS storage; never delete unidentified LUNs. For continued Home Assistant and other stateful workload operation:
test backup restoration to a separate volume, establish off-NAS backups,
test expansion if required, and design controller-managed workload recovery.
Unexpected power loss and cross-worker failover have not been validated.
Snapshots on this NAS alone are not independent backups.

## Recent storage incident

On 2026-10-10, worker-02 could not stage Home Assistant/Matter LUNs despite
healthy NAS volumes and attached VolumeAttachments. CSI startup failed DSM login
because `pulsar.home.antonu.org` DNS lookup timed out, leaving DSM unregistered
while the plugin remained Running/Ready. The operator confirmed recovery; the
initial DNS timeout cause and exact recovery commands remain unknown.
See the [CSI postmortem](../incidents/postmortems/2026-10-10-synology-csi-dns-startup.md).
Inspect startup logs, name resolution and DSM registration before altering LUNs.

## Remaining work and limitations

Argo, Gateway, cert-manager, ESO and application adoption are deployed according
to the 2026-10-10 Argo list. Home Assistant and Matter recovered; both Pi workers
already joined the cluster. Synced/Healthy does not independently demonstrate
backup restoration, certificate renewal, every integration or completed legacy
service retirement. ExternalDNS is an active unresolved issue.

Inventory/API automation and independent storage remain future work. Do not
build nominally replicated Ceph from disks all hosted on this NAS and describe
it as independent fault tolerance. The operator reconfirmed Quantum is SD-dependent on 2026-10-10; standalone
NVMe boot remains unresolved. Fan follow-up remains subject to its build history.
