# deCONZ and RaspBee II

This package prepares a fresh deCONZ/Phoscon deployment. It deliberately does
not migrate `/home/anton/quantum-infra/deconz`: the operator-created Phoscon
backup is the application-level migration artifact and will be restored through
the Phoscon UI.

The source container was inspected read-only on 2026-10-05. It used
`deconzcommunity/deconz`, reported deCONZ `2.29.1`, exposed ports `8080` and
`8443`, mounted `/opt/deCONZ`, and passed only `/dev/ttyAMA0`. The Kubernetes
deployment pins `2.29.1` for the initial restore instead of changing deCONZ
versions during migration.

## Desired state

- `deconz-data` is a retained 5 GiB `ReadWriteOnce` PVC from `synology-block`.
- `/opt/deCONZ` is backed by that PVC from the first start.
- The pod requires both `hardware.home.antonu.org/raspbee2=true` and
  `storage.home.antonu.org/synology-iscsi=true`.
- `/dev/ttyAMA0` is mounted from the node as a character device.
- The container is privileged because a plain Kubernetes `hostPath` does not
  provide Docker Compose's `devices` cgroup grant.
- The Deployment runs one replica. Its node affinity and character-device mount
  require the node label and UART to be available before it can start.

The PVC, PV and Synology LUN are not independent backups. Keep the exported
Phoscon backup outside the Synology failure domain. Keep the old Raspberry Pi,
container and data directory intact until the restored network is accepted.

## 1. Prepare the Talos node

The RaspBee II is a GPIO HAT, not a hot-pluggable USB dongle. Its UART must not
be used by the Talos serial console. The repository contains the dedicated
`talos/image-factory/schematic-rpi4-raspbee.yaml` schematic, which removes
serial console arguments and keeps `console=tty0`. Its recorded schematic ID is
in `schematic-rpi4-raspbee.id`.

Before moving the hardware, promote the arm64 installer and perform a normal
Talos image upgrade of **talos-worker-02 (`192.168.40.41`)**. This is a live node
upgrade and reboot, not a reinstall or disk wipe:

```sh
SCHEMATIC=$(tr -d '\r\n' < talos/image-factory/schematic-rpi4-raspbee.id)
TALOS_VERSION=v1.14.2
ARCHIVE="talos/generated/artifacts/installer-arm64-${SCHEMATIC}-${TALOS_VERSION}.tar"
INSTALLER="registry.home.antonu.org/talos/metal-installer/${SCHEMATIC}:${TALOS_VERSION}"

curl --fail --location \
  --output "$ARCHIVE" \
  "https://talos.home.antonu.org/image/${SCHEMATIC}/${TALOS_VERSION}/installer-arm64.tar"
skopeo copy "docker-archive:${ARCHIVE}" "docker://${INSTALLER}"
skopeo inspect --format '{{.Digest}}' "docker://${INSTALLER}"

talosctl -n 192.168.40.41 upgrade --image "$INSTALLER" --wait
```

Apply the updated `talos/patches/worker-02.yaml` through the same reviewed
machine-config generation/apply workflow used for the existing storage,
Home Assistant and RTL-SDR labels. It adds:

```text
hardware.home.antonu.org/raspbee2=true
```

Do not use `kubectl label` as a substitute; the label would drift from Talos
machine configuration.

## 2. Move the RaspBee II

This stage interrupts Zigbee service.

1. Confirm the Phoscon backup is readable and stored away from both Pis.
2. Stop the old deCONZ container so only one process can own the coordinator.
3. Shut down and remove power from the old Raspberry Pi.
4. Shut down and remove power from talos-worker-02 (`192.168.40.41`).
5. Move the RaspBee II to the GPIO header, checking pin alignment carefully.
6. Power on talos-worker-02 and wait for the node and existing workloads to
   become Ready.

Never install or remove the RaspBee II while either board is powered.

Verify the node before starting deCONZ:

```sh
talosctl -n 192.168.40.41 read /proc/cmdline
talosctl -n 192.168.40.41 ls /dev/ttyAMA0
kubectl get node talos-worker-02 \
  -L hardware.home.antonu.org/raspbee2 \
  -L storage.home.antonu.org/synology-iscsi
```

Stop if `/dev/ttyAMA0` is absent, if the kernel command line assigns a console
to `ttyAMA0`/`serial0`, or if either label is missing. Do not start the pod and
hope device access will repair itself.

## 3. Deploy through Argo

Commit and push the reviewed declarative changes. Sync `gitops`,
`home-cloud-gateway`, then `deconz`, all without pruning. This starts one deCONZ
replica. The PVC uses `WaitForFirstConsumer` and binds when the pod is scheduled.
All workload resources use the default sync wave so Argo creates the PVC and
Deployment together; an earlier PVC wave would block waiting for its consumer.

Read-only checks:

```sh
argocd app diff deconz
kubectl -n deconz get deployment,pvc,service,httproute
```

## 4. Start fresh and restore Phoscon

After the Argo sync, verify startup before restoring the Phoscon backup.

```sh
kubectl -n deconz rollout status deployment/deconz --timeout=300s
kubectl -n deconz get pod,pvc,service,httproute -o wide
kubectl -n deconz logs deployment/deconz
```

Require the pod to run on `talos-worker-02`, the PVC to be Bound, and the logs
to show deCONZ `2.29.1` opening `/dev/ttyAMA0`. Open
`https://deconz.home.antonu.org`, complete only the minimum fresh setup needed
to reach Gateway settings, then restore the Phoscon backup. Do not pair devices
again unless the restore is proven unsuccessful.

The Service exposes HTTP `8080` and WebSocket `8443`. The Gateway's normal HTTPS
listener routes the Phoscon UI to `8080`; its dedicated HTTPS `8443` listener
routes WebSockets to `8443`, preserving the ports advertised by deCONZ. If Home
Assistant does not rediscover deCONZ across the pod network, configure the
existing integration to use `deconz.deconz.svc.cluster.local` with HTTP port
`8080`; the Service also exposes WebSocket port `8443`.

Acceptance requires:

- the Phoscon gateway shows the RaspBee II and restored Zigbee network;
- representative lights and sensors update without re-pairing;
- Phoscon remains usable through the HTTPS hostname;
- Home Assistant receives deCONZ state changes and can control a test device;
- a pod restart reattaches the PVC and coordinator successfully.

Only after acceptance should deCONZ be upgraded separately from `2.29.1`.

## Rollback

Scale the Kubernetes Deployment back to zero through Git/Argo before touching
the hardware. Power off both boards, move the RaspBee II back to the old Pi,
then restart the untouched old container. Never run the old and new deCONZ
instances against the same coordinator. Keep the new retained PVC and Phoscon
backup until rollback is no longer required.
