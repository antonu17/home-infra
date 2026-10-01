# 2026-09-29 07:27:44 by RouterOS 7.24.4
# software id = 13VH-LBNR
#
# model = RB5009UPr+S+
# serial number = HH50ABVE5W8
/interface bridge
add admin-mac=F4:1E:57:51:95:74 auto-mac=no comment=defconf frame-types=\
    admit-only-vlan-tagged name=bridge protocol-mode=none vlan-filtering=yes
/interface ethernet
set [ find default-name=ether1 ] comment=syno-lag1 l2mtu=1514
set [ find default-name=ether2 ] comment=syno-lag2 l2mtu=1514
set [ find default-name=ether3 ] comment=tv l2mtu=1514
set [ find default-name=ether4 ] comment=denis l2mtu=1514
set [ find default-name=ether5 ] comment=pihole l2mtu=1514
set [ find default-name=ether6 ] comment=hass l2mtu=1514
set [ find default-name=ether7 ] comment=aruba l2mtu=1514
set [ find default-name=ether8 ] comment=anton l2mtu=1514 loop-protect=off
set [ find default-name=sfp-sfpplus1 ] l2mtu=1514
/interface vlan
add interface=bridge name=vlan1-mgmt vlan-id=1
add interface=bridge name=vlan100-trusted vlan-id=100
add interface=bridge name=vlan200-guest vlan-id=200
/interface bonding
add comment=pulsar mode=802.3ad name=syno1 slaves=ether1,ether2
/interface list
add comment=defconf name=WAN
add comment=defconf name=LAN
/ip pool
add name=dhcp_pool1 ranges=192.168.100.50-192.168.100.254
add name=dhcp_pool2 ranges=192.168.200.2-192.168.200.254
/ip dhcp-server
add address-pool=dhcp_pool1 interface=vlan100-trusted name=dhcp1
add address-pool=dhcp_pool2 interface=vlan200-guest name=dhcp2
/disk settings
set auto-media-interface=bridge auto-media-sharing=yes auto-smb-sharing=yes
/interface bridge port
add bridge=bridge comment=tv frame-types=\
    admit-only-untagged-and-priority-tagged interface=ether3 pvid=100
add bridge=bridge comment=denis frame-types=\
    admit-only-untagged-and-priority-tagged interface=ether4 pvid=100
add bridge=bridge comment=dns-pi frame-types=\
    admit-only-untagged-and-priority-tagged interface=ether5 pvid=100
add bridge=bridge comment=hass frame-types=\
    admit-only-untagged-and-priority-tagged interface=ether6 pvid=100
add bridge=bridge comment=aruba interface=ether7
add bridge=bridge frame-types=admit-only-untagged-and-priority-tagged \
    interface=syno1 pvid=100
add bridge=bridge comment=anton interface=ether8 pvid=100
/ip neighbor discovery-settings
set discover-interface-list=LAN
/interface bridge vlan
add bridge=bridge comment=aruba tagged=ether7 vlan-ids=100,200
/interface list member
add interface=bridge list=LAN
add interface=ether8 list=WAN
add interface=vlan100-trusted list=LAN
add interface=vlan200-guest list=LAN
add interface=sfp-sfpplus1 list=WAN
/interface ovpn-server server
add mac-address=FE:DB:2E:1D:C5:2C name=ovpn-server1
/ip address
add address=192.168.88.1/24 comment=defconf interface=vlan1-mgmt network=\
    192.168.88.0
add address=192.168.100.1/24 interface=vlan100-trusted network=192.168.100.0
add address=192.168.200.1/24 interface=vlan200-guest network=192.168.200.0
/ip dhcp-client
add interface=sfp-sfpplus1 name=sfp-sfpplus1 use-peer-dns=no
/ip dhcp-server lease
add address=192.168.100.26 client-id=1:40:23:43:d9:f3:90 mac-address=\
    40:23:43:D9:F3:90 server=dhcp1
/ip dhcp-server network
add address=192.168.100.0/24 dns-server=192.168.100.2 gateway=192.168.100.1
add address=192.168.200.0/24 dns-server=192.168.200.1 gateway=192.168.200.1
/ip dns
set allow-remote-requests=yes servers=1.1.1.1
/ip dns static
add address=192.168.88.1 comment=defconf name=router.lan type=A
add address=192.168.100.5 name=pulsar.antonu.org type=A
add address=192.168.88.1 name=router.home.antonu.org type=A
/ip firewall filter
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMP" protocol=icmp
add action=accept chain=input comment=\
    "defconf: accept to local loopback (for CAPsMAN)" dst-address=127.0.0.1
add action=drop chain=input comment="defconf: drop all not coming from LAN" \
    in-interface-list=!LAN
add action=accept chain=forward comment="defconf: accept in ipsec policy" \
    ipsec-policy=in,ipsec
add action=accept chain=forward comment="defconf: accept out ipsec policy" \
    ipsec-policy=out,ipsec
add action=fasttrack-connection chain=forward comment="defconf: fasttrack" \
    connection-state=established,related
add action=accept chain=forward comment=\
    "defconf: accept established,related, untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid
add action=drop chain=forward comment=\
    "defconf: drop all from WAN not DSTNATed" connection-nat-state=!dstnat \
    connection-state=new in-interface-list=WAN
/ip firewall nat
add action=masquerade chain=srcnat comment="defconf: masquerade" \
    ipsec-policy=out,none out-interface-list=WAN
/ip ipsec profile
set [ find default=yes ] dpd-interval=2m dpd-maximum-failures=5
/ipv6 address
add address=2a02:8109:8380:9002::1 comment="VLAN100 gateway v6" interface=\
    vlan100-trusted
/ipv6 dhcp-client
add add-default-route=yes interface=sfp-sfpplus1 pool-name=vodafone request=\
    address,prefix use-peer-dns=no
/ipv6 firewall address-list
add address=::/128 comment="defconf: unspecified address" list=bad_ipv6
add address=::1/128 comment="defconf: lo" list=bad_ipv6
add address=fec0::/10 comment="defconf: site-local" list=bad_ipv6
add address=::ffff:0.0.0.0/96 comment="defconf: ipv4-mapped" list=bad_ipv6
add address=::/96 comment="defconf: ipv4 compat" list=bad_ipv6
add address=100::/64 comment="defconf: discard only " list=bad_ipv6
add address=2001:db8::/32 comment="defconf: documentation" list=bad_ipv6
add address=2001:10::/28 comment="defconf: ORCHID" list=bad_ipv6
add address=3ffe::/16 comment="defconf: 6bone" list=bad_ipv6
/ipv6 firewall filter
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=input comment="defconf: accept UDP traceroute" \
    dst-port=33434-33534 protocol=udp
add action=accept chain=input comment=\
    "defconf: accept DHCPv6-Client prefix delegation." dst-port=546 protocol=\
    udp src-address=fe80::/10
add action=accept chain=input comment="defconf: accept IKE" dst-port=500,4500 \
    protocol=udp
add action=accept chain=input comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=input comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=input comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=input comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN
add action=accept chain=forward comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=accept chain=forward disabled=yes dst-address=\
    2a02:8109:8380:9002::10/128 dst-port=443 protocol=tcp
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid
add action=drop chain=forward comment=\
    "defconf: drop packets with bad src ipv6" src-address-list=bad_ipv6
add action=drop chain=forward comment=\
    "defconf: drop packets with bad dst ipv6" dst-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: rfc4890 drop hop-limit=1" \
    hop-limit=equal:1 protocol=icmpv6
add action=accept chain=forward comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=forward comment="defconf: accept HIP" protocol=139
add action=accept chain=forward comment="defconf: accept IKE" dst-port=\
    500,4500 protocol=udp
add action=accept chain=forward comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=forward comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=forward comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=forward comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN
/ipv6 nd
# automatic dns option advertising is not started, re-apply dns config
add advertise-dns=yes interface=vlan100-trusted ra-interval=20s-1m
add disabled=yes interface=vlan1-mgmt
add disabled=yes interface=vlan200-guest
/system scheduler
add !days disabled=yes interval=1s name=schedule1 on-event=asdf policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=2024-11-30 start-time=19:54:07
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
/tool sniffer
set filter-interface=sfp-sfpplus1 filter-ipv6-address=\
    2a02:8109:8380:9002::1/128,2a02:8109:8380:9002::10/128
