# Quantum: RP1 PWM fan rebuild

Prepared 2026-10-06 at the operator's explicit request to resume fan work.
This does not resume the separate U-Boot/NVMe-only boot experiment.
All build, registry, cluster and disk-changing commands are OPERATOR-RUN.
No live change or compilation was performed while preparing this runbook.

## Evidence and scope

Worker-03 (`192.168.40.42`) runs its fan constantly at full speed while CPU
temperature is 38600 millidegrees C (38.6 C). Sysfs showed thermal_zone0 but no
PWM controller. Kernel log: `platform cooling_fan: deferred probe pending:
pwm-fan: Could not get PWM`. Its kernel config enables generic PWM fan and RP1
clock/pin-control support, but has no RP1 PWM driver option.

The Pi 5 device tree uses RP1 PWM channel 3 for the fan. The helper backports
`pwm-rp1.c`, Kconfig and Makefile registration from the same pinned Raspberry Pi
source used for PL011. `rp1-pwm-config.patch` enables it built-in, not as a Talos
extension. No fan threshold change is needed merely to obtain a PWM provider.

The donor driver uses managed clock/PWM registration but also manually disables
the clock on failure/removal; its remove callback retrieves unset platform
drvdata. The backport removes that redundant cleanup, leaving devres to release
the PWM chip before the clock. No register/PWM algorithm changes were made.
Its public PWM APIs were checked against Linux 6.18.54. This is source-level
compatibility checking, NOT compiler or hardware acceptance. A missing clock,
device-tree mismatch or other probe failure may still prevent fan control.

- pkgs pin: `6c312e4b77817a9c1bd4975a532b3fd23d33430c`.
- Raspberry Pi source: `60ea684a8ace97bb0db1a16e20753bdd6ab371ff`.
- Donor driver SHA-256: `d82b44834f624c6c3df52fdec44ab434168c4118efa43ca66c11d44cf1654841`.
- Generated PWM patch SHA-256: `1c81f7dcada2965c324069b5a037235a6ba869d246045327ffdafbdd09c00038`.
- Existing PL011 patch must remain SHA-256
  `b4dad001ddc873347ddf2bbc3458aafdbabf11d2f07fbfce9bf2a5e6662e42dd`.

Preserve the working SD, original kernel export, image tags/digests and installed
NVMe. Reuse the existing builder and caches, but a changed kernel patch/config
invalidates the compile layer: it may take as long as the original kernel
compile. Do not promise incremental object caching that was not established.
Keep the Lima swap available for final BTF generation; do not disable BTF.

## 1. Preflight

```sh
cd /Users/anton/projects/home-infra
export DOCKER_CONTEXT=lima-default
CUSTOM_BUILD_DIR=/Users/anton/projects/home-infra/talos/generated/custom-rpi5/build.7qb4C2

docker info --format 'name={{.Name}} os={{.OSType}} arch={{.Architecture}}'
docker buildx inspect talos-rpi5
limactl shell default free -h
git -C "$CUSTOM_BUILD_DIR/pkgs" rev-parse HEAD
git -C "$CUSTOM_BUILD_DIR/pkgs" status --short
```

Require Linux/aarch64, the existing ARM64 builder, expected pkgs commit, and
adequate memory/swap. The previous 8 GiB RAM/no-swap build OOMed; its successful
retry used 8 GiB swap. Preserve unexpected checkout changes and stop if they
overlap. The expected pre-fan change is the untracked PL011 patch. If PWM was
already prepared/applied, inspect it rather than rerunning exclusive creation.

## 2. Prepare PWM and enable the built-in driver

The helper's default mode writes nothing; `--pkgs-dir` creates only a new
`0020-pwm-add-rp1.patch`, refuses to replace an existing file, and verifies the
existing PL011 patch. Kernel config is changed separately by git apply:

```sh
python3 talos/custom-rpi5/prepare-pwm-backport.py
python3 talos/custom-rpi5/prepare-pwm-backport.py \
  --pkgs-dir "$CUSTOM_BUILD_DIR/pkgs"

git -C "$CUSTOM_BUILD_DIR/pkgs" apply --check \
  "$PWD/talos/custom-rpi5/rp1-pwm-config.patch"
git -C "$CUSTOM_BUILD_DIR/pkgs" apply \
  "$PWD/talos/custom-rpi5/rp1-pwm-config.patch"

git -C "$CUSTOM_BUILD_DIR/pkgs" diff -- kernel/build/config-arm64
shasum -a 256 "$CUSTOM_BUILD_DIR/pkgs/kernel/build/patches/0019-serial-pl011-add-rpi5-axi.patch"
shasum -a 256 "$CUSTOM_BUILD_DIR/pkgs/kernel/build/patches/0020-pwm-add-rp1.patch"
```

Require only the intended config addition `CONFIG_PWM_RP1=y`, unchanged PL011
hash and the PWM hash above. Stop on any source/hash/apply error.

## 3. Export the rebuilt kernel into a NEW directory

```sh
FAN_BUILD_DIR=$(mktemp -d "$CUSTOM_BUILD_DIR/fan.XXXXXX")
printf 'Fan rebuild directory: %s\n' "$FAN_BUILD_DIR"

gmake -C "$CUSTOM_BUILD_DIR/pkgs" local-kernel \
  PLATFORM=linux/arm64 PUSH=false \
  BUILD='docker buildx build --builder talos-rpi5' \
  DEST="$FAN_BUILD_DIR/kernel"

test -s "$FAN_BUILD_DIR/kernel/boot/vmlinuz"
test -d "$FAN_BUILD_DIR/kernel/usr/lib/modules/6.18.54-talos"
shasum -a 256 "$FAN_BUILD_DIR/kernel/boot/vmlinuz"
```

Stop and retain logs on compilation, patching, hardening, BTF or OOM errors.
Successful export is not fan acceptance. Never overwrite the original
`$CUSTOM_BUILD_DIR/kernel` export. Keep FAN_BUILD_DIR for the following gates.

## 4. Publish a NEW kernel revision

OPERATOR-RUN registry write. First verify this tag is genuinely absent:

```sh
FAN_TAG=v1.14.2-rp1-axi-pwm1
KERNEL_IMAGE=registry.home.antonu.org/talos/custom-rpi5/kernel:$FAN_TAG
docker buildx imagetools inspect "$KERNEL_IMAGE"
```

Only on confirmed missing manifest (not TLS/auth/network failure), publish.
If it exists, inspect provenance and choose a new revision rather than replace.
Provenance is disabled for this single-platform package to make its image digest
unambiguous; sources and patch hashes are retained in labels and this runbook.

```sh
docker buildx build --builder talos-rpi5 \
  --platform linux/arm64 --provenance=false \
  --file "$PWD/talos/custom-rpi5/kernel.Dockerfile" \
  --label org.opencontainers.image.version="$FAN_TAG" \
  --label org.opencontainers.image.title='Quantum Talos PL011 AXI and RP1 PWM kernel' \
  --label home.antonu.org.rp1-pwm-backport-sha256=1c81f7dcada2965c324069b5a037235a6ba869d246045327ffdafbdd09c00038 \
  --tag "$KERNEL_IMAGE" \
  --metadata-file "$FAN_BUILD_DIR/kernel-image-metadata.json" \
  --push "$FAN_BUILD_DIR/kernel"

KERNEL_DIGEST=$(jq -er '."containerimage.digest"' "$FAN_BUILD_DIR/kernel-image-metadata.json")
KERNEL_REF="registry.home.antonu.org/talos/custom-rpi5/kernel@$KERNEL_DIGEST"
docker buildx imagetools inspect "$KERNEL_REF"
```

Require ARM64 and the new recorded digest; save it in the build record. The
old PL011 label remains valid because its patch is still included.

## 5. Rebuild imager with matching kernel and modules

Reuse the existing pinned Talos checkout and AMD64 kernel-stage patch. Do not
clone over it or reapply existing patches. Its GRUB selection patch may also be
present from the installer-base build; preserve it. Check the candidate tag is
absent before publishing:

```sh
git -C "$CUSTOM_BUILD_DIR/talos" rev-parse HEAD
git -C "$CUSTOM_BUILD_DIR/talos" diff --stat
docker buildx imagetools inspect \
  "registry.home.antonu.org/talos/custom-rpi5/imager:$FAN_TAG"
```

Require Talos commit `f513c7358cefc69255e29b517ba96c651e0326ad`; inspect unexpected
changes. Only when the new tag is absent:

```sh
gmake -C "$CUSTOM_BUILD_DIR/talos" imager \
  ARCH=arm64 PLATFORM=linux/arm64 INSTALLER_ARCH=targetarch \
  TAG=v1.14.2 IMAGE_TAG_OUT="$FAN_TAG" \
  IMAGE_REGISTRY=registry.home.antonu.org USERNAME=talos/custom-rpi5 \
  PKG_KERNEL="$KERNEL_REF" \
  PUSH=true BUILD='docker buildx build --builder talos-rpi5'

docker buildx imagetools inspect \
  "registry.home.antonu.org/talos/custom-rpi5/imager:$FAN_TAG"
```

Record the displayed imager digest before artifact assembly. Set IMAGER to that
exact digest, not a guessed value or the old imager. No installer-base rebuild
is required: the existing GRUB-forced base supplies the same installation tools.

## 6. Assemble test SD and full installer from the NEW imager

Set IMAGER to the verified digest from gate 5. These profiles preserve UART,
iSCSI, console and overlay settings. Their kernel/initramfs paths are inside the
selected imager, so choosing the new digest supplies PWM support without editing
the profiles. The stock overlay/U-Boot is intentionally unchanged.

```sh
: "${IMAGER:?Set the verified NEW custom imager digest reference}"
SD_ARTIFACT_DIR=$(mktemp -d "$FAN_BUILD_DIR/sd.XXXXXX")
docker run --rm --privileged --platform linux/arm64 -i \
  "$IMAGER" - --tar-to-stdout \
  < talos/custom-rpi5/sd-image.yaml \
  > "$SD_ARTIFACT_DIR/artifacts.tar.gz"
```

Stop on error. On success require exactly `metal-arm64.raw.xz` in the outer
archive, then extract it to that new directory and test it:

```sh
tar -tzf "$SD_ARTIFACT_DIR/artifacts.tar.gz"
tar -xzf "$SD_ARTIFACT_DIR/artifacts.tar.gz" \
  -C "$SD_ARTIFACT_DIR" metal-arm64.raw.xz
xz --test "$SD_ARTIFACT_DIR/metal-arm64.raw.xz"
xz --decompress --keep "$SD_ARTIFACT_DIR/metal-arm64.raw.xz"
sgdisk --print "$SD_ARTIFACT_DIR/metal-arm64.raw"
```

The raw image is only a local regular file. Require partition 4 to be the 1 MB
META partition before changing its label to make this another boot-only SD:

```sh
sgdisk --change-name=4:SD-BOOT-META "$SD_ARTIFACT_DIR/metal-arm64.raw"
sgdisk --print "$SD_ARTIFACT_DIR/metal-arm64.raw"
shasum -a 256 "$SD_ARTIFACT_DIR/metal-arm64.raw"
```

Confirm only the partition name changed. Do NOT flash the unmodified image with
recognized SD META alongside the installed NVMe and assume Talos chooses the
correct system disk. No machine configuration or cluster identity is embedded.

**STOP before physical writes.** Connect ONLY the spare SD to the Mac and run
`diskutil list external physical`; review its exact identity/size before giving
or running a flash command. The working SD stays untouched. No physical disk
write command is authorized by this preparation runbook.

Full installer assembly is optional until the SD fan test succeeds:

```sh
INSTALLER_ARTIFACT_DIR=$(mktemp -d "$FAN_BUILD_DIR/installer.XXXXXX")
docker run --rm --privileged --platform linux/arm64 -i \
  "$IMAGER" - --tar-to-stdout \
  < talos/custom-rpi5/installer.yaml \
  > "$INSTALLER_ARTIFACT_DIR/artifacts.tar.gz"
```

Stop on error. Review the listing, require `installer-arm64.tar`, extract it,
then publish under a confirmed-absent NEW `installer:$FAN_TAG` tag using the
archive-promotion procedure in the build history. Record its resulting digest.
Do not update worker-03-install.yaml or apply its `wipe: true` configuration.
Installer publication alone cannot fix a kernel still booted from the old SD.

## 7. Hardware acceptance and recovery

Spare-card flashing and a shutdown/card swap are separate operator actions
after identity review. They interrupt worker-03 and its deCONZ workload. No
standalone NVMe boot fix is attempted here. Keep the fan connected.

After the candidate boots, use the authenticated project environment:

```sh
talosctl -e 192.168.40.42 -n 192.168.40.42 get systemdisks
talosctl -e 192.168.40.42 -n 192.168.40.42 get volumestatus META
talosctl -e 192.168.40.42 -n 192.168.40.42 ls /sys/class/pwm --depth 2
talosctl -e 192.168.40.42 -n 192.168.40.42 ls /sys/class/thermal --depth 2
talosctl -e 192.168.40.42 -n 192.168.40.42 read /sys/class/thermal/thermal_zone0/temp
talosctl -e 192.168.40.42 -n 192.168.40.42 dmesg | \
  rg -i 'ttyAMA|PL011 AXI|pwm|cooling_fan|thermal|clock|probe.*fail'
kubectl get node talos-worker-03 -o wide
```

Require NVMe system disk/META still selected, PWM controller registered, fan
cooling device bound (no `Could not get PWM`), sane temperature and automatic
fan behavior. At low temperature the fan need not keep running full speed.
Verify ttyAMA0 remains present, node Ready, deCONZ direct control and HA sensor
updates still work. Existing clock errors need investigation if they prevent
PWM binding. Do not declare success from a built image or PWM driver presence
alone. Do not disable cooling to hide a failure.

Rollback: power off safely, disconnect power, restore the original working SD,
and power on. No NVMe wipe, GRUB/U-Boot replacement, credential regeneration,
or cluster bootstrap is part of this test. Updating installed NVMe for future
maintenance requires a separate reviewed upgrade plan, not repeating install.
