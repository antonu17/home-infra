# Synology CSI through Argo CD

The `synology-csi` Application adopts the existing driver and StorageClass and
includes its Vault-backed credentials in the same Kustomize package. Repository
onboarding is prepared; no cluster changes have been executed here.

The package includes Namespace, CSIDriver, controller StatefulSet, node DaemonSet,
their ServiceAccounts/RBAC, `synology-block` StorageClass, and ESO login/store/secret
resources. Driver and sidecar versions, pod specifications, selectors, and storage
settings are preserved. Vendor manifests remain pinned and unmodified.

It does not manage existing PVCs, PVs or NAS LUNs. `storage-test.yaml` is an optional
operator test and is not included in the production Kustomization.

## Ownership and ordering

- Namespace is reconciled at wave `-2`; its existing privileged Pod Security level
  is retained because the driver needs privileged host access.
- ESO login ServiceAccount/TokenRequest RBAC is wave `-1`.
- Driver RBAC, CSIDriver, StorageClass, SecretStore and ExternalSecret are wave `0`.
- Controller/node workloads are wave `1`.

The source adds `Prune=false,Delete=false` to every resource. The Application has
no cascading deletion finalizer and no automated sync/pruning. Server-side apply
is enabled; client-side apply migration is disabled. Shared Argo ownership fails
the sync instead of silently taking resources from another Application.

ESO targets the existing `synology-csi/client-info-secret`, preserving the exact
`client-info.yml` bytes. Vault data is at `home-cloud/synology-csi/client-info`;
Terraform's `eso-synology-csi` identity reads that workload prefix only. The
ExternalSecret uses Orphan/Retain, so removing it does not delete the Secret.

Storage-backed Vault/ESO depend on functioning storage. Keep the existing retained
credential Secret during outages and keep independent Vault backups; rebuilding
an empty cluster requires a reviewed credential/storage bootstrap sequence.

## Operator-run adoption

Use the project direnv environment, including `KUBECONFIG`. Read-only preflight:

```sh
direnv reload
kubectl config current-context
kubectl -n synology-csi get statefulset,daemonset,pods
kubectl get csidriver csi.san.synology.com
kubectl get storageclass synology-block
kubectl get pvc -A
kubectl get pv
kubectl -n synology-csi get secret client-info-secret
argocd app list
```

Existing data/backups and the credential Secret must remain available. Terraform
was reported applied on 2026-10-04. Confirm ESO and its CRDs are ready and the
reviewer JWT remains valid. Do not reinstall the driver or delete storage to adopt.

Render offline and check the AppProject allows every rendered kind:

```sh
kustomize build kubernetes/synology-csi
```

Review and commit/push the source, documentation and Application rename together.
Replace the old `kubernetes/gitops/synology-csi-secrets.yaml` with
`kubernetes/gitops/synology-csi.yaml`; do not commit both declarations. Argo reads
remote Git, not the working tree.

If an older `synology-csi-secrets` Application is listed, detach it before syncing
the new Application. This **deletes only Argo Application metadata**
(`argocd/synology-csi-secrets`) and retains its managed resources:

```sh
argocd app delete synology-csi-secrets --cascade=false
```

Skip that command if the Application does not exist. Its old manifest must already
be removed from the pushed Git revision so the root will not recreate it.
Never use a cascading delete for this handoff.

These are **operator-run live adoption changes**:

```sh
argocd app sync gitops
argocd app get synology-csi --hard-refresh
argocd app diff synology-csi
```

Review the diff before syncing. Expect Argo retention/tracking annotations and ESO
resources; stop on pod-template changes, selector/image changes, credential-data
changes, StorageClass parameters/reclaim-policy changes, replacements or deletion.
The controller was observed with one ready replica and the node DaemonSet with
two ready instances on 2026-10-04. The controller stays on `talos-worker-01`; nodes
keep `storage.home.antonu.org/synology-iscsi=true` selection.

After the diff is approved locally:

```sh
argocd app sync synology-csi
```

Keep pruning disabled. Do not use force/replace or prune to resolve conflicts.
After adoption, make driver changes through Git/Argo rather than applying this
Kustomize package separately.

## Readiness and rollback

```sh
kubectl -n synology-csi wait --for=condition=Ready --timeout=180s secretstore/home-cloud-vault
kubectl -n synology-csi wait --for=condition=Ready --timeout=180s externalsecret/client-info-secret
kubectl -n synology-csi rollout status statefulset/synology-csi-controller --timeout=300s
kubectl -n synology-csi rollout status daemonset/synology-csi-node --timeout=300s
kubectl -n synology-csi get pods
kubectl get pvc -A
kubectl get pv
argocd app get synology-csi
```

Require Synced/Healthy, Ready store/ExternalSecret, ready driver workloads and
unchanged existing Bound claims. These checks do not establish backup recovery
or new-volume provisioning; no write-capable storage test is executed by this task.

On a failed adoption, stop further syncs and retain all driver/storage/credential
resources. Revert unintended changes in Git. To return lifecycle control to the
operator, first remove the Application declaration from the root's Git source,
then detach `argocd/synology-csi` with `argocd app delete synology-csi --cascade=false`.
That removes Argo metadata and retains workloads. Do not delete Namespace,
StorageClass, CSIDriver, PVCs/PVs, Secrets or NAS LUNs as rollback.

References: [Argo retention and server-side apply](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
and [non-cascading Application deletion](https://argo-cd.readthedocs.io/en/stable/user-guide/app_deletion/).
