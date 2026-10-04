# Cilium

The root package follows the repository's Kustomize + upstream Helm pattern:
chart `cilium` 1.20.2, release `cilium`, namespace `kube-system`, and
`values.yaml`, alongside local BGP/LB-IPAM/Hubble resources and pinned Gateway
API CRDs. The Helm repository is the official `https://helm.cilium.io/`.
Do not set a global Kustomize namespace: the package includes cluster-scoped
resources and explicitly namespaced Hubble routes.

Local rendering (downloads the pinned chart and Gateway API CRDs):

```sh
kustomize build --enable-helm kubernetes/cilium
```

Rendering does not transfer deployment ownership. The existing Cilium release
remains Helm-managed, as documented in `docs/gitops.md`. Do not apply the combined
render or add it to Argo without a separate adoption and rollback plan. Keep the
existing Helm upgrade procedure for the CNI; never uninstall Cilium to migrate.

The local resource entry point excludes chart resources and Gateway API CRDs:

```sh
kubectl kustomize kubernetes/cilium/manifests
```

For operator deployment, review `kubectl diff -k kubernetes/cilium/manifests`
(exit 1 means differences), then run `kubectl apply -k kubernetes/cilium/manifests`
only if the diff contains intended changes. This includes BGP/LB-IPAM as well as
Hubble routes. Follow `docs/gateway-bootstrap.md` for route acceptance checks.
Install Gateway API CRDs separately before the Helm upgrade using
`kubernetes/cilium/gateway-api`. Keep versions and values consistent between
rendering and Helm maintenance. Existing CNI/BGP health checks and stop conditions
remain mandatory; no deployment or ownership migration is performed by this edit.

## Existing TLS material

The root maintenance render excludes Secrets and ConfigMaps labeled
`cilium.io/helm-template-non-idempotent=true`. Offline Helm cannot look up the
live CA or leaf certificates and otherwise generates replacements on every
render. This exclusion preserves existing Helm-generated TLS resources; it does
not migrate their ownership or renew them. Never prune these excluded resources.

Before applying the root maintenance render, confirm that `cilium-ca`,
`hubble-server-certs`, and `hubble-relay-client-certs` exist in
`kube-system` (names only; do not display their contents). Stop if any are missing.
This root package is now for an existing installation, not standalone fresh
bootstrap; use the documented Helm bootstrap to establish TLS material first.
Certificate renewal and a complete Helm ownership migration remain separate work.

The maintenance render also omits the operator readiness probe's
`initialDelaySeconds`, leaving its existing field management and value intact.
The pinned chart explicitly renders zero; adopting that field is not needed for
Hubble routing. This is a limited maintenance apply, not full Helm adoption.
The 1.20.2 chart does not reference the older `hubble-ca-cert` ConfigMap.
