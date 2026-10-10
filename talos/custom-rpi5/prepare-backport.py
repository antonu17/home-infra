#!/usr/bin/env python3
"""Generate a minimal GPL-2.0 PL011 AXI backport; default is read-only check.

Driver code is extracted from the Raspberry Pi Linux project, not reimplemented.
No Docker, registry, disk, or remote configuration commands are run here.
"""

import argparse
import difflib
import hashlib
import pathlib
import subprocess
import urllib.request

PKGS_COMMIT = "6c312e4b77817a9c1bd4975a532b3fd23d33430c"
SOURCES = {
    "upstream": (
        "https://raw.githubusercontent.com/gregkh/linux/v6.18.54/drivers/tty/serial/amba-pl011.c",
        "89a2cd4c993c185a25c64fb78484d1aea285e2a637178f5bca3ef15ac5ab01e6",
    ),
    "raspberrypi": (
        "https://raw.githubusercontent.com/raspberrypi/linux/60ea684a8ace97bb0db1a16e20753bdd6ab371ff/drivers/tty/serial/amba-pl011.c",
        "a0dfa8a116ef30253cc77cce7b3fec8a7c12c86ff5a9bcfdacce8fcaa095c976",
    ),
}


def fetch(label):
    url, expected = SOURCES[label]
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read()
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected:
        raise ValueError(f"{label}: unexpected source checksum {actual}")
    return data.decode()


def section(text, start, end):
    if text.count(start) != 1 or text.count(end) != 1:
        raise ValueError("Source structure changed; review the backport")
    return text[text.index(start):text.index(end)]


def insert_before(text, marker, addition):
    if text.count(marker) != 1:
        raise ValueError(f"Expected one insertion point: {marker!r}")
    return text.replace(marker, addition + marker, 1)


def generate_patch():
    upstream = fetch("upstream")
    downstream = fetch("raspberrypi")
    vendor_marker = "#ifdef CONFIG_ACPI_SPCR_TABLE\nstatic const struct vendor_data vendor_qdt"
    vendor = section(downstream, "static struct vendor_data vendor_arm_axi = {", vendor_marker)
    driver = section(downstream, "static int pl011_axi_probe(", "static const struct amba_id pl011_ids[] = {")
    # Verify every existing helper used by the transplanted probe is available.
    for helper in (
        "pl011_find_free_port", "pl011_setup_port", "pl011_register_port",
        "pl011_unregister_port", "pl011_trigger_start_tx", "pl011_trigger_stop_tx",
        "pl011_rs485_config", "pl011_rs485_supported", "pl011_dev_pm_ops",
        "cts_event_workaround", "hrtimer_setup",
    ):
        if helper not in upstream:
            raise ValueError(f"Missing upstream helper/member: {helper}")
    modified = insert_before(upstream, vendor_marker, vendor)
    modified = insert_before(modified, "static const struct amba_id pl011_ids[] = {", driver)
    modified = insert_before(
        modified, "\treturn amba_driver_register(&pl011_driver);",
        '\tif (platform_driver_register(&pl011_axi_platform_driver))\n'
        '\t\tpr_warn("could not register PL011 AXI platform driver\\n");\n',
    )
    modified = insert_before(
        modified, "\tamba_driver_unregister(&pl011_driver);",
        "\tplatform_driver_unregister(&pl011_axi_platform_driver);\n",
    )
    patch = "".join(difflib.unified_diff(
        upstream.splitlines(keepends=True), modified.splitlines(keepends=True),
        fromfile="a/drivers/tty/serial/amba-pl011.c",
        tofile="b/drivers/tty/serial/amba-pl011.c",
    ))
    return patch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pkgs-dir", type=pathlib.Path, help="Explicitly write the patch into a dedicated pinned pkgs checkout")
    args = parser.parse_args()
    patch = generate_patch()
    digest = hashlib.sha256(patch.encode()).hexdigest()
    print(f"source checksums and insertion points OK; patch_sha256={digest}")
    if args.pkgs_dir is None:
        print("Read-only check: no files written; compilation and hardware NOT tested")
        return
    checkout = args.pkgs_dir.resolve(strict=True)
    commit = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
    if commit != PKGS_COMMIT:
        raise ValueError(f"Wrong pkgs commit: {commit}")
    target = checkout / "kernel/build/patches/0019-serial-pl011-add-rpi5-axi.patch"
    if not target.parent.is_dir():
        raise ValueError("Not a pkgs kernel patch directory")
    # Never silently replace a patch in the operator's checkout.
    with target.open("x") as output:
        output.write(patch)
    print(f"Prepared {target}; build remains operator-run")


if __name__ == "__main__":
    main()
