# Vault configuration for home-cloud ESO

This module manages the NAS-hosted Vault KV v2 mount `home-cloud`, Kubernetes
auth mount `kubernetes-home-cloud`, and a separate read-only policy/role for each
workload. Secret values are stored directly in Vault, outside Terraform.

Terraform has been applied. On 2026-10-04, the cert-manager SecretStore and
Route53 ExternalSecret were checked Ready, and the operator confirmed a successful
Argo sync. The Home Assistant store remains an example, not part of its workload
Kustomization. The ADS-B role below is repository-prepared and has not yet been
applied.

| Vault role / policy | Kubernetes identity | Readable KV paths |
|---|---|---|
| `eso-adsb` | `adsb/vault-eso` | `home-cloud/adsb/*` |
| `eso-cert-manager` | `cert-manager/vault-eso` | `home-cloud/cert-manager/*` |
| `eso-external-dns` | `external-dns/vault-eso` | `home-cloud/external-dns/*` |
| `eso-synology-csi` | `synology-csi/vault-eso` | `home-cloud/synology-csi/*` |
| `eso-home-assistant` | `home-assistant/vault-eso` | `home-cloud/home-assistant/*` |

Both roles use login audience `vault`, a 15-minute token TTL, and a one-hour
maximum TTL. Policies allow scoped reads/metadata discovery and management of
the caller's own token. They do not grant secret writes or the default policy.

## 1. Load the existing private inputs

Run commands from the repository root. `KUBECONFIG` and `TALOSCONFIG` come from
project direnv; do not add explicit configuration flags.

- `.envrc` is the committed loader.
- `.envrc.local` is ignored and contains private inputs and workstation settings.
- `.private/vault-kubernetes-ca.pem` contains the Kubernetes API CA.
- `.private/vault-reviewer.jwt` contains the dedicated reviewer JWT.

The private files already exist on this workstation. Reuse them; do not recreate
accounts or issue another reviewer token as part of a normal Terraform run.
The local file uses these credential-file settings:

```sh
export VAULT_KUBERNETES_CA_FILE='.private/vault-kubernetes-ca.pem'
export VAULT_KUBERNETES_REVIEWER_JWT_FILE='.private/vault-reviewer.jwt'
```

Assume `VAULT_ADDR` and `VAULT_TOKEN` are already exported in your environment
(for example, from `$HOME/.envrc`). Do not duplicate the Vault address or token in
project-local files. The project loader maps them to the module's Terraform
variables and reads Kubernetes credentials from the configured files:

| Terraform variable | Local input |
|---|---|
| `TF_VAR_vault_address` | Existing `VAULT_ADDR` |
| `TF_VAR_vault_token` | Existing `VAULT_TOKEN` |
| `TF_VAR_kubernetes_host` | `VAULT_KUBERNETES_HOST` |
| `TF_VAR_kubernetes_ca_cert` | Contents of `VAULT_KUBERNETES_CA_FILE` |
| `TF_VAR_kubernetes_token_reviewer_jwt` | Contents of `VAULT_KUBERNETES_REVIEWER_JWT_FILE` |

Reload after changing inputs. These checks show only whether values exist:

```sh
direnv reload
test -n "$VAULT_ADDR"
test -n "$VAULT_TOKEN"
test -s .private/vault-kubernetes-ca.pem
test -s .private/vault-reviewer.jwt
test -n "$TF_VAR_vault_token"
test -n "$TF_VAR_kubernetes_ca_cert"
test -n "$TF_VAR_kubernetes_token_reviewer_jwt"
```

If a check fails, correct the local setting and reload before planning. For a
fresh checkout, copy `.envrc.local.example` only if `.envrc.local` does not exist,
fill the private inputs, and review/allow `.envrc` with `direnv allow`.
Keep `.private` mode 700 and private files mode 600. Do not print or commit
credentials, private environment files, state, or saved plans.

## 2. Check the Synology state share

The module uses Terraform's local backend with the state file on a mounted NAS
share. Keep both settings in `.envrc.local`, using this workstation's actual
mount and state path:

```sh
export TF_STATE_MOUNT='/Volumes/nas-share'
export TF_STATE_PATH='/Volumes/nas-share/terraform/vault.tfstate'
```

`.envrc` checks the mount and state parent directory, then supplies the backend
path through `TF_CLI_ARGS_init`. The `.terraform/` directory stays local; it
contains provider files and backend metadata, not the managed-resource state.
Initializing the backend alone does not create a populated resource state file.

The current SMB share does not support Terraform state locking. After the mount
checks pass, `.envrc` supplies `-lock=false` through `TF_CLI_ARGS_plan` and
`TF_CLI_ARGS_apply`, so normal `terraform plan` / `terraform apply` work without
extra flags. This is a CLI setting, not a `.tf` backend option. Explicit CLI flags
take precedence. Run from one workstation at a time: automatic flags disable
locking, they do not provide a replacement lock. Verify the share stays mounted
before each operation; stop if it disconnects. Restrict share access and keep
encrypted backups of state, which includes the reviewer JWT.

Do not migrate or import the already configured state during routine updates.
If changing backend paths, back up both state locations and review a one-time
`terraform -chdir=terraform/vault init -migrate-state` operation. Do not overwrite
an existing destination state or use `-force-copy`.

## 3. Plan and apply

Install Terraform 1.10 or later, below 2.0; Vault provider 5.9.0 is pinned.
With direnv loaded and the state share mounted, run from the repository root:

```sh
umask 077
terraform -chdir=terraform/vault init
terraform -chdir=terraform/vault validate
terraform -chdir=terraform/vault plan -out=configure.tfplan
```

Review the plan locally. Stop on unexpected deletions, mount/auth changes, or
broader secret access. If overriding `TF_VAR_eso_roles` with JSON, include every
identity you want to retain: the override replaces the default map.

Apply the reviewed plan (**operator-run live Vault changes**):

```sh
terraform -chdir=terraform/vault apply configure.tfplan
```

These commands do not deploy Kubernetes resources. Do not use `terraform destroy`
as rollback: disabling the KV mount deletes its data. Mounts have
`prevent_destroy`; renaming them requires a separately reviewed migration.

## 4. Configure each workload through Argo

Keep a namespaced SecretStore and a scoped Vault identity per workload. Cluster
stores and ESO's global TokenRequest grants remain disabled.

cert-manager already includes its `vault-eso` ServiceAccount, scoped TokenRequest
Role/RoleBinding, SecretStore and Route53 ExternalSecret in
`kubernetes/cert-manager/config/`. Its target remains
`cert-manager/route53-credentials`, with keys `access-key-id` and
`secret-access-key`, read from `home-cloud/cert-manager/route53-credentials`.
ESO preserves the Secret if the ExternalSecret or Vault entry is removed.

For a new workload:

1. Add its namespace, service account and non-overlapping secret prefix to
   `eso_roles`, then review/apply Terraform.
2. Add the store, identity/RBAC and ExternalSecret to that workload's existing
   Argo source/Kustomization. Use `examples/home-assistant-store.yaml` and
   `examples/external-secret.yaml` as references. ESO gets TokenRequest access
   only for the selected account; it requests the workload login JWT itself.
3. Populate the referenced secret properties in Vault. Commit/push only manifests
   containing references, then review and manually sync the workload Application
   without pruning. Do not separately apply an Argo-owned package.
4. Check store and ExternalSecret readiness without showing Secret payloads.

For cert-manager:

```sh
kubectl -n cert-manager wait --for=condition=Ready --timeout=180s secretstore/home-cloud-vault
kubectl -n cert-manager wait --for=condition=Ready --timeout=180s externalsecret/route53-credentials
kubectl -n cert-manager get secret route53-credentials
```

Vault HTTPS verification stays enabled. If using a private CA, configure the
store's `caProvider` or `caBundle`; the Kubernetes CA input verifies the Kubernetes
API, not Vault. NAS Vault must reach the API, and ESO must reach Vault.

ExternalDNS and Synology CSI credential values were copied into Vault and
verified against the existing Kubernetes Secrets on 2026-10-04. Their scoped
roles and ESO resources require operator Terraform apply and Argo sync; follow
[the deployment secret guide](../../docs/secret-management.md). CSI's driver, StorageClass and credentials are now included in one `synology-csi`
Argo Application, pending operator adoption. PVCs, PVs and NAS LUNs retain their
existing owners; follow the [CSI guide](../../kubernetes/synology-csi/README.md).

## Reviewer token maintenance

The current module still passes a dedicated `token_reviewer_jwt` to Vault.
`external-secrets/vault-token-reviewer` and its TokenReview-only RBAC are managed
alongside ESO in `kubernetes/external-secrets/vault-reviewer.yaml`; do not apply
the duplicate reviewer example separately.

ESO creates short-lived **workload login tokens** through each store's
`serviceAccountRef`. It does not renew the dedicated reviewer JWT stored in
`.private/vault-reviewer.jwt` or update Vault's auth configuration.

The earlier reviewer token was requested with a 24-hour lifetime; the API server
may have limited that duration. Before it expires, obtain a replacement for the
same reviewer identity using an API-accepted audience, save it privately at the
configured path, reload direnv, and plan/apply Terraform. Expiry breaks new Vault
Kubernetes logins. This maintenance remains required by the current design;
removing manual reviewer rotation requires an authentication design change, not
just a README edit. Keep the reviewer audience separate from the workload login
audience `vault`.

## References

- [Vault Kubernetes authentication and reviewer-token lifetime](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [ESO Vault authentication](https://external-secrets.io/latest/provider/hashicorp-vault/)
- [ESO Secret retention](https://external-secrets.io/latest/guides/ownership-deletion-policy/)
- [Vault Terraform provider 5.9.0](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs)
