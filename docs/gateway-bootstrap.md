# Gateway bootstrap after Argo CD installation

This supersedes the TLS import and Gateway deployment sequence in `gitops.md`.
Repository preparation only: no commands below have been executed by the agent.

## Ownership

- Operator: initial Argo CD Kustomize bootstrap and Git-ignored Route53
  credential Secret.
- cert-manager: generated frontend TLS Secret and renewals.
- Argo root `home-cloud`: AppProjects and child Applications.
- Argo child `argocd`: Argo CD itself after bootstrap.
- Argo child `cert-manager`: upstream Helm chart, CRDs and ClusterIssuers.
- Argo child `home-cloud-gateway`: frontend Certificate, Gateway and two Argo
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
Argo UI, sync `home-cloud`, then `argocd`, complete the cert-manager credential
bootstrap, combined sync and readiness checks, and only then sync
`home-cloud-gateway`.
Do not separately apply `kubernetes/gateway`. Root sync also registers the existing
ExternalDNS child; **do not sync ExternalDNS yet**. Syncs remain manual, with no
automatic prune. The `home-cloud` project's existing namespaced-resource policy
allows the Certificate; generated Secrets remain outside Argo ownership.

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

## Hubble UI route — operator-managed Cilium resources

Cilium Kustomize includes `kube-system/hubble-ui` and
`kube-system/hubble-ui-redirect` HTTPRoutes for `hubble.home.antonu.org`.
The shared Gateway admits `kube-system` on both listeners. Clients use the
existing Gateway VIP `10.40.0.10` on TCP 443; TCP 80 redirects to HTTPS.
TLS terminates at the Gateway using the existing wildcard certificate, then
forwards HTTP to `kube-system/hubble-ui:80`. No route authentication is configured;
keep access within the trusted home network. ExternalDNS derives the hostname
from the route under its existing activation and ownership procedure.

For an Argo-adopted Cilium installation, commit/push the route changes and manually
sync `cilium` after syncing `gateway`; follow the Cilium adoption guide for checks.
The direct-apply sequence below is pre-adoption only.

Operator-run deployment, after loading the repository direnv environment:

1. Review `kubectl -n kube-system get service hubble-ui` and
   `kubectl -n gateway get gateway home-cloud`. Stop if the Service does not
   expose port 80 or the Gateway is not ready.
2. Review and commit/push only the intended source changes, then manually sync
   the Argo `home-cloud-gateway` Application to admit `kube-system`.
3. Review `kubectl diff -k kubernetes/cilium/manifests` (exit 1 means differences).
   This includes existing BGP/LB-IPAM resources but excludes the Helm chart and Gateway API CRDs; stop if
   the diff includes unintended changes.
4. Live change: run `kubectl apply -k kubernetes/cilium/manifests` only after reviewing
   the full diff. This package remains operator-managed, separate from Helm.
5. Check `kubectl -n kube-system get httproute hubble-ui hubble-ui-redirect -o yaml`.
   Require current-generation Accepted and ResolvedRefs on `gateway/home-cloud`.
   Verify TLS/UI with `curl --resolve hubble.home.antonu.org:443:10.40.0.10
   https://hubble.home.antonu.org/` (put the command on one line), and confirm
   TCP 80 redirects to HTTPS. Verify DNS separately once ExternalDNS is active.

If acceptance fails, stop and retain existing recovery access. To roll back,
remove only the two Hubble routes from source and delete exactly those resources
with `kubectl -n kube-system delete httproute hubble-ui hubble-ui-redirect`
(operator-run live change). Remove `kube-system` from the Gateway allowlists only
if no other routes need it, then commit/push and manually sync the Gateway.
