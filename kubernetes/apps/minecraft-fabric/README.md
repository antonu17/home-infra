# Crafty panel and Fabric Minecraft 26.3

Argo CD Application/AppProject `minecraft-fabric` renders this Kustomize package
into namespace `minecraft`. Crafty Controller 4.10.8 replaces the itzg container
and owns Minecraft process control, console, server configuration and mods.
Minecraft Java **26.3**, Fabric Loader **0.20.1**, Java **25** are the target.
The game version is selected during panel setup; the Deployment annotation records
intent and does not configure Crafty's database. No older game is provisioned.

Argo owns Kubernetes resources and the panel image/resources. Crafty owns game
versions, JVM arguments, server files and user accounts on the PVC. Do not update
Crafty itself from its UI; change the image pin in Git and manually sync Argo.
Mods use browser upload and file editing; no searchable mod catalog is promised.

## Storage and scheduling

Source is prepared to move active Crafty data from Synology to local NVMe on
`talos-worker-03`; live migration has not been executed.
The static PV uses `/var/mnt/minecraft-crafty` on the existing NVMe-backed `/var`,
with no repartitioning. PVC `crafty-local-data` holds all five Crafty directories;
PV node affinity and Deployment nodeSelector pin the workload to worker-03.
The PV/PVC are retained, with nominal 20 GiB capacity but no directory quota.
The original NAS `crafty-data` and `minecraft-data` claims remain unchanged.

**Migration stop point:** Deployment replicas are 0 until the stopped NAS data is
copied and verified. Follow [local storage migration](migration/README.md), then
set replicas to 1 in Git and manually sync. The init container requires a verified
copy marker before starting Crafty. Do not use the ordinary deployment sequence
below to bypass migration. Workload remains non-root with Recreate and 180-second
termination grace. CPU/memory settings are unchanged: 500m/3 GiB requests and
2 CPU/4 GiB limits for panel/game, plus the proxy's resources.

Local files share the system NVMe filesystem with runtime data and persist across
ordinary reboots/rollouts. Talos EPHEMERAL reset/wipe or disk loss can destroy them;
this workload cannot relocate to another worker. Monitor free space and limit
local backup retention. No Talos installation or disk configuration is changed.

## Deployment

For the existing NAS-backed installation, complete [local storage migration](migration/README.md)
instead of directly following this general application-sync sequence.

From `/Users/anton/projects/home-infra`, load the repository direnv environment.
Local rendering does not contact the cluster:

```sh
kustomize build kubernetes/apps/minecraft-fabric
```

Read-only preflight:

```sh
: "${KUBECONFIG:?Load the repository direnv environment}"
kubectl config current-context
kubectl get storageclass synology-block
kubectl get node talos-worker-03
kubectl -n minecraft get deployments,pods,pvc,services
argocd app list --grpc-web
```

A missing namespace is expected for a fresh installation. If the previous itzg
server is running, first stop player activity, back up all of its `/data` to
independent storage, and record its version. Review the diff: this replaces the
container in the same Deployment, stopping the old writer before Crafty starts;
it does not import or upgrade the previous world automatically. Preserve the
`minecraft-data` claim. Stop here if backup or current ownership is uncertain.

Review and publish intended changes to GitHub `main`; Argo reads remote Git.
Live changes, manual sync with pruning disabled:

```sh
argocd app diff gitops --grpc-web
argocd app sync gitops --grpc-web
argocd app get minecraft-fabric --refresh --grpc-web
argocd app diff minecraft-fabric --grpc-web
argocd app sync minecraft-fabric --grpc-web
argocd app wait minecraft-fabric --sync --health --timeout 900 --grpc-web
kubectl -n minecraft rollout status deployment/minecraft-fabric --timeout=15m
kubectl -n minecraft get pods,pvc,services
kubectl -n minecraft port-forward service/crafty 8443:8443
```

Open https://localhost:8443. Crafty initially presents a self-signed certificate;
verify access is through the localhost forward. Retrieve the generated admin
credentials privately from `/crafty/app/config/default-creds.txt` inside the pod,
using a local trusted terminal; do not paste credentials or that file into chat,
Git or shared logs. Change the password immediately and enable TOTP.

Normal UI access is https://crafty.home.antonu.org through the shared Gateway.
The localhost forward remains recovery access. See Exposure below for DNS,
networking, sync order and acceptance checks.

## Create the 26.3 server in Crafty

1. Create a Minecraft Java server using Fabric and explicitly select **26.3**;
   do not choose Latest, a snapshot or 1.21.1. Choose Loader **0.20.1** if the
   builder exposes the loader setting. If the builder does not offer this exact
   combination, use the explicit ZIP-import procedure below.
2. Set Java to the installed Java 25 executable, not the default `java` command:
   `/usr/lib/jvm/java-25-openjdk-amd64/bin/java` on amd64 or
   `/usr/lib/jvm/java-25-openjdk-arm64/bin/java` on arm64. Set min/max heap to
   1024/2048 MiB and port to **25565**, binding to `0.0.0.0`/all interfaces.
3. Review https://aka.ms/MinecraftEULA and accept through the panel or set
   `eula=true` in this server's `eula.txt` only after agreeing. Crafty does not use
   the itzg `EULA` environment variable; deployment alone does not accept it.
4. Keep `online-mode=true`, `enable-rcon=false`, `enable-query=false` and
   `white-list=true` in `server.properties`. Add intended players to the whitelist
   through the console. Start the server and require the console to identify
   Minecraft **26.3**, Fabric Loader **0.20.1** and successful world startup.
5. Stop the server before adding mods. In Files, upload Fabric **26.3** compatible
   JARs to `mods/`, including the compatible Fabric API and dependencies when
   required. Start once to generate configuration, stop, edit `config/` in the
   browser, then start and inspect the console. Client content mods must match.
   Back up before updating/removing mods; do not assume 1.21 mods work on 26.3.
6. Enable Crafty's start-on-boot for this server after successful acceptance.
   Kubernetes readiness checks the panel, so an intentionally stopped game does
   not restart the pod or remove access to the panel.

### Explicit Fabric ZIP import

If Fabric/26.3 is missing from Crafty's builder, prepare an archive locally using
Java 25 and Fabric's pinned official installer. These write only a new directory
under the local temporary directory; no cluster or existing world is changed.

```sh
fabric_dir=$(mktemp -d "${TMPDIR:-/tmp}/fabric-26.3.XXXXXX")
curl --fail --location --output "$fabric_dir/fabric-installer.jar" \
  https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.2/fabric-installer-1.1.2.jar
java -version
# Require Java 25 before the next command.
java -jar "$fabric_dir/fabric-installer.jar" server \
  -mcversion 26.3 -loader 0.20.1 -downloadMinecraft -dir "$fabric_dir/server"
(cd "$fabric_dir/server" && zip -r "$fabric_dir/fabric-26.3.zip" .)
```

Upload that ZIP through Crafty's Create Server → Import ZIP. Select the archive's
server root and `fabric-server-launch.jar` as executable. Set the Java 25 path
and JVM heap as above; the launch command is the selected Java executable followed
by `-Xms1G -Xmx2G -jar fabric-server-launch.jar nogui`. Complete EULA, whitelist
and game acceptance checks before enabling start-on-boot. Import is a UI step;
the manifests do not silently create a Crafty server record.

## Verification

In a second terminal, forward the game port after starting the server:

```sh
kubectl -n minecraft port-forward service/minecraft-fabric 25565:25565
```

Join `localhost:25565` with a Minecraft Java **26.3** client and compatible mods.
Verify console commands, stop/start, a mod configuration edit, and a backup from
the UI. A Ready panel is not proof the game is running. Before any subsequent
Argo rollout, stop Minecraft in the panel and wait for its save/shutdown to finish.
Do not print full Crafty logs/configuration files that may contain credentials.

## Backup, migration and rollback

Export a consistent backup of world, mods, server configuration and Crafty panel
configuration/database. Stop the game for consistent world backup; quiesce the
panel for a consistent panel database backup. Crafty's backups on the same PVC
are convenient recovery copies, not independent backups. Keep independent copies
and limit local retention to avoid filling the node filesystem. The declared
20 GiB local PV capacity is not a filesystem quota.

To migrate an existing itzg world, use its independently stored, stopped-server
backup and Crafty's ZIP import; retain the original PVC untouched. Test the
import separately before relying on it. Minecraft 26.3 upgrades older world data;
rollback requires a pre-upgrade world backup, not just an old container image.

For the NAS-to-local storage rollback, follow [the migration runbook](migration/README.md#rollback).
For panel/configuration rollback, stop the game, restore the compatible Crafty
backup if its database changed, revert source in Git, publish and manually sync
`minecraft-fabric` with pruning disabled. To return to the previous itzg package,
stop Crafty's game first and restore the previous package revision pointing to
`minecraft-data`. That claim contains only its previous data, not subsequent
Crafty writes; reconcile/export those before switching. Never attach both writers
to the same world or delete the namespace, PVCs, retained PVs or NAS LUNs.

## References

- https://www.minecraft.net/en-us/article/minecraft-java-edition-26-3
- https://www.fabricmc.net/2026/09/15/263.html
- https://meta.fabricmc.net/v2/versions/installer
- https://docs.craftycontrol.com/pages/getting-started/installation/docker/
- https://docs.craftycontrol.com/pages/getting-started/access/
- https://docs.craftycontrol.com/pages/user-guide/file-manager/
- https://gitlab.com/crafty-controller/crafty-4/-/blob/v4.10.8/Dockerfile

## Exposure

| Endpoint | Destination | Protocol |
|---|---|---|
| `https://crafty.home.antonu.org` | Gateway `10.40.0.10` → crafty:8080 → pod loopback8443 | HTTPS443, WebSocket console, uploads up to 1 GiB |
| `http://crafty.home.antonu.org` | Shared Gateway | HTTP80 redirects to HTTPS |
| `minecraft.home.antonu.org:25565` | Game Service `10.40.0.20` | TCP25565 |
| `minecraft.home.antonu.org:24454` | Same game Service | UDP24454, Simple Voice Chat |

No Minecraft HTTPRoute is used: game TCP and voice UDP go directly through a
Cilium LoadBalancer. Both ports share one IP; NodePorts are disabled. Source
ranges restrict game/voice traffic to Home `192.168.100.0/24` and Cloud
`192.168.40.0/24`. Source addresses seen through VPN/NAT require explicit review
before adding remote access. This is internal routed exposure, with no WAN NAT.
Existing RouterOS source permits Home and Cloud to routed `10.40.0.0/24`; no
router source changes are needed. Live firewall/BGP state still needs acceptance.

The Gateway's HTTP/HTTPS listener namespace lists now include `minecraft`.
Its existing wildcard certificate covers the UI hostname. The same-pod nginx
proxy accepts HTTP8080 from the Gateway and forwards WebSockets/uploads to
Crafty's self-signed HTTPS listener on 127.0.0.1:8443. Certificate verification is
disabled only for this loopback hop. Gateway-to-proxy HTTP matches existing app
routing; this does not provide encrypted transport across the cluster. No new
certificate, private key, ReferenceGrant, DNS credentials or controller is added.
The generated proxy ConfigMap name changes on edits and triggers a pod rollout.
The proxy adds a 10m CPU/32 MiB memory request and a 128 MiB memory limit.

ExternalDNS retains `home-cloud` TXT ownership, `external-dns-` TXT prefix,
upsert-only behavior and existing domain filters. The Service source is added
alongside HTTPRoute discovery, filtered to LoadBalancer Services. Crafty's name
comes from the route; Minecraft's comes from the Service hostname annotation.
The documented ExternalDNS crash loop is a deployment blocker for automatic DNS;
follow `docs/external-dns.md` if it persists. Do not treat Argo health as DNS proof.

### Exposure deployment and acceptance

Before publishing source, use the loaded repository direnv for read-only checks:

```sh
kubectl get services -A -o wide
kubectl -n gateway get gateway home-cloud
kubectl -n gateway get certificate home-antonu-org
kubectl -n external-dns get pods
```

Require no allocation collision for `10.40.0.20`; review live LoadBalancer hostname
annotations before enabling Service discovery. Check that neither new hostname
has an existing manual DNS record or conflicting TXT owner; do not overwrite one.
Before replacing a running pod, stop Minecraft in Crafty and complete its save.
Publish reviewed source to main. These are live changes, manually run without
pruning after reviewing each application's diff:

```sh
argocd app diff gateway --grpc-web
argocd app sync gateway --grpc-web
argocd app diff minecraft-fabric --grpc-web
argocd app sync minecraft-fabric --grpc-web
argocd app wait minecraft-fabric --sync --health --timeout 900 --grpc-web
argocd app diff external-dns --grpc-web
argocd app sync external-dns --grpc-web
```

Read-only acceptance from a trusted Home client:

```sh
kubectl -n minecraft get services,httproutes
kubectl -n minecraft get httproute crafty crafty-redirect -o yaml
curl --fail --resolve crafty.home.antonu.org:443:10.40.0.10 https://crafty.home.antonu.org/login -o /dev/null
curl -I --resolve crafty.home.antonu.org:80:10.40.0.10 http://crafty.home.antonu.org/
dig +short crafty.home.antonu.org A
dig +short minecraft.home.antonu.org A
```

Require current-generation Accepted/ResolvedRefs on both HTTPRoutes, LB status
`10.40.0.20`, valid frontend TLS and HTTPS redirect. Log in, use the WebSocket
console and upload a mod to verify the full UI path. Expected DNS targets are
`10.40.0.10` and `10.40.0.20` respectively. DNS resolution must use the home
resolver; these are private addresses, not public Internet endpoints.

In Crafty keep game port25565, bind to all interfaces, and configure
`config/voicechat/voicechat-server.properties` with `port=24454`, blank
`bind_address` and `voice_host=minecraft.home.antonu.org:24454`, then restart only
the game through the panel. Join Minecraft at `minecraft.home.antonu.org` and
verify actual voice audio between clients. A UDP port probe alone is not proof.

For exposure rollback, restore the prior networking source, publish and manually
sync affected Applications without pruning; preserve both PVCs. Because Argo
pruning is disabled, removed HTTPRoutes and upsert-only DNS records remain until
an explicitly reviewed cleanup. For immediate isolation, revert the game Service
to ClusterIP and remove `minecraft` from the shared Gateway HTTP/HTTPS listener
namespace lists, then sync `minecraft-fabric` and `gateway`; retain the
localhost8443 forward for panel access. DNS may
remain stale during rollback; do not delete namespaces or data to remove exposure.

## Proxy startup failure — 2026-10-24

Read-only cluster diagnostics identified `crafty-proxy` exiting with code1:
`mkdir() "/var/cache/nginx/fastcgi_temp" failed (30: Read-only file system)`.
Crafty itself was Ready with zero restarts. nginx initializes FastCGI/uWSGI/SCGI
temporary directories even when the proxy does not use those protocols.
`crafty-proxy.conf` now places all five nginx temp directories under the existing
writable `/tmp` emptyDir; the root filesystem stays read-only. Kustomize changes
the generated ConfigMap hash and pod template when this file changes.

Publish the reviewed fix and manually sync `minecraft-fabric`, without pruning.
Recreate replaces the entire pod, including Crafty; stop any running game through
the recovery localhost8443 forward first and wait for its save to finish.

```sh
argocd app diff minecraft-fabric --grpc-web
argocd app sync minecraft-fabric --grpc-web
kubectl -n minecraft rollout status deployment/minecraft-fabric --timeout=15m
kubectl -n minecraft get pods -l app.kubernetes.io/name=minecraft-fabric
```

Require both containers Ready and no proxy restarts. Verify UI login and console
through `https://crafty.home.antonu.org`. Source validation is complete; the fix
requires this manual sync and subsequent live acceptance.

## Friends outside the home network

The separate [Playit application](../playit/README.md) forwards its public
Minecraft Java endpoint to `10.40.0.20:25565/TCP` and its public Simple Voice Chat
endpoint to `10.40.0.20:24454/UDP`. Both tunnel Local Address fields use the
reserved LoadBalancer IP `10.40.0.20`, not a Pod IP or localhost. The ClusterIP is
an alternative diagnostic target, not the configured tunnel target.

LAN players continue using `minecraft.home.antonu.org`; friends use Playit's
assigned public Java hostname/port. With Playit enabled, set `voice_host` to its
assigned public UDP hostname/port while retaining internal `port=24454`.
Crafty remains private at `https://crafty.home.antonu.org`. The agent's network
policy excludes Crafty ports, and its key belongs in Vault/ESO.

Confirm the Service's live LoadBalancer address and test game/voice access from
outside the home network. See the Playit runbook for the unverified VIP routing
and source-policy acceptance checks. Disabling the provider tunnels leaves LAN
access available; changing the game Service to ClusterIP also removes the VIP
used by Playit and therefore interrupts public access.
