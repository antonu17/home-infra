# Quantum: custom Talos build history and handoff

Recorded 2026-10-06 from repository sources and operator-provided output.
This is a historical record, not an instruction to repeat installation.
All infrastructure, Docker build, registry, and disk-changing commands were
operator-run. The agent prepared source and inspected evidence. No secrets or
generated machine configurations are reproduced here.

## Last recorded boot state (2026-10-06)

The operator stopped bootloader work on 2026-10-06. Do not resume it
automatically. Later the same day, deCONZ and HA were reported working and
fan-driver work was explicitly resumed; see [the separate PWM rebuild plan](../talos/custom-rpi5/FAN-REBUILD.md).
The historical findings below describe the earlier stopping point unless noted.

- Custom Talos v1.14.2 / Linux `6.18.54-talos` boots from the working SD.
- Quantum joined Kubernetes as `talos-worker-03`, reported Ready, v1.37.1.
- SystemDisk is `/dev/nvme0n1`; META is ready on `/dev/nvme0n1p4`.
- This is an NVMe-installed node with an SD-dependent boot path, NOT successful
  standalone NVMe boot. The SD can supply kernel/initramfs while Talos uses
  NVMe system state; the system-disk resource alone does not identify boot media.
- Without SD, HDMI stays at the U-Boot logo. Space did not produce a prompt.
- GPIO UART `/dev/ttyAMA0` registered as PL011 AXI in the custom SD boot.
  No serial console argument is present. This does not prove RaspBee operation.
- `raspberrypi-clk ... probe ... error -22` remained in kernel logs.
- Latest repository `worker-03.yaml` contains the RaspBee scheduling label.
  Its live application and radio acceptance are not established by this record.
  Worker-02's source no longer contains that label; source omission alone does
  not delete a key from an existing Talos configuration.
- No patched U-Boot build, spare-card write, or NVMe bootloader replacement was
  reported complete. A spare SD is available. No debug UART adapter is available.
- The temporary diagnostic pod was created and used; its final cleanup was not
  confirmed. Inspect `deconz/quantum-boot-diag` if returning to this work.

Boot recovery recorded on 2026-10-06: disconnect power, restore the known-working boot-only SD,
and power on. SD reinsertion previously restored access. Latest power/SD state
after the final failed boot test was not confirmed. Preserve this SD, NVMe,
original image, build checkout, registry artifacts, and independent backups.
Do not reset, bootstrap, reinstall, or upgrade merely to troubleshoot boot.

On 2026-10-10, operator node output again showed Quantum Ready at `.40.42`,
Talos v1.14.2 / Kubernetes v1.37.1 / kernel 6.18.54-talos. This confirms node
operation, not standalone NVMe boot or completion of the fan/U-Boot proposals.
Current boot-media status is awaiting confirmation; preserve the historical
constraints below until a successful standalone boot is documented.

## Hardware, environment, and scope

| Item | Recorded identity |
| --- | --- |
| Quantum | Raspberry Pi 5; `talos-worker-03`; `192.168.40.42` |
| Ethernet | MAC `2C:CF:67:1B:D6:FE`, MikroTik ether5, VLAN 400 |
| Installation disk | `/dev/nvme0n1`, SanDisk SSD Plus 250GB A3N, serial `24380U800133` |
| NVMe WWID | `eui.e8238fa6bf530001001b448b40c23b46` |
| Working SD | `/dev/mmcblk0`, about 64 GB; META relabeled `SD-BOOT-META` |
| Mac SD identity during work | external physical `/dev/disk4`, 63.9 GB; NOT a persistent identifier |
| Project | `/Users/anton/projects/home-infra` |
| Docker | `lima-default`, Linux/aarch64, 4 CPUs, 8 GiB RAM |
| Builder | `talos-rpi5`, docker-container driver, linux/arm64 |
| Main build directory | `/Users/anton/projects/home-infra/talos/generated/custom-rpi5/build.7qb4C2` |
| Cluster identity | Existing ignored `talos/secrets/home-cloud.yaml`; never regenerated |

Pi 4 worker-02 is a different node, `192.168.40.41`, on ether6. RaspBee worked
on Quantum under Pi OS/deCONZ 2.32.5 but not on that Pi 4, including before Talos.
Pi 4/X825 interference or hardware failure was considered, not demonstrated.
The RTL-SDR receiver belongs on worker-02. Do not conflate the two boards.

## Why a custom kernel was needed

Stock Talos v1.14.2 registered only the Pi 5 debug UART `ttyAMA10`, not GPIO
`ttyAMA0`, even after adding firmware UART settings. Pi OS had used ttyAMA0
for RaspBee II. Removing kernel console arguments does not create a missing
device; firmware configuration, device tree, and kernel driver support are
separate requirements.

The GPIO UART uses `arm,pl011-axi`. The pinned upstream PL011 driver lacked
the Raspberry Pi downstream AXI platform implementation. We backported AXI
vendor data, probe/remove, device matching, and registration into Talos's
existing driver rather than replacing the kernel wholesale.

Source pins:

- Talos v1.14.2: `f513c7358cefc69255e29b517ba96c651e0326ad`.
- Talos pkgs: `6c312e4b77817a9c1bd4975a532b3fd23d33430c`.
- Linux: 6.18.54.
- Raspberry Pi driver: `60ea684a8ace97bb0db1a16e20753bdd6ab371ff`.
- Backport SHA-256: `b4dad001ddc873347ddf2bbc3458aafdbabf11d2f07fbfce9bf2a5e6662e42dd`.
- Exported kernel SHA-256: `94f4bc505f79e7f4d734ef213af806d1d2cd569e8b44801492f15a2e9010783a`.

`talos/custom-rpi5/prepare-backport.py` verifies source hashes and insertion
points. Its default mode fetches public sources but writes nothing;
`--pkgs-dir` writes only the new patch into an explicitly selected pinned
checkout and refuses to overwrite it. The generated patch is
`kernel/build/patches/0019-serial-pl011-add-rpi5-axi.patch`.

Firmware settings used in both SD and installer profiles:

```ini
[all]
dtparam=uart0=on
dtoverlay=uart0-pi5
```

Kernel customization removes default consoles with `-console`, then adds only
`console=tty0`. The overlay's `[pi5] enable_uart=0` was retained for its U-Boot
compatibility setting; this is distinct from enabling GPIO UART0 via dtparam.
Pi OS's `/boot/firmware/config.txt`, Talos overlay's `/boot/EFI/config.txt`, and
the Mac EFI volume's root `config.txt` refer to the same firmware file role.

## What was built, in order

1. **Kernel package:** pinned pkgs checkout plus PL011 AXI backport. GNU Make
   `local-kernel` exported the complete kernel package (kernel and matching
   `usr/lib/modules/6.18.54-talos`), about 248 MB. A scratch Dockerfile packaged
   the entire exported root and the operator pushed it to the private registry.
2. **Custom imager:** pinned Talos checkout, using the custom ARM64 package.
   `talos-arm64-kernel.patch` pins the AMD64 stage to the original stock package
   because the build still references AMD64 metadata even for ARM64 output.
   `INSTALLER_ARCH=targetarch` limits boot artifact generation to ARM64.
   The imager rebuilds initramfs with matching modules; it is not an installer.
3. **SD image:** custom imager plus `sd-image.yaml`, Pi 5 overlay, iSCSI tools,
   UART settings, console-free serial path, and GRUB image options.
   Output `metal-arm64.raw.xz` booted and registered ttyAMA0 as PL011 AXI.
4. **First full installer:** initial stock installer base. It assembled after
   correcting a missing overlay-installer reference, but was superseded for
   fresh installation because auto-selection would choose systemd-boot.
5. **Custom installer base:** `installer-force-grub.patch` changes ONLY fresh
   installation bootloader selection to GRUB. Upgrade still probes the existing
   bootloader. This dedicated Quantum build is not a general-purpose or Secure
   Boot installer. It supplies installer tools, not the custom operating kernel.
6. **Corrected full installer:** same custom imager kernel/initramfs, extensions,
   firmware overlay, and UART settings, now with the GRUB-forced base.
   The operator extracted `installer-arm64.tar` and published it using skopeo.
7. **Boot-only SD and NVMe installation:** SD META had to be hidden so Talos
   would regard the boot environment as uninstalled and run the NVMe installer.
   Existing cluster identity was reused; no bootstrap was run.

The detailed kernel, package, imager, image-generation, swap, and installation
commands remain in [the build runbook](../talos/custom-rpi5/README.md).

## Published artifact inventory

Registry namespace: `registry.home.antonu.org/talos/custom-rpi5/`.
Tags identify history; digests are the authoritative build inputs.

| Artifact | Tag | Digest |
| --- | --- | --- |
| Kernel OCI index | `kernel:v1.14.2-rp1-axi1` | `sha256:9e2ffebec51e9e2e5415ecb9d40cfbb21ea2f69244436efef77f9638ddab4970` |
| Kernel ARM64 manifest (used by imager) | same tag | `sha256:4b98181fc90cda31fc763c1e8ccbb89cc37aa34030ff132ef55083c891ddc0b7` |
| Custom imager | `imager:v1.14.2-rp1-axi1` | `sha256:2f7d64b1b23560b0a6dbedcbe326ad01286735327a563ff520f6b271681c14bc` |
| First installer, superseded | `installer:v1.14.2-rp1-axi1` | `sha256:1881a7c50e7b3e07a6ecfba409fa2372610c60800863ad076909086ffaeec75d` |
| GRUB-forced installer base | `installer-base:v1.14.2-rp1-axi1-grub1` | `sha256:e2339472d224416af70ed213f527fa95be51dc304dd314a017f168acb9864e1b` |
| Installed full installer | `installer:v1.14.2-rp1-axi1-grub1` | `sha256:2c8c7da39af1b40750687b234fae81f866f5573c1cf569198cc0fb5323c8b89e` |

Shared inputs pinned in the profiles:

- Pi overlay v0.2.2: `ghcr.io/siderolabs/sbc-raspberrypi@sha256:af82d9f97241fb66c5b660b03e9154fd54ba4560b58ed3b53765bb930d564167`.
- iSCSI tools v0.2.0: `ghcr.io/siderolabs/iscsi-tools@sha256:8b0c13a73a0a82cbd7c458c170241c4bb08de3ec536d97fbde6bced24668d11e`.

The kernel OCI index includes a provenance manifest with unknown/unknown
platform. That is not another kernel architecture. Use the ARM64 manifest pin.
The custom kernel, imager, installer-base, and full installer are different
artifacts; never pass a kernel package or imager to `talosctl upgrade`.

Local historical SD archive directory:
`talos/generated/custom-rpi5/build.7qb4C2/sd.o9NZUq`.
The first successful installer archive was under `installer.VykOeh`.
The corrected installer attempt used `installer-grub.ylqPpU`; its first publish
attempt failed because the inner tar had not been extracted. Shell variables
are session-local; an old value must not be assumed to identify a current file.

## Missing recipe detail: installer-base build and archive promotion

The following is a reconstruction from the pinned Makefile and checked-in
patches, not a claim that the literal shell transcript was retained.
OPERATOR-RUN ONLY; do not run now or overwrite existing tags. For a future
rebuild, use a new isolated checkout/output revision and review its diff.

In the pinned Talos checkout, `talos-arm64-kernel.patch` was already applied.
The additional installer change was:

```sh
git -C "$CUSTOM_BUILD_DIR/talos" apply --check \
  "$PWD/talos/custom-rpi5/installer-force-grub.patch"
git -C "$CUSTOM_BUILD_DIR/talos" apply \
  "$PWD/talos/custom-rpi5/installer-force-grub.patch"
```

Equivalent ARM64 installer-base build settings (publishes a registry image):

```sh
gmake -C "$CUSTOM_BUILD_DIR/talos" installer-base \
  ARCH=arm64 PLATFORM=linux/arm64 INSTALLER_ARCH=targetarch \
  TAG=v1.14.2 IMAGE_TAG_OUT=v1.14.2-rp1-axi1-grub1 \
  IMAGE_REGISTRY=registry.home.antonu.org USERNAME=talos/custom-rpi5 \
  PKG_KERNEL=registry.home.antonu.org/talos/custom-rpi5/kernel@sha256:4b98181fc90cda31fc763c1e8ccbb89cc37aa34030ff132ef55083c891ddc0b7 \
  PUSH=true BUILD='docker buildx build --builder talos-rpi5'
```

Its resulting digest was inserted into `input.baseInstaller.imageRef` in
`installer.yaml`. Both `input.overlayInstaller.imageRef` and
`overlay.image.imageRef` must be set. Assembly with the already-published custom
imager does not require rebuilding the kernel or imager just to change the base.

After successful assembly and review of the outer archive listing:

```sh
tar -xzf "$INSTALLER_ARTIFACT_DIR/artifacts.tar.gz" \
  -C "$INSTALLER_ARTIFACT_DIR" installer-arm64.tar
skopeo copy \
  "docker-archive:$INSTALLER_ARTIFACT_DIR/installer-arm64.tar" \
  "docker://$INSTALLER_IMAGE"
skopeo inspect --format 'arch={{.Architecture}} digest={{.Digest}}' \
  "docker://$INSTALLER_IMAGE"
```

The outer gzip archive contains a Docker archive; it is not itself the image
to push. A digest printed by a local build is not proof that a different target
tag was pushed. Registry publication was confirmed for the final digest above.

## Failures and workarounds encountered

| Failure / symptom | Finding or workaround |
| --- | --- |
| No ttyAMA0 on stock Talos | Firmware settings alone were insufficient; custom PL011 AXI driver backport registered it. |
| No Buildx plugin initially | Homebrew docker-buildx, client plugin link, existing Lima context and a named ARM64 builder. |
| `git status --short~` error | Accidental extra character, not a source/build failure. |
| macOS `make`: missing separator, line 156 | Use Homebrew GNU Make (`gmake`), not Apple's older make. |
| BTFIDS / invalid BTF, final build `cannot allocate memory` | OOM during pahole on 8 GiB Lima; an operator-created 8 GiB temporary swap file allowed compilation. BTF was retained. |
| AMD64 stage tries custom ARM64-only package | Pin the AMD64 kernel stage to `ghcr.io/siderolabs/kernel:v1.14.0-37-g6c312e4`. |
| macOS FAT partition won't mount, even read-only | fsck read-only reported FSInfo free-space mismatch; no successful direct-mount repair established. Workaround used raw-image manipulation. |
| Installer `error pulling image : parsing reference ""` | Missing explicit `input.overlayInstaller.imageRef`; corrected profile and new artifact directory. |
| Pi 4 upgrade fails creating efivarfs writer | Separate worker-02 event. Pi 5 boot reports EFI v2.11 by Das U-Boot; this motivated avoiding fresh sd-boot, not proof of the same Pi 5 failure. |
| SD image says installed; NVMe install skipped | SD META was ready, so installed-state gate skipped unattended installation. Changing disk selector alone did not migrate it. |
| `gpt label ... operation not permitted` on Mac | Relabel META in a regular-file image copy using sgdisk, then operator rewrites the SD. No SIP bypass. |
| Registry tag `manifest unknown` | Expected new tag had not actually been published. |
| skopeo source archive missing | Extract `installer-arm64.tar` from the outer `artifacts.tar.gz` first. |
| Talos ls/read rejects `--insecure` | These commands do not support maintenance-mode insecure access; use supported get/dmesg, then authenticated diagnostics after joining. |
| NVMe-only boot stays at U-Boot logo | Unresolved. File presence and working Linux NVMe access do not prove bootloader NVMe access. |
| Space cannot open U-Boot prompt | Could be unavailable keyboard/console or early stall; no specific cause proven. |

Lima swap path: `/var/lib/talos-rpi5-build.swap`, 8 GiB, activated manually,
not added to fstab. Do not delete it while active. Its latest activation status
is unknown; do not recreate over it or assume reboot preserved activation.

## Boot-only SD and the installation actually performed

Raw Talos SD images have EFI p1, BIOS p2, BOOT p3, META p4. Talos recognized SD
META and initially chose mmcblk0 as the system disk. To permit fresh NVMe
installation, the operator kept the original compressed artifact, decompressed
a separate regular-file copy, relabeled partition 4 to `SD-BOOT-META` with
`sgdisk --change-name=4:SD-BOOT-META`, and rewrote the SD from that copy.

**DESTRUCTIVE historical step:** SD rewrite erased the then-verified external
63.9 GB disk4. Never reuse that device identifier without checking the current
physical disk. No flash command is provided here as an automatic recovery step.
After boot, maintenance get showed no system disk and META phase missing.

The generated worker configuration reused existing home-cloud identity, Talos
1.14.2, Kubernetes 1.37.1, Cilium patch, worker-03 hostname/labels, and the
UnattendedInstallConfig from `worker-03-install.yaml`. The selector required
both NVMe device path and serial; `wipe: true` was explicit.

**DESTRUCTIVE historical step:** the operator applied that configuration and
overwrote Quantum's old NVMe OS/data. Do not repeat it. The installed state was:

```text
SystemDisk: diskID=nvme0n1, devPath=/dev/nvme0n1
META: phase=ready, location=/dev/nvme0n1p4, size=1048576
META partition UUID: 6e27f91d-a680-4620-856d-fc69c3257389
Node: talos-worker-03 Ready, 192.168.40.42
OS: Talos v1.14.2; kernel 6.18.54-talos; Kubernetes v1.37.1
Container runtime: containerd 2.3.6
```

NVMe-only cold boot failed. SD reinsertion worked. The old Pi OS recovery route
is no longer available on that overwritten disk; it requires an independent
backup/reinstallation, not removing the SD.

## Read-only diagnostic pod evidence

Temporary pod `deconz/quantum-boot-diag`, `alpine:3.22.1`, privileged, pinned
with `nodeName: talos-worker-03`, no service-account token, one-hour deadline.
The existing deconz namespace permits privileged containers. Explicit hostPath
BlockDevice mounts exposed SD/NVMe EFI p1 read-only. Privilege is powerful;
read-only filesystem options constrain these diagnostics, not all possible
commands a privileged pod could run. Mount propagation was left private.

EFI partitions mounted VFAT with `ro,nosuid,nodev,noexec`. BOOT partitions p3
were available under /dev in the privileged pod and mounted XFS with
`ro,norecovery,nouuid,nosuid,nodev,noexec`; norecovery avoids journal replay.
No filesystem repair, journal recovery, write mount, or file replacement was
performed by the supplied diagnostic scripts. BOOT mounts were unmounted on
script exit. The pod deletion instructions were supplied, not confirmed run.

Observed comparison:

| File / property | NVMe | SD |
| --- | --- | --- |
| Firmware config | Same displayed contents: u-boot.bin, ARM64, Pi 5 UART setting, GPIO UART overlay | Same |
| u-boot.bin SHA-256 | `e9531bed2632eabb7afe0e6cdeb0512ff782a4ed8dbd06ce38a9ca0626bb5405` | Identical; cmp confirmed |
| EFI boot executable | `EFI/BOOT/BOOTAA64.EFI` | `EFI/boot/BOOTAA64.efi` |
| EFI executable SHA-256 | `e255ae228ed133347cc582ab963b1d0ad21afdcea19ac5a8c6ac6907a52b2712` | `297eb569dbafcb6b3f69eeaf46524379fbb5026c281ea93906ff28a1ac7547c9` |
| Kernel/initramfs | `/A/vmlinuz`, `/A/initramfs.xz` exist on BOOT | Same paths exist |
| GRUB configuration | `/grub/grub.cfg`, matching displayed contents | Same |
| ubootefi.var | Not listed | Present on EFI |

Different EFI hashes are not evidence of corruption: SD image generation and
fresh grub installation take different build paths. FAT path case differences
do not by themselves explain failure. No SD/NVMe kernel or initramfs byte-level
comparison was recorded. The significance of ubootefi.var was not established;
do not copy EFI variables blindly.

GRUB default: `A - Talos v1.14.2`, timeout 3 seconds, console input/output,
`linux /A/vmlinuz` with the expected Talos args and only `console=tty0`, followed
by `initrd /A/initramfs.xz`. The separate reset entry adds
`talos.experimental.wipe=system:EPHEMERAL,STATE`; NEVER select it for diagnostics.
The initial EFI-only diagnostic missed grub.cfg because it lives on XFS BOOT.
Talos `ls /boot --depth 2` showed only `.` and `EFI`; it did not establish that
installed boot assets were absent.

These findings rule out obvious missing files/config paths, NOT an early U-Boot
stall, PCIe/NVMe support problem, EFI handoff problem, or damaged executable.
Linux detecting NVMe after SD boot does not prove U-Boot can enumerate it.

## Unexecuted next proposal: separate U-Boot experiment

Research only; no result or spare-card image was reported. No debug adapter is
available. HDMI displayed only the U-Boot logo; Space did not reach a shell.
Proposed U-Boot shell diagnostics (`version`, `nvme scan`, `nvme info`,
`part list nvme 0`, `fatls nvme 0:1 /EFI/BOOT`) were not run.

[Siderolabs issue 81](https://github.com/siderolabs/sbc-raspberrypi/issues/81)
reports Pi 5 NVMe work. [PR 88](https://github.com/siderolabs/sbc-raspberrypi/pull/88)
was open when inspected on 2026-10-06. Proposed candidate:

- Repo: `https://github.com/sidero-community/sbc-raspberrypi.git`.
- Revision: `9abca1be155611111be455ce4c10bc98ebf49108`.
- U-Boot source version: 2026.01, SHA-256
  `b60d5865cefdbc75da8da4156c56c458e00de75a49b80c1a2e58a96e30ad0d54`.
- Its patch series adds BCM2712, PCIe/RP1, clocks/GPIO/network/DMA support,
  enables NVMe/EFI, adds preboot NVMe scan, and disables EFI boot-manager code
  with a reported low-memory reservation conflict. These are candidate changes,
  not a demonstrated explanation or fix for this board.
- The suggested local build was `gmake ... local-u-boot PLATFORM=linux/arm64
  PUSH=false BUILD='docker buildx build --builder talos-rpi5' DEST=...`, in a new
  isolated checkout. Commands were supplied, but build completion is unknown.
- The working SD was to remain untouched; a spare SD test was proposed before
  any NVMe change. No card-write recipe or successful boot test was reached.

Do not blindly flash the Tinkerbell v2026.04-rc1.5 release linked from issue 81:
the issue claims Pi 5 use, while the release describes Pi 4/Pi 400 targets.
Compatibility and artifact provenance require review before use.

If work is explicitly resumed: confirm node/SD state, preserve recovery media,
inspect any already-started candidate checkout instead of overwriting it, and
agree the experimental scope before builds or media writes. Do not reuse the
NVMe wipe patch, replace just the operating kernel, or assume a stock Talos
upgrade preserves AXI support. A tested U-Boot change would also need to be
integrated into the overlay/installer lineage for future maintenance.

## Files to preserve and future maintenance risk

- `talos/custom-rpi5/`: helper, kernel Dockerfile, Talos Dockerfile patch,
  fresh-install GRUB patch, SD/imager profiles and detailed recipes.
- `talos/patches/worker-03.yaml` and `worker-03-install.yaml`: preserve user
  changes; the latter is explicitly destructive fresh-install configuration.
- `talos/image-factory/schematic-rpi5-raspbee.{yaml,id}`: firmware/extension
  customization reference, NOT a substitute for the custom AXI kernel build.
- Ignored generated build outputs and original SD artifact; preserve needed
  exports separately. They will not be backed up by committing documentation.
- Existing cluster identity/client configs: private, independent secure backup;
  never paste them or commit them with this public provenance record.

Stock upgrades can remove the custom driver. Future maintenance needs a reviewed
rebase, kernel and matching initramfs/modules, extension checks, installer
bootloader compatibility, and UART/radio/boot acceptance. Do not infer production
readiness from a successful compile, registry push, node Ready, or ttyAMA0 alone.
