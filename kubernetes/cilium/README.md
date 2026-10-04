# Cilium — prepared Argo adoption

The root package follows the repository's Kustomize + upstream Helm pattern:
chart `cilium` 1.20.2 from `https://helm.cilium.io/`, release `cilium`,
namespace `kube-system`, and existing `values.yaml`, alongside BGP/LB-IPAM,
Hubble HTTPRoutes and pinned Gateway API CRDs. No global namespace transformer
is used: chart RBAC also targets `cilium-secrets` and custom resources are
cluster-scoped.

`kubernetes/gitops/cilium.yaml` adds AppProject/Application `cilium` to the
existing directory-based `gitops` catalog. The child remains manually synced,
without automatic prune or a cascade-deletion finalizer. Server-side apply
adopts rendered fields into `argocd-controller`; client-side apply migration is
disabled to avoid sweeping unrelated Helm fields into ownership. Shared-resource
conflicts stop sync. Every rendered resource has `Prune=false,Delete=false`,
and CRDs use wave `-2` before wave-0 resources. This is an administrative
networking boundary, scoped to the rendered cluster kinds and namespaces.

## TLS and existing fields

Offline Helm cannot look up live certificates. The package excludes Secrets and
ConfigMaps labeled `cilium.io/helm-template-non-idempotent=true`; existing
`kube-system/cilium-ca`, `hubble-server-certs` and `hubble-relay-client-certs`
remain outside Argo ownership. Do not prune or delete them. Their renewal and
backup remain operator responsibilities until a separate certificate lifecycle
is implemented. The 1.20.2 chart does not reference `hubble-ca-cert`.

The operator readiness `initialDelaySeconds` is omitted to retain its existing
field management. Argo adopts only fields present in the render. Helm's historical
release record and any omitted fields remain; this is not a fresh-cluster bootstrap.
Use the documented Helm bootstrap only before adoption on a fresh cluster.

## Operator adoption — no live actions performed by the agent

Run from `/Users/anton/projects/home-infra` with direnv loaded. Maintain Talos
management/recovery access; Cilium carries cluster and Argo connectivity.

1. Preflight: privately compare existing Helm values with Git and retain an
   encrypted backup of Helm release history, existing TLS material, and the last
   known-good sources outside Git. Do not print private keys. Confirm readiness:

   ```sh
   kubectl get nodes
   kubectl -n kube-system get daemonset cilium
   kubectl -n kube-system get deployment cilium-operator hubble-relay hubble-ui
   kubectl -n kube-system get secret cilium-ca hubble-server-certs hubble-relay-client-certs
   kubectl get ciliumbgpclusterconfigs,ciliumbgppeerconfigs,ciliumbgpadvertisements,ciliumloadbalancerippools
   kubectl -n argocd get configmap argocd-cm -o jsonpath='{.data.kustomize\.buildOptions}{"\n"}'
   ```

   Require `--enable-helm` in Argo's build options. Stop on unhealthy CNI/BGP,
   missing TLS resources, or live overrides absent from Git.
2. Check the local render with `kustomize build --enable-helm kubernetes/cilium`.
   Rendering downloads pinned public charts/CRDs and does not contact the
   Kubernetes API.
3. Review and commit/push only intended files yourself. Manually sync `gitops`
   to register the child (this does not sync Cilium):

   ```sh
   argocd app sync gitops --grpc-web
   argocd app get cilium --hard-refresh --grpc-web
   argocd app diff cilium --grpc-web
   ```

   Review all resource diffs and ownership. Stop on resources already tracked by
   another Argo Application, any unexpected scheduling/configuration changes,
   deletion, or certificate replacement. No Secret payloads should be rendered.
4. Live change, operator-run, after review:

   ```sh
   argocd app sync cilium --grpc-web
   argocd app wait cilium --sync --health --timeout 600 --grpc-web
   ```

   Argo's SSA uses force-conflicts to transfer desired fields from `helm` or
   `cilium-kustomize` to `argocd-controller`. Do not select Force, Replace, or Prune
   in the UI; Force/Replace can recreate CNI resources. Stop using separate Helm
   upgrades and kubectl applies after adoption. Never uninstall the old release.
5. Readiness and acceptance:

   ```sh
   kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
   kubectl -n kube-system rollout status deployment/cilium-operator --timeout=300s
   kubectl -n kube-system rollout status deployment/hubble-relay --timeout=300s
   kubectl get nodes
   kubectl get gatewayclass cilium
   kubectl -n gateway get gateway home-cloud
   kubectl -n kube-system get httproute hubble-ui hubble-ui-redirect -o yaml
   ```

   Require healthy nodes/CNI, working BGP/service reachability, Gateway
   Accepted/Programmed, and current route Accepted/ResolvedRefs. Test Hubble at
   `https://hubble.home.antonu.org`; DNS/TLS and actual flow visibility need live
   verification. Local render success does not establish them.

## Stop and rollback

If sync or connectivity fails, stop further syncs. If Argo remains reachable,
terminate an active operation with `argocd app terminate-op cilium --grpc-web`.
Revert only the failed Cilium source change in Git, push and manually sync the
last known-good revision without pruning. Do not delete the Application with
cascade, CRDs, BGP resources, namespaces, or TLS Secrets, and do not uninstall Helm.
If Argo cannot reach the API, use independent Talos recovery access and the saved
known-good sources; do not regenerate cluster identity. Returning to Helm is a
separate operator handoff requiring reviewed values/certificates and paused Argo
management, not an automatic `helm rollback` against stale history.

The `manifests/` and `gateway-api/` entry points remain useful for local inspection
and pre-adoption bootstrap. After Argo adoption, sync the child instead of applying
those directories independently.
