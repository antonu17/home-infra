# Gateway bootstrap after Argo CD installation

This supersedes the TLS import and Gateway deployment sequence in `gitops.md`.
The operator reports `gateway`, `argocd`, `cilium` and `cert-manager`
Synced/Healthy on 2026-10-10. The sequence below is fresh-bootstrap/recovery
guidance, not pending adoption. No commands were executed by the agent; live
HTTPS/renewal acceptance is separate from the supplied Argo health list.

## Ownership

- Operator: initial Argo CD Kustomize bootstrap and Vault credential provisioning.
  ESO maintains the Route53 credential Secret.
- cert-manager: generated frontend TLS Secret and renewals.
- Argo root `gitops`: AppProjects and child Applications.
- Argo child `argocd`: Argo CD itself after bootstrap.
- Argo child `cert-manager`: upstream Helm chart, CRDs and ClusterIssuers.
- Argo child `gateway`: frontend Certificate, Gateway and two Argo
  routes.

Frontend: `gateway/home-cloud`, VIP `10.40.0.10`, Secret
`gateway/home-antonu-org-tls`. TLS terminates there. The Gateway forwards plain
HTTP to `argocd-server:80`; Argo therefore deliberately renders
`server.insecure=true`. This is an internal plaintext trust boundary, not an
end-to-end TLS design. No backend Certificate, CA ConfigMap, BackendTLSPolicy, or
`gateway-system` namespace is required.

## 1. Certificates — Argo-managed configuration

Complete the ordered onboarding in [cert-manager](cert-manager.md) first. Keep
port-forward UI access available and confirm the production issuer is Ready before
syncing the Gateway Application:

```sh
kubectl get clusterissuer letsencrypt-prod
```

The checked-in frontend Certificate selects `letsencrypt-prod`. Inspect the served
certificate's issuer, not only `Ready`, to verify production issuance. For a first
untested deployment, use the documented staging-first Git/Argo workflow.

No backend certificate is created. Do not add an Argo backend Certificate,
`argocd-server-tls` Secret, CA ConfigMap, or BackendTLSPolicy.

## 2. TLS boundary

Clients validate the wildcard certificate at the Cilium Gateway. Traffic from the
Gateway to Argo is HTTP inside the cluster. Keep the Service ClusterIP-only and do
not expose port 80 through NodePort or LoadBalancer.

## 3. Let Argo deploy the Gateway — manual steps

Review and commit/push the changed manifests to your GitHub `main` first. Argo
reads the remote repository, not your working tree. Configure read-only repository
credentials privately if necessary. Ensure VIP `10.40.0.10` is unused.

The root Application is installed with Argo CD by the bootstrap command in
`gitops.md`; do not apply the GitOps catalog separately. In the port-forwarded
Argo UI, sync `gitops`, then `argocd`, complete the cert-manager credential
bootstrap, combined sync and readiness checks, and only then sync
`gateway`.
Do not separately apply `kubernetes/gateway`. Root sync also registers the existing
ExternalDNS child; on a fresh bootstrap, defer its sync until the checks in [ExternalDNS](external-dns.md) pass.
On the existing cluster ExternalDNS is present but crash-looping (2026-10-10). Syncs remain manual, with no
automatic prune. The `gateway` project allows all resource kinds in its
destination; generated Secrets remain outside Argo ownership.

```sh
kubectl -n gateway wait --for=condition=Ready certificate/home-antonu-org --timeout=10m
kubectl -n gateway get gateway home-cloud -o yaml
kubectl -n gateway get services -o wide
kubectl -n argocd get httproutes -o yaml
```

Require current-generation Gateway Accepted/Programmed, VIP `10.40.0.10`, and
route Accepted/ResolvedRefs. Check BGP reachability before DNS changes. With DNS
already correct, visit `https://argocd.home.antonu.org`;
otherwise wait for the separately reviewed DNS step. Use `--grpc-web` for the
Argo CLI through HTTPRoute. Keep the port-forward as recovery access until all
checks pass. No ExternalDNS or router changes are part of this task.

## Hubble UI route — Argo-owned Cilium resources

Cilium Kustomize includes `kube-system/hubble-ui` and
`kube-system/hubble-ui-redirect` HTTPRoutes for `hubble.home.antonu.org`.
The shared Gateway admits `kube-system` on both listeners. Clients use the
existing Gateway VIP `10.40.0.10` on TCP 443; TCP 80 redirects to HTTPS.
TLS terminates at the Gateway using the existing wildcard certificate, then
forwards HTTP to `kube-system/hubble-ui:80`. No route authentication is configured;
keep access within the trusted home network. ExternalDNS derives the hostname
from the route under its existing activation and ownership procedure.

For current changes, load repository direnv and inspect the existing Service,
Gateway and route status first. Review `argocd app diff cilium` and, only if
listener permissions also change, `argocd app diff gateway` privately. Publish
reviewed source and manually sync the affected Applications without pruning;
do not separately apply `kubernetes/cilium/manifests` on the adopted cluster.

Read-only acceptance checks:

```sh
kubectl -n kube-system get service hubble-ui
kubectl -n gateway get gateway home-cloud -o yaml
kubectl -n kube-system get httproute hubble-ui hubble-ui-redirect -o yaml
curl --fail --resolve hubble.home.antonu.org:443:10.40.0.10 https://hubble.home.antonu.org/
curl -I --resolve hubble.home.antonu.org:80:10.40.0.10 http://hubble.home.antonu.org/
```

Require current-generation Accepted/ResolvedRefs, valid TLS/UI and HTTP→HTTPS
redirect. DNS is separate and currently affected by the ExternalDNS crash loop;
`--resolve` tests the Gateway path without relying on current DNS reconciliation.

If acceptance fails, retain recovery access and revert the source change, then
manually sync `cilium` and any affected `gateway` changes without pruning. This
restores declared configuration but does not delete removed source objects.
Deleting the two Hubble routes is **DESTRUCTIVE** to that UI path and requires a
separately reviewed exact-resource prune/deletion; do not treat it as routine
rollback. Keep `kube-system` in listener allowlists if other routes still need it.

## Other current listeners

The source also declares HTTPS port8443 for deCONZ WebSocket traffic, terminating
at the same wildcard Secret and admitting only the `deconz` namespace. Ports80
and443 admit the explicitly listed application namespaces. This listener does
not change Argo's HTTP backend or introduce a second Gateway/Application.
