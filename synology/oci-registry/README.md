# OCI registry on Synology

A single CNCF Distribution registry for Image Factory schematics, cached assets,
generated installers and promoted Talos installers. This project is prepared
configuration; the existing NAS registry's version and storage path must be
verified before adoption.

| Setting | Compose configuration |
|---|---|
| Image | `registry:3` (floating major tag) |
| Restart | `unless-stopped` |
| Backend | HTTP, NAS port 5005 → container port 5000 |
| Persistent storage | `./data` → `/var/lib/registry` |
| Client endpoint | `https://registry.home.antonu.org` through the NAS frontend |

There is no custom config, build or initializer. The image supplies its default
configuration. The directory mount follows the
[upstream deployment pattern](https://distribution.github.io/distribution/about/deploying/).
`data/.gitkeep` preserves the directory in Git; runtime contents are ignored.
This is a storage registry, not a configured pull-through cache.

## Deploy or adopt

All NAS commands below are **operator-run**.

1. Review `compose.yaml`, confirm port 5005 is available, and verify the existing
   HTTPS frontend's backend port. Do not replace another project's port mapping.
2. For an existing registry, inspect its image version and actual storage mount
   in Container Manager. Record its exact image ID/digest for rollback. Back up
   the entire registry storage independently of the NAS. If currently on version
   2, review the [v3 release notes](https://github.com/distribution/distribution/releases/tag/v3.0.0)
   before adopting this version-3 project; this README does not validate an upgrade.
3. Stop the existing registry before copying storage. Copy the complete contents
   of its `/var/lib/registry` backing directory into this project's `data/`,
   preserving ownership and permissions. Keep the original storage unchanged.
   Do not start a replacement over empty `data/`, which would serve an empty
   registry. For a fresh installation, upload Compose and the supplied empty
   `data/` directory. Synology ACLs must allow the container to write there.
4. From the project directory, validate and start, or update/create the project
   in Container Manager:

   ```sh
   docker compose config --quiet
   docker compose up -d
   ```

`registry:3` can resolve to a different release when pulled later. Confirm and
record the resolved version/digest before updates; the current Compose file is
not reproducibly pinned. No image upgrade or port change is made by this README.

## HTTPS and access

Retain the existing Web Station/nginx frontend. Its effective route should be
HTTPS `registry.home.antonu.org:443` → HTTP `127.0.0.1:5005`, using the NAS-managed
certificate. Preserve the external hostname so Image Factory and Talos installer
references keep working. Clients use HTTPS; Image Factory keeps `insecure: false`.
Certificate issuance/renewal remains outside this Compose project; see the
[Image Factory and registry runbook](../../docs/talos-mirror.md).

The Compose file configures no authentication, and `5005:5000` publishes the
backend on all host interfaces. Anyone allowed to reach it can read and push
registry content. TLS at the frontend encrypts traffic but does not restrict
access. Confirm existing NAS firewall/proxy access controls before adoption;
backend access can bypass frontend controls. Restrict access to intended lab
clients and the Image Factory; private schematics/cache must not be exposed to
untrusted clients. Installer reads must remain available to the Talos nodes.

Distribution generates an HTTP upload-state signing secret at startup when one
is not configured, as described in the
[configuration reference](https://distribution.github.io/distribution/about/configuration/).
That secret is separate from Image Factory's persistent cache signing key.
This single-container project requires no manually generated key or certificate.
Interrupted uploads across registry restarts may need to be retried.

## Verify

Read-only checks on the NAS after the operator starts the project:

```sh
docker compose ps
docker compose logs --tail=30 registry
curl --fail --silent --show-error http://127.0.0.1:5005/v2/
curl --fail --silent --show-error https://registry.home.antonu.org/v2/
```

For this unauthenticated configuration, expect HTTP 200 and `{}` from both
endpoints. If the existing frontend intentionally authenticates requests, use
its established private credential mechanism instead. Do not disable TLS checks.
The base API response proves reachability, not that existing images survived.
Check a known installer manifest by digest using the existing read-only workflow
in the runbook, then verify the Image Factory can retrieve an existing schematic
and cached artifact. Upload success and proxy handling of large layers still
require an operator-run push test against a deliberately chosen test repository.

## Backup and rollback

Back up the full `data/` directory with the registry stopped for a consistent
filesystem copy. Keep an encrypted off-NAS copy; a NAS snapshot alone does not
protect against loss of the NAS. Retain the deployed Compose file, resolved image
reference, and frontend configuration with the backup. Retain Image Factory's
signing key separately so restored signed caches remain usable.

If adoption fails, stop the replacement, restore the saved Compose/image and
original storage mount, and verify the known installer again. After an upgrade,
do not assume an older registry can safely use storage changed by the new
version; recover using the compatible pre-change backup. Keep both storage copies.
Do not remove `data/`, delete tags/blobs or run garbage collection during adoption.

## Validation performed

On 2026-10-08, local Compose validation and structural checks passed for the
image, restart policy, port mapping and resolved project-relative storage mount.
The configuration was compared with upstream deployment/configuration docs and
the local Image Factory configuration. No registry container, NAS deployment,
TLS frontend, data migration or push/pull operation was tested in this validation.
