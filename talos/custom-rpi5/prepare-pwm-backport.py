#!/usr/bin/env python3
"""Prepare a pinned GPL-2.0 RP1 PWM backport; default is read-only.

Fetches/checks public source and generates a patch in memory. Only an explicit
--pkgs-dir writes a new patch into the operator's existing pinned checkout.
Does not build, change kernel config, contact a cluster, or push an image.
"""

import argparse
import difflib
import hashlib
import pathlib
import subprocess
import urllib.request

PKGS_COMMIT = "6c312e4b77817a9c1bd4975a532b3fd23d33430c"
PL011_SHA256 = "b4dad001ddc873347ddf2bbc3458aafdbabf11d2f07fbfce9bf2a5e6662e42dd"
LINUX = "https://raw.githubusercontent.com/gregkh/linux/v6.18.54"
RPI = "https://raw.githubusercontent.com/raspberrypi/linux/60ea684a8ace97bb0db1a16e20753bdd6ab371ff"
SOURCES = {
    "kconfig": (f"{LINUX}/drivers/pwm/Kconfig", "a6c9324b756b5c313084db2445e50af061c37c56aecb9c4d9e5025c206be5dfa"),
    "makefile": (f"{LINUX}/drivers/pwm/Makefile", "7e3efd2b018bddacbfd9d77fb551438b21f463f47ff494a6d5ca14f69bb0b42a"),
    "driver": (f"{RPI}/drivers/pwm/pwm-rp1.c", "d82b44834f624c6c3df52fdec44ab434168c4118efa43ca66c11d44cf1654841"),
}


def fetch(label):
    url, expected = SOURCES[label]
    with urllib.request.urlopen(url, timeout=30) as response:
        data = response.read()
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected:
        raise ValueError(f"{label}: unexpected source checksum {actual}")
    return data.decode()


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Expected exactly one source marker: {old!r}")
    return text.replace(old, new, 1)


def adapt_driver(driver):
    # Both clock enable and PWM registration are devm-managed. The donor's
    # explicit disable duplicates managed cleanup; its remove callback also
    # reads platform drvdata that the probe never sets. Let devres release the
    # PWM chip before disabling its earlier-acquired clock, including failures.
    driver = replace_once(driver, "\tint ret;\n", "")
    start = "\tret = devm_pwmchip_add(&pdev->dev, chip);\n"
    end = "static const struct of_device_id rp1_pwm_of_match[] = {\n"
    if driver.count(start) != 1 or driver.count(end) != 1:
        raise ValueError("Donor probe/remove structure changed")
    begin, finish = driver.index(start), driver.index(end)
    driver = driver[:begin] + "\treturn devm_pwmchip_add(&pdev->dev, chip);\n}\n\n" + driver[finish:]
    driver = replace_once(driver, "\t.remove = rp1_pwm_remove,\n", "")
    if "clk_disable_unprepare" in driver or "platform_get_drvdata" in driver:
        raise ValueError("Unmanaged cleanup remains")
    return driver


def unified(old, new, path):
    return "".join(difflib.unified_diff(
        old.splitlines(keepends=True), new.splitlines(keepends=True),
        fromfile=f"a/{path}" if old else "/dev/null", tofile=f"b/{path}",
    ))


def generate_patch():
    kconfig = fetch("kconfig")
    makefile = fetch("makefile")
    driver = adapt_driver(fetch("driver"))
    addition = (
        'config PWM_RP1\n\ttristate "RP1 PWM support"\n'
        '\tdepends on ARCH_BCM2835 || COMPILE_TEST\n'
        '\tdepends on HAS_IOMEM && COMMON_CLK && OF\n'
        '\thelp\n\t  PWM framework driver for Raspberry Pi RP1 controller.\n'
        '\t  The module will be called pwm-rp1.\n\n'
    )
    new_kconfig = replace_once(kconfig, "config PWM_ROCKCHIP\n", addition + "config PWM_ROCKCHIP\n")
    marker = "obj-$(CONFIG_PWM_ROCKCHIP)\t+= pwm-rockchip.o\n"
    new_makefile = replace_once(makefile, marker, "obj-$(CONFIG_PWM_RP1)\t\t+= pwm-rp1.o\n" + marker)
    return (
        unified(kconfig, new_kconfig, "drivers/pwm/Kconfig")
        + unified(makefile, new_makefile, "drivers/pwm/Makefile")
        + unified("", driver, "drivers/pwm/pwm-rp1.c")
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pkgs-dir", type=pathlib.Path, help="Explicitly create the PWM patch in the existing pinned PL011 checkout")
    args = parser.parse_args()
    patch = generate_patch()
    digest = hashlib.sha256(patch.encode()).hexdigest()
    print(f"RP1 PWM source checksums and insertion points OK; patch_sha256={digest}")
    if args.pkgs_dir is None:
        # Parse the diff without applying it or creating a source tree.
        subprocess.run(["git", "apply", "--numstat", "-"], input=patch, text=True, check=True)
        print("Read-only check: no files written; compilation and fan operation NOT tested")
        return
    checkout = args.pkgs_dir.resolve(strict=True)
    commit = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
    if commit != PKGS_COMMIT:
        raise ValueError(f"Wrong pkgs commit: {commit}")
    pl011 = checkout / "kernel/build/patches/0019-serial-pl011-add-rpi5-axi.patch"
    if hashlib.sha256(pl011.read_bytes()).hexdigest() != PL011_SHA256:
        raise ValueError("Existing PL011 backport is absent or differs; preserve UART support")
    target = pl011.with_name("0020-pwm-add-rp1.patch")
    with target.open("x") as output:
        output.write(patch)
    print(f"Prepared {target}; config change and build remain operator-run")


if __name__ == "__main__":
    main()
