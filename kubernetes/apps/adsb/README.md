# ADS-B receiver

Argo-managed migration of the Compose project at
`https://github.com/antonu17/pi-adsb`. The deployment retains its three processes:
`dump1090-fa`, PiAware and `fr24feed`. They run as separate containers in one
`Recreate` Deployment so only one pod can own the RTL-SDR receiver and all three
can use loopback for the decoder feeds.

## Image ownership

Argo deploys images; it does not build them. The manifest pins the source commit
`5d339a807e4969dbc6e22d0ee8400caffd483c32` as the image tag
`registry.home.antonu.org/apps/pi-adsb:5d339a807e49`. Build and push that tag from
the source repository before syncing this Application. Do not replace it with
`latest`. After promotion, record and pin the registry digest in `deployment.yaml`.

Example operator-run build from a clean checkout at that commit:

```sh
git clone https://github.com/antonu17/pi-adsb.git /tmp/pi-adsb-build
git -C /tmp/pi-adsb-build checkout 5d339a807e4969dbc6e22d0ee8400caffd483c32
docker buildx build \
  --platform linux/arm64 \
  --tag registry.home.antonu.org/apps/pi-adsb:5d339a807e49 \
  --push /tmp/pi-adsb-build
skopeo inspect docker://registry.home.antonu.org/apps/pi-adsb:5d339a807e49
```

The build and push mutate the registry and are operator-run. Stop if the source
checkout is dirty, the existing tag resolves to unrelated content, ARM64 package
installation fails, or the registry requires an unconfigured pull credential.

## Hardware and scheduling

The Nooelec NESDR SMArt v5 is USB `0bda:2838` on `talos-worker-02`. The Deployment
requires node label `hardware.home.antonu.org/rtl-sdr=true`; that desired label is
recorded in `talos/patches/worker-02.yaml` and must exist before sync.

`dump1090-fa` preserves the old Compose stack's privileged mode and mounts
`/dev/bus/usb`. This gives that container access to every USB device visible on
the node, not only the receiver. PiAware and `fr24feed` are not privileged. A
vendor/product-aware device plugin is the intended future reduction in privilege.

No persistent volume is required. Runtime JSON and `fr24feed` logs use memory-backed
`emptyDir` volumes, matching the previous tmpfs behavior.

## Vault and ESO

The namespaced store authenticates as `eso-adsb` and can read only
`home-cloud/adsb/*`. The ExternalSecret reads these properties from Vault KV v2
path `home-cloud/adsb/feeders` and creates `adsb/adsb-config`:

- `LAT`
- `LON`
- `FLIGHTAWARE_FEEDER_ID`
- `FR24KEY`

Terraform manages only the scoped Vault policy and Kubernetes-auth role; it does
not manage secret values. Populate the entry privately before syncing ADS-B. A
placeholder entry can be created with the operator-run command below, but the pod
must not be treated as ready until every placeholder is replaced:

```sh
vault kv put home-cloud/adsb/feeders \
  LAT='REPLACE_ME' \
  LON='REPLACE_ME' \
  FLIGHTAWARE_FEEDER_ID='REPLACE_ME' \
  FR24KEY='REPLACE_ME'
```

Do not paste the real values into Git, chat, Terraform variables, plans or logs.

## Activation order

All live commands are operator-run:

1. Build/push the ARM64 image and pin its digest.
2. Apply the reviewed `terraform/vault` plan adding only `eso-adsb`.
3. Create the Vault entry and replace all placeholders with the existing values.
4. Preview and then apply only the reviewed worker label patch:

   ```sh
   talosctl patch machineconfig -n 192.168.40.41 \
     --patch @talos/patches/worker-02.yaml --dry-run
   talosctl patch machineconfig -n 192.168.40.41 \
     --patch @talos/patches/worker-02.yaml --mode=no-reboot
   ```

   Stop if the preview contains anything beyond the expected worker documents and
   labels. If Talos rejects `no-reboot`, review the reason before scheduling a reboot.
5. Commit and push the intended files. Sync `gitops` and `home-cloud-gateway` with
   pruning disabled. Stop the old Compose stack, then sync `adsb`; do not run two
   feeders with the same identities concurrently.
6. Verify without printing Secret payloads:

   ```sh
   kubectl -n adsb wait --for=condition=Ready --timeout=180s secretstore/home-cloud-vault
   kubectl -n adsb wait --for=condition=Ready --timeout=180s externalsecret/adsb-config
   kubectl -n adsb rollout status deployment/adsb --timeout=300s
   kubectl -n adsb get pods,services,httproutes
   kubectl get node talos-worker-02 -L hardware.home.antonu.org/rtl-sdr
   ```

Before changing DNS, verify the new interfaces through temporary port-forwards:

```sh
kubectl -n adsb port-forward service/dump1090-fa 8080:8080
kubectl -n adsb port-forward service/fr24feed 8754:8754
```

The existing `adsb.home.antonu.org` and `fr24.home.antonu.org` names are excluded
from ExternalDNS ownership. Cut them over manually to the shared Gateway address
`10.40.0.10` only after the routes are Accepted and the new receiver is producing
aircraft data. Preserve the old Compose configuration for rollback, but keep its
feeders stopped while the Kubernetes deployment uses the same identities.

Rollback is a Git revert and manual Argo sync without pruning. If the receiver pod
must move back immediately, scale or stop it before starting the old receiver so
two stations do not use the same feeder identities concurrently. Do not delete the
ExternalSecret or its generated Secret as a troubleshooting step.
