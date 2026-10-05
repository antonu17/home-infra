# cert-manager and Route53 DNS-01

Repository preparation only; nothing has been installed or checked on the live
cluster. The Argo root registers one manually synced `cert-manager` Application.
That Application renders the pinned upstream Helm chart and local ClusterIssuers
together through Kustomize. The Gateway Application owns the frontend Certificate.

## Version and compatibility gate

The official chart is pinned to **v1.21.2**. The
[official support matrix](https://cert-manager.io/docs/releases/) lists Kubernetes
**1.33–1.36** for cert-manager 1.21, not this cluster's **1.37.1**. This remains a
review candidate rather than a verified supported combination. Before syncing,
explicitly accept that gap for this lab or wait for a release documenting 1.37
support and update the pin and validation. Local rendering does not establish
runtime compatibility.

Gateway API CRDs must exist before cert-manager starts. The repository manages
those separately with Cilium. ListenerSet support is not enabled.

## Layout and ownership

```text
kubernetes/cert-manager/
  kustomization.yaml           # chart plus all non-secret resources
  values.yaml                  # CRDs and Gateway API controller configuration
  namespace.yaml               # cert-manager namespace, retained
  config/
    namespace.yaml             # gateway namespace, retained
    vault-store.yaml           # namespaced Vault store and scoped TokenRequest RBAC
    route53-external-secret.yaml # ESO references only; no credential values
    clusterissuers.yaml        # staging and production Route53 issuers
kubernetes/gateway/
  certificate.yaml             # gateway/home-antonu-org
kubernetes/gitops/
  bootstrap/cert-manager-project.yaml
  applications/cert-manager.yaml
```

`kubernetes/cert-manager/kustomization.yaml` follows the same pattern as the Argo
CD package: `helmCharts` renders the official chart from
`https://charts.jetstack.io`, while ordinary Kustomize `resources` add the
namespaces and ClusterIssuers. The chart values install and retain
its CRDs and enable Gateway API integration through the controller's supported
file-based configuration:

```yaml
config:
  apiVersion: controller.config.cert-manager.io/v1alpha1
  kind: ControllerConfiguration
  gatewayAPI:
    enabled: true
```

There is one Argo Application for cert-manager and its issuers. It uses server-side
apply for the large CRDs. Sync waves order retained namespaces at `-2`, Vault login identity/RBAC at `-1`,
chart resources, SecretStore and ExternalSecret at `0`, and ClusterIssuers at `1`.
ESO and its CRDs must already be healthy before cert-manager is synced. Argo waits
for the wave-0 resources before submitting issuer resources. The separate Gateway
Application owns its Certificate at wave `-1`, ahead of the Gateway at wave `0`.
Sync remains manual and pruning is not automated.

The dedicated AppProject permits only this repository, the `cert-manager` and
`gateway` namespaces, and the cluster-scoped kinds rendered by the pinned chart
plus `ClusterIssuer`.

## Secret boundary

Route53 credentials are stored in Vault KV v2 at
`home-cloud/cert-manager/route53-credentials`, with properties `access-key-id`
and `secret-access-key`. On 2026-10-04, the ignored local file was copied into
Vault and both values were verified privately against the source. Terraform was
reported applied by the operator; the newly added cert-manager role still needs
another operator plan/apply. No Kubernetes migration has been executed here.

The cert-manager Argo source now includes a namespaced `home-cloud-vault`
SecretStore and `route53-credentials` ExternalSecret. It authenticates as
`cert-manager/vault-eso` through `kubernetes-home-cloud`, role `eso-cert-manager`,
audience `vault`. ESO's controller has TokenRequest permission for that account
only. Terraform restricts the role to the `cert-manager/` Vault prefix.

ESO targets the existing `cert-manager/route53-credentials` Secret with the same
two keys consumed by the ClusterIssuers. `creationPolicy: Owner` creates or updates the Secret with an owner reference
to the ExternalSecret, allowing Argo to display it as a child. Deleting the
ExternalSecret can garbage-collect the Secret; `deletionPolicy: Retain` only
preserves it if the Vault entry disappears.
ESO now maintains the Secret; the operator confirmed a successful cert-manager
sync on 2026-10-04. Never commit, render, diff or paste Secret payloads. Any old
client-side last-applied annotation may also contain keys.

Automatically generated ACME account keys remain cert-manager-owned. Do not
manually create those account keys or the generated Gateway TLS Secret.

The IAM identity should be limited to:

- `GetChange` on Route53 changes.
- `ListResourceRecordSets` in the selected public `antonu.org` zone.
- `ChangeResourceRecordSets` only for TXT records named
  `_acme-challenge.home.antonu.org` in that zone.

The explicit hosted-zone ID means `ListHostedZonesByName` is unnecessary. This
policy assumes there is no delegated `_acme-challenge` zone or CNAME.

## Argo onboarding — operator-run, not executed here

Run from `/Users/anton/projects/home-infra`. Commit and push the reviewed files
first; Argo reads remote `main`, not the local working tree.

Read-only preflight:

```sh
kubectl config current-context
kubectl get crd gateways.gateway.networking.k8s.io
kubectl -n cert-manager get deployments 2>/dev/null || true
kubectl get crd certificates.cert-manager.io 2>/dev/null || true
argocd app get home-cloud
```

Before syncing, configure the new Vault role. These are **operator-run live
Vault changes**; inspect the Terraform plan first. Keep the existing
home-assistant role if you override `TF_VAR_eso_roles`. With the NAS SMB backend,
run from one workstation only; the share does not support Terraform locking.

```sh
cd /Users/anton/projects/home-infra
direnv reload
cd terraform/vault
umask 077
terraform plan -lock=false -out=configure.tfplan
terraform apply -lock=false configure.tfplan
cd ../..
```

Require only the intended cert-manager policy/role additions. Stop if the plan
removes existing roles or changes the mount/auth configuration unexpectedly.
Confirm ESO is healthy and its `ExternalSecret` / `SecretStore` CRDs exist before
syncing cert-manager. The Vault entry is already populated; no manual Kubernetes
Secret application is needed.

Register the Application through the root, review its complete combined diff,
then sync it once. These are **operator-run live changes**:

```sh
argocd app sync home-cloud
argocd app diff cert-manager
argocd app sync cert-manager
```

The Application is intended to adopt a matching v1.21.2 installation without
deleting it. Do not use force, replace, or prune to resolve an ownership conflict.
Stop on unexpected chart version, image, argument, namespace, RBAC, CRD, issuer,
Certificate, or field-manager differences.

Readiness and acceptance checks:

```sh
kubectl wait --for=condition=Established --timeout=120s \
  crd/certificates.cert-manager.io \
  crd/certificaterequests.cert-manager.io \
  crd/issuers.cert-manager.io \
  crd/clusterissuers.cert-manager.io \
  crd/orders.acme.cert-manager.io \
  crd/challenges.acme.cert-manager.io

kubectl -n cert-manager wait --for=condition=Ready --timeout=180s secretstore/home-cloud-vault
kubectl -n cert-manager wait --for=condition=Ready --timeout=180s externalsecret/route53-credentials
# Names and status only; do not print Secret data or annotations.
kubectl -n cert-manager get secret route53-credentials

kubectl -n cert-manager rollout status deployment/cert-manager --timeout=180s
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector --timeout=180s
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=180s
cmctl check api --wait=2m
kubectl get clusterissuer
```

Stop if controller or webhook readiness fails. Issuer readiness proves account
registration, not necessarily that Route53 challenge permissions work. Only after
the production issuer is ready, follow [Gateway bootstrap](gateway-bootstrap.md)
to review and sync `home-cloud-gateway`; that Application creates the Certificate.

## Staging and production

The current Certificate selects `letsencrypt-prod`. For a first untested
deployment, prefer changing it to `letsencrypt-staging` before commit and sync:

```yaml
issuerRef:
  name: letsencrypt-staging
```

After staging issuance succeeds, change it back to `letsencrypt-prod` in
`kubernetes/gateway/certificate.yaml`, commit and push, review
`argocd app diff home-cloud-gateway`, and manually sync the Gateway Application.
Do not delete the Certificate or TLS Secret. Verify the resulting certificate's
issuer and SANs rather than relying only on `Ready=True`.

## Troubleshooting

```sh
kubectl -n cert-manager get pods
kubectl describe clusterissuer letsencrypt-prod
kubectl -n gateway describe certificate home-antonu-org
kubectl get certificaterequest,order,challenge -A
kubectl -n cert-manager logs deployment/cert-manager --since=15m

# Public certificate only; never print tls.key:
kubectl -n gateway get secret home-antonu-org-tls \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Expected after production issuance: Certificate `gateway/home-antonu-org` is
Ready, Secret `gateway/home-antonu-org-tls` is type `kubernetes.io/tls`, and the
certificate contains `home.antonu.org` and `*.home.antonu.org`.

- For `AccessDenied`, check the Secret key names, hosted-zone ID and IAM policy
  without displaying credential values.
- While a Challenge is active, public DNS should expose a temporary TXT record at
  `_acme-challenge.home.antonu.org`; cert-manager removes it after success.
- If split DNS masks public TXT/SOA answers, consider chart values
  `dns01RecursiveNameservers` and `dns01RecursiveNameserversOnly` after reviewing
  DNS egress and caching implications.
- No public inbound application port is required for DNS-01.

## Rollback

If the first sync shows ownership conflicts or causes regression, stop further
syncs. Revert the Git change first. To detach Argo without deleting managed
resources, this is an **operator-run live ownership rollback**:

```sh
argocd app delete cert-manager --cascade=false
```

The exact affected Argo resource is `argocd/cert-manager`.
`--cascade=false` retains CRDs, controllers, issuers and generated account Secrets.
The Gateway-owned Certificate and TLS Secret are outside this rollback. Do not
delete CRDs, ACME account-key Secrets, the Certificate, or the Gateway TLS Secret
as rollback.

## Local validation

The combined source renders locally without contacting the Kubernetes API:

```sh
kustomize build --enable-helm kubernetes/cert-manager > /dev/null
bash kubernetes/verify-gitops.sh
```

Rendering downloads the pinned chart over HTTPS. It verifies structure and
ordering only; it does not test live admission, Kubernetes 1.37 compatibility,
AWS authorization, DNS propagation, certificate issuance, or traffic.

Vault/ESO references: [Vault provider](https://external-secrets.io/latest/provider/hashicorp-vault/)
and [Secret lifecycle](https://external-secrets.io/latest/guides/ownership-deletion-policy/).
