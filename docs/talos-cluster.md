# Talos home-cloud cluster

## Current architecture

Reconciled on 2026-10-01 from repository configuration and the operator's
implementation handoff; this documentation update did not query the live lab.

| Component | Implemented state |
|---|---|
| Talos / Kubernetes | `v1.14.2` / `v1.37.1` |
| Nodes | Three control planes and one worker, all Synology VMM guests; reported Ready |
| Networking | Cilium `1.20.2`, CNI and eBPF kube-proxy replacement |
| Removed components | Flannel and kube-proxy |
| Storage | Synology CSI `v1.3.1`, working iSCSI persistent volumes |
| Provisioning | RouterOS DHCP/TFTP, local Image Factory, local installer registry |
| Extensions | `siderolabs/iscsi-tools` installed on all four nodes after rolling upgrades |

See [topology](network-topology.svg), [addressing](addressing.md),
[PXE](pxe.md) and [Image Factory / registry](talos-mirror.md).
Three etcd members provide quorum resilience to one member being unavailable,
**not independent physical HA**: all guests and their storage share one NAS.

## Addressing

| Purpose | Address | MAC address |
|---|---|---|
| Kubernetes API VIP | `192.168.40.20` (`k8s.home.antonu.org`) | Elected control-plane owner |
| `talos-cp-01` | `192.168.40.21` | `02:11:32:28:5A:95` |
| `talos-cp-02` | `192.168.40.22` | `02:11:32:25:8E:20` |
| `talos-cp-03` | `192.168.40.23` | `02:11:32:22:49:65` |
| `talos-worker-01` | `192.168.40.40` | `02:11:32:2E:F4:1B` |

The CP VMs were provisioned with 2 vCPUs, 4 GiB RAM and 34 GB `/dev/sda`;
the worker has 8 GiB RAM and a 34 GB system disk. NIC `ens3` uses RouterOS
DHCP reservations on VLAN 400. All three CP patches include the shared VIP.

Kubernetes clients use `https://k8s.home.antonu.org:6443`. Talos management
uses actual CP endpoints `.21,.22,.23` on TCP/50000, **not the API VIP**.
`-e` chooses the contacted Talos endpoint; `-n` chooses the target node.
Always specify `-n` for maintenance: saved defaults can target multiple nodes.

## Source configuration and secrets

| Path | Role |
|---|---|
| `talos/image-factory/schematic-amd64.yaml` | Normal schematic source, including iSCSI extension |
| `talos/image-factory/schematic-amd64.id` | Derived normal schematic ID |
| `talos/image-factory/schematic-amd64-wipe.{yaml,id}` | Separate destructive reprovisioning schematic |
| `talos/patches/cilium.yaml` | Disable proxy deployment and remove legacy CNI documents |
| `talos/patches/cp-01.yaml`, `cp-02.yaml`, `cp-03.yaml` | DHCP, common VIP and individual hostname |
| `talos/patches/worker-01.yaml` | Worker hostname |
| `talos/secrets/home-cloud.yaml` | Persistent, sensitive cluster identity input |
| `talos/generated/` | Disposable generated configs and client credentials |
| `kubernetes/cilium/values.yaml` | Actual Cilium Helm settings |

**Security gap found during documentation review:** `.gitignore` excludes
`talos/generated/`, but does not cover `talos/secrets/` or
`kubernetes/storage/synology-csi/secret/`. Both directories are untracked.
Do not use `git add .`. Establish ignore/encryption rules before committing;
review any archived configs/backups as potentially sensitive too. This docs-only
update did not inspect secret contents or change ignore rules.

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

## Safe regeneration

Run from the repository root with Talos CLI 1.14.2. Check
`talosctl version --client` first: `mise.toml` currently has both
`talos = "1.14.2"` and `talosctl = "1.14.1"`; command resolution must be
reconciled by the operator. The commands below were checked against the
installed 1.14.2 CLI help, not executed against the cluster.

Generate into a **new review directory**, preserving existing outputs:

```sh
umask 077
test -s talos/secrets/home-cloud.yaml || exit 1
SCHEMATIC=$(tr -d '\r\n' < talos/image-factory/schematic-amd64.id)
INSTALLER="registry.home.antonu.org/talos/metal-installer/${SCHEMATIC}:v1.14.2"
REGEN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/home-cloud-config.XXXXXX")
talosctl gen config home-cloud https://k8s.home.antonu.org:6443 \
  --with-secrets talos/secrets/home-cloud.yaml \
  --talos-version v1.14.2 --kubernetes-version 1.37.1 \
  --install-disk /dev/sda --install-image "$INSTALLER" \
  --config-patch @talos/patches/cilium.yaml \
  --output "$REGEN_DIR" --with-docs=false --with-examples=false

for NODE in cp-01 cp-02 cp-03; do
  talosctl machineconfig patch "$REGEN_DIR/controlplane.yaml" \
    --patch "@talos/patches/${NODE}.yaml" \
    --output "$REGEN_DIR/talos-${NODE}.yaml"
done
talosctl machineconfig patch "$REGEN_DIR/worker.yaml" \
  --patch @talos/patches/worker-01.yaml \
  --output "$REGEN_DIR/talos-worker-01.yaml"

for NODE in cp-01 cp-02 cp-03 worker-01; do
  talosctl validate --config "$REGEN_DIR/talos-${NODE}.yaml" --mode metal
done
talosctl --talosconfig "$REGEN_DIR/talosconfig" \
  -e 192.168.40.21 -n 192.168.40.21 version
```

These commands create sensitive local outputs; do not publish their contents.
Review privately before replacing files under `talos/generated/home-cloud/`.
The final command checks authentication, not full configuration equivalence.
Regeneration is not an instruction to apply every generated file.

For initial provisioning only: inspect the maintenance node's disks, confirm
the installation disk is disposable, then explicitly apply the reviewed
per-node config to that node. It installs to disk; later boots normally use
that disk. Workers and additional CPs join the existing cluster; do not
bootstrap each node.

## Talos 1.14 multi-document networking

Configs include separate `HostnameConfig`, `KubeNetworkConfig`,
`KubeProxyConfig`, `KubeFlannelCNIConfig` and `UnattendedInstallConfig`
documents. Preserve this structure and inspect the generated installer
document rather than assuming the old `machine.install.image` layout.

The committed Cilium patch uses all three operations:

```yaml
cluster:
  proxy:
    disabled: true
---
apiVersion: v1alpha1
kind: KubeProxyConfig
$patch: delete
---
apiVersion: v1alpha1
kind: KubeFlannelCNIConfig
$patch: delete
```

`KubeProxyConfig.disabled: true` was invalid. Deleting that document alone did
not stop proxy deployment; `cluster.proxy.disabled` is the switch used.
Do not combine the old `cluster.network.cni.name: none` pattern with these
new network documents: that produced conflicts during implementation.
Each node patch supplies `HostnameConfig` with `auto: off`.

## Cilium

The current values configure Kubernetes IPAM, kube-proxy replacement and
KubePrism at `localhost:7445`. They disable automatic cgroup mounting, use
`/sys/fs/cgroup`, set `bpf.hostLegacyRouting: true`, and explicitly list
Talos-compatible capabilities. Keep the checked-in values authoritative.

The reproducible installation/update command uses the **OCI chart**, not
`helm repo add`. This is a cluster-changing command; review before running:

```sh
export KUBECONFIG="$PWD/talos/generated/home-cloud/kubeconfig"
helm upgrade --install cilium oci://quay.io/cilium/charts/cilium \
  --version 1.20.2 --namespace kube-system \
  --values kubernetes/cilium/values.yaml
```

Control-plane bootstrap preceded Cilium installation. Nodes/CoreDNS became
healthy after Cilium was installed. Read-only checks:

```sh
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
kubectl -n kube-system get daemonsets
```

Expect Cilium, healthy CoreDNS, and no Flannel or kube-proxy DaemonSets.
Cilium BGP Control Plane, LB-IPAM pools and MikroTik eBGP peering are **not
configured**. The Kubernetes API VIP is separate from future service LB IPs.

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

## Rolling image upgrade

Before starting, verify cluster health, preserve a recoverable etcd backup and
plan workload interruption. The single worker hosts CSI as well as workloads.
The successful sequence was worker canary first, then CPs **one at a time**.

```sh
SCHEMATIC=$(tr -d '\r\n' < talos/image-factory/schematic-amd64.id)
INSTALLER="registry.home.antonu.org/talos/metal-installer/${SCHEMATIC}:v1.14.2"
talosctl --talosconfig talos/generated/home-cloud/talosconfig \
  -e 192.168.40.21 -n 192.168.40.40 \
  upgrade --image "$INSTALLER" --wait
talosctl --talosconfig talos/generated/home-cloud/talosconfig \
  -e 192.168.40.21 -n 192.168.40.40 get extensions
kubectl get nodes -o wide
```

The upgrade lifecycle performs drain, image retrieval/installation, reboot,
post-checks and uncordon. Drain can block on workload constraints; investigate
rather than bypassing it. Do not use deprecated `--force`.

After the canary is healthy, repeat for `.21`, then `.22`, then `.23`,
waiting and checking etcd health/node readiness between each. Use another
healthy CP endpoint when upgrading the endpoint itself (for example `-e .22`
with the full IP while targeting `.21`). Do not run these CP upgrades in
parallel. Check extensions and Cilium/CSI recovery after maintenance.

Three etcd members require two for quorum. A planned complete shutdown is
possible with downtime: one returning member has no quorum, two restore it,
three restore full membership, assuming their existing state is intact.
**Never run `talosctl bootstrap` again just because the initialized cluster
was powered off.** Actual state loss requires a separate recovery procedure.

## Current persistent storage

Synology DS923+ / DSM 7.4.1-90080, RAID10 backing pool, Btrfs Volume 3
(300 GB; about 254 GB free at initial setup) hosts the iSCSI LUNs.
Those capacity figures are historical, not live monitoring.

`kubernetes/storage/synology-csi/kustomization.yaml` deploys the pinned
`synology/synology-csi:v1.3.1` controller and node plugin and includes
`storageclass.yaml`. Both components are still selected onto
`talos-worker-01`: installing the extension on all four nodes does not broaden
CSI placement. Review the selector before scheduling storage consumers elsewhere.

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
clean up NAS storage; never delete unidentified LUNs. Before HA migration:
test backup restoration to a separate volume, establish off-NAS backups,
test expansion if required, and design controller-managed workload recovery.
Unexpected power loss and cross-worker failover have not been validated.
Snapshots on this NAS alone are not independent backups.

## Planned, not deployed

- Cilium LB-IPAM and BGP Control Plane; eBGP to MikroTik.
- Home Assistant migration from HAOS and migration of quantum-infra services.
- Freed Raspberry Pis as Talos nodes, additional workers and inventory/API.
- Ceph/Rook only if independent local disks/failure domains become available.

Do not build a nominally replicated Ceph cluster from VMs whose disks all
reside on this same NAS and describe it as fault-domain-independent storage.
