# Crafty and Fabric Minecraft

Argo CD Application/AppProject `minecraft-fabric` renders this Kustomize package
into namespace `minecraft`. Sync is manual, without automated pruning or a
cascading Application finalizer. Crafty Controller is pinned to4.10.8;
Minecraft Java26.3, Fabric Loader0.20.1 and Java25 are the configured targets.
Game settings and files are managed in Crafty, not through Deployment annotations.

## Storage and placement

One replica runs on `talos-worker-03` using static local PV
`minecraft-crafty-worker-03` and PVC `crafty-local-data`. The path
`/var/mnt/minecraft-crafty` is on the node's existing NVMe-backed `/var`
(`/dev/nvme0n1p6`, XFS). Node affinity and the Deployment nodeSelector keep it on
worker-03. The declared20 GiB capacity is not an enforced filesystem quota.

Read-only checks on2026-10-24 confirmed both containers Ready with zero restarts
and the server mount on the NVMe. The init container requires the existing Crafty
SQLite database before starting, then prepares directory mounts and checks Java25.
This prevents silently starting an empty panel on the wrong local directory.

The PVC maps `config`, `servers`, `backups`, `logs` and `import` to their respective
Crafty paths. PV reclaim policy is Retain; namespace/PV/PVC use
`Prune=false,Delete=false`. The Talos patch
`talos/patches/worker-03-local-storage.yaml` must remain applied: it exposes
`/var/mnt` read-write to kubelet while preserving the node's kubelet settings.
Include it when regenerating worker-03 configuration and reconcile its image pin
during Kubernetes upgrades. No formatting or repartitioning is needed.

The filesystem is shared with container images and logs. Limit backup retention
and monitor free space. Ordinary rollouts/reboots preserve data; Talos EPHEMERAL
reset, reinstall, disk loss or node loss can make it unavailable or destroy it.
The workload cannot move its local data to another node automatically.

Only the local PV/PVC are managed by this package. Earlier NAS claims, if still
present, are retained outside the current manifests; source cleanup does not
delete their PVCs, PVs or LUNs. Their retirement requires separate data cleanup.

## Runtime

Non-root UID/GID1000, restricted Pod Security, no host paths or Kubernetes token.
Recreate prevents overlapping rollout writers; shutdown grace is180 seconds.
Crafty starts the game as a child process in its container. The second container
is an nginx UI proxy. Stop the game cleanly before a pod rollout.

Panel/game requests: 500m CPU/3 GiB RAM; limits:2 CPU/4 GiB RAM. Start the game
with1 GiB initial/2 GiB maximum heap and keep room for the panel/native memory.
The proxy requests10m CPU/32 MiB RAM and is limited to128 MiB. Increase resources
in Git; use Crafty for game heap/settings. Its Java25 paths are
`/usr/lib/jvm/java-25-openjdk-arm64/bin/java` on worker-03 and
`/usr/lib/jvm/java-25-openjdk-amd64/bin/java` on amd64.

## Access and networking

| Endpoint | Destination | Protocol |
|---|---|---|
| `https://crafty.home.antonu.org` | Shared Gateway `10.40.0.10` | HTTPS443 |
| `http://crafty.home.antonu.org` | Shared Gateway | HTTP80 redirects to HTTPS |
| `minecraft.home.antonu.org` | LoadBalancer `10.40.0.20` | TCP25565 |
| Voice chat | Same LoadBalancer | UDP24454 |

The existing Gateway wildcard certificate covers Crafty. HTTPRoute forwards to
`crafty:8080`; nginx forwards to Crafty's HTTPS8443 listener on pod loopback.
WebSockets and uploads up to1 GiB are supported. Only the loopback self-signed
certificate check is disabled. Gateway-to-proxy traffic uses HTTP inside the
cluster. Generated proxy ConfigMap hashes trigger rollouts after config edits.

Gateway HTTP/HTTPS listeners admit namespace `minecraft`. ExternalDNS discovers
the UI through HTTPRoute and the game through the LoadBalancer Service's
`external-dns.kubernetes.io/hostname` annotation. Existing TXT ownership and
upsert-only policy remain. Verify actual DNS health; prior ExternalDNS failures
are documented in `docs/external-dns.md`.

The game Service disables NodePorts and allows Home192.168.100.0/24 and
Cloud192.168.40.0/24 sources. No router WAN forwarding is configured.
The separate [Playit application](../playit/README.md) uses `10.40.0.20` as its
local target for TCP25565 and UDP24454. Friends use its assigned public Java
endpoint. Keep internal voice port24454 and set `voice_host` to the assigned
public Playit UDP hostname/port; LAN players also use that advertised voice path.
Crafty remains private. Follow the Playit runbook for routing/policy acceptance.

Recovery UI access, with repository direnv loaded:

```sh
kubectl -n minecraft port-forward service/crafty 8443:8443
```

Open https://localhost:8443. Retrieve initial generated credentials privately from
`/crafty/app/config/default-creds.txt` if needed; do not publish that file or full
panel configuration/logs. Change the initial admin password and enable TOTP.

## Game and mods

Use the existing server in Crafty. Keep Minecraft26.3, Fabric Loader0.20.1,
Java25 and game port25565 consistent. Bind the game to all interfaces. Review
https://aka.ms/MinecraftEULA before accepting it. Keep online authentication
enabled; manage whitelist access through the server console.

Stop the game and back it up before uploading compatible server mod JARs into
`mods/` and editing `config/` in Crafty's Files tab. Fabric API/dependencies must
match the game version. Client-only mods stay on clients. Raw Modrinth mrpack
archives require preparation outside Crafty; import extracted server files,
not the raw archive. Enable start-on-boot only after the game starts successfully.

## Deployment and verification

From `/Users/anton/projects/home-infra`, load repository direnv. Local rendering:

```sh
kustomize build kubernetes/apps/minecraft-fabric
```

Stop Minecraft through Crafty and wait for its save before rollout. Review and
publish intended Git changes to main; Argo reads remote Git. Sync only affected
Applications, without pruning. Normal workload updates:

```sh
argocd app diff minecraft-fabric --grpc-web
argocd app sync minecraft-fabric --grpc-web
kubectl -n minecraft rollout status deployment/minecraft-fabric --timeout=10m
kubectl -n minecraft get pods,pvc -o wide
kubectl get pv minecraft-crafty-worker-03
```

For routing/DNS changes also review and manually sync `gateway` and
`external-dns` as applicable. Preserve the existing Service and its reserved VIP.
Require worker-03 placement, both containers Ready, local PVC Bound, current
HTTPRoute Accepted/ResolvedRefs, valid TLS and expected DNS:

```sh
kubectl -n minecraft get httproute crafty crafty-redirect
curl --fail --resolve crafty.home.antonu.org:443:10.40.0.10 https://crafty.home.antonu.org/login -o /dev/null
dig +short crafty.home.antonu.org A
dig +short minecraft.home.antonu.org A
```

Expected targets are10.40.0.10 and10.40.0.20. Verify panel login, WebSocket console,
game world/player state, mod loading, LAN join and public Playit join/voice.
Pod readiness checks the panel, not whether the game is intentionally stopped.

## Backup and rollback

Keep consistent copies of world, mods, server configuration and panel
configuration/database. Stop the game for world backup and quiesce Crafty for
its database backup. Backups on this same NVMe are not independent; export copies
when needed and enforce retention to avoid filling the node filesystem.

For configuration/image rollback, stop the game, restore a compatible panel
backup if its database changed, revert the relevant source and manually sync.
Keep the local PV/PVC and Talos kubelet mount. Game-version rollback needs a
compatible pre-upgrade world backup; reverting the image alone does not undo
world changes. Do not delete namespace, PVC/PV, local files or storage finalizers
to recover a failed rollout.
