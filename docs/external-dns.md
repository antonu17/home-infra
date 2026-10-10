# ExternalDNS → MikroTik

## Current state — open failure, 2026-10-10

The operator reports `external-dns` Synced/Progressing in Argo and the controller
still crash-looping. At `2026-10-10T19:26:24Z`, it exited with:

```text
failed to do run once: Get "http://127.0.0.1:8888/records": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```

The controller created Kubernetes/Gateway API clients, then timed out awaiting
its local webhook response. This establishes the failing controller→webhook call,
not the underlying cause. A blocked/slow webhook→RouterOS request, provider
failure or another webhook problem remains to be diagnosed. Do not assert a DNS,
credential, Cilium or router-firewall cause from this log alone. This issue remains
open; no recovery or successful current reconciliation has been reported.

Argo sync status is desired-resource convergence, not DNS reconciliation health.
Health probes do not prove `/records` completes. The earlier 2026-10-03 handoff
recorded creation of Argo A/TXT records; it does not establish current automation.
The agent has performed source/doc review only, with no live queries or changes.

## Pinned source and ownership

Argo `external-dns` renders `kubernetes/external-dns` with official chart
`1.22.0`, controller `0.22.0`, and webhook
`ghcr.io/mirceanton/external-dns-provider-mikrotik:v1.6.3`. The catalog is
`kubernetes/gitops/external-dns.yaml`; the root is `gitops`. Do not install a
second Helm release or separately apply the already adopted package.

Current values select one replica, `dry-run: false`, `policy: upsert-only`,
TXT registry owner `home-cloud`, prefix `external-dns-`, and A records. The
webhook does not enforce ExternalDNS dry-run; **dry-run is not a no-write guarantee**.
`upsert-only` avoids reconciliation deletions, but is not a read-only mode and
provider updates may involve delete/create operations. Do not switch to `sync`
or change owner/prefix while diagnosing the current failure.

Only `gateway-httproute` is watched, for Gateway `home-cloud` in namespace
`gateway`. HTTPRoute hostnames and Gateway status provide names/targets. The
regex permits a single label under `home.antonu.org`, rejecting wildcards,
zone apex and nested subdomains. A wildcard Gateway listener is not a wildcard
DNS record.

**Source drift:** the current values contain no `regex-domain-exclusion`.
The older documentation's claims that pulsar/router/printer/registry/legacy
application names were excluded are false for this source. TXT ownership still
matters, but no extra name-deny filter is configured. Before creating/changing
routes, review existing manual records and managed TXT ownership privately.
Do not adopt or overwrite a manual record merely because a route uses its name.
The provider is not itself an ownership-enforcing boundary; avoid duplicate
manual/managed records for the same name/type/target.

## Router API, source address and policy

The current operator-selected endpoint is RouterOS REST over **HTTP port80** at
`192.168.40.1`, not binary API8728/8729. The CiliumNetworkPolicy in
`resources/network-policy.yaml` allows that exact router IP/port, Kubernetes API
and cluster DNS. There is no CA mount. Credentials cross the LAN unencrypted;
verified HTTPS is a separate hardening change requiring endpoint, certificate,
Cilium policy and RouterOS input-rule alignment. This audit does not change them.

The webhook API listens at `127.0.0.1:8888` inside the Pod; health checks use
port8080. No Service exposes the webhook. Kubelet probe identities are allowed.
The numbered RouterOS filter has an `ExternalDNS current HTTP REST` **input**
exception, separate from inter-VLAN **forward** traffic.

Verify the actual router-visible source and account allowed-address restrictions;
Cilium source NAT/placement can affect which address is seen. Do not open an
entire subnet or change the firewall without that evidence. RouterOS group
`read,write,api,rest-api` is not DNS-only permission; keep a dedicated account
and source restrictions. Read-only diagnostics must never expose its password.

## Vault-backed credentials and lifecycle

A namespaced `home-cloud-vault` SecretStore authenticates as `vault-eso`, role
`eso-external-dns`, through Vault auth mount `kubernetes-home-cloud`. The
ExternalSecret targets `external-dns/mikrotik-credentials` with keys
`MIKROTIK_BASEURL`, `MIKROTIK_USERNAME`, `MIKROTIK_PASSWORD`, sourced from
`home-cloud/external-dns/mikrotik-credentials`. Values were privately verified
in Vault on 2026-10-04; the Application is now adopted according to the operator
list. ESO readiness and successful DNS reconciliation remain separate checks.

The current ExternalSecret omits explicit creation/deletion policies, relying on
ESO defaults (Owner/Retain). Deleting an ExternalSecret can garbage-collect its
owned Secret; Retain does not prevent that deletion. Preserve both during
troubleshooting. Credentials are not stored in a plaintext repository manifest.
ExternalDNS reads environment credentials at startup: actual rotation needs an
operator-reviewed rollout after ESO refresh. Identical-value adoption alone does
not require a restart. See [secret management](secret-management.md).

## Read-only diagnosis — operator-run

Load repository direnv and confirm the intended context. Collect both sides of
the local call, including previous controller termination, without Secret payloads:

```sh
kubectl config current-context
kubectl -n external-dns get pods -o wide
kubectl -n external-dns logs deployment/external-dns -c external-dns --previous --tail=100
kubectl -n external-dns logs deployment/external-dns -c external-dns --since=15m
kubectl -n external-dns logs deployment/external-dns -c webhook --since=15m
kubectl -n external-dns get secretstore,externalsecret
kubectl -n external-dns get secret mikrotik-credentials
kubectl -n external-dns get ciliumnetworkpolicy external-dns
```

Review logs privately and redact credentials/Authorization headers before sharing.
Correlate `/records` with webhook errors and router request timings. Check whether
its failure is startup, API authentication, timeout, policy drop or provider
processing. If a container lacks diagnostic tools, do not assume `curl` exists
or install tools into a live container as part of this read-only sequence.

Router-side read-only checks:

```routeros
/ip service print detail
/ip firewall filter print stats where chain=input
/ip firewall filter print detail where comment="ExternalDNS current HTTP REST"
```

Account allowed-address and observed egress source must match. A network-policy
or input accept counter alone is not proof of a successful REST response.
Do not repeatedly sync/restart the workload as a substitute for finding the
webhook failure. The current evidence does not justify a specific repair yet.

## Acceptance after a separately reviewed repair

The operator publishes reviewed source and syncs only `external-dns` without
pruning. Require both containers Ready **and** a complete successful reconciliation
with no provider timeout/authentication/ownership error. Compare A/TXT records
against a private baseline and verify unrelated manual records are unchanged.
Use an existing, approved HTTPRoute with a non-conflicting hostname; the old
`kubernetes/external-dns/test/` directory no longer exists.

For Argo, after confirming that its record is managed and Gateway is ready:

```sh
kubectl -n gateway get gateway home-cloud -o yaml
kubectl -n argocd get httproutes -o yaml
dig @192.168.40.1 argocd.home.antonu.org A +short
dig argocd.home.antonu.org A +short
curl --fail https://argocd.home.antonu.org/
```

Expected service target is `10.40.0.10`; validate from a normal Home client.
If direct and client DNS disagree, inspect resolver forwarding/cache without
creating a Pi-hole↔MikroTik loop. Valid DNS does not prove current reconciliation:
cached/pre-existing records can continue working during the crash loop.

Record recovery evidence and time before marking this issue resolved. Do not
run the old dry-run/deletion/collision test: it relied on absent resources and
an unenforced no-write assumption. Any future DNS deletion or policy=`sync`
test requires a separate reviewed plan with exact disposable records/backups.
Emergency containment (operator-run live change) may pause this Deployment or
disable its dedicated router account; preserve existing DNS records and document
which setting must be restored. No containment has been executed by the agent.

## Local validation limitations

`kubernetes/verify-gitops.sh` is absent. `kubernetes/external-dns/verify.rb` exists
but is stale: it expects a missing exclusion argument and explicit Orphan/Retain
policies while the source uses defaults. Do not claim it validates current source
or bypass its failures. Fixing that verifier is separate from this documentation
review. Local rendering downloads the pinned chart and does not prove live API,
credentials, provider behavior or RouterOS ownership safety.

## Pinned implementation references

- [Provider README v1.6.3](https://github.com/mirceanton/external-dns-provider-mikrotik/blob/v1.6.3/README.md)
- [Provider RouterOS client](https://github.com/mirceanton/external-dns-provider-mikrotik/blob/v1.6.3/internal/mikrotik/client.go)
- [ExternalDNS TXT registry v0.22.0](https://github.com/kubernetes-sigs/external-dns/blob/v0.22.0/registry/txt/registry.go)
- [Gateway source v0.22.0](https://github.com/kubernetes-sigs/external-dns/blob/v0.22.0/docs/sources/gateway-api.md)
- [Official chart 1.22.0](https://github.com/kubernetes-sigs/external-dns/tree/external-dns-helm-chart-1.22.0/charts/external-dns)
