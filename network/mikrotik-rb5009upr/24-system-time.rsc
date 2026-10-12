# RouterOS owns the host clock shared by containers.
# Cloudflare anycast NTP addresses avoid a DNS dependency during startup.
/system clock set time-zone-autodetect=no time-zone-name=Europe/Berlin
/system ntp client set enabled=yes mode=unicast vrf=main servers=162.159.200.1,162.159.200.123
# No NTP server or container UDP123 firewall exception is enabled here.
