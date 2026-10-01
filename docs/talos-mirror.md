# Talos Image Factory and installer registry on Synology

## Current deployment

The 2026-10-01 implementation handoff reports Image Factory
`ghcr.io/siderolabs/image-factory:v1.7.0` and a generic OCI registry running
in Synology Container Manager, published through Web Station/nginx with valid TLS.

| Service | Endpoint | Purpose |
|---|---|---|
| Image Factory | `https://talos.home.antonu.org` | Schematic-derived kernel, initramfs, PXE script and installer archive |
| OCI registry | `https://registry.home.antonu.org` | Promoted Talos installer images |
| NAS | `192.168.100.5` | VLAN 100, routed access from Home Cloud VLAN 400 |

The historical `synology/talos-mirror/compose.yaml`, `nginx.conf`, `sync.sh`
and `assets/` described the **legacy static nginx mirror**, not the deployed
Image Factory or registry. Those files are deleted in the current working tree;
do not restore/redeploy that Compose project over the current service.
Factory/registry deployment manifests and certificate renewal hooks
have not yet been captured here. Backend ports, volumes and registry image
version must be obtained from the Synology deployment, not inferred.

The old static mirror's `/healthz` and version-directory asset URLs are not
the current factory API contract.

## Local artifact pipeline

```text
schematic-amd64.yaml -> local Image Factory -> kernel/initramfs/PXE -> iPXE
                              |
                              +-> installer-amd64.tar -> skopeo -> OCI registry
                                                                     |
                                                         Talos install / upgrade
```

The source is `talos/image-factory/schematic-amd64.yaml`; its derived ID is
recorded in `schematic-amd64.id`. It includes `siderolabs/iscsi-tools`:

```text
c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac
```

The separate `schematic-amd64-wipe.yaml` and `.id` are for destructive clean
reprovisioning, not normal installs or upgrades. See [PXE](pxe.md).

Current installer:

```text
registry.home.antonu.org/talos/metal-installer/c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac:v1.14.2
```

Registry digest verified during implementation (operator-reported):

```text
sha256:f3f9ee5846a54ebef99c98f5070bd821fe5042155f043bd5aa19e0f902d5418e
```

This is **not air-gapped Kubernetes**. The factory may fetch upstream build
inputs; workload/CSI images and the Cilium OCI Helm chart still use public
registries. Local installers avoid the slow public-factory pull experienced
during initial provisioning, not every external dependency.

## Artifact generation and promotion

Run from the repository root. Register a changed schematic with the local
factory, verify the returned ID, then update its corresponding `.id` file:

```sh
curl --fail --silent --show-error \
  --header 'Content-Type: application/yaml' \
  --data-binary @talos/image-factory/schematic-amd64.yaml \
  https://talos.home.antonu.org/schematics
```

Download and promote a versioned installer without a Docker daemon:

```sh
SCHEMATIC=$(tr -d '\r\n' < talos/image-factory/schematic-amd64.id)
TALOS_VERSION=v1.14.2
INSTALLER="registry.home.antonu.org/talos/metal-installer/${SCHEMATIC}:${TALOS_VERSION}"
mkdir -p talos/generated/artifacts
curl --fail --location \
  --output "talos/generated/artifacts/installer-amd64-${TALOS_VERSION}.tar" \
  "https://talos.home.antonu.org/image/${SCHEMATIC}/${TALOS_VERSION}/installer-amd64.tar"
skopeo copy \
  "docker-archive:talos/generated/artifacts/installer-amd64-${TALOS_VERSION}.tar" \
  "docker://${INSTALLER}"
skopeo inspect --format '{{.Digest}}' "docker://${INSTALLER}"
```

Promotion writes to the registry. Review the tag before running; do not silently
replace an existing tag with different contents. Keep registry credentials in a
private authentication store, not Git. Record the resulting digest and retain
TLS verification. A rebuilt artifact may have a different digest.
API reference: [Image Factory v1.7.0](https://github.com/siderolabs/image-factory/blob/v1.7.0/docs/api.md).

## TLS and connectivity

Wildcard TLS covers `home.antonu.org` and `*.home.antonu.org`.
`acme.sh` on Synology uses Route53 DNS validation for issuance/renewal.
AWS credentials, certificate private keys and sensitive renewal configuration
must not enter plaintext Git.

Clients need DNS for both service names and routed TCP/443 access to the NAS.
The registry `/v2/` endpoint was verified during implementation:

```sh
curl --fail --silent --show-error https://registry.home.antonu.org/v2/
```

The repository's iPXE menu still uses HTTP; see the explicit discrepancy in
[PXE](pxe.md). Do not disable certificate verification to hide TLS failures.

## Troubleshooting

- **First artifact request returns HTTP 504:** Web Station/nginx can time out
  while the factory generates a new artifact. Check backend progress, then
  retry after generation completes. The cached installer succeeded on retry
  during implementation; not every 504 has this cause.
- **PXE works but installer pulls remain slow:** these are separate transfers.
  Check that the install/upgrade reference uses the local registry.
- **Schematic changed but extension absent:** regenerating configuration does
  not upgrade the installed image. Follow [Talos operations](talos-cluster.md).
