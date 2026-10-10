# Home infrastructure

One home cluster, deliberately split between operator-controlled bootstrap and
GitOps. See [bootstrap and recovery](docs/gitops.md) for the executable sequence,
ownership, TLS renewal and acceptance checks. As confirmed by the operator on
2026-10-10, Argo CD manages the platform and workloads, including Cilium,
Synology CSI and Gateway. Sync is manual; ExternalDNS remains crash-looping.
See the runbook for recorded application health and remaining acceptance checks.

- [Production incident postmortems](incidents/postmortems/README.md)
- [Network addressing](docs/addressing.md) and [topology](docs/network-topology.svg)
- [Talos and storage](docs/talos-cluster.md)
- [PXE](docs/pxe.md), [Image Factory / registry](docs/talos-mirror.md)
- [Quantum Pi 5 experimental GPIO UART kernel backport](talos/custom-rpi5/README.md)
- [Quantum custom Talos build history and current SD-dependent boot state](docs/quantum-talos-build-history.md)
- [Home Assistant Kubernetes deployment and deferred migration](kubernetes/apps/home-assistant/README.md)
- [ADS-B receiver Kubernetes deployment](kubernetes/apps/adsb/README.md)
- [Anki Sync Server Kubernetes deployment and data migration](kubernetes/apps/anki-sync/README.md)
- [deCONZ / RaspBee II Kubernetes deployment](kubernetes/apps/deconz/README.md)
- [Grocy Kubernetes migration](kubernetes/apps/grocy/README.md)
- [Mealie Kubernetes migration](kubernetes/apps/mealie/README.md)
- [ExternalDNS activation and ownership tests](docs/external-dns.md)
- [cert-manager / Route53 Argo CD onboarding](docs/cert-manager.md)
- [Current Gateway TLS termination / Argo bootstrap](docs/gateway-bootstrap.md)

```text
kubernetes/
  cilium/gateway-api/         # pinned upstream CRDs owned by the Cilium Application
  cilium/                     # Argo-managed pinned Helm-in-Kustomize
  argocd/                     # Kustomize bootstrap + pinned upstream Helm chart
  cert-manager/               # one Argo Kustomize package: chart + configuration
  gitops/                    # gitops root owns AppProjects + child Application catalog
  gateway/                   # child owns Gateway and routes
  external-dns/              # official chart values, scoped policy, optional test
  apps/home-assistant/        # Argo-managed fresh Home Assistant Container
  apps/adsb/                  # Argo-managed RTL-SDR decoder and feeder stack
  apps/anki-sync/             # Argo-managed Python-based Anki Sync Server, initially scaled to zero
  apps/deconz/                # Argo-managed deCONZ pinned to the RaspBee II node
  synology-csi/               # Argo-managed driver, retained StorageClass and ESO
```

Deployment credentials belong in Vault and are synchronized through namespaced
ESO stores; see [secret management](docs/secret-management.md). Other local
secrets remain outside Git (`.private/` and Talos secrets are ignored). Ignore rules do not remove secrets previously committed; review staged
changes and keep independent encrypted backups. Never commit certificate keys,
kubeconfigs, generated Talos configs, or decoded Kubernetes Secrets.

cert-manager Route53 credentials are stored in Vault and synchronized by ESO.
See [the cert-manager guide](docs/cert-manager.md) for the scoped Vault role and
Argo configuration.

- [External Secrets Operator installation](docs/external-secrets.md)

- [Vault KV v2 and Kubernetes auth for ESO](terraform/vault/README.md)
