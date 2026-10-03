# GitOps / Gateway bootstrap

> TLS/Gateway sequence superseded by [Gateway bootstrap](gateway-bootstrap.md).
> Do not run the historical namespace creation or TLS import steps below.
> Current namespace is `gateway`; cert-manager owns the frontend TLS Secret.

Prepared 2026-10-02; no live changes or connectivity checks performed by the agent.
Operator reports Cilium BGP and Synology CSI working. First prove this foundation,
then migrate applications. Commands run from the repository root, one stage at a
time, against the intended home-cloud kubeconfig.

## Decisions and ownership

| Owner | Resources |
|---|---|
| Operator / Talos | Machines, PKI, API VIP, router, NAS and DNS |
| Operator / Kustomize | Gateway API 1.6.1 standard CRDs; existing Cilium BGP/IPAM CRs; existing CSI; initial Argo bootstrap |
| Kustomize + upstream Helm | Argo CD chart 10.9.6 / app 3.5.3; root Application |
| Helm | Cilium 1.20.2 |
| Argo root `home-cloud` | Child Application declarations |
| Argo child `argocd` | Argo CD itself after the initial bootstrap |
| Argo child `home-cloud-gateway` | Gateway and Argo HTTPRoutes |
| Argo child `external-dns` | Official chart-rendered DNS controller/webhook, RBAC and network policy; initially dry-run |
| cert-manager | Gateway frontend TLS Secret |

Argo adopts its own Kustomize/Helm installation after bootstrap, using
server-side apply as required for its CRDs. It does not adopt the Cilium Helm
release or CSI. The one-time bootstrap deliberately forces field ownership from
the old Helm manager to Argo's `argocd-controller` manager; subsequent ownership
is declarative. There are no automated syncs, automated pruning, or
cascade-deletion finalizers. Manual sync is intentional for learning; Git remains
the desired state. A future CSI adoption needs a separate ownership review. The
Argo self-management project permits all resource kinds so it can manage the
chart, its CRDs, and the built-in root Application. It is restricted to this
repository and the `argocd` destination namespace, but it remains an
administrative boundary. Protect `main`.

Cilium's existing pool `10.40.0.0/24` and BGP CRs are unchanged. The Gateway requests
`10.40.0.10` for stable DNS. This trades automatic address selection for predictable
recreation; check it is unallocated before use. Only the allocated Service /32 is
advertised, not a permanent /24. The API VIP remains `192.168.40.20`.

TLS: client → Gateway HTTPS → Argo HTTP. The Gateway owns TLS termination and
forwards to `argocd-server:80`; Argo deliberately uses `server.insecure=true`.
The backend hop is plaintext inside the cluster and has no BackendTLSPolicy, CA
ConfigMap, or backend certificate. Use CLI `--grpc-web` through HTTPRoute.

The repo contains NAS service/DNS conventions but no complete ACME renewal
integration. Retain existing acme.sh / Route53 issuance; no AWS credentials or new
certificate controller are introduced. Certificate import/renewal remains an
explicit operator step, not falsely advertised as automated.

## 1. Preflight and local rendering

`bash kubernetes/verify-gitops.sh` performs local render/structural checks using
kubectl, Helm and Ruby's standard YAML library. It downloads pinned sources but
does not contact a Kubernetes API. This is not live admission or end-to-end testing.

```sh
export KUBECONFIG="$PWD/talos/generated/home-cloud/kubeconfig"
kubectl config current-context
kubectl get nodes -o wide
kubectl get services -A -o wide
kubectl get ciliumbgpclusterconfigs,ciliumbgppeerconfigs,ciliumbgpadvertisements,ciliumloadbalancerippools
kubectl kustomize kubernetes/cilium
kubectl kustomize kubernetes/gateway
kustomize build --enable-helm kubernetes/argocd
```

Confirm `.10` is unused, BGP healthy, and existing Cilium Helm release is named
`cilium` in `kube-system`. Compare `helm get values cilium -n kube-system` privately
against Git before upgrading; do not discard undocumented live overrides.
Keep encrypted Talos secrets, etcd snapshot, CSI credentials and application data
backups outside this NAS. All VMs and LUNs still share one physical failure domain.

## 2. CRDs, then Cilium

Cilium 1.20.2 uses the ten 1.6.1 CRDs included here, kube-proxy
replacement and L7 proxy. Existing values retain all Talos-specific settings.
Read the diff first; CNI rollout is a maintenance operation.

```sh
kubectl diff --server-side -k kubernetes/cilium/gateway-api
kubectl apply --server-side -k kubernetes/cilium/gateway-api
kubectl wait --for=condition=Established --timeout=120s \
  crd/gateways.gateway.networking.k8s.io crd/backendtlspolicies.gateway.networking.k8s.io
helm upgrade --install cilium oci://quay.io/cilium/charts/cilium \
  --version 1.20.2 -n kube-system -f kubernetes/cilium/values.yaml
kubectl -n kube-system rollout restart deployment/cilium-operator
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status deployment/cilium-operator --timeout=300s
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl get gatewayclass cilium -o yaml
```

Stop if the class is not Accepted or existing connectivity/BGP regresses. On a
fresh cluster also apply `kubectl apply -k kubernetes/cilium` after Cilium CRDs
exist. On the working cluster do not gratuitously re-own these existing CRs.
Default Gateway datapath uses TPROXY; if timeouts occur inspect Envoy/Cilium logs
and Talos kernel support, not blind firewall openings or beta datapath toggles.

## 3. Namespace and certificate prerequisites

Follow [Gateway bootstrap](gateway-bootstrap.md) for the current sequence. Only
the Gateway frontend needs a certificate. Argo's backend is intentionally HTTP;
do not add an `argocd-server-tls` Secret for this architecture.

## 4. Bootstrap Argo, access it without the Gateway

```sh
kustomize build --enable-helm kubernetes/argocd | \
  kubectl apply --server-side --force-conflicts \
    --field-manager=argocd-controller -f -
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=10m
kubectl -n argocd rollout status deployment/argocd-server --timeout=10m
kubectl -n argocd get pods
kubectl -n argocd port-forward service/argocd-server 8080:80
```

This single bootstrap installs the pinned upstream chart and the `home-cloud`
root Application. `--force-conflicts` is intentional only for this Helm-to-Argo
ownership handoff; the explicit field manager makes the bootstrap and Argo's own
server-side sync use the same owner. Do not run Helm upgrades after this handoff.
The root creates all AppProjects and child Applications, including the `argocd`
child that takes over the same Kustomize package.

Keep port-forward running in another terminal and test the internal HTTP endpoint:

```sh
curl --fail http://localhost:8080/
```

Normal DNS is unchanged. Retrieve the initial admin password privately
with `argocd admin initial-password -n argocd` or the initial-admin Secret, change
it immediately, then delete only `argocd-initial-admin-secret`. Do not paste it
into chat/Git. Keep admin authentication enabled until a tested SSO/admin alternative
exists. No anonymous access is enabled.

Review and commit/push these repository changes yourself **before** syncing: Argo
fetches GitHub `main`, not your working tree. If the repo is private, configure a
read-only repository credential in Argo privately first (UI/CLI), never in Git.

Use the port-forward UI to sync `home-cloud`, then sync `argocd` and
`home-cloud-gateway`.
Alternatively use `argocd app sync` after authenticating. Both applications start
manual and neither prunes by default. Do not apply the Gateway directory separately
and give it a second lifecycle owner.

Pods and ReplicaSets created below a managed Deployment are visible in that
Application's resource tree. Argo's global Resources page intentionally shows
only objects directly declared in Git, not controller-created descendants.

## 5. Verify, then DNS

```sh
kubectl -n gateway get gateway home-cloud -o yaml
kubectl -n gateway get services -o wide
kubectl -n argocd get httproutes -o yaml
kubectl -n argocd get applications
```

Require Gateway Accepted/Programmed, address `10.40.0.10`, and HTTPRoute parent
Accepted/ResolvedRefs for the current generation. Verify MikroTik has the
corresponding /32 with expected BGP next hops. If frontend TLS fails, inspect the
Gateway listener, frontend Secret, certificate chain, and SAN.

Follow [ExternalDNS activation](external-dns.md) to create
`argocd.home.antonu.org → 10.40.0.10` automatically from its HTTPRoute. Bootstrap
Argo via port-forward while DNS automation is being validated. If an Argo record
already exists manually, exclude it until a separately reviewed migration; do not
silently adopt/overwrite it. Client resolvers must consult the MikroTik zone without
a Pi-hole forwarding loop. No public WAN forwarding is required.

```sh
dig +short argocd.home.antonu.org
curl --fail https://argocd.home.antonu.org/
curl -I http://argocd.home.antonu.org/
argocd login argocd.home.antonu.org --grpc-web
```

Expect validated HTTPS and HTTP→HTTPS redirect. Test LAN access first. Tailscale
must separately advertise/approve `10.40.0.0/24` with appropriate grants and a
working return path; current advertisement of only `192.168.100.0/24` is insufficient.
That subnet route is not a Cilium BGP aggregate advertisement. No Tailscale changes
are made here. Do not open management access to all VLANs merely to make it work.

## Fresh cluster and recovery

1. Restore router/NAS/DNS/PXE/factory/registry and secure source secrets. Existing
   `rb5009-config.rsc` predates recent VLAN/BGP changes: obtain a current sanitized
   export plus secure full backup; Git alone cannot yet recreate the live router.
2. Follow [Talos](talos-cluster.md): provision reviewed node configs with preserved
   identity, initialize etcd once for a genuinely new cluster, or use Talos's etcd
   recovery procedure for state loss. Never bootstrap an intact restarted cluster.
3. Install CRDs and Cilium Helm, then its separate CRs; confirm node/DNS/BGP health.
4. Restore CSI credential and apply existing CSI Kustomize. Preserve LUNs and
   retained PV mappings; recreating a PVC name does not restore its former data.
5. Bootstrap the pinned Argo Kustomize package, restore repository access, sync
   root, then Argo itself and Gateway. Restore DNS and verify. HA is not part of
   this graph.

If Argo or Gateway fails, kubeconfig + Helm + port-forward remain independent
recovery paths. Inspect `helm history` and review the previous revision before
rolling back a release; do not delete CNI CRDs or storage to recover the UI.
For Gateway changes revert the Git commit and manually sync. Deletion/pruning is
an explicit review, not automatic. Back up the Argo server secret if retaining SSO
or token identities matters; Git does not include these credentials.

Resource sizing: this deliberately uses non-HA Argo defaults. Monitor worker memory
after installation and before adding HA; 8 GiB is shared by CSI and applications,
not reserved for Argo. Three control planes on one NAS do not change that capacity.

## Sources

- [Cilium 1.20 Gateway prerequisites](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [Official Argo Helm chart](https://github.com/argoproj/argo-helm/tree/argo-cd-10.9.6/charts/argo-cd)
- [Argo Gateway / ingress](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)
