# External Secrets Operator

ESO installation remains operator-controlled. The operator reports the Vault
Terraform configuration applied. Route53 values were copied to Vault on
2026-10-04; the cert-manager role and Kubernetes migration are prepared below.
No cluster changes were executed here.

Argo manages `kubernetes/external-secrets` using the upstream ESO chart pinned
at 2.10.0 (app v2.10.0). The `external-secrets` child Application uses manual
sync and server-side apply. The existing GitOps root discovers its Application
and AppProject from `kubernetes/gitops`. Do not install a separate Helm release
or apply this directory separately after Argo takes ownership.

The controller, webhook and certificate controller run in `external-secrets`.
Chart defaults provide probes and restrictive container security contexts.
Service account tokens are required for their Kubernetes API access.
Namespace and CRDs are protected from pruning. Cluster stores, cluster fan-out,
cluster generators and push controllers are disabled; namespaced SecretStore
and ExternalSecret resources remain enabled. ESO still has cross-namespace
Secret permissions: restrict who can change its Git sources and RBAC.
Automatic RBAC aggregation and global service-account TokenRequest grants are
disabled. The package now includes `vault-token-reviewer` and dedicated
TokenReview-only ClusterRole/ClusterRoleBinding for the NAS-hosted Vault; these
are deployed. A persistent service-account-token Secret supplies the reviewer JWT
for NAS-hosted Vault; its payload stays outside Git. Rotate it if exposed. Future Vault Kubernetes authentication must add a namespaced Role
restricted to the selected service account's `serviceaccounts/token` subresource
and a RoleBinding to ESO's controller service account.

## Operator-run installation

1. Confirm the intended context and check for a pre-existing installation:

   ```sh
   cd /Users/anton/projects/home-infra
   export KUBECONFIG="$PWD/talos/generated/home-cloud/kubeconfig"
   kubectl config current-context
   kubectl get deployments -A -l app.kubernetes.io/name=external-secrets
   helm list -A --filter external-secrets
   kubectl get crd externalsecrets.external-secrets.io secretstores.external-secrets.io
   ```

   NotFound CRDs are expected for a fresh installation. Stop if an existing
   installation owns these resources; review adoption before syncing.

2. Render locally (downloads pinned chart, does not contact Kubernetes):

   ```sh
   kustomize build --enable-helm kubernetes/external-secrets > /tmp/home-infra-eso.yaml
   ```

   Review the rendered resources and the Argo Application/AppProject diff.
   The chart's Kubernetes version constraint allows the repository's 1.37.1;
   local rendering does not prove live admission or runtime compatibility.

3. Review and commit/push only the intended files yourself. Argo reads GitHub
   `main`, not this working tree. In Argo, manually sync the existing `gitops`
   root to register the child, then review and sync `external-secrets` with
   pruning disabled. These syncs are **live changes, operator-run**.

4. Check readiness without displaying Secret payloads:

   ```sh
   kubectl wait --for=condition=Established --timeout=120s \
     crd/externalsecrets.external-secrets.io crd/secretstores.external-secrets.io
   kubectl -n external-secrets rollout status deployment/external-secrets --timeout=300s
   kubectl -n external-secrets rollout status deployment/external-secrets-webhook --timeout=300s
   kubectl -n external-secrets rollout status deployment/external-secrets-cert-controller --timeout=300s
   kubectl -n external-secrets get pods
   ```

   Require Argo Synced/Healthy and all three deployments ready. Stop if webhook
   admission or rollout fails. Review events privately; do not share credentials.

## Workload integration later

Vault provisioning is prepared in [terraform/vault](../terraform/vault/README.md):
KV v2 `home-cloud`, a dedicated Kubernetes auth mount, and configurable scoped
ESO policies/roles. Credentials enter through sensitive Terraform variables
exported by the committed project `.envrc` from ignored `.envrc.local` inputs. The operator reports Terraform applied; newly added roles require another plan/apply.
Reviewer RBAC is included in this ESO package. Workload TokenRequest RBAC,
namespaced SecretStore, and acceptance ExternalSecret examples live with that
module; activate those through the existing workload Argo source as described there. No Vault endpoint, credentials,
SecretStore or ExternalSecret is installed by this ESO chart package.
Add namespaced stores and Vault path/property references alongside each workload
when its connection is configured. Use `external-secrets.io/v1`. Actual values
remain in Vault and ESO-created Kubernetes Secrets; never commit Secret payloads.
Use TLS verification and restrict Vault policies to the required paths.
Route53 credentials are synchronized from Vault through the cert-manager source:
a namespaced Vault store and an ExternalSecret that preserves the existing Secret.
The operator confirmed a successful cert-manager sync on 2026-10-04; see
[the cert-manager guide](cert-manager.md). ExternalDNS and CSI have additional ESO migrations prepared; values are verified
in Vault, and their new roles/stores require operator apply/sync. Follow
[secret management](secret-management.md). Certificate Secrets stay cert-manager-owned.

## Rollback

Revert an installation configuration change in Git and manually sync the child
without pruning. Do not delete the namespace or CRDs to troubleshoot: deleting
CRDs can remove all corresponding stores and ExternalSecrets. Once consumers
exist, stopping ESO also stops refreshes; preserve generated Secrets and check
workloads before removing any component. This runbook does not authorize deletion.

## Sources

- [Upstream chart](https://github.com/external-secrets/external-secrets/tree/v2.11.0/deploy/charts/external-secrets)
- [Vault provider](https://external-secrets.io/latest/provider/hashicorp-vault/)
