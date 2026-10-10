# Quantum: custom Talos Pi 5 build and installation

## Current status / stopping point (2026-10-06)

The original bootloader troubleshooting stopped at the operator's request.
Fan-driver work was explicitly resumed on 2026-10-06; see
[RP1 PWM fan rebuild](FAN-REBUILD.md). This does not authorize resuming the
U-Boot experiment, reinstalling NVMe, or executing infrastructure changes.

The custom kernel, imager, GRUB-forced installer base, and full installer were
built and published. Quantum joined as `talos-worker-03` and was reported Ready.
Talos identifies NVMe as its system disk and META is ready on `nvme0n1p4`.
However, boot still requires the working boot-only SD. Without SD, HDMI stays
at the U-Boot logo; Space did not open a prompt. Independent NVMe boot has NOT
succeeded. The operator subsequently reported deCONZ working perfectly and
Home Assistant devices reconnected. The fan runs full speed at 38.6 C; kernel
diagnostics show the fan waiting for an unavailable PWM provider.

See [the complete build history and handoff](../../docs/quantum-talos-build-history.md)
for artifact digests, failures/workarounds, installer-base reconstruction,
diagnostic evidence, and the unexecuted U-Boot proposal. This file retains the
operator-run build recipes; older gate text describes the state at that stage,
not the latest state. Do not rerun the destructive installation to fix boot.

Prepared 2026-10-05. Compilation succeeded 2026-10-06 after adding swap.
Operator reported successful SD boot on 2026-10-06: `ttyAMA0` registered as
PL011 AXI at `0x1f00030000`, with only `console=tty0`; NVMe was detected.
RaspBee communication remains untested, and the clock probe error persists.
Stock Talos v1.14.2 did not register `ttyAMA0` with either UART boot setting.
The generated image contains `dtparam=uart0=on`, `dtoverlay=uart0-pi5` and
the corresponding overlay file. `ttyAMA10` is the separate debug UART.

Quantum is Raspberry Pi 5, MAC `2C:CF:67:1B:D6:FE`, ether5/VLAN 400,
`192.168.40.42`, now `talos-worker-03`. Its approved installation target was
`/dev/nvme0n1`, SanDisk SSD Plus 250GB A3N, serial `24380U800133`.
The build steps themselves do not write NVMe; the operator subsequently
installed Talos there. Preserve the installed disk and working SD.

## Candidate and provenance

Talos v1.14.2 pins pkgs to `6c312e4b77817a9c1bd4975a532b3fd23d33430c`,
Linux 6.18.54. Its PL011 driver lacks the `arm,pl011-axi` platform interface
used by the Pi 5 GPIO UART's DTB. Raspberry Pi downstream implements it.
The helper extracts only AXI vendor data, probe/remove, match table and driver
registration. It retains Talos's configuration and other kernel patches.
It does not replace the full driver or switch to the Raspberry Pi OS kernel.

This may reveal additional clock, pinctrl, firmware or device-tree problems;
it is not proof that this patch alone will make RaspBee II work. The observed
`raspberrypi-clk` probe error remains unresolved.

Sources:

- [Talos package pin](https://github.com/siderolabs/talos/blob/v1.14.2/Makefile)
- [Exact kernel configuration](https://github.com/siderolabs/pkgs/blob/6c312e4b77817a9c1bd4975a532b3fd23d33430c/kernel/build/config-arm64)
- [Linux 6.18.54 driver](https://github.com/gregkh/linux/blob/v6.18.54/drivers/tty/serial/amba-pl011.c)
- [Pinned Raspberry Pi driver, GPL-2.0-or-later](https://github.com/raspberrypi/linux/blob/60ea684a8ace97bb0db1a16e20753bdd6ab371ff/drivers/tty/serial/amba-pl011.c)

Raspberry Pi OS mounts the firmware partition at `/boot/firmware`; Talos's
overlay writes it at `/boot/EFI`. On macOS, `config.txt` is at the EFI volume
root. These are mount-path differences, not different firmware search paths.
Keep the overlay's `enable_uart=0` until a separate bootloader test justifies
changing it. Console-free settings must survive the eventual installation.

## Gate 1: prepare and compile

All commands below are OPERATOR-RUN. Builds modify a local Docker builder,
download public inputs and consume substantial RAM/CPU/disk. Use a local
Linux/arm64-capable builder, NOT the `quantum` Docker context.
Operator verified `lima-default` is running Linux/aarch64 with 4 CPUs and
8 GiB RAM on 2026-10-05. Buildx was absent from the Mac client. Install the
client plugin without changing or printing Docker's credential-bearing config:

```sh
brew install docker-buildx
brew install make
mkdir -p /Users/anton/.docker/cli-plugins
ln -s /opt/homebrew/lib/docker/cli-plugins/docker-buildx \
  /Users/anton/.docker/cli-plugins/docker-buildx
docker buildx version
gmake --version
```

The symlink command intentionally has no overwrite flag. If its destination
already exists, stop and inspect that plugin path instead of replacing it.
Check the daemon and available builders before proceeding:

```sh
cd /Users/anton/projects/home-infra
export DOCKER_CONTEXT=lima-default
docker info --format 'name={{.Name}} os={{.OSType}} arch={{.Architecture}}'
docker buildx ls
python3 talos/custom-rpi5/prepare-backport.py
```

Default helper mode checks pinned file hashes and source insertion points;
it writes nothing and does not compile. Expected patch SHA-256:
`b4dad001ddc873347ddf2bbc3458aafdbabf11d2f07fbfce9bf2a5e6662e42dd`.
Stop if the daemon is unavailable or unsuitable; do not reconfigure a VM blindly.

If the named builder does not already exist, create it on the chosen context:

```sh
docker buildx create --name talos-rpi5 --driver docker-container
docker buildx inspect talos-rpi5 --bootstrap
```

Prepare a new isolated checkout and the backport (never an existing checkout):

```sh
mkdir -p talos/generated/custom-rpi5
CUSTOM_BUILD_DIR=$(mktemp -d "$PWD/talos/generated/custom-rpi5/build.XXXXXX")
git clone https://github.com/siderolabs/pkgs.git "$CUSTOM_BUILD_DIR/pkgs"
git -C "$CUSTOM_BUILD_DIR/pkgs" switch --detach \
  6c312e4b77817a9c1bd4975a532b3fd23d33430c
python3 talos/custom-rpi5/prepare-backport.py --pkgs-dir "$CUSTOM_BUILD_DIR/pkgs"
git -C "$CUSTOM_BUILD_DIR/pkgs" status --short
```

Review `kernel/build/patches/0019-serial-pl011-add-rpi5-axi.patch`; only this
new patch should appear. The helper refuses another commit or an existing patch.

```sh
gmake -C "$CUSTOM_BUILD_DIR/pkgs" local-kernel \
  PLATFORM=linux/arm64 PUSH=false \
  BUILD='docker buildx build --builder talos-rpi5' \
  DEST="$CUSTOM_BUILD_DIR/kernel"
test -s "$CUSTOM_BUILD_DIR/kernel/boot/vmlinuz"
shasum -a 256 "$CUSTOM_BUILD_DIR/kernel/boot/vmlinuz"
```

This exports a kernel and matching module tree; no OCI push, SD/NVMe write,
or Kubernetes/Talos mutation. Stop on patch/compiler/module errors. Keep the
build directory and logs. Compilation success is NOT boot or radio acceptance.

## Gate 2: publish the compiled kernel package

The exported `boot/vmlinuz` SHA-256 was inspected on 2026-10-06:
`94f4bc505f79e7f4d734ef213af806d1d2cd569e8b44801492f15a2e9010783a`.
Its matching modules directory is `usr/lib/modules/6.18.54-talos`.
Package the COMPLETE exported root, not just vmlinuz. This step does not
compile the kernel again or write boot media.

OPERATOR-RUN registry write: new ARM64-only package at
`registry.home.antonu.org/talos/custom-rpi5/kernel:v1.14.2-rp1-axi1`.
Check the tag is absent before publishing; if it exists, inspect its digest
and provenance instead of overwriting. Missing authentication or connectivity
is not evidence that the tag is absent.

```sh
cd /Users/anton/projects/home-infra
export DOCKER_CONTEXT=lima-default
CUSTOM_BUILD_DIR=/Users/anton/projects/home-infra/talos/generated/custom-rpi5/build.7qb4C2
KERNEL_IMAGE=registry.home.antonu.org/talos/custom-rpi5/kernel:v1.14.2-rp1-axi1
docker buildx imagetools inspect "$KERNEL_IMAGE"
```

Only on a confirmed missing manifest/tag:

```sh
docker buildx build --builder talos-rpi5 \
  --platform linux/arm64 \
  --file "$PWD/talos/custom-rpi5/kernel.Dockerfile" \
  --tag "$KERNEL_IMAGE" \
  --metadata-file "$CUSTOM_BUILD_DIR/kernel-image-metadata.json" \
  --push "$CUSTOM_BUILD_DIR/kernel"
docker buildx imagetools inspect "$KERNEL_IMAGE"
```

Keep the resulting digest. Subsequent imager inputs must use it, not a mutable
tag alone. This custom package is not a Talos installer and must never be used
as an apply-config or upgrade installer image.

## Gate 3: build the ARM64 custom imager

Operator published the kernel package on 2026-10-06. Its OCI index digest is
`sha256:9e2ffebec51e9e2e5415ecb9d40cfbb21ea2f69244436efef77f9638ddab4970`;
the ARM64 image manifest digest used below is
`sha256:4b98181fc90cda31fc763c1e8ccbb89cc37aa34030ff132ef55083c891ddc0b7`.
The additional unknown/unknown manifest is Buildx provenance, not a kernel.

Talos's build also references an AMD64 kernel for metadata generation, even
when the output architecture is ARM64. The one-line Dockerfile patch keeps
that input on the exact stock package tag from the Talos v1.14.2 Makefile,
while PKG_KERNEL supplies the custom ARM64 package to its ARM64 stages.
INSTALLER_ARCH=targetarch selects only ARM64 boot artifacts for this imager.
Talos core/version stays v1.14.2; the separate output tag identifies the custom
kernel. This stage rebuilds initramfs with the matching ARM64 modules.

OPERATOR-RUN checkout preparation (stop on any error):

```sh
cd /Users/anton/projects/home-infra
export DOCKER_CONTEXT=lima-default
CUSTOM_BUILD_DIR=/Users/anton/projects/home-infra/talos/generated/custom-rpi5/build.7qb4C2
git clone https://github.com/siderolabs/talos.git "$CUSTOM_BUILD_DIR/talos"
git -C "$CUSTOM_BUILD_DIR/talos" switch --detach \
  f513c7358cefc69255e29b517ba96c651e0326ad
git -C "$CUSTOM_BUILD_DIR/talos" apply --check \
  "$PWD/talos/custom-rpi5/talos-arm64-kernel.patch"
git -C "$CUSTOM_BUILD_DIR/talos" apply \
  "$PWD/talos/custom-rpi5/talos-arm64-kernel.patch"
git -C "$CUSTOM_BUILD_DIR/talos" diff --stat
```

Require exactly one changed line in Dockerfile. Do not clone over an existing
checkout; reuse and inspect it if already present rather than overwriting it.
Confirm the new destination tag is missing (not auth/TLS/network failure):

```sh
docker buildx imagetools inspect \
  registry.home.antonu.org/talos/custom-rpi5/imager:v1.14.2-rp1-axi1
```

OPERATOR-RUN BUILD AND REGISTRY PUSH: new custom imager only, no stock tag
replacement, no disk write, no cluster change. This can be another substantial
build; retain Lima swap and stop on errors.

```sh
gmake -C "$CUSTOM_BUILD_DIR/talos" imager \
  ARCH=arm64 PLATFORM=linux/arm64 INSTALLER_ARCH=targetarch \
  TAG=v1.14.2 IMAGE_TAG_OUT=v1.14.2-rp1-axi1 \
  IMAGE_REGISTRY=registry.home.antonu.org USERNAME=talos/custom-rpi5 \
  PKG_KERNEL=registry.home.antonu.org/talos/custom-rpi5/kernel@sha256:4b98181fc90cda31fc763c1e8ccbb89cc37aa34030ff132ef55083c891ddc0b7 \
  PUSH=true BUILD='docker buildx build --builder talos-rpi5'
docker buildx imagetools inspect \
  registry.home.antonu.org/talos/custom-rpi5/imager:v1.14.2-rp1-axi1
```

Keep the imager digest for SD/installer assembly. The imager itself is NOT a
node installer; do not use it with apply-config or upgrade.

## Gate 4: generate SD test image

Operator reported successful imager publication on 2026-10-06:
`registry.home.antonu.org/talos/custom-rpi5/imager@sha256:2f7d64b1b23560b0a6dbedcbe326ad01286735327a563ff520f6b271681c14bc`.
`sd-image.yaml` uses this imager's ARM64 kernel/initramfs paths, the Pi 5
overlay v0.2.2 and iSCSI v0.2.0 by digest, GPIO UART settings, no serial console,
and GRUB rather than sd-boot. It embeds no machine configuration or secrets.

OPERATOR-RUN: start a privileged image-generation container ONLY on local
`lima-default`. Privilege is for image partition/loop/mount operations inside
Lima, not a cluster workload. No physical SD/NVMe is passed into the container.
Use stdin for the profile and a gzip tar stream to the Mac; this avoids assuming
the Mac home-directory mount inside Lima is writable. Progress goes to stderr;
do not use `-t`, which could corrupt the binary stdout archive.

```sh
cd /Users/anton/projects/home-infra
export DOCKER_CONTEXT=lima-default
CUSTOM_BUILD_DIR=/Users/anton/projects/home-infra/talos/generated/custom-rpi5/build.7qb4C2
SD_ARTIFACT_DIR=$(mktemp -d "$CUSTOM_BUILD_DIR/sd.XXXXXX")
IMAGER=registry.home.antonu.org/talos/custom-rpi5/imager@sha256:2f7d64b1b23560b0a6dbedcbe326ad01286735327a563ff520f6b271681c14bc
docker run --rm --privileged --platform linux/arm64 -i \
  "$IMAGER" - --tar-to-stdout \
  < talos/custom-rpi5/sd-image.yaml \
  > "$SD_ARTIFACT_DIR/artifacts.tar.gz"
```

Stop on any container error; the output archive may be partial. Only after
successful completion list/extract it into the new empty artifact directory:

```sh
tar -tzf "$SD_ARTIFACT_DIR/artifacts.tar.gz"
tar -xzf "$SD_ARTIFACT_DIR/artifacts.tar.gz" -C "$SD_ARTIFACT_DIR"
xz --test "$SD_ARTIFACT_DIR/metal-arm64.raw.xz"
shasum -a 256 "$SD_ARTIFACT_DIR/metal-arm64.raw.xz"
printf 'SD artifact directory: %s\n' "$SD_ARTIFACT_DIR"
```

Review the tar listing first; require the generated image path, no unexpected
absolute or parent-traversal paths. No physical disk is written at this gate.
Reconfirm the SD identity and prepare operator-only write instructions after
generation succeeds. Boot/UART/radio acceptance is still pending.

## Gate 5: assemble the matching installer archive

`installer.yaml` uses the same custom imager kernel/initramfs, extensions,
overlay and UART settings as the SD image. Its custom v1.14.2 ARM64 installer
base supplies installation tools and the fresh-install GRUB selection patch,
not a replacement kernel. Operator reported publication of this base on
2026-10-06, digest
`sha256:e2339472d224416af70ed213f527fa95be51dc304dd314a017f168acb9864e1b`.
The profile must explicitly set `input.overlayInstaller.imageRef` as well as
`overlay.image.imageRef`: profile-file mode does not infer the installer input
from the overlay used during assembly. The first attempt on 2026-10-06 failed
at this missing reference after building the UKI; the profile is now corrected.
Use a new artifact directory when retrying; do not promote the failed archive.

OPERATOR-RUN, local Lima container only; no registry push or physical disk write:

```sh
cd /Users/anton/projects/home-infra
export DOCKER_CONTEXT=lima-default
CUSTOM_BUILD_DIR=/Users/anton/projects/home-infra/talos/generated/custom-rpi5/build.7qb4C2
INSTALLER_ARTIFACT_DIR=$(mktemp -d "$CUSTOM_BUILD_DIR/installer.XXXXXX")
IMAGER=registry.home.antonu.org/talos/custom-rpi5/imager@sha256:2f7d64b1b23560b0a6dbedcbe326ad01286735327a563ff520f6b271681c14bc
docker run --rm --privileged --platform linux/arm64 -i \
  "$IMAGER" - --tar-to-stdout \
  < talos/custom-rpi5/installer.yaml \
  > "$INSTALLER_ARTIFACT_DIR/artifacts.tar.gz"
```

Stop on any container error. After success:

```sh
tar -tzf "$INSTALLER_ARTIFACT_DIR/artifacts.tar.gz"
printf 'Installer artifact directory: %s\n' "$INSTALLER_ARTIFACT_DIR"
```

Require exactly `installer-arm64.tar` before extraction and registry promotion.
Do not use the imager image as the node installer. GRUB in `sd-image.yaml`
controls only SD image creation; fresh installation bootloader selection must
be checked separately before applying a destructive NVMe configuration.

## Historical installation gates (already performed)

These record the original fresh installation, not a recovery procedure.
Quantum is now installed. Do not repeat `wipe: true` or insecure apply-config
on this node to troubleshoot its SD dependency.

### Gate 6: operator-run NVMe installation

On 2026-10-06 operator reported boot-only SD acceptance: no SystemDisk resource
and META phase `missing`. Direct Mac GPT relabel was denied; operator instead
relabeled partition 4 in a copy of the original raw image using sgdisk and
rewrote the test SD. The original artifact remains unchanged.

`talos/patches/worker-03-install.yaml` pins the corrected full installer and
requires BOTH `/dev/nvme0n1` and serial `24380U800133`. It enables wiping.
Do not reuse it on any other node or boot with recognized SD META.
All commands below are operator-run. First reconfirm the disk and Talos CLI:

```sh
cd /Users/anton/projects/home-infra
talosctl version --client
talosctl -n 192.168.40.42 get disks --insecure
```

Require Talos CLI v1.14.2 and the approved SanDisk 250 GB disk/serial. Verify
backups remain available independently of the old NVMe. Generate only this
worker configuration into a new private output directory, using EXISTING
cluster secrets. Never bootstrap or regenerate cluster identity:

```sh
umask 077
: "${TALOSCONFIG:?Load the project direnv environment}"
: "${KUBECONFIG:?Load the project direnv environment}"
test -s talos/secrets/home-cloud.yaml
QUANTUM_CONFIG_DIR=$(mktemp -d "$PWD/talos/generated/quantum-config.XXXXXX")
INSTALLER=registry.home.antonu.org/talos/custom-rpi5/installer@sha256:2c8c7da39af1b40750687b234fae81f866f5573c1cf569198cc0fb5323c8b89e
talosctl gen config home-cloud https://k8s.home.antonu.org:6443 \
  --with-secrets talos/secrets/home-cloud.yaml \
  --talos-version v1.14.2 --kubernetes-version 1.37.1 \
  --install-disk /dev/nvme0n1 --install-image "$INSTALLER" \
  --config-patch-worker @talos/patches/cilium.yaml \
  --config-patch-worker @talos/patches/worker-03.yaml \
  --config-patch-worker @talos/patches/worker-03-install.yaml \
  --output-types worker --output "$QUANTUM_CONFIG_DIR/worker-03.yaml" \
  --with-docs=false --with-examples=false --with-cluster-discovery=false
talosctl validate --config "$QUANTUM_CONFIG_DIR/worker-03.yaml" --mode metal
```

Stop on any error, including missing secrets or environment. Review privately:
hostname worker-03, exact installer digest, NVMe path AND serial selector,
wipe true, proxy disabled, no Flannel config. Never paste the full config.

DESTRUCTIVE: applying erases Quantum's old NVMe OS/data on `/dev/nvme0n1`,
serial `24380U800133`, node `192.168.40.42`. It uses the custom fresh-install
GRUB path. Independent backups and confirmed boot-only SD are prerequisites.

```sh
talosctl -e 192.168.40.42 -n 192.168.40.42 apply-config --insecure \
  -f "$QUANTUM_CONFIG_DIR/worker-03.yaml"
```

Successful API acceptance is not installation acceptance. Allow installation
and automatic reboot, then use the existing authenticated project environment:

```sh
talosctl -e 192.168.40.42 -n 192.168.40.42 get systemdisks -o yaml
talosctl -e 192.168.40.42 -n 192.168.40.42 get volumestatus META -o yaml
kubectl get node talos-worker-03 -o wide
```

Require NVMe system disk and ready NVMe META. Stop on installation, auth or
boot errors instead of retrying destructive operations. Final acceptance must
include graceful shutdown, physical SD removal and successful NVMe-only boot,
UART/console/extension checks and RaspBee communication. Hardware label and
deCONZ migration remain gated on radio acceptance. Before installation SD can
be restored from the original image; after NVMe wipe the old OS/data require
independent backups, not the SD rollback.

Operator reported corrected full installer publication on 2026-10-06:
`registry.home.antonu.org/talos/custom-rpi5/installer@sha256:2c8c7da39af1b40750687b234fae81f866f5573c1cf569198cc0fb5323c8b89e`
(ARM64, tag `v1.14.2-rp1-axi1-grub1`). Registry publication does not prove
NVMe installation or boot. Before applying configuration, check system disk
and META volume status: raw SD images contain META, and the unattended install
controller skips installation if `MachineState.Installed()` reports a ready
META volume. Do not assume applying an NVMe selector migrates an installed SD
system to NVMe. Installation/configuration instructions remain gated on this
read-only check; no node or disk changes have been executed by the agent.

Operator's check confirmed system disk `mmcblk0`, META ready on `mmcblk0p4`.
The SD was then moved to the Mac and identified as external physical `disk4`,
63.9 GB, with a 1 MB fourth partition. Reconfirm identity before each write.
The attempted direct `gpt label` command failed with `operation not permitted`.
Do not repeat it or disable macOS protections. The successful workaround used
`sgdisk --change-name=4:SD-BOOT-META` on a regular-file copy of the raw image,
then rewrote the SD from that copy. This hid SD META from Talos while preserving
the original artifact. See the build history for details and safety boundaries.

### EFI bootloader gate, 2026-10-06

Operator assembled and promoted the first custom installer as ARM64:
`registry.home.antonu.org/talos/custom-rpi5/installer@sha256:1881a7c50e7b3e07a6ecfba409fa2372610c60800863ad076909086ffaeec75d`.
This artifact is retained but NOT approved for fresh NVMe installation:
kernel logs show `EFI v2.11 by Das U-Boot`. Talos v1.14.2's fresh installer
selects sd-boot whenever `/sys/firmware/efi` exists, even when SD boot used GRUB.
There is no bootloader override in `UnattendedInstallConfig`. The previous
Pi 4 efivarfs failure is not proof that this Pi 5 fails identically, but do not
wipe NVMe to test that assumption. `talosctl ls/read` do not support insecure
maintenance access; use supported maintenance diagnostics instead.

`installer-force-grub.patch` changes only fresh-install selection in a dedicated
Quantum installer base. Upgrade continues to probe the installed bootloader;
image creation still respects its profile. It is NOT a general-purpose installer
and must not be used on other nodes or for Secure Boot. No kernel recompilation
or SD rewrite is required. Operator must apply this patch to the isolated Talos
checkout, build a new installer-base tag `v1.14.2-rp1-axi1-grub1`, record its
digest, and then assemble a new installer using that base by digest. Do not
overwrite the first installer or existing stock tags. NVMe
boot acceptance of this installer-base change is still pending. Operator
reported successful compilation/publication of the base; `installer.yaml`
now pins that digest. Publish the resulting full installer under a NEW tag
`v1.14.2-rp1-axi1-grub1`, never over the first `v1.14.2-rp1-axi1` installer.

### Build-memory failure observed on 2026-10-05

The 8 GiB Lima VM had no swap. Kernel OOM logs confirmed `pahole` was killed
at approximately 6.7 GiB resident memory during final BTF generation. The Mac
has 16 GiB RAM. Retain BTF; do not treat this as a UART compiler error.
The VM had 62 GiB free disk when checked. Operator-run mitigation creates
an 8 GiB temporary swap file ONLY inside the local Lima `default` VM:

```sh
limactl shell default sudo sh -c '
  test ! -e /var/lib/talos-rpi5-build.swap &&
  test ! -L /var/lib/talos-rpi5-build.swap &&
  fallocate -l 8G /var/lib/talos-rpi5-build.swap &&
  chmod 600 /var/lib/talos-rpi5-build.swap &&
  mkswap /var/lib/talos-rpi5-build.swap &&
  swapon /var/lib/talos-rpi5-build.swap
'
limactl shell default free -h
```

Stop if any step fails or the file already exists; do not overwrite it or
blindly repeat initialization. No fstab change is made, so activation is not
persistent across VM reboots. Retry the same gmake command with the same build
directory. Buildkit retains completed dependency layers, but the failed kernel
compile layer will generally run again. Swap can make the final link slower.
The swap file remains allocated until the operator later disables it and
removes this exact file; do not delete it while active.

After the imager build succeeds, assemble matching boot and installer artifacts.
Do not replace only a boot partition kernel. The local/public Image Factory
does not support arbitrary custom kernel inputs; use this custom imager instead.

Assemble both SD `metal-arm64.raw.xz` and an installer archive with the same
kernel/initramfs, console-free arguments, Pi 5 overlay v0.2.2, iSCSI v0.2.0.
Use a separate registry namespace, e.g.
`registry.home.antonu.org/talos/custom-rpi5/`, tag `v1.14.2-rp1-axi1`, and record
digests. Never overwrite stock installers or existing custom revisions.
All registry promotion remains explicitly operator-run.

DESTRUCTIVE: SD test-media writing erases the selected SD card. Reconfirm its
identity immediately with `diskutil list external physical`; do not assume
`/dev/disk4` remains correct. Preserve needed contents. Do not write NVMe yet.
Boot SD and check:

```sh
talosctl -n 192.168.40.42 get disks --insecure
talosctl -n 192.168.40.42 dmesg --insecure |
  rg -i 'Kernel command line|ttyAMA|PL011 AXI|pinctrl|clock|probe.*fail'
```

Require `ttyAMA0`, no UART console, stable Ethernet, NVMe detection and no
UART/clock/pinctrl error preventing its use. Then prepare the worker config
using the existing cluster identity and custom installer by digest. Never
regenerate identity or run bootstrap. Keep generated configs private.

DESTRUCTIVE: eventual installation erases Quantum's `/dev/nvme0n1`, SanDisk
serial `24380U800133`, replacing its old OS. Reconfirm disk identity, independent
backups, and bootloader behavior first. Installation commands are withheld
until the custom image passes SD acceptance. After joining, verify RaspBee
firmware communication and direct Phoscon device control before transferring
the hardware scheduling label; preserve the existing deCONZ PVC.

## Rollback and maintenance

**Current recovery:** with power disconnected, reinsert the known-working
boot-only SD and power on. This previously restored access to the installed
NVMe-backed Talos node. The original Pi OS NVMe installation was overwritten;
removing SD no longer returns to that old OS. No patched U-Boot was installed.

Historical, before NVMe installation only: power off and remove experimental SD to boot the
untouched old NVMe OS. Its network was VLAN 100; recovery also requires reviewing
ether5 PVID/DHCP, not assuming old `192.168.100.2` works on VLAN 400.

After installation retain independent backups of build inputs, custom boot
media, installer digests and workload data. Stock upgrades can remove AXI
support. Each custom upgrade must rebase the patch, verify extensions, rebuild
both artifacts and repeat SD/UART/radio acceptance before node maintenance.
Do not change DT compatible strings merely to force another driver to bind.
