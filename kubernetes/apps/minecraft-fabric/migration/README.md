# Crafty: Synology to worker-03 NVMe

Source is prepared; no disk or cluster change has been executed. Application
replicas are deliberately0 until migration completes. Do not sync this change
without scheduling downtime and completing the steps below.

## Layout

Read-only observation on 2026-10-24: worker-03 (`192.168.40.42`) has Talos
EPHEMERAL on `/dev/nvme0n1p6`, approximately248 GB, mounted at `/var`; approximately
235 GB available. The NVMe is also the system disk. Use existing free filesystem
space, not a new partition. No Talos configuration change, wipe, format, reinstall,
boot-media change or node restart is needed. Preserve the SD boot dependency.

Local PV `minecraft-crafty-worker-03` exposes `/var/mnt/minecraft-crafty`, reserves
PVC `minecraft/crafty-local-data`, and has Retain plus worker-03 node affinity.
Both use an explicit empty storageClassName and a static volumeName/claimRef
pair, so the default NAS provisioner cannot claim this workload. The declared
20 GiB is scheduling capacity, not a directory quota. This shares the NVMe `/var`
filesystem with container images/logs; control backup retention and free space.
Talos EPHEMERAL reset/wipe/reinstall can destroy this data. Ordinary pod rollouts
and node reboots preserve it; node/disk failure prevents relocation.

`minecraft/crafty-data` remains the unchanged NAS source. Copy includes config,
Crafty's SQLite database, servers/worlds/mods, backups, logs and imports. Source
is mounted read-only. New data is written only to the named empty local directory.

## 1. Stop the source writer

Load repository direnv. Save a backup through Crafty, stop the game and wait for
its clean save/shutdown. Review the changed AppProject (adds only PersistentVolume
permission), PV/PVC and Deployment diff. Publish the prepared source with
`replicas: 0`. Manually sync root first to grant PV permission, then workload,
without pruning. These are live changes:

```sh
argocd app diff gitops --grpc-web
argocd app sync gitops --grpc-web
argocd app diff minecraft-fabric --grpc-web
argocd app sync minecraft-fabric --grpc-web
kubectl -n minecraft wait --for=delete pod -l app.kubernetes.io/name=minecraft-fabric --timeout=300s
kubectl -n minecraft get deployment minecraft-fabric
```

Require desired/ready replicas0 and no Crafty pods before copying. The panel and
all game servers must remain stopped, not just the game. Inspect any other pod
using the source PVC and stop on another writer. Keep both NAS PVCs and local PV.

## 2. Prepare one local directory

Operator-run live change: creates `/var/mnt/minecraft-crafty` on **talos-worker-03**
and sets only that empty directory's owner/group1000 and mode0750. No disks are
formatted. The dedicated temporary namespace permits hostPath; the regular
Minecraft namespace remains restricted. The preparation Pod is not privileged
but runs as root with narrowly scoped filesystem capabilities. Inspect this
manifest before running it; it has access only to the named host directory.

```sh
kubectl apply -f kubernetes/apps/minecraft-fabric/migration/prepare-directory.yaml
kubectl -n minecraft-storage-migration wait --for=jsonpath='{.status.phase}'=Succeeded pod/prepare-crafty-directory --timeout=180s
kubectl -n minecraft-storage-migration logs prepare-crafty-directory
```

Require success and an empty target. If the target already contains data, the
Pod refuses to proceed. Do not erase it or rerun blindly; inspect before recovery.

## 3. Copy and verify

Operator-run live change: copies the read-only NAS source into the local PVC.
The copy runs non-root on worker-03, rejects a populated target, compares paths,
file sizes and SHA256 hashes, and checks the source did not change. It writes a
completion marker only after verification. It never prints credential contents.
No fsGroup is set on the copy Pod, avoiding a recursive ownership change to the
NAS source. Source files must be readable by the existing Crafty UID1000.

```sh
kubectl -n minecraft get pvc crafty-data crafty-local-data
kubectl apply -f kubernetes/apps/minecraft-fabric/migration/copy-data.yaml
kubectl -n minecraft wait --for=jsonpath='{.status.phase}'=Succeeded pod/crafty-storage-copy --timeout=1800s
kubectl -n minecraft logs crafty-storage-copy
```

Require both PVCs Bound, copy Pod Succeeded and its verified completion message.
On failure keep replicas0; the partially populated destination is deliberately
not overwritten by retries. Preserve and inspect it before any cleanup.

## 4. Start on local storage

After successful verification, change only Deployment `spec.replicas` from0 to1
in `kubernetes/apps/minecraft-fabric/deployment.yaml`, publish and manually sync
`minecraft-fabric` without pruning:

```sh
argocd app diff minecraft-fabric --grpc-web
argocd app sync minecraft-fabric --grpc-web
kubectl -n minecraft rollout status deployment/minecraft-fabric --timeout=10m
kubectl -n minecraft get pods -o wide
```

Require worker-03 placement, both containers Ready and the `crafty-local-data`
volume reference. The init container checks the completion marker and refuses an
unverified destination. In Crafty verify existing accounts and server UUIDs,
start the existing game if auto-start is disabled, confirm mods/world/player
state, and test LAN plus Playit and voice chat. Compare freeze behavior/I/O
pressure under similar player load; local storage does not guarantee tick/CPU
performance. Do not create a replacement empty server.

## Rollback

Stop the game cleanly; publish replicas0 and sync; wait for the entire Crafty pod
to disappear. The NAS copy is unchanged but becomes stale after local writes.
Before returning to it, decide whether to retain/export local progress; do not
silently discard it. Restore the previous Deployment version from Git with its
NAS `crafty-data` volume and original init configuration, then publish/sync.
Keep current PVC/PV resource declarations and do not prune either data copy.

Completed migration Pods and the dedicated preparation namespace can be removed
later through an explicitly reviewed cleanup. Do not use namespace/PVC/PV deletion
as rollback. Keep the source claim until local acceptance is complete.
