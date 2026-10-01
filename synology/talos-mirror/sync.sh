#!/bin/sh
set -eu

version="${1:-v1.14.1}"
schematic_id="376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
architecture="amd64"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
destination="${script_dir}/assets/${version}"
factory="https://pxe.factory.talos.dev/image/${schematic_id}/${version}"

mkdir -p "$destination"

for asset in "kernel-${architecture}" "initramfs-${architecture}.xz"; do
    temporary="${destination}/${asset}.part"
    curl --fail --location --show-error --output "$temporary" "${factory}/${asset}"
    mv "$temporary" "${destination}/${asset}"
done

(
    cd "$destination"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "kernel-${architecture}" "initramfs-${architecture}.xz" > SHA256SUMS
    else
        shasum -a 256 "kernel-${architecture}" "initramfs-${architecture}.xz" > SHA256SUMS
    fi
)

echo "Mirrored Talos ${version} into ${destination}"
