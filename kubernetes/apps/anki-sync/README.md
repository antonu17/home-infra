# Anki sync server

Argo-managed migration of the existing `ankibot-anki-sync-1` container from the
remote Docker context `quantum`. The source was inspected read-only on 2026-10-05:

- Python `3.12.13`
- Anki `26.8.1`
- named volume `ankibot_anki-data` mounted at `/root/.syncserver`
- 896 files, 22,849,128 bytes, including two SQLite databases and their WAL files

The checked-in StatefulSet deliberately starts at zero replicas. Argo may create
the retained PVC, Service, route and ESO resources, but it must not start an empty
sync server before the stopped-source archive has been imported and verified.

## Storage and backup boundary

`anki-sync-data` requests 5 GiB, `ReadWriteOnce`, from `synology-block`. The
StorageClass and PVC both retain data against ordinary application pruning. The
StatefulSet mounts PVC subdirectory `syncserver` at `/root/.syncserver`.

The Synology LUN, its retained PV and NAS snapshots share one failure domain;
none is an independent backup. Keep the final stopped-source archive and checksum
outside the Synology. Never delete the PVC, PV, LUN, source container or Docker
volume during migration or rollback.

An ignored preflight copy was downloaded while the source remained online to:

```text
.private/migrations/anki-sync/preflight-20261005T121002+0200.tar.gz
```

Its SHA-256 is:

```text
3b64e354a61c357494231e646e2fc563d08f7c4a2c1d8888eaa992277af7838e
```

The preflight copy matches the observed file count and byte count, but it is not
the final migration artifact because the SQLite databases were open during copy.

## Vault and ESO

The namespaced store authenticates as `eso-anki-sync` and reads only
`home-cloud/anki-sync/*`. `anki-sync-credentials` maps property `SYNC_USER1` from
KV v2 path `home-cloud/anki-sync/credentials`. Its value keeps Anki's required
`username:password` form.

Terraform creates only the scoped policy and Kubernetes-auth role. Create a stub
privately, then replace it with the existing real credential before starting the
StatefulSet:

```sh
vault kv put home-cloud/anki-sync/credentials \
  SYNC_USER1='REPLACE_WITH_USERNAME:REPLACE_WITH_PASSWORD'
```

Never paste the actual value into Git, Terraform state/variables, chat or command
output captured for review.

## Phase 1: prepare the inactive target

All live operations below are operator-run.

1. Review the Vault Terraform plan. Require the addition of `eso-anki-sync` only,
   then apply it.
2. Populate the real Vault value.
3. Commit and push the intended files. Sync `gitops`, `home-cloud-gateway`, then
   `anki-sync`, all without pruning.
4. Require the SecretStore and ExternalSecret to become ready. The StatefulSet
   must remain at zero replicas:

   ```sh
   kubectl -n anki-sync wait --for=condition=Ready --timeout=180s \
     secretstore/home-cloud-vault
   kubectl -n anki-sync wait --for=condition=Ready --timeout=180s \
     externalsecret/anki-sync-credentials
   kubectl -n anki-sync get statefulset anki-sync pvc anki-sync-data
   ```

The PVC may remain `Pending` because `synology-block` uses
`WaitForFirstConsumer`; the migration pod below is its first consumer.

## Phase 2: final consistency-guaranteed source copy

This phase starts downtime. Ensure Anki clients are idle first. Keep the source
container and named volume; stopping is reversible, deleting them is not.

```sh
ANKI_MIGRATION_DIR=".private/migrations/anki-sync/final-$(date +%Y%m%dT%H%M%S%z)"
mkdir -p "$ANKI_MIGRATION_DIR/source"

docker --context quantum stop --time 60 ankibot-anki-sync-1
docker --context quantum inspect --format '{{.State.Status}}' ankibot-anki-sync-1

docker --context quantum cp ankibot-anki-sync-1:/root/.syncserver/. \
  "$ANKI_MIGRATION_DIR/source/"
tar -C "$ANKI_MIGRATION_DIR/source" -czf \
  "$ANKI_MIGRATION_DIR/anki-sync-data.tar.gz" .
shasum -a 256 "$ANKI_MIGRATION_DIR/anki-sync-data.tar.gz" | \
  tee "$ANKI_MIGRATION_DIR/anki-sync-data.tar.gz.sha256"
```

Require Docker status `exited`, a non-empty archive and a recorded checksum. If
copy or archive creation fails, do not continue: run
`docker --context quantum start ankibot-anki-sync-1` and investigate while the
untouched named volume remains authoritative.

## Phase 3: restore and verify the PVC

`migration/pod.yaml` is intentionally excluded from Argo ownership. It is a
one-time PVC consumer and must be removed before the StatefulSet can attach the
`ReadWriteOnce` volume.

```sh
kubectl apply -f kubernetes/apps/anki-sync/migration/pod.yaml
kubectl -n anki-sync wait --for=condition=Ready --timeout=300s \
  pod/anki-sync-migration

kubectl -n anki-sync exec anki-sync-migration -- \
  sh -ec 'test ! -e /data/syncserver'

kubectl -n anki-sync cp "$ANKI_MIGRATION_DIR/anki-sync-data.tar.gz" \
  anki-sync-migration:/tmp/anki-sync-data.tar.gz
shasum -a 256 "$ANKI_MIGRATION_DIR/anki-sync-data.tar.gz"
kubectl -n anki-sync exec anki-sync-migration -- \
  sha256sum /tmp/anki-sync-data.tar.gz
```

The two hashes must be identical. Stop if `/data/syncserver` already exists or a
hash differs; do not extract over unknown PVC data.

Extract with Python's traversal-safe tar filter:

```sh
kubectl -n anki-sync exec anki-sync-migration -- python -c '
import pathlib, tarfile
target = pathlib.Path("/data/syncserver")
assert not target.exists()
target.mkdir(mode=0o700)
with tarfile.open("/tmp/anki-sync-data.tar.gz", "r:gz") as archive:
    archive.extractall(target, filter="data")
'
```

Check aggregate data and both SQLite databases without printing paths or content:

```sh
kubectl -n anki-sync exec anki-sync-migration -- python -c '
import pathlib, sqlite3
root = pathlib.Path("/data/syncserver")
files = [path for path in root.rglob("*") if path.is_file()]
magic = bytes.fromhex("53514c69746520666f726d6174203300")
databases = [path for path in files if path.open("rb").read(16) == magic]
for path in databases:
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    assert connection.execute("PRAGMA quick_check").fetchall() == [("ok",)]
    connection.close()
print(f"files={len(files)} bytes={sum(path.stat().st_size for path in files)} sqlite_files={len(databases)} quick_check=ok")
'
```

Expect two SQLite files and `quick_check=ok`. The final file/byte counts may be
slightly greater than the preflight inventory, but they must match a count taken
from the stopped source copy. Preserve the final archive even after success.

Remove only the temporary pod after verification:

```sh
kubectl delete -f kubernetes/apps/anki-sync/migration/pod.yaml
kubectl -n anki-sync wait --for=delete --timeout=180s pod/anki-sync-migration
```

This deletion affects only the disposable migration pod; it does not delete the
PVC or imported data.

## Phase 4: start and accept the new server

Change `statefulset.yaml` from `replicas: 0` to `replicas: 1`, commit/push that
single migration-gate change, review the Argo diff and sync `anki-sync` without
pruning.

```sh
kubectl -n anki-sync rollout status statefulset/anki-sync --timeout=300s
kubectl -n anki-sync get pod,pvc,service,httproute
kubectl -n anki-sync port-forward service/anki-sync 8088:8088
```

Perform a real Anki client sync through the port-forward before DNS cutover. The
existing `anki-anton.home.antonu.org` record is excluded from ExternalDNS; update
it manually to shared Gateway address `10.40.0.10` only after the route is Accepted
and client sync succeeds. Then test one client sync through the HTTPS hostname.

## Rollback

Before any clients write to the Kubernetes server, rollback is straightforward:
return the StatefulSet to zero replicas, sync, then run
`docker --context quantum start ankibot-anki-sync-1` and restore its former DNS
target.

After clients have written to Kubernetes, the old Docker volume and new PVC have
diverged. Stop both servers and explicitly choose an authoritative dataset; do not
blindly copy one over the other. Retain the source volume, PVC and final archive
until multiple client syncs and a separately tested backup establish confidence.
