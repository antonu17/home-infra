#!/bin/sh
set -eu
context=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output=${1:-/tmp/thread-rio-sync.tar}
docker buildx build --platform linux/arm64 --provenance=false --sbom=false \
    --tag thread-rio-sync:2026-11-05 \
    --output "type=docker,oci-mediatypes=false,compression=uncompressed,force-compression=true,dest=$output" "$context"
python3 - "$output" <<'PY'
import json
import sys
import tarfile
with tarfile.open(sys.argv[1]) as archive:
    manifest = json.load(archive.extractfile("manifest.json"))
    assert len(manifest) == 1, "Expected one image"
    config = json.load(archive.extractfile(manifest[0]["Config"]))
    assert config["architecture"] == "arm64", "Expected ARM64"
    assert config["os"] == "linux", "Expected Linux"
    for layer in manifest[0]["Layers"]:
        archive.getmember(layer)
        with tarfile.open(fileobj=archive.extractfile(layer), mode="r:") as contents:
            for member in contents:
                pass
print("Docker archive validated")
PY

python3 "$context/legacy_archive.py" "$output" "$output.legacy"
mv "$output.legacy" "$output"
