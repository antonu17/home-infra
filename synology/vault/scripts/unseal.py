"""Initialize once and unseal using a persistent, private initialization JSON."""
import json
import os
import stat
import sys
from pathlib import Path
import time
import urllib.request

BASE = "http://vault:8200/v1/sys/"
STORAGE = Path("/vault/storage")
INIT_FILE = STORAGE / "secrets/init.json"
READY_FILE = Path("/tmp/storage-ready")
# Matches the explicit user in compose.yaml, independent of image defaults.
VAULT_UID, VAULT_GID = 100, 1000
DEFAULT_CONFIG = 'ui = true\n# Raft uses memory-mapped files. Disable NAS swap before use (see README).\ndisable_mlock = true\napi_addr = "https://vault.home.antonu.org"\ncluster_addr = "http://vault:8201"\n\nstorage "raft" {\n  path = "/vault/storage/data"\n  node_id = "synology-vault-01"\n}\n\n# HTTP is confined to the project network and NAS loopback; DSM terminates TLS.\nlistener "tcp" {\n  address = "0.0.0.0:8200"\n  cluster_address = "0.0.0.0:8201"\n  tls_disable = true\n}\n'


def secure_path(path, uid, gid, mode, directory=False):
    info = path.lstat()
    expected = stat.S_ISDIR if directory else stat.S_ISREG
    if not expected(info.st_mode) or (not directory and info.st_nlink != 1):
        raise ValueError("unexpected path type or hard link")
    os.chown(path, uid, gid, follow_symlinks=False)
    os.chmod(path, mode, follow_symlinks=False)


def secure_tree(root, uid, gid):
    # Never follow symlinks or broaden secret/data access.
    secure_path(root, uid, gid, 0o700, directory=True)
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in dirs:
            secure_path(Path(directory) / name, uid, gid, 0o700, directory=True)
        for name in files:
            secure_path(Path(directory) / name, uid, gid, 0o600)


def prepare_storage():
    READY_FILE.unlink(missing_ok=True)
    STORAGE.mkdir(parents=True, exist_ok=True)
    secure_path(STORAGE, 0, VAULT_GID, 0o750, directory=True)
    for name, uid, gid in (("config", 0, VAULT_GID),
                           ("data", VAULT_UID, VAULT_GID), ("secrets", 0, 0)):
        directory = STORAGE / name
        directory.mkdir(exist_ok=True)
        secure_path(directory, uid, gid, 0o750 if name == "config" else 0o700,
                    directory=True)
    config = STORAGE / "config/vault.hcl"
    if not os.path.lexists(config):
        # Preserve existing config; generate defaults only for a fresh setup.
        with config.open("x", encoding="utf-8") as output:
            output.write(DEFAULT_CONFIG)
            output.flush()
            os.fsync(output.fileno())
    secure_path(config, 0, VAULT_GID, 0o640)
    secure_tree(STORAGE / "data", VAULT_UID, VAULT_GID)
    secure_tree(STORAGE / "secrets", 0, 0)
    # This marker is private runtime state, never a config-directory entry.
    READY_FILE.write_text("prepared\n", encoding="ascii")



def request(path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(BASE + path, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def load_keys(threshold):
    with INIT_FILE.open(encoding="utf-8") as source:
        document = json.load(source)
    # Accept the complete HTTP API response and older CLI initialization JSON.
    keys = document.get("keys_base64", document.get("unseal_keys_b64"))
    if (not isinstance(keys, list) or
            any(not isinstance(key, str) or not key for key in keys) or
            len(set(keys)) < threshold):
        raise ValueError("invalid initialization document")
    return list(dict.fromkeys(keys))


def initialize():
    # Reserve the file durably BEFORE requesting initialization. Never overwrite
    # it or automatically retry a potentially successful request with lost output.
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
    fd = os.open(INIT_FILE, flags, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as output:
        output.flush()
        os.fsync(output.fileno())
        directory = os.open(INIT_FILE.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
        document = request("init", {"secret_shares": 5, "secret_threshold": 3})
        # Retain the entire response, including root_token and every key share.
        json.dump(document, output, indent=2)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())


def tick():
    status = request("seal-status")
    if not status["initialized"]:
        if os.path.lexists(INIT_FILE):
            return "blocked: uninitialized Vault with existing init.json; operator review required"
        initialize()
        status = request("seal-status")
    if not status["sealed"]:
        return "unsealed"
    if not INIT_FILE.exists():
        return "blocked: initialized Vault needs its original init.json"
    for key in load_keys(status["t"]):
        status = request("unseal", {"key": key})
        if not status["sealed"]:
            return "unsealed"
    return "unseal incomplete; operator review required"


def main():
    os.umask(0o077)
    try:
        prepare_storage()
    except Exception:
        print("blocked: shared storage preparation failed; check NAS ACLs and path types privately", flush=True)
        raise SystemExit(1)
    print("shared storage prepared", flush=True)
    last = None
    while True:
        try:
            state = tick()
        except Exception:
            # Never log response bodies, exceptions, key shares, or root tokens.
            state = "waiting: check Vault availability and init.json privately; never delete it to retry"
        if state != last:
            print(state, flush=True)
            last = state
        time.sleep(15)


if __name__ == "__main__":
    if sys.argv[1:] == ["--ready"]:
        raise SystemExit(0 if READY_FILE.is_file() else 1)
    main()
