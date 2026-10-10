# NAS storage inventory

Recorded 2026-10-10 from operator-supplied Docker inspection on `pulsar`
(`192.168.40.5`, Home Cloud). The agent did not query or change the NAS.
This records live metadata, not a deployment recipe or backup verification.

## Confirmed container storage

| Container / image | NAS source → container destination | Access / state |
|---|---|---|
| `talos-image-factory`, Image Factory `v1.7.0` | `/volume3/labs/talos-image-factory/data` → `/etc/image-factory` | Read-only; running |
| `talos-image-factory-key-init-1`, `alpine/openssl:3.5.8` | Same factory folder → `/etc/image-factory` | Writable; exited, exit code not yet supplied |
| `registry`, `registry:3` | `/volume3/labs/oci-registry/data` → `/var/lib/registry` | Writable; running |
| `pi-hole-pihole-1`, `pihole/pihole:latest` | `/volume3/labs/pi-hole/etc-pihole` → `/etc/pihole` | Writable; running |
| `vault-vault-1`, `hashicorp/vault:2.1.1` | `/volume3/labs/vault/storage` → `/vault/storage` | Writable; running |
| `vault-unseal-1`, `python:3.13.7-alpine` | Same Vault storage → `/vault/storage`; `/volume3/labs/vault/scripts` → `/app` | Storage writable, scripts read-only; running |
| `pinggy-pinggy-1`, `home-infra/pinggy:local` | `/volume3/labs/pinggy/scripts` → `/app`; `/volume3/labs/pinggy/ssh` → `/mnt/ssh` | Both read-only; running |
| Pinggy named volume `pinggy_ssh-host-keys` | `/volume1/@docker/volumes/pinggy_ssh-host-keys/_data` → `/var/lib/ssh-host-keys` | Writable |
| Vault additional anonymous volumes | Two directories under `/volume1/@docker/volumes/` → `/vault/file` and `/vault/logs` | Writable; contents/use not established |

Published ports: factory8080, registry5005→5000, Pi-hole TCP/UDP53 and8081→80
on IPv4/IPv6 wildcard addresses; Vault8200 on IPv4 loopback only. Pinggy and
helpers publish none. Docker showing an exposed port with null bindings is not
an externally published port.

The main application bind mounts are on Volume3, but Docker-managed Vault
volumes and Pinggy SSH host keys are on Volume1. A backup covering only
`/volume3/labs` does not include those Volume1 directories. Whether every such
volume holds recovery-critical data remains unconfirmed; do not remove them.

## Source alignment and limits

Registry and factory image tags, ports and folder-mount layout match their
repository Compose sources. The factory key initializer exists and exited;
its successful exit and signing-key preservation still need separate evidence.
Inspection does not reveal key contents or prove their provenance/backup.

Pi-hole runs `latest`, while source pins `2026.09.0`. Its persistent folder and
published ports match source. Actual application version behind the pulled
`latest` image is unknown; do not infer it from the current upstream tag or
redeploy/downgrade it merely to align documentation.

Vault's storage bind and unseal helper match source. The checked-in Raft config
uses `/vault/storage/data`; the live Raft path/config and use of `/vault/file`
or `/vault/logs` were not inspected. Mount existence does not establish whether
those additional volumes contain active data. Initialization/unseal material
under the shared storage is sensitive; do not print or share it.

Pinggy uses a local image and persists SSH host identity separately from its
Volume3 inputs. Its source/build reproducibility and host-key backup are not
established by a Running state. Do not regenerate or display private host keys.

## Observed local image IDs

These are Docker image IDs from container inspection, **not registry manifest
RepoDigests** and not substitutes for verified portable image references.

| Image | Observed image ID |
|---|---|
| Image Factory | `sha256:d5c9f35f06b86a38d33d6210e27a144ad1c2df1913dca2dbc7e751534e3d9b50` |
| Factory key initializer | `sha256:5c14a3d90f2f19241ad3ffa9cd7b1c875a03f2e8f4e33045096510085e36db5f` |
| Registry | `sha256:b16ad6cc19df5d687ed2e5b4ba6fa51a38bfbb4687ecc11bf54e0899638c0ee2` |
| Pi-hole | `sha256:15d302c0f85902d6378e159b906b3ffc7b5ef2af079e1d296d1dcf3f5f217e29` |
| Vault | `sha256:7a32cec814d1d2781ed5a2d3631254649039717be8084328e2b4374e147b6a3c` |
| Vault unseal helper | `sha256:6aead542d468d5e99b0795777ec50fd233b236d99e08be4f18267eb02112067b` |
| Pinggy | `sha256:279985ce8e6cf0a29b93f0644558e16c9e39f9a55d8bf335b719ab119451d639` |

## Remaining confirmation

- Current storage pools, RAID layout, volume filesystems/capacity and health.
  Earlier documentation records RAID10/Btrfs/Volume3, not a fresh Storage Manager check.
- Datastore/volume holding cp-01 and worker-01 VMM disks.
- Exact live Vault Raft data path and whether the anonymous volumes are used.
- Factory initializer exit code; retained signing identity and independent backup.
- Actual Pi-hole release and persistent configuration/backup coverage.
- Off-NAS backup scope, destination, schedule and last successful restore for
  VMs, LUNs, Vault, registry, factory signing identity/config, Pi-hole and Pinggy keys.
- CSI volume expansion and cross-worker recovery acceptance; retained LUNs or
  snapshots alone do not prove restoration. The CSI DNS incident was resolved,
  but that recovery was not a backup-restore test.

Nothing here authorizes storage copying, permission changes, container recreation,
volume deletion, key rotation or migration. Preserve all existing data while
collecting read-only evidence.
