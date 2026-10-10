# cert-manager and Route53 DNS-01

Operator sync and cert-manager ESO readiness were reported on 2026-10-04.
The operator also reported `cert-manager` Synced/Healthy on 2026-10-10.
The agent has not queried the live cluster; current issuance/renewal acceptance
remains a separate operator check. The Argo root registers one manually synced `cert-manager` Application.
That Application renders the pinned upstream Helm chart and local ClusterIssuers
together through Kustomize. The Gateway Application owns the frontend Certificate.

## Version and compatibility gate

The official chart is pinned to **v1.21.2**. The
[official support matrix](https://cert-manager.io/docs/releases/) lists Kubernetes
**1.33–1.36** for cert-manager 1.21, not this cluster's **1.37.1**. Rechecked on 2026-10-10, this is a
deployed but out-of-matrix combination: the operator reports the Application
Synced/Healthy, which does not extend upstream support. Preserve the pin for
this documentation audit; any upgrade/compatibility decision is separate. Local rendering does not establish
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
    vault-store.yaml           # namespaced Vault store and scoped TokenRequest RBAC
    route53-external-secret.yaml # ESO references only; no credential values
    clusterissuers.yaml        # staging and production Route53 issuers
kubernetes/gateway/
  certificate.yaml             # gateway/home-antonu-org
kubernetes/gitops/
  cert-manager.yaml            # AppProject and Application
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

The current AppProject targets `cert-manager` and this repository, but allows
all cluster-scoped and namespaced resource kinds. It is an administrative
boundary, not a kind-restricted project. The Gateway package owns the frontend
Certificate in `gateway`.

## Secret boundary

Route53 credentials are stored in Vault KV v2 at
`home-cloud/cert-manager/route53-credentials`, with properties `access-key-id`
and `secret-access-key`. On 2026-10-04, the ignored local file was copied into
Vault and both values were verified privately against the source. Terraform was
reported applied by the operator. Subsequent cert-manager sync and ESO readiness
were confirmed on 2026-10-04; do not repeat credential migration merely because
this guide retains its onboarding procedure.

The cert-manager Argo source now includes a namespaced `home-cloud-vault`
SecretStore and `route53-credentials` ExternalSecret. It authenticates as
`cert-manager/vault-eso` through `kubernetes-home-cloud`, role `eso-cert-manager`,
audience `vault`. ESO's controller has TokenRequest permission for that account
only. Terraform restricts the role to the `cert-manager/` Vault prefix.

ESO targets the existing `cert-manager/route53-credentials` Secret with the same
two keys consumed by the ClusterIssuers. The source omits explicit target
lifecycle policies and relies on ESO defaults Owner/Retain, giving the Secret an
ExternalSecret owner reference for Argo child visibility. Deleting the
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

## Fresh onboarding / recovery — operator-run, not executed here

Run from `/Users/anton/projects/home-infra`. Commit and push the reviewed files
first; Argo reads remote `main`, not the local working tree.

Read-only preflight:

```sh
kubectl config current-context
kubectl get crd gateways.gateway.networking.k8s.io
kubectl -n cert-manager get deployments 2>/dev/null || true
kubectl get crd certificates.cert-manager.io 2>/dev/null || true
argocd app get gitops
```

For a fresh onboarding only, configure a missing Vault role. The existing
cert-manager integration was already reported working; inspect the plan before
changing it. These are **operator-run live
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
argocd app sync gitops
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
to review and sync `gateway`; that Application creates the Certificate.

## Staging and production

The current Certificate selects `letsencrypt-prod`. For a first untested
deployment, prefer changing it to `letsencrypt-staging` before commit and sync:

```yaml
issuerRef:
  name: letsencrypt-staging
```

After staging issuance succeeds, change it back to `letsencrypt-prod` in
`kubernetes/gateway/certificate.yaml`, commit and push, review
`argocd app diff gateway`, and manually sync the Gateway Application.
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
```

Rendering downloads the pinned chart over HTTPS. It verifies structure and
ordering only; it does not test live admission, Kubernetes 1.37 compatibility,
AWS authorization, DNS propagation, certificate issuance, or traffic.

Vault/ESO references: [Vault provider](https://external-secrets.io/latest/provider/hashicorp-vault/)
and [Secret lifecycle](https://external-secrets.io/latest/guides/ownership-deletion-policy/).
