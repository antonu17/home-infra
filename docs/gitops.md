# GitOps, bootstrap and recovery

## Recorded deployment — 2026-10-10

The operator supplied `argocd app list`: all 14 Applications are Synced and use
Manual sync. Thirteen are Healthy; ExternalDNS is Progressing and its controller
is crash-looping. The agent has not queried the live cluster. This is deployment
and resource-health evidence, not proof of every DNS, HTTPS, storage or integration
acceptance check.

| Application | Namespace | Recorded health / source |
|---|---|---|
| `gitops` | `argocd` | Healthy; directory catalog `kubernetes/gitops` |
| `argocd` | `argocd` | Healthy; `kubernetes/argocd` |
| `cilium` | `kube-system` | Healthy; `kubernetes/cilium` |
| `cert-manager` | `cert-manager` | Healthy; `kubernetes/cert-manager` |
| `external-secrets` | `external-secrets` | Healthy; `kubernetes/external-secrets` |
| `gateway` | `gateway` | Healthy; `kubernetes/gateway` |
| `external-dns` | `external-dns` | Progressing; `kubernetes/external-dns` |
| `synology-csi` | `synology-csi` | Healthy; `kubernetes/synology-csi` |
| `adsb`, `anki-sync`, `deconz`, `grocy`, `home-assistant`, `mealie` | Matching application name | Healthy; `kubernetes/apps/<name>` |

`gitops` is the root Application. `gateway` is the Gateway Application;
`gateway/home-cloud` is the Gateway **resource**, not the Application name.
`home-cloud` also remains the Vault KV mount/TXT owner/cluster identifier.
The former `home-cloud-gateway` Application name is obsolete.

## Sources, ownership and access boundaries

`kubernetes/argocd/gitops.yaml` bootstraps the root AppProject and Application.
The root points to `kubernetes/gitops`, a directory of YAML pairs containing
AppProjects and child Applications; there are no `bootstrap/` or `applications/`
subdirectories and no catalog Kustomization. Argo performs directory discovery.

All installed platform/workload packages are now Argo-owned. Their pinned charts
are rendered with Kustomize `helmCharts`; operator Helm upgrades/direct applies
must not compete with those Applications. Cilium adoption and CSI adoption are
complete according to the operator list; their README handoff procedures remain
historical/recovery references. PVCs/PVs and NAS LUNs retain their existing owners.

Sync is manual, with no automated prune/self-heal or cascading Application
finalizers in the current catalog. Some children have server-side-apply options;
others rely on defaults. Preserve individual retention annotations and inspect
the diff before any sync. A removed source object is not automatically deleted.

The current AppProjects allow all cluster-scoped and namespaced resource kinds.
Most child projects restrict repository/destination namespaces, but the root
`gitops` project permits wildcard repositories and destinations. These are broad
administrative boundaries; the repo does not implement the older documented
kind-level least-privilege restrictions. This audit does not change RBAC.

Pins in source: Argo chart `10.9.6`, Cilium `1.20.2`, Gateway API CRDs `1.6.1`,
cert-manager `v1.21.2`, ESO chart `2.10.0`, ExternalDNS chart `1.22.0` / app
`0.22.0`, Synology CSI `v1.3.1`. Preserve pins unless performing a separate
researched upgrade. See [cert-manager](cert-manager.md) for its Kubernetes
support gap.

## Networking, TLS and secrets

Cilium LB-IPAM pool `10.40.0.0/24` is routed service space, not a physical VLAN.
Four nodes `.40.21`, `.40.40`, `.40.41`, `.40.42` (ASN65001) peer with RB5009
`.40.1` (ASN65000); allocated service VIPs are advertised as /32s. The API VIP
is separately `192.168.40.20`. Gateway `gateway/home-cloud` requests `10.40.0.10`.

TLS flow is client HTTPS → Gateway termination → Argo HTTP on
`argocd-server:80`. Argo deliberately sets `server.insecure=true`; there is no
backend Certificate or BackendTLSPolicy. The Argo CLI uses `--grpc-web` through
HTTPRoute. [Gateway bootstrap](gateway-bootstrap.md) contains the ordered checks.

cert-manager owns issuance/renewal and generated ACME/TLS Secrets. Its frontend
Certificate belongs to the `gateway` Application. Route53 credentials come from
NAS-hosted Vault through ESO, not a manually maintained credential manifest.
ExternalDNS owns application A/TXT records according to its registry; manual
infrastructure names require explicit collision review. **ExternalDNS is currently
failing**, so a Healthy Gateway does not prove DNS automation works.

Approved Tailscale routing to service IPs needs a route covering `10.40.0.0/24`,
appropriate grants and a return path. A route covering only `192.168.100.0/24`
would be insufficient; current advertisements were not supplied. Router and
Tailscale configuration are independent operator responsibilities.

## Read-only preflight and local review

Run from `/Users/anton/projects/home-infra` with repository direnv loaded:

```sh
direnv reload
: "${KUBECONFIG:?Load the repository direnv environment}"
: "${TALOSCONFIG:?Load the repository direnv environment}"
kubectl config current-context
argocd app list
kubectl get nodes -o wide
kubectl get services -A -o wide
kubectl get ciliumbgpclusterconfigs,ciliumbgppeerconfigs,ciliumbgpadvertisements,ciliumloadbalancerippools
kubectl -n gateway get gateway home-cloud -o yaml
kubectl -n argocd get httproutes -o yaml
```

Review existing Application diffs privately: rendered charts/diffs can include
Secrets. Require no unintended replacement, deletion, selector, storage, CRD or
field-manager change. Argo reads remote GitHub `main`, not the working tree.
The operator reviews and commits/pushes only intended changes.

For local rendering, `kustomize build --enable-helm <package>` downloads pinned
charts/remote sources but does not contact the Kubernetes API. Use `kubectl
kustomize kubernetes/gateway` for the chart-free Gateway package. Review sensitive
rendered outputs privately and do not publish them. The old
`kubernetes/verify-gitops.sh` no longer exists; do not claim its checks passed.
The ExternalDNS-specific verifier also has source drift; see its runbook.

## Existing cluster changes — operator-run

1. Confirm preflight and backups. Preserve Talos identity, etcd, Vault, CSI
   credentials and independent application-data backups.
2. Review the complete Git/Argo diff and publish reviewed source yourself.
3. If registering a new/changed child, manually sync `gitops` first.
4. Manually sync only the affected Application, with pruning disabled unless a
   separately reviewed deletion is required. Do not rerun initial bootstrap or
   alternate managers for an already adopted package.
5. Verify the affected resource health and service acceptance; stop on regression.
   For ExternalDNS use [its open-issue checks](external-dns.md), not repeated sync
   as evidence of recovery.

Revert an unwanted source change in Git, publish it and manually sync the affected
Application. Deletion/pruning is **DESTRUCTIVE** and requires naming the exact
objects and reviewing their dependent workloads/data first. Do not delete CNI
CRDs, namespaces, PVCs/PVs, LUNs or credential Secrets to recover an application.

## Fresh-cluster bootstrap and recovery only

These are operator-run live procedures, **not instructions to repeat on the
current adopted cluster**. No commands here were executed by the agent.

1. Restore router/NAS/network/DNS/PXE/factory/registry and independent backups.
   Use [the numbered router source](../network/mikrotik-rb5009upr/README.md).
   Treat full router exports/backups as sensitive and potentially older than the
   last import; collect current state privately. Preserve the documented PXE
   filename/menu discrepancies until explicitly reconciled.
2. Follow [Talos](talos-cluster.md), preserving the existing identity. Initialize
   etcd once only for a genuinely new cluster; state loss requires Talos recovery.
   Never bootstrap an intact restarted cluster. Current architecture has one CP.
3. Install Gateway CRDs before Cilium and cert-manager. For a fresh cluster only,
   review/apply `kubernetes/cilium/gateway-api`, install pinned Cilium with its
   values, then apply its local manifests after Cilium CRDs exist. Restore node,
   DNS and BGP health before application adoption.
4. Restore CSI credentials and driver as a controlled bootstrap owner, preserving
   PV/LUN mappings; recreating a PVC name does not restore its former data.
5. Bootstrap the pinned Argo package only after checking for existing managers:

   ```sh
   kustomize build --enable-helm kubernetes/argocd | \
     kubectl apply --server-side --force-conflicts \
       --field-manager=argocd-controller -f -
   kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=10m
   kubectl -n argocd rollout status deployment/argocd-server --timeout=10m
   kubectl -n argocd port-forward service/argocd-server 8080:80
   ```

   `--force-conflicts` transfers field ownership; it is a reviewed bootstrap
   handoff, not a routine repair flag. Keep port-forward recovery access.
   Retrieve/change the initial admin password privately; never paste it or Secret
   payloads. Removing the initial-admin Secret is an explicit deletion of that
   exact Secret after verifying replacement authentication.
6. Restore read-only repository access privately. Sync `gitops`, then `argocd`;
   adopt Cilium/CSI once using their guides and stop their bootstrap managers.
   Restore Vault/ESO and retained credentials before dependent applications.
7. Follow cert-manager and Gateway readiness gates, then recover DNS automation.
   Restore workloads/data with the original mappings and verify application
   acceptance. All current apps, including Home Assistant/Matter, are in source.

The control-plane VM and worker-01 share the NAS, as do Synology-backed workload
volumes on the physical workers. Non-HA Argo and a single etcd member do not
provide independent fault tolerance. Port-forward, existing kubeconfig and Talos
credentials provide recovery access; they do not remove these shared dependencies.

## References

- [Cilium adoption / rollback](../kubernetes/cilium/README.md)
- [CSI adoption / rollback](../kubernetes/synology-csi/README.md)
- [Gateway TLS and acceptance](gateway-bootstrap.md)
- [cert-manager / Route53](cert-manager.md)
- [Vault / ESO ownership](secret-management.md)
- [Production incident postmortems](../incidents/postmortems/README.md)
