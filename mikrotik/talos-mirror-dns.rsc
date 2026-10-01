# DNS record for the Synology-hosted Talos asset mirror.
# Review existing records before adding this entry.

/ip dns static
add address=192.168.100.5 comment="Synology Talos mirror" \
    name=talos.home.antonu.org type=A
