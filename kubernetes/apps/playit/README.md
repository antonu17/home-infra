# Playit Minecraft tunnels

Source is prepared; live agent/tunnel provisioning and external access have not
been verified.
Argo Application/AppProject `playit` renders this directory into namespace
`playit`, with manual sync and no automated pruning. One non-root Recreate
Deployment runs official agent1.0.10 pinned by digest. Account identity persists
in Vault; only runtime files/socket use emptyDir. No PVC, host networking,
privileged container, public listener, Kubernetes token or extra Gateway needed.

The agent's NetworkPolicy accepts no unsolicited ingress. It permits DNS,
Minecraft pods on TCP25565/UDP24454 and outbound Internet relay/control traffic.
Private/local destinations are excluded from that Internet rule. Crafty's
TCP8080/8443 and other homelab services are excluded. Public relay addresses and
ports are dynamic, so Internet egress is not limited to a fixed provider IP list.
Only IPv4 egress is prepared; an IPv6-only origin needs a separately tested policy.

## Traffic path

```text
Friends → Playit public Java endpoint → agent → 10.40.0.20:25565/TCP
Friends → Playit public voice endpoint → agent → 10.40.0.20:24454/UDP
```

The two public endpoints may have different hostnames and ports. Both use the
same reserved internal LoadBalancer IP. Crafty is accessed separately through
the private HTTPS Gateway and is never a tunnel target.

## 1. Register the agent and store its key

In the Playit account setup, choose Docker/headless setup, create an agent named
`homelab-minecraft` and copy its SECRET_KEY privately. Account registration alone
does not create the deployed agent. Do not paste the key in chat, Git, shell
history or command arguments. The agent image wrapper passes the key to its own
process internally; keep process inspection/log access limited to administrators.

In the existing Vault UI, KV mount `home-cloud`, create secret `playit/agent`
with one field `SECRET_KEY` containing the agent key. This is a live secret write;
no secret value belongs in Terraform. The new Terraform role `eso-playit` permits
only `playit/vault-eso` with audience `vault` to read `home-cloud/playit/*`.

## 2. Provision Vault identity and sync

Load repository direnv and ensure the NAS Terraform state share is mounted.
Use one Terraform writer; preserve all existing identities if a private
`TF_VAR_eso_roles` overrides the default map, adding the playit entry there too.
Review a plan requiring only the new playit policy/auth role. Stop on changes to
existing roles, mounts, auth configuration or credentials. Plan output/state can
be sensitive; do not paste it into chat.

```sh
cd /Users/anton/projects/home-infra
terraform -chdir=terraform/vault plan -out=configure.tfplan
# Live Vault change, only after reviewing the plan:
terraform -chdir=terraform/vault apply configure.tfplan
```

Publish only reviewed source to GitHub main. Live Kubernetes changes:

```sh
argocd app diff gitops --grpc-web
argocd app sync gitops --grpc-web
argocd app get playit --refresh --grpc-web
argocd app diff playit --grpc-web
argocd app sync playit --grpc-web
kubectl -n playit wait --for=condition=Ready secretstore/home-cloud-vault --timeout=180s
kubectl -n playit wait --for=condition=Ready externalsecret/playit-agent --timeout=180s
kubectl -n playit rollout status deployment/playit-agent --timeout=5m
```

Check the agent is Online in Playit. A Running pod does not prove relay health;
there is no fabricated liveness/readiness test for an unsupported health API.
Do not publish complete agent logs, account keys or claim links. A missing Vault
entry or role prevents startup; do not create a second unmanaged Kubernetes Secret.

## 3. Create two tunnels in the Playit dashboard

Use the reserved LoadBalancer address `10.40.0.20` as Local Address in both
tunnels. This allocation is declared in the Minecraft Service manifest. Confirm
that its live LoadBalancer status has that address:

```sh
kubectl -n minecraft get service minecraft-fabric -o wide
```

| Tunnel | Agent | Local address | Local port |
|---|---|---|---|
| Minecraft Java, free network | homelab-minecraft | 10.40.0.20 | 25565/TCP |
| Simple Voice Chat / UDP, free network | same agent | 10.40.0.20 | 24454/UDP |

Using a LoadBalancer address from an in-cluster agent is valid. This path remains
unverified. The Service's source ranges permit Home/Cloud subnets; whether Cilium
applies that filtering to this connection and which source address it sees must
be established by testing. The agent's NetworkPolicy explicitly permits traffic
to the Minecraft pods on these two ports; policy enforcement through the VIP also
needs acceptance. If access fails, inspect the actual routing/policy drops before
changing source ranges; do not broaden access speculatively.

Do not use localhost: the game runs in another pod. The Service ClusterIP is an
alternative diagnostic target, available with the command below. It remains stable
across pod rollouts but can change if the Service is deleted and recreated.

```sh
kubectl -n minecraft get service minecraft-fabric -o jsonpath='{.spec.clusterIP}{"\n"}'
```

Create the Java preset and the Simple Voice Chat/UDP preset, keeping PROXY
protocol disabled for the direct Fabric server. Record both assigned public
hostnames and ports; they may differ. Use the complete Java endpoint shown in
the dashboard for friends. Keep these tunnel objects and agent identity for
endpoint stability; do not delete/recreate them to restart a pod. This is a
provider-managed endpoint, not a dedicated public IPv4 owned by the homelab.

## 4. Voice chat and client access

In Crafty stop the game and edit
`config/voicechat/voicechat-server.properties`:

```properties
port=24454
bind_address=
voice_host=THE_ASSIGNED_PUBLIC_VOICE_HOST:THE_ASSIGNED_PUBLIC_UDP_PORT
```

Replace both placeholders with the exact UDP tunnel endpoint. Keep the internal
port24454 even if Playit assigns a different external port. Start the game.
This advertises the public voice endpoint to LAN players too; they need outbound
access to it. The ordinary LAN game name remains `minecraft.home.antonu.org`.

Friends connect to the assigned public Java endpoint without installing the
Playit agent. They need Minecraft26.3 and the compatible client mods. Keep
online-mode and whitelist enabled; add approved players through Crafty's console.
Test joining and two-way voice from outside the home network. Watch agent
connectivity and server load; restarting the agent interrupts public sessions.

No ExternalDNS, public DNS, HTTPRoute or router port-forward is needed for these
provider hostnames. Existing ExternalDNS manages private home.antonu.org records;
do not replace their private targets with Playit endpoints. Crafty remains private.
Custom public DNS can be designed after the actual assigned endpoints are known.

## Rollback and credential rotation

For immediate public-access shutdown, disable both tunnels in the Playit dashboard;
LAN play and Crafty remain available. To stop the agent declaratively, set this
Deployment's replicas to0 in Git, publish and manually sync `playit`. Do not remove
the namespace, ESO resources, agent account identity or game PVCs as a shutdown.
Removing source alone will not prune running resources.

After key rotation, update Vault, wait for ESO and trigger a reviewed pod-template
change through Git/Argo; environment credentials do not hot-reload. Keep existing
Playit tunnel allocations if the provider allows rotation without replacement.
Revert the voice_host setting to the private endpoint if public voice is disabled.

## References

- https://playit.gg/support/
- https://github.com/playit-cloud/playit-agent/pkgs/container/playit-agent
- https://github.com/playit-cloud/playit-agent/blob/v1.0.10/docker/entrypoint.sh
