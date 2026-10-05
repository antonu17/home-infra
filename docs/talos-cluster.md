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
| `talos/image-factory/schematic-rpi4.yaml` | Normal Raspberry Pi 4 schematic with iSCSI support |
| `talos/image-factory/schematic-rpi4-raspbee.{yaml,id}` | Raspberry Pi 4 schematic with the serial console removed for RaspBee II UART access |
| `talos/patches/cilium.yaml` | Disable proxy deployment and remove legacy CNI documents |
| `talos/patches/cp-01.yaml`, `cp-02.yaml`, `cp-03.yaml` | DHCP, common VIP and individual hostname |
| `talos/patches/worker-01.yaml` | Worker hostname |
| `talos/patches/worker-02.yaml` | Physical Raspberry Pi worker hostname and persistent hardware/workload labels |
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

## Safe regeneration

Run from the repository root with Talos CLI 1.14.2. Check
`talosctl version --client` first: both tool entries in `mise.toml` now pin
`1.14.2`. The commands below were checked against the
installed 1.14.2 CLI help, not executed against the cluster.

Generate into a **new review directory**, preserving existing outputs:

```sh
umask 077
test -s talos/secrets/home-cloud.yaml || exit 1

talosctl gen config home-cloud https://k8s.home.antonu.org:6443 \
  --with-secrets talos/secrets/home-cloud.yaml \
  --talos-version ${TALOS_VERSION} --kubernetes-version 1.37.1 \
  --install-disk /dev/sda --install-image "$TALOS_INSTALLER" \
  --config-patch-control-plane @talos/patches/cilium.yaml \
  --output "$TALOS_DIR" --with-docs=false --with-examples=false --with-cluster-discovery=false

talosctl machineconfig patch "$TALOS_DIR/controlplane.yaml" --patch "@talos/patches/cp-01.yaml" --output "$TALOS_DIR/nodes/cp-01.yaml"
talosctl machineconfig patch "$TALOS_DIR/worker.yaml" --patch "@talos/patches/worker-01.yaml" --output "$TALOS_DIR/nodes/worker-01.yaml"

talosctl validate --config "$TALOS_DIR/nodes/cp-01.yaml" --mode metal
talosctl validate --config "$TALOS_DIR/nodes/worker-01.yaml" --mode metal

talosctl apply-config --insecure -n 192.168.40.21 -f talos/generated/home-cloud/nodes/cp-01.yaml
talosctl apply-config --insecure -n 192.168.40.40 -f talos/generated/home-cloud/nodes/worker-01.yaml
talosctl bootstrap -n 192.168.40.21

talosctl config endpoint 192.168.40.21
talosctl -n 192.168.40.21 version
talosctl -n 192.168.40.21 get extensions
talosctl kubeconfig -n 192.168.40.21
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
apiVersion: v1alpha1
kind: KubeFlannelCNIConfig
$patch: delete
---
apiVersion: v1alpha1
kind: KubeProxyConfig
enabled: false
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
The operator reports working BGP on all four nodes (ASN 65001), peering with
RB5009 `.40.1` (ASN 65000), and LB-IPAM pool `10.40.0.0/24`. Allocated Service
VIPs are advertised as /32 routes. The Kubernetes API VIP is separate.
The existing Helm release is the pre-adoption owner; Argo adoption is prepared. `kubernetes/cilium/kustomization.yaml`
renders the pinned chart plus local resources using the standard `helmCharts`
pattern; `kubernetes/cilium/manifests` is the separate local-resource apply target.
Follow the explicit Argo adoption and rollback plan in `kubernetes/cilium/README.md`.
After adoption, manually sync `cilium` instead of running separate Helm upgrades.
Values now also prepare Gateway API: install the pinned CRDs **before** upgrading
the release using [the GitOps sequence](gitops.md).

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

`kubernetes/synology-csi/kustomization.yaml` deploys the pinned
`synology/synology-csi:v1.3.1` controller and node plugin and includes
`storageclass.yaml` and the namespaced ESO resources. The controller is pinned
to `talos-worker-01`; the node DaemonSet selects nodes labeled
`storage.home.antonu.org/synology-iscsi=true` (two ready instances observed on
2026-10-04). Extension installation alone does not broaden that selector.

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
`client-info.yml` bytes. ESO synchronization is prepared under
`kubernetes/synology-csi/external-secrets`, included in the full `synology-csi`
Argo Application alongside the driver and StorageClass. Terraform was reported
applied; operator Argo adoption remains pending. Follow the
[CSI adoption guide](../kubernetes/synology-csi/README.md).
The target remains `synology-csi/client-info-secret`; do not delete or recreate it.
PVCs, PVs and NAS LUNs retain their existing owners.
Vault/ESO depend on existing cluster storage: preserve the retained Kubernetes
Secret during outages and do not prune it or delete storage to troubleshoot auth.

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

- Argo CD and Cilium Gateway API: manifests prepared; deployment/acceptance pending.
- Home Assistant migration from HAOS and migration of quantum-infra services.
- Freed Raspberry Pis as Talos nodes, additional workers and inventory/API.
- Ceph/Rook only if independent local disks/failure domains become available.

Do not build a nominally replicated Ceph cluster from VMs whose disks all
reside on this same NAS and describe it as fault-domain-independent storage.
