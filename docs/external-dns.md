# ExternalDNS → MikroTik: staged activation

## Current operation (2026-10-03)

Normal write-enabled operation is selected: `dry-run: false`, one replica,
`upsert-only`, TXT owner `home-cloud`. The pinned webhook path does not enforce
ExternalDNS dry-run; the historical preview procedure below must NOT be used as
a no-write guarantee. A and TXT records for Argo were already created and should
be retained. Route removal does not delete DNS under upsert-only; stale-record
cleanup remains deliberate. Name exclusions continue to protect legacy apps.

Commit/push the values and sync the existing `external-dns` Argo Application.
Sync restores the paused Deployment to one replica. No Helm installation or
record recreation is needed. Confirm both containers are Ready and reconciliation
completes without authentication, ownership or provider errors.

The current router endpoint uses HTTP port 80 by operator choice; the CA mount
was removed. This sends credentials unencrypted on the LAN. It is a remaining
hardening task, not production-grade transport security. Keep the dedicated
account/source restrictions and migrate to verified HTTPS separately.

The rest of this document contains the original staged/HTTPS bootstrap guidance;
the operation mode and transport described in this section supersede it.

Prepared 2026-10-02, not deployed or end-to-end verified. Operator performs all
router/cluster changes. Existing manual records must remain untouched.

## Pinned implementation and ownership

Official ExternalDNS chart **1.22.0**, app **0.22.0**; webhook
`mirceanton/external-dns-provider-mikrotik:v1.6.3`. The provider is listed upstream,
has a June 2026 release and subsequent repository activity. It requires
ExternalDNS >=0.15 and documents RouterOS 7.16 as tested (7.12 does not work).
Our exact RouterOS/Kubernetes/provider combination still requires the tests below.
The provider explicitly warns it has not had extensive production testing.

Argo Application `external-dns` uses the official chart plus values from this repo
and a CiliumNetworkPolicy. Helm is used by Argo for rendering, **not** a second
operator-installed Helm release. Its separate AppProject permits chart RBAC without
granting the Gateway project cluster-wide RBAC rights. Namespaces, router account,
credential synchronization is prepared through ESO. The router account remains
operator-owned; no SOPS/age component is added.

Only `gateway-httproute` is watched, limited to Gateway `home-cloud` in
`gateway`. Hostnames derive from HTTPRoute specs and targets from Gateway
status; no IP override annotation or Service source. The exact-name regex rejects
wildcards, the zone apex and nested subdomains. The Gateway wildcard **listener**
is not a wildcard DNS record. If a future application needs nested names, review
the regex and certificate coverage together.

TXT registry: owner `home-cloud`, prefix `external-dns-`, A records only. TXT
ownership records are still created by the registry; they are not a separate
source of application TXT records. Keep owner/prefix stable and back up DNS state.
Do not fabricate ownership TXT records or use `registry: noop`.

Initial state: `dry-run: true`, `policy: upsert-only`. After the reviewed dry run,
set `dry-run: false` in Git and sync. `upsert-only` suppresses reconciliation
deletions, but updates inside this provider can be implemented as delete/create;
it does not mean the account is incapable of deleting records.

### Protect manual records and handle collisions

The regex exclusion protects known infrastructure and legacy names: pulsar,
router, printer, talos, registry, k8s, quantum, pihole, adsb, anki-anton, fr24,
grocy, ha, mealie, grafana. It also excludes matching prefixed TXT names. Review
against a current router DNS export before enabling writes; the repo is not a
complete inventory. Add other infrastructure names to this exclusion as needed.

ExternalDNS TXT code filters updates/deletes by owner. The provider itself does
not enforce ownership; its delete lookup matches name, record type and target,
not the record comment. Consequently, **never mix manual and managed duplicate
records for the same name/type/value**, and never claim an existing manual record
merely because the new HTTPRoute uses its name. Treat a collision as a migration
gate, not as something ExternalDNS should overwrite. RouterOS regexp DNS records
are an upstream limitation; inventory them and stop if they cause plan errors.

Legacy HA/mealie/grafana names intentionally remain excluded. Their cutover needs
a separate reviewed backup/removal of the old manual record, then removal from
the exclusion and creation by ExternalDNS. Unrelated manual records are never
part of that operation. For *new* non-conflicting app names, resources plus an
HTTPRoute are sufficient once its namespace is admitted to the shared Gateway.

## Router prerequisites: HTTPS REST, not TCP8728/8729

Pinned source calls `/rest/system/resource` and `/rest/ip/dns/static` with Basic
authentication over HTTPS. Enable/review `www-ssl`, with a valid certificate;
binary `api`/`api-ssl` network services are not needed. Do not enable plaintext
HTTP or copy the upstream example's `MIKROTIK_SKIP_TLS_VERIFY=true`.

The documented minimal practical group is:

```routeros
/user group add name=external-dns policy=read,write,api,rest-api
```

Check whether the group already exists before adding. Create a dedicated user
in that group through WinBox, with a strong unique password and an allowed source
address restricted to the verified workload egress source. Do not use your admin
account. These permissions are **not DNS-only**; RouterOS cannot scope this group
to a DNS name/zone. The credential is sensitive even though Git scope is narrow.

The prepared egress policy allows only router `192.168.40.1:443`, Kubernetes API
and cluster DNS. Webhook mutation endpoint listens on **127.0.0.1:8888** inside
the Pod; its separate health server uses Pod port8080. There is no Service or
Ingress for either. Kubelet probes are allowed from node identities.

Inspect `/ip service print detail`, input firewall and the actual source address
seen at the router. With Cilium masquerading this may be the hosting node address;
otherwise it may be a routed pod address. Do not guess. Permit TCP443 to `.40.1`
only from that source, before the relevant input drop; it is **input**, not forward.
For example, only if the source has been confirmed as `.40.40`:

```routeros
/ip firewall filter add chain=input action=accept protocol=tcp src-address=192.168.40.40/32 dst-address=192.168.40.1 dst-port=443 comment="ExternalDNS HTTPS REST"
```

Review placement before enabling; appending below a drop does not help. Preserve
existing management sources in `www-ssl address=` restrictions. If Pod placement
changes, reevaluate the source restriction rather than opening all VLANs. Do not
add the example if existing scoped rules already permit access. Cilium policy is
defense in depth, not a replacement for RouterOS account/firewall restrictions.

Use `https://192.168.40.1:443` only if the certificate includes that **IP SAN**.
Otherwise use an independently/manual-resolvable router hostname whose SAN matches
and whose address is `.40.1`; keep that infrastructure hostname excluded. Do not
depend on ExternalDNS to create its own management endpoint. A changed API port
requires matching egress/firewall changes before deployment.

## Vault-backed MikroTik credentials

The source now includes a namespaced `home-cloud-vault` SecretStore, a
`vault-eso` identity with scoped TokenRequest RBAC, and a `mikrotik-credentials`
ExternalSecret. Values are stored at `home-cloud/external-dns/mikrotik-credentials`
with properties `MIKROTIK_BASEURL`, `MIKROTIK_USERNAME`, and `MIKROTIK_PASSWORD`.
They were copied into Vault and verified privately against the live Secret on
2026-10-04. Terraform role `eso-external-dns` reads only the `external-dns/` prefix.

Apply the new Terraform role, then commit/push and sync the existing ExternalDNS
Application without pruning, following [the secret migration guide](secret-management.md).
The target name and environment references are unchanged. The Secret has an owner reference to the ExternalSecret for Argo child visibility.
Deleting the ExternalSecret can garbage-collect the Secret. `deletionPolicy: Retain`
protects against provider-entry deletion only. Do not delete/recreate it to migrate.
Credentials are managed through Vault; no local plaintext credential file is needed.

The current router endpoint still uses HTTP by operator choice. This migration
does not change transport, RouterOS accounts, DNS ownership or record filters.
Future credentials changed in Vault reach the Kubernetes Secret on refresh, but
ExternalDNS's environment variables are read at startup: schedule an operator
rollout after a real rotation. No restart is needed to adopt identical values.

## Activate through Argo

1. Back up static DNS records and note unrelated record IDs/types/values/comments,
   including a manually owned name **not excluded** to prove TXT behavior.
2. Confirm Gateway `.10`, HTTPS and CRDs work; review existing `argocd` DNS records.
   If Argo's name already exists manually, leave it alone and explicitly exclude
   `argocd` until you authorize a separate migration. Port-forward still bootstraps.
3. Review/push Git, apply updated `kubernetes/gitops/bootstrap`, sync `home-cloud`,
   then `external-dns` after credentials and API access are ready.
4. Review both container logs. Readiness only proves the health server responds,
   not successful DNS reconciliation. Require successful router connection and
   Kubernetes watches with no TLS/RBAC/policy errors.

```sh
kubectl -n external-dns get pods
kubectl -n external-dns logs deployment/external-dns -c external-dns --tail=100
kubectl -n external-dns logs deployment/external-dns -c webhook --tail=100
```

## Acceptance test — operator-run, results pending

First confirm `test.home.antonu.org` and its prospective ownership names do not
exist. If occupied, choose another unused exact hostname in the test manifest.
The optional test is not included in the GitOps root:

```sh
kubectl apply -f kubernetes/external-dns/test/application.yaml
argocd app sync dns-acceptance
kubectl -n gateway-system get httproute dns-acceptance -o yaml
```

Require Argo Synced/Healthy and route Accepted/ResolvedRefs for the current
generation. Dry-run logs must propose only the new test A/TXT and other reviewed
non-conflicting route names, never manual infrastructure changes. Stop on any
unexpected plan. Then change `dry-run` to false in Git, push, sync `external-dns`.

On RouterOS inspect `/ip dns static print detail` for the exact test A and related
TXT entries. Confirm TXT contains `external-dns/owner=home-cloud`; discover actual
TXT names rather than assuming one format. Compare all unrelated entries against
the baseline, including IDs/comments. Then from a normal LAN client:

```sh
dig @192.168.40.1 test.home.antonu.org A +short
dig test.home.antonu.org A +short
curl --fail https://test.home.antonu.org/
```

Both DNS queries must return `10.40.0.10`; HTTP body must contain
`home-cloud-dns-acceptance`, with valid TLS. If normal DNS differs, inspect client
resolver/Pi-hole forwarding for `home.antonu.org`. Avoid a Pi-hole↔MikroTik loop.
Test from the actual LAN, not only inside the cluster.

### Deletion and ownership gate

1. With `upsert-only`, remove `route.yaml` from the test Kustomization in Git,
   push, and sync **dns-acceptance with prune explicitly enabled for this review**.
   Confirm the HTTPRoute was actually removed (root apps do not auto-prune).
2. Wait at least two reconciliation intervals. Test DNS A/TXT should remain;
   unrelated manual entries must be unchanged. Restore the route in Git and sync.
3. To test unowned collision protection, use a second disposable *manual* record
   with a different test name/IP, not excluded and no ownership TXT. Temporarily
   point the test route's hostname at it. Verify dry-run first, then upsert-only:
   its original value/ID must remain unmodified. Restore the route afterward.
4. Before `sync`, briefly set dry-run true and policy sync in Git and inspect
   the full proposed plan. Audit all records owned by `home-cloud`, including
   stale prior tests. Never change owner/prefix or remove ownership TXT as a shortcut.
5. Only after explicit operator approval set dry-run false with sync. Repeat
   route removal via Git/prune. Require only its owned A/TXT to disappear; unrelated
   manual entries and the disposable unowned record remain unchanged. Check router
   state directly; recursive DNS may cache the old answer until TTL expires.
6. Restore upsert-only if anything is unexpected. For immediate containment scale
   ExternalDNS to zero or disable its dedicated router account; investigate before
   resuming. The app has no automated self-heal that would undo an emergency scale.

Finally remove optional test workload/Application deliberately. Deleting Application
alone does not cascade in this repo. Remove only identified disposable manual test
records; never run a domain-wide delete. Record results/date and relevant IDs in
this document before declaring `sync` safe. No test above has been performed yet.

## Sources inspected

Local verification: `bash kubernetes/verify-gitops.sh` renders all manifests and
checks the initial DNS safety settings, image pin, credential references and
hostname filters. Its assertions intentionally require dry-run/upsert-only;
update those expectations explicitly when promoting the tested configuration.
Rendering and source review are not evidence of live RouterOS ownership safety.

- [Provider README at v1.6.3](https://github.com/mirceanton/external-dns-provider-mikrotik/blob/v1.6.3/README.md)
- [Provider record deletion / TLS source](https://github.com/mirceanton/external-dns-provider-mikrotik/blob/v1.6.3/internal/mikrotik/client.go)
- [ExternalDNS TXT ownership](https://github.com/kubernetes-sigs/external-dns/blob/v0.22.0/registry/txt/registry.go)
- [Gateway source documentation](https://github.com/kubernetes-sigs/external-dns/blob/v0.22.0/docs/sources/gateway-api.md)
- [Official chart 1.22.0](https://github.com/kubernetes-sigs/external-dns/tree/external-dns-helm-chart-1.22.0/charts/external-dns)
