# RouterOS-native PXE bootstrap for VLAN 400 / 192.168.40.0/24
#
# Prerequisite: upload the files from mikrotik/pxe/files/ to flash/pxe/
# and verify their paths with /file print where name~"pxe".
# If this router has no flash directory, adjust real-filename to the persistent
# path shown by /file print before importing this file.

/ip tftp settings
set max-block-size=1468

/ip tftp
add allow=yes comment="PXE x86-64 UEFI bootstrap" \
    ip-address=192.168.40.0/24 read-only=yes \
    real-filename=/flash/pxe/snponly-x86_64.efi \
    req-filename="(snponly-x86_64[.]efi)|(/snponly-x86_64[.]efi)"
add allow=yes comment="PXE iPXE automatic startup" \
    ip-address=192.168.40.0/24 read-only=yes \
    real-filename=/flash/pxe/autoexec.ipxe \
    req-filename="(autoexec[.]ipxe)|(/autoexec[.]ipxe)"
add allow=yes comment="PXE home-cloud boot menu" \
    ip-address=192.168.40.0/24 read-only=yes \
    real-filename=/flash/pxe/boot.ipxe \
    req-filename="(boot[.]ipxe)|(/boot[.]ipxe)"

/ip dhcp-server network
set [find where address="192.168.40.0/24"] \
    next-server=192.168.40.1 \
    boot-file-name=snponly-x86_64.efi
