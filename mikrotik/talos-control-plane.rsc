# First Talos control-plane reservation and Kubernetes API VIP name.
# Review the matching lease before importing this configuration.

/ip dhcp-server lease
make-static [find where server="dhcp400-home-cloud" mac-address="02:11:32:28:5A:95"]
set [find where server="dhcp400-home-cloud" mac-address="02:11:32:28:5A:95"] \
    address=192.168.40.21 comment="talos-cp-01"
make-static [find where server="dhcp400-home-cloud" mac-address="02:11:32:25:8E:20"]
set [find where server="dhcp400-home-cloud" mac-address="02:11:32:25:8E:20"] \
    address=192.168.40.22 comment="talos-cp-02"
make-static [find where server="dhcp400-home-cloud" mac-address="02:11:32:22:49:65"]
set [find where server="dhcp400-home-cloud" mac-address="02:11:32:22:49:65"] \
    address=192.168.40.23 comment="talos-cp-03"

/ip dns static
add address=192.168.40.20 comment="Talos Kubernetes API VIP" \
    name=k8s.home.antonu.org type=A
