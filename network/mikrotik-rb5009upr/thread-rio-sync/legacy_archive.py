"""Convert a Docker-compatible blob archive to sequential legacy Docker layout."""
import io
import json
import sys
import tarfile

def convert(source, destination):
    if source == destination:
        raise ValueError("Use a different output path")
    with tarfile.open(source) as src, tarfile.open(destination, "w", format=tarfile.USTAR_FORMAT) as dst:
        manifest = json.load(src.extractfile("manifest.json"))
        if len(manifest) != 1:
            raise ValueError("Expected exactly one image")
        image = manifest[0]
        config = json.load(src.extractfile(image["Config"]))
        if config.get("architecture") != "arm64":
            raise ValueError("Expected ARM64")
        layers = image["Layers"]
        if len(layers) != len(config["rootfs"]["diff_ids"]):
            raise ValueError("Layer count mismatch")
        rewritten = dict(image, Config="config.json",
                         Layers=[f"{i}/layer.tar" for i in range(len(layers))])
        def add(name, data):
            member = tarfile.TarInfo(name)
            member.size = len(data)
            dst.addfile(member, io.BytesIO(data))
        add("manifest.json", json.dumps([rewritten]).encode())
        add("config.json", json.dumps(config).encode())
        for index, layer in enumerate(layers):
            data = src.extractfile(layer).read()
            import hashlib
            expected = config["rootfs"]["diff_ids"][index]
            if "sha256:" + hashlib.sha256(data).hexdigest() != expected:
                raise ValueError("Layer digest mismatch")
            with tarfile.open(fileobj=io.BytesIO(data), mode="r:"):
                pass
            add(f"{index}/VERSION", b"1.0")
            add(f"{index}/json", json.dumps({"id": str(index)}).encode())
            add(f"{index}/layer.tar", data)
    print("Validated legacy Docker archive:", destination)

if __name__ == "__main__":
    convert(*sys.argv[1:])
