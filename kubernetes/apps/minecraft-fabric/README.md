# Fabric Minecraft Java server

Argo CD Application and AppProject: `minecraft-fabric`, namespace: `minecraft`.
The root `gitops` Application discovers `kubernetes/gitops/minecraft-fabric.yaml`;
the child renders this directory with Kustomize. Sync remains manual, without
automated pruning or a cascading Application finalizer. Namespace and PVC carry
`Prune=false,Delete=false`. Prepared source only; no cluster sync performed.

One replica with
`Recreate`, a 120-second graceful shutdown window and a 20 GiB RWO PVC mounted
at `/data`. No host paths, privileged containers or Talos changes are required.
Do not scale above one or force-delete a pod on an unreachable node; fence the
old writer before recovery. RWO does not prevent two writers on the same node.

## Configuration

`deployment.yaml` pins the container, Minecraft, Fabric loader and launcher.
Defaults: Minecraft 1.21.1, Java 21, 1–2 GiB heap, 2 GiB memory request, 3 GiB
memory limit, 500m CPU request and 2 CPU limit. Edit these together for the mod
pack and player count. Match the client game version. Fabric API and other mods
are not bundled; install compatible server mods in `/data/mods` before use.

`EULA: "TRUE"` explicitly accepts https://aka.ms/MinecraftEULA. Review and agree
before applying. Online authentication stays enabled; RCON and query are disabled.

Prerequisites: repository direnv environment loaded, working Synology CSI,
`storage.home.antonu.org/synology-iscsi=true` on an eligible node with sufficient
capacity, and DNS/HTTPS egress for image/game/Fabric downloads plus Minecraft
authentication. The StorageClass uses WaitForFirstConsumer and Retain. Pending
storage before pod scheduling can be normal. Live admission, downloads, volume
permissions and application startup remain unverified.

## Deployment

Run from `/Users/anton/projects/home-infra` with repository direnv loaded.
Review and agree to the EULA before syncing: `EULA: "TRUE"` is explicit acceptance.
Argo CD reads published GitHub `main`, not the local working tree.

Local validation, without cluster access:

```sh
kustomize build kubernetes/apps/minecraft-fabric
```

Read-only preflight: confirm target context, storage/node eligibility, available
capacity and that the namespace and resource names have no conflicting owner.

```sh
: "${KUBECONFIG:?Load the repository direnv environment}"
kubectl config current-context
kubectl get storageclass synology-block
kubectl get nodes -l storage.home.antonu.org/synology-iscsi=true
argocd app list
```

Review and publish only the intended source changes to `main`. The following
live changes register the AppProject/Application, then create the namespace,
PVC, Deployment and Service. Review the Argo diff and keep pruning disabled.
Do not apply the workload directory directly with kubectl.

```sh
argocd app diff gitops --grpc-web
argocd app sync gitops --grpc-web
argocd app get minecraft-fabric --refresh --grpc-web
argocd app diff minecraft-fabric --grpc-web
argocd app sync minecraft-fabric --grpc-web
argocd app wait minecraft-fabric --sync --health --timeout 900 --grpc-web
kubectl -n minecraft rollout status deployment/minecraft-fabric --timeout=15m
kubectl -n minecraft get pods,pvc,svc
kubectl -n minecraft logs deployment/minecraft-fabric --tail=100
kubectl -n minecraft port-forward service/minecraft-fabric 25565:25565
```

Connect the Java client to `localhost:25565` while the forward runs. The Service
is cluster-internal; port-forward binds to localhost. TCP readiness proves a
listening socket; confirm the server's Done message and a successful client join.
LAN access would require a separately reviewed Cilium LoadBalancer allocation and
routing/firewall policy for trusted clients to TCP/25565; no Gateway HTTP route
or WAN exposure is configured here.

## Backup and rollback

Back up all of `/data`, including world, mods and configuration, before changing
game/mod versions. Stop the server cleanly for a consistent storage backup and
keep an independently stored copy. A retained PV or NAS snapshot shares the NAS
failure domain and is not an independent backup.

For a configuration-only rollback, restore the prior source values in Git, publish them,
review the Argo diff and manually sync `minecraft-fabric` again. Changes under the pod template trigger Recreate and cause downtime.
Game upgrades can migrate the world; reverting the image alone does not roll
back data. Restore a compatible pre-upgrade backup before starting an older
version. Keep the PVC, namespace and retained PV/LUN during rollback; do not delete or prune
these resources as a rollback procedure.

Upstream: https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/server-types/fabric/
Image release: https://github.com/itzg/docker-minecraft-server/releases/tag/2026.9.2
