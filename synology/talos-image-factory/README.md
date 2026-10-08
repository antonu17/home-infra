# Image Factory on Synology

The project uses upstream Image Factory v1.7.0 and a one-shot
`alpine/openssl:3.5.8` key initializer. Both mount the same NAS directory at
`/etc/image-factory/`; only the initializer can write it. Image Factory waits for
`key-init` to exit successfully (`service_completed_successfully`). The
initializer has no network access and does not stay running.

The project-local `data/` directory contains `config.yaml` and
`cache-signing-key.key`. Both containers mount `./data` at `/etc/image-factory`;
the factory's internal paths, name, port and registry settings are preserved.
No custom build, script upload or manual key generation is required.

## Signing key

If the key is absent, the inline Compose command generates an unencrypted
PEM ECDSA P-256 key using the command from the
[official on-prem guide](https://docs.siderolabs.com/omni/self-hosted/run-image-factory-on-prem).
It writes privately with mode 0600, then publishes the complete file without
overwriting an existing key. Subsequent runs validate and preserve the existing
key and permissions. Empty, invalid, symlink or non-regular keys fail startup;
none are silently replaced. Initialization logs contain no key values.

The legacy key's original creator is unknown from repository evidence. Preserve
it and record its origin privately if known. Image Factory signs cached assets
and generated installers with this identity; keep an encrypted off-NAS backup.
Never delete the key to repair startup. TLS remains managed by the NAS frontend.

## Existing deployment

All NAS changes below are **operator-run**. Before updating, privately back up
the old Compose file, deployed config and key. Confirm the existing key is
present and non-empty; stop if missing. Stop the existing project in Container
Manager. From its directory, copy the deployed files into `data/` before starting
the updated project. This retains the originals for rollback and refuses an
existing destination:

```sh
if [ -e data ] || [ -L data ]; then
  echo "STOP: data already exists; inspect before migrating"
else
  mkdir -m 700 data && cp -p config.yaml cache-signing-key.key data/
fi
test -s data/config.yaml && test -s data/cache-signing-key.key
```

Continue only after a successful copy and verification. Upload the revised
`compose.yaml`; preserve deployed configuration rather than replacing it with
the repository example. Update the existing Container Manager project, or run:

```sh
docker compose config --quiet
docker compose up -d
docker compose ps -a
docker compose logs key-init
```

Expect `key-init` to show Exited (0) and report preservation of the existing key;
Image Factory should remain running. Check the existing HTTPS/PXE workflow and
a known cached artifact. Compare `/oci/cosign/signing-key.pub` before and after;
stop if the identity changes. New keys are root-owned mode 0600 and the current
factory uses its default root user; preserve existing user settings and NAS ACLs.

Rollback: restore the old Compose file and update the same project. The retained original
config and key still support the old file mounts. Retain `data/` and the originals.

## Fresh installation

Upload `compose.yaml` and the supplied `data/config.yaml`, retaining that
directory layout. Start the project normally: the initializer creates the missing key and exits before the
factory starts. Keep that generated key permanently. Compose start ordering
applies to project updates/startup; Docker's restart policy can restart the
factory directly after a daemon restart, using the already persisted key.
