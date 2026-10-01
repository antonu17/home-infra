# Talos home-cloud cluster

## Addressing

| Purpose | Address | MAC address |
| --- | --- | --- |
| Kubernetes API virtual IP | `192.168.40.20` (`k8s.home.antonu.org`) | Shared by the active control plane |
| `talos-cp-01` | `192.168.40.21` | `02:11:32:28:5A:95` |
| `talos-cp-02` | `192.168.40.22` | `02:11:32:25:8E:20` |
| `talos-cp-03` | `192.168.40.23` | `02:11:32:22:49:65` |

All three control-plane VMs have 2 vCPUs, 4 GiB RAM, interface `ens3`, and a
34 GB `/dev/sda` Talos installation disk. RouterOS remains the DHCP authority
and supplies DNS to VLAN 400. Each VM obtains its node address from a static
DHCP reservation.

The three-node etcd quorum and Kubernetes control plane are operational. The
Git-ignored `talosconfig` is configured with `.21`, `.22`, and `.23` as Talos
API endpoints. `k8s.home.antonu.org` points clients at the shared `.20` API VIP.

Trusted VLAN 100 clients use Pi-hole at `192.168.100.2`, not RouterOS, as their
DNS resolver. Add the following Pi-hole local DNS record as well as the RouterOS
record stored in `mikrotik/talos-control-plane.rsc`:

```text
k8s.home.antonu.org  192.168.40.20
```

Both records are required: Talos nodes resolve the name through `192.168.40.1`,
while administration workstations resolve it through Pi-hole.

## Configuration files

`talos/patches/cp-01.yaml` is safe to commit and adds the layer-2 API VIP to
the discovered `ens3` interface. The `hostname-cp-*.yaml` patches use the Talos
1.14 `HostnameConfig` document with automatic naming disabled, producing the
Kubernetes node names `talos-cp-01`, `talos-cp-02`, and `talos-cp-03`.
Generated files under `talos/generated/` contain cluster CA private keys,
client credentials, and bootstrap secrets. They are excluded from Git and must
be backed up securely.

Generate the initial configuration with the project-pinned `talosctl`:

```sh
mkdir -p talos/generated/home-cloud
talosctl gen config home-cloud https://k8s.home.antonu.org:6443 \
  --output talos/generated/home-cloud \
  --install-disk /dev/sda \
  --config-patch-control-plane @talos/patches/cp-01.yaml \
  --with-docs=false \
  --with-examples=false
```

The generated installer reference is versioned and still fetched from the
Talos Image Factory during installation. The local Synology HTTP mirror serves
the PXE kernel and initramfs; it is not yet an OCI registry mirror.
