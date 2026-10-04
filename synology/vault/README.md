# Install Vault on Synology

Vault 2.1.1, single-node Raft, with automatic initialization and Shamir
unsealing. Both services use the default Compose network and share `storage/`.
All commands below are **operator-run on your NAS**. Replace `/path/to/vault-project`
with your chosen project directory on a NAS volume in every example.
The repository files are prepared configuration, not proof of deployment.

## 1. Upload the project

Install Container Manager and confirm host port 8200 is available. Upload
`compose.yaml`, `scripts/`, and the supplied `storage/` tree to
`/path/to/vault-project` for a fresh installation. For an existing deployment,
follow the migration instructions below before copying anything into storage.
No manual folder creation, UID lookup, chown, or chmod is required for a fresh
installation. Compose creates the storage bind directory, and the sidecar
prepares everything inside it before Vault starts.

```text
/path/to/vault-project/
├── compose.yaml
├── scripts/unseal.py
└── storage/
    ├── config/vault.hcl      # supplied default config
    ├── data/.gitkeep         # empty database directory placeholder
    └── secrets/
        ├── .gitkeep          # empty secrets directory placeholder
        └── init.json         # generated at runtime; retained permanently
```

The supplied config is already at `storage/config/vault.hcl`. The sidecar
sets its permissions and preserves its contents; if absent, it generates the
same defaults. `.gitkeep` files only preserve empty directories in Git.
Runtime data and initialization JSON are excluded from Git.

### Existing installation: preserve the initialized Vault

For your earlier layout containing `data/`, `config/`, and `secrets/`, first
back up the database with an authenticated Raft snapshot and keep an encrypted
off-NAS copy of the complete original initialization JSON. Stop the existing
`vault` project in Container Manager. Copy the folders into the new layout
**before starting the updated project**. Do not start with empty replacement
storage: it would initialize a different Vault.

Run as root, only with the project stopped. This refuses an existing storage
path and retains all original folders:

```sh
cd /path/to/vault-project
if [ -e storage ] || [ -L storage ]; then
  echo "STOP: storage already exists; inspect the layout before migrating"
else
  mkdir -m 700 storage && cp -a config data secrets storage/
fi
```

Continue only after a successful copy. In `storage/config/vault.hcl`, change
only the Raft path from `/vault/data` to `/vault/storage/data`. Keep the original
`storage/secrets/init.json`; both CLI and API formats are supported. If the
original JSON was removed, recover it from your private backup before starting.
Do not create an empty JSON file or reinitialize the existing database.

For an existing installation already using `storage/`, simply preserve it
when replacing Compose and scripts. Before upgrading from 1.21.4, review the
[upgrade guide](https://developer.hashicorp.com/vault/docs/upgrade) and
[important changes](https://developer.hashicorp.com/vault/docs/updates/important-changes).

## 2. Start the project

In Container Manager → Project → Create, use name **vault**, select
`/path/to/vault-project`, and use `compose.yaml`. Update/rebuild the existing
project when migrating. Alternatively, operator-run CLI:

```sh
cd /path/to/vault-project
docker compose -p vault config --quiet
docker compose -p vault up -d
```

The root sidecar prepares shared storage first. Vault waits for its readiness
health check, then runs as UID 100, GID 1000, explicitly set in Compose.
The sidecar initializes only an uninitialized Vault without an existing
initialization file: five shares, threshold three. It saves the complete
response including all keys and the root token, then uses those keys to unseal.
The root token is retained and is not used or automatically revoked.

The sidecar applies these permissions at each startup:

| Path | Owner UID:GID | Mode |
|---|---|---|
| `storage/` and `storage/config/` | 0:1000 | 750 |
| `storage/config/vault.hcl` | 0:1000 | 640 |
| `storage/data/` and subdirectories | 100:1000 | 700 |
| Files under `storage/data/` | 100:1000 | 600 |
| `storage/secrets/` and subdirectories | 0:0 | 700 |
| Files under `storage/secrets/`, including `init.json` | 0:0 | 600 |

Symlinks, special files, and hard-linked files in managed paths are rejected.
Ownership/modes are changed only inside the shared storage directory.
Vault cannot read the root-only secrets directory. The sidecar has CHOWN,
FOWNER, and DAC_OVERRIDE capabilities to prepare the bind mount; its other
filesystem paths are read-only, except private `/tmp` runtime state.

Synology ACLs and a read-only/locked shared folder can still prevent setup.
If storage preparation fails, Vault will not start. Check File Station →
Properties → Permission for the exact project path, without recursively
removing ACLs or granting general users access to secrets. Root must be able
to prepare storage; UID 100/GID 1000 must be able to read config and write data.

## 3. Check readiness

Allow up to a minute, then run these read-only checks:

```sh
cd /path/to/vault-project
docker compose -p vault ps
docker compose -p vault logs --tail=15 unseal
docker compose -p vault exec vault vault status
docker compose -p vault port vault 8200
curl -i http://127.0.0.1:8200/v1/sys/health
test -s storage/secrets/init.json && echo "Initialization JSON is present"
```

Expect `Initialized true`, `Sealed false`, threshold 3, port `127.0.0.1:8200`,
and HTTP 200. Sidecar health means storage is prepared, not that unsealing
has completed. Initial sealed status exits with code 2.

Initialization files are never overwritten or removed. If the initialization
response is lost or saving it is interrupted, an empty/partial file may remain.
The sidecar blocks automatic reinitialization: check state and backups privately.
Never delete this file or data to force a retry. Run exactly one sidecar.

## 4. Configure HTTPS

Set local DNS: `vault.home.antonu.org` → NAS `192.168.100.5`. In
**Control Panel → Login Portal → Advanced → Reverse Proxy → Create**:

| Setting | Source | Destination |
|---|---|---|
| Protocol | HTTPS | HTTP |
| Hostname | vault.home.antonu.org | 127.0.0.1 |
| Port | 443 | 8200 |

Assign a matching certificate under **Security → Certificate → Settings**.
Open `https://vault.home.antonu.org/ui/` and verify HTTPS health returns 200.
Web Station registration is unnecessary. Permit HTTPS only from authorized
clients on VLAN 100 and, if required, VLAN 400; exclude Guest/IoT networks.
No DNS, router, certificate, or firewall changes are automated.

## 5. Back up and test restart

Retain `storage/secrets/init.json` permanently and keep an encrypted off-NAS
copy with authenticated Raft snapshots. Anyone who reads it has all unseal
shares and the initial root token. Never put it in Git, logs, screenshots,
shell arguments, or chat. Use scoped authentication for routine access.

Restart Vault during a maintenance window and confirm automatic unseal,
HTTPS health, and scoped login. Test recovery separately. Raft uses
`disable_mlock = true`; review NAS swap handling before storing real secrets.
Audit logging is not configured. NAS-only snapshots are not independent backups.

For intentional sealing, stop `unseal` first, then seal through an
authenticated Vault session. Otherwise the sidecar will undo the seal:

```sh
cd /path/to/vault-project
docker compose -p vault stop unseal
```

Rollback: stop the project and disable only its new reverse-proxy/DNS entry;
retain storage and the original folders. Do not delete directories, use
`down -v`, or downgrade data written by 2.1.1. Upgrade recovery requires a
compatible pre-upgrade snapshot restored into a separate isolated deployment.
