# Deployment secrets through Vault and ESO

Use a separate namespaced SecretStore and Vault policy/role for each workload.
Secret values are kept in Vault KV v2, not Git or Terraform resources/state.
Kubernetes receives them through ESO; existing target names and keys are preserved.

## Migration status (2026-10-04)

| Consumer | Vault path beneath `home-cloud` | Kubernetes target | Status |
|---|---|---|---|
| ADS-B | `adsb/feeders` | `adsb/adsb-config` | References prepared; placeholder/real values and Terraform apply operator-pending |
| cert-manager | `cert-manager/route53-credentials` | `cert-manager/route53-credentials` | ESO Ready and operator sync confirmed |
| ExternalDNS | `external-dns/mikrotik-credentials` | `external-dns/mikrotik-credentials` | Values verified in Vault; Terraform applied, Argo sync pending |
| Synology CSI | `synology-csi/client-info` | `synology-csi/client-info-secret` | Values verified in Vault; Terraform applied, Argo sync pending |

ExternalDNS keeps `MIKROTIK_BASEURL`, `MIKROTIK_USERNAME`, `MIKROTIK_PASSWORD`.
CSI keeps the single `client-info.yml` key and the exact live configuration bytes.
Local plaintext sources are removed after private Vault verification and offline
manifest validation. Existing Kubernetes Secrets have not been deleted or changed
by this migration work. No account/password rotation was performed.

Controller-generated TLS/ACME keys, Argo admin/server/Redis credentials, Cilium CA,
and Talos identity remain with their existing owners. They are not local deployment
credential manifests and are not adopted by these ExternalSecrets. Home Assistant
currently has no repository-managed deployment credentials to migrate.

## Operator-run activation

From the repository root, load direnv (`VAULT_ADDR`, `VAULT_TOKEN`, `KUBECONFIG`
are preconfigured) and verify the NAS state share remains mounted. Terraform
plan/apply default to disabled locking through project `.envrc`; use one writer.

```sh
direnv reload
umask 077
terraform -chdir=terraform/vault init
terraform -chdir=terraform/vault plan -out=configure.tfplan
```

For the ADS-B onboarding, require the addition of `eso-adsb` only. Stop on changes
to existing roles, unintended deletion, auth configuration changes, mount changes
or scope expansion. If using `TF_VAR_eso_roles`, retain every existing identity in
that map.

Apply the reviewed plan (**live Vault changes**):

```sh
terraform -chdir=terraform/vault apply configure.tfplan
```

Review and commit/push the intended declarative changes. Argo consumes remote Git,
not the local working tree. ESO and its CRDs must be healthy before activation.

- Sync the `gitops` root to register the full `synology-csi` Application.
- Review and sync existing `external-dns`, with pruning disabled.
- Adopt and sync `synology-csi`, with pruning disabled, following the
  [CSI adoption guide](../kubernetes/synology-csi/README.md).

The single CSI Application includes the driver workloads, RBAC, CSIDriver,
retained StorageClass, namespace and ESO resources from `kubernetes/synology-csi`.
It excludes storage-test resources and existing PVCs/PVs/LUNs. Source resources
have `Prune=false,Delete=false`; the Secret remains ESO-created and retained.
Stop separately applying the driver package after Argo adopts it. If the older
credential-only Application exists, detach it without cascading before adoption;
see the CSI guide for the handoff.

Check readiness without printing payloads or annotations:

```sh
kubectl -n external-dns wait --for=condition=Ready --timeout=180s secretstore/home-cloud-vault
kubectl -n external-dns wait --for=condition=Ready --timeout=180s externalsecret/mikrotik-credentials
kubectl -n external-dns get secret mikrotik-credentials
kubectl -n external-dns get deployment external-dns
kubectl -n synology-csi wait --for=condition=Ready --timeout=180s secretstore/home-cloud-vault
kubectl -n synology-csi wait --for=condition=Ready --timeout=180s externalsecret/client-info-secret
kubectl -n synology-csi get secret client-info-secret
kubectl -n synology-csi get statefulset,daemonset,pods
```

A first reconciliation may briefly report the store not ready; require final
`Ready=True` / `SecretSynced`. Offline rendering does not prove authentication,
network access or workload health. Inspect errors privately if readiness fails.

## Retention, bootstrap and rotation

Targets use `creationPolicy: Owner` / `deletionPolicy: Retain`. ESO attaches an
owner reference to each target Secret so Argo can display it as a child.
Deleting an ExternalSecret can garbage-collect its Secret. Retain protects only
against provider-entry deletion; existing values remain during Vault outages.
Do not delete ExternalSecrets or Secrets to force reconciliation. Storage-backed Vault/ESO need functioning cluster storage,
so CSI's existing credential Secret is also a recovery dependency. Keep independent
Vault backups; a fresh-cluster rebuild may need a reviewed bootstrap sequence.

Rotate values through the Vault UI or authenticated CLI, then wait for ESO refresh.
ExternalDNS reads environment credentials at startup, so a real credential rotation
needs an operator-scheduled rollout. CSI configuration reload behavior has not been
validated; plan a controlled driver rollout separately for an actual rotation.
Identical-value adoption does not require a restart. RouterOS and DSM account
changes remain separate operator actions.

The dedicated reviewer JWT is still an expiring input to Vault Kubernetes auth;
see [Terraform reviewer maintenance](../terraform/vault/README.md#reviewer-token-maintenance).
ESO does not automatically rotate it.

References: [Vault provider](https://external-secrets.io/latest/provider/hashicorp-vault/)
and [Secret lifecycle](https://external-secrets.io/latest/guides/ownership-deletion-policy/).

## Owner-reference activation (prepared 2026-10-05)

This change updates only the three ExternalSecret target creation policies;
Vault paths, Secret names/keys, refresh settings and Retain policies stay the same.
No ESO Deployment rollout or Vault changes are needed.

Operator-run sequence, with repository direnv loaded:

1. Confirm the intended context with `kubectl config current-context`. Ensure
   recovery access to the corresponding Vault entries. Review Git changes and
   commit/push only the intended files.
2. Review `argocd app diff cert-manager`, `argocd app diff external-dns` and
   `argocd app diff synology-csi` privately. Stop on unrelated workload changes,
   replacements, deletions or Secret payload differences.
3. Live changes, operator-run: sync each affected application without pruning:

   ```sh
   argocd app sync cert-manager
   argocd app sync external-dns
   argocd app sync synology-csi
   ```

4. Verify ESO reconciliation and only Secret owner metadata:

   ```sh
   kubectl -n cert-manager wait --for=condition=Ready --timeout=180s externalsecret/route53-credentials
   kubectl -n external-dns wait --for=condition=Ready --timeout=180s externalsecret/mikrotik-credentials
   kubectl -n synology-csi wait --for=condition=Ready --timeout=180s externalsecret/client-info-secret
   kubectl -n cert-manager get secret route53-credentials -o jsonpath='{.metadata.ownerReferences}'
   kubectl -n external-dns get secret mikrotik-credentials -o jsonpath='{.metadata.ownerReferences}'
   kubectl -n synology-csi get secret client-info-secret -o jsonpath='{.metadata.ownerReferences}'
   ```

   Require an ExternalSecret owner reference with the corresponding name and UID.
   Refresh the Argo application tree. Stop on ownership conflicts; do not delete
   or replace a Secret to resolve them.

For rollback, restore `creationPolicy: Orphan` in Git and sync without pruning,
then verify the owner reference has been removed before deleting any ExternalSecret.
Do not delete the CSI credential Secret: it is a storage recovery dependency.
