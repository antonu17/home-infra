# Talos Image Factory and installer registry on Synology

## Current deployment

The 2026-10-01 implementation handoff reports Image Factory
`ghcr.io/siderolabs/image-factory:v1.7.0` and a generic OCI registry running
in Synology Container Manager, published through Web Station/nginx with valid TLS.

| Service | Endpoint | Purpose |
|---|---|---|
| Image Factory | `https://talos.home.antonu.org` | Schematic-derived kernel, initramfs, PXE script and installer archive |
| OCI registry | `https://registry.home.antonu.org` | Promoted Talos installer images |
| NAS (observed 2026-10-10) | `192.168.40.5` | VLAN400 / Home Cloud, gateway `192.168.40.1` |

Operator evidence on 2026-10-10 confirms NAS `192.168.40.5` on VLAN400.
Previously the NAS used `192.168.100.5` in VLAN100. Factory/registry
hostnames remain the same; their DNS, reverse-proxy bindings and any IP-based
references need separate post-move verification; NAS addressing alone does not
prove every service binding is correct. No service or DNS
configuration is changed by this documentation.

The historical `synology/talos-mirror/compose.yaml`, `nginx.conf`, `sync.sh`
and `assets/` described the **legacy static nginx mirror**, not the deployed
Image Factory or registry. Those files are absent from the current repository;
do not restore/redeploy that Compose project over the current service.
Image Factory configuration is captured in
[`synology/talos-image-factory`](../synology/talos-image-factory/README.md).
Its directory mount and one-shot key initializer are repository-prepared
changes, not confirmation of deployment. Copy the existing key and deployed config into
project-local `data/` before updating;
follow that README before updating the NAS project. Registry Compose configuration
is captured in [`synology/oci-registry`](../synology/oci-registry/README.md), using
`registry:3`, host port 5005 and project-local `data/`. These are prepared settings,
not verification of the live registry version or storage mount. Certificate
renewal hooks remain uncaptured; obtain them from the deployment.

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

AMD64 VM installer (not the ARM64 Raspberry Pi installer):

```text
registry.home.antonu.org/talos/metal-installer/c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac:v1.14.2
```

AMD64 registry digest verified during the original implementation (operator-reported):

```text
sha256:f3f9ee5846a54ebef99c98f5070bd821fe5042155f043bd5aa19e0f902d5418e
```

This is **not air-gapped Kubernetes**. The factory may fetch upstream build
inputs; workload/CSI images still use public registries, and Helm rendering downloads
pinned charts.
Raspberry Pi 4 uses its ARM64 schematic; Quantum Pi 5 uses the
custom installer lineage in [its build history](quantum-talos-build-history.md).
Local installers avoid the slow public-factory pull experienced
during initial provisioning, not every external dependency.

## Artifact generation and promotion

**Operator-run remote changes:** registration writes to Image Factory and
promotion writes to the registry. Run from the repository root. Register a changed
schematic with the local factory, verify the returned ID, then update its corresponding `.id` file:

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

The original Synology handoff recorded wildcard TLS for `home.antonu.org` and
`*.home.antonu.org`, with `acme.sh`/Route53 DNS validation. Current renewal hooks
and successful renewal have not been confirmed in this audit; Gateway certificate
renewal is independently cert-manager-owned.
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
