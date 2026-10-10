# Deployment secrets through Vault and ESO

Use a separate namespaced SecretStore and Vault policy/role for each workload.
Secret values are kept in Vault KV v2, not Git or Terraform resources/state.
Kubernetes receives them through ESO; existing target names and keys are preserved.

## Recorded ownership and adoption — 2026-10-10

The operator reports all corresponding Applications adopted and Synced. ESO,
cert-manager, CSI, ADS-B and Anki are Healthy; ExternalDNS is Progressing and its
controller crash-loops awaiting webhook `/records`. The table records source
ownership plus Argo evidence, not a direct check of every SecretStore/ExternalSecret.

| Consumer | Vault path beneath `home-cloud` | Kubernetes target | Recorded status |
|---|---|---|---|
| ADS-B | `adsb/feeders` | `adsb/adsb-config` | Application Synced/Healthy; ESO references in source |
| Anki Sync | `anki-sync/credentials` | `anki-sync/anki-sync-credentials` | Application Synced/Healthy; ESO references in source |
| cert-manager | `cert-manager/route53-credentials` | `cert-manager/route53-credentials` | Application Synced/Healthy; ESO Ready also reported 2026-10-04 |
| ExternalDNS | `external-dns/mikrotik-credentials` | `external-dns/mikrotik-credentials` | Application Synced/Progressing; current DNS reconciliation fails |
| Synology CSI | `synology-csi/client-info` | `synology-csi/client-info-secret` | Application Synced/Healthy; DNS-startup incident recovered |

ExternalDNS reconciliation, ESO credential refresh and DSM registration are
separate checks. See [ExternalDNS](external-dns.md) and the
[CSI postmortem](../incidents/postmortems/2026-10-10-synology-csi-dns-startup.md).

ExternalDNS keeps `MIKROTIK_BASEURL`, `MIKROTIK_USERNAME`, `MIKROTIK_PASSWORD`.
CSI keeps the single `client-info.yml` key and the exact live configuration bytes.
Local plaintext sources are removed after private Vault verification and offline
manifest validation. Existing Kubernetes Secrets have not been deleted or changed
by this migration work. No account/password rotation was performed.

Controller-generated TLS/ACME keys, Argo admin/server/Redis credentials, Cilium CA,
and Talos identity remain with their existing owners. They are not local deployment
credential manifests and are not adopted by these ExternalSecrets. Home Assistant
currently has no repository-managed deployment credentials to migrate.

## Fresh onboarding / recovery — operator-run

From the repository root, load direnv (`VAULT_ADDR`, `VAULT_TOKEN`, `KUBECONFIG`
are preconfigured) and verify the NAS state share remains mounted. Terraform
plan/apply default to disabled locking through project `.envrc`; use one writer.

```sh
direnv reload
umask 077
terraform -chdir=terraform/vault init
terraform -chdir=terraform/vault plan -out=configure.tfplan
```

For a workload onboarding, require only its expected new role (`eso-adsb` or
`eso-anki-sync`). Stop on changes to existing roles, unintended deletion, auth
configuration changes, mount changes or scope expansion. If using
`TF_VAR_eso_roles`, retain every existing identity in that map.

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

Targets use ESO Owner/Retain lifecycle, explicitly for ADS-B/Anki and by
default for cert-manager/ExternalDNS/CSI. ESO attaches an
owner reference to each target Secret so Argo can display it as a child.
Deleting an ExternalSecret can garbage-collect its Secret. Retain protects only
against provider-entry deletion; existing values remain during Vault outages.
Do not delete ExternalSecrets or Secrets to force reconciliation.
Vault runs on the NAS; ESO runs in Kubernetes. Both share dependencies on the
NAS/network/control plane, and CSI's existing credential Secret is a recovery
dependency. Do not describe Vault as a Kubernetes-hosted PVC consumer. Keep independent
Vault backups; a fresh-cluster rebuild may need a reviewed bootstrap sequence.

Rotate values through the Vault UI or authenticated CLI, then wait for ESO refresh.
ExternalDNS reads environment credentials at startup, so a real credential rotation
needs an operator-scheduled rollout. CSI configuration reload behavior has not been
validated; plan a controlled driver rollout separately for an actual rotation.
Identical-value adoption does not require a restart. RouterOS and DSM account
changes remain separate operator actions.

The dedicated reviewer JWT is a persistent TokenReview-only credential;
see [Terraform reviewer maintenance](../terraform/vault/README.md#reviewer-token-maintenance).
ESO does not automatically rotate it.

References: [Vault provider](https://external-secrets.io/latest/provider/hashicorp-vault/)
and [Secret lifecycle](https://external-secrets.io/latest/guides/ownership-deletion-policy/).

## Owner-reference verification (source reviewed 2026-10-10)

ADS-B/Anki explicitly select Owner/Retain; current cert-manager, ExternalDNS
and CSI ExternalSecrets omit these fields and rely on ESO Owner/Retain defaults.
The old explicit-policy migration is no longer the current source diff. Verify
owner metadata without deleting/recreating targets; a change to defaults or
ownership must be reviewed separately. These Applications are already adopted.

Read-only checks, with repository direnv loaded:

```sh
kubectl config current-context
kubectl -n cert-manager wait --for=condition=Ready --timeout=180s externalsecret/route53-credentials
kubectl -n external-dns wait --for=condition=Ready --timeout=180s externalsecret/mikrotik-credentials
kubectl -n synology-csi wait --for=condition=Ready --timeout=180s externalsecret/client-info-secret
kubectl -n cert-manager get secret route53-credentials -o jsonpath='{.metadata.ownerReferences}'
kubectl -n external-dns get secret mikrotik-credentials -o jsonpath='{.metadata.ownerReferences}'
kubectl -n synology-csi get secret client-info-secret -o jsonpath='{.metadata.ownerReferences}'
```

Require the corresponding ExternalSecret owner reference and successful refresh.
These metadata checks do not print Secret payloads. Stop on ownership conflicts;
do not delete or replace a Secret. Detaching ownership via `creationPolicy:
Orphan` is a separate reviewed live change, not a generic rollback command.
Preserve CSI credentials during every storage recovery.
