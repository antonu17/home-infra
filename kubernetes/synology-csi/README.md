# Synology CSI through Argo CD

The `synology-csi` Application adopts the existing driver and StorageClass and
includes its Vault-backed credentials in the same Kustomize package. Repository
onboarding is prepared; no cluster changes have been executed here.

The package includes Namespace, CSIDriver, controller StatefulSet, node DaemonSet,
their ServiceAccounts/RBAC, `synology-block` StorageClass, and ESO login/store/secret
resources. Driver and sidecar versions, selectors, and storage settings are preserved.
The node pod template adds the startup gate described below. Vendor manifests remain pinned and unmodified.

The operator's 2026-10-09 network target places Synology at
`192.168.40.5/24` in VLAN400 / Home Cloud, gateway `192.168.40.1`, replacing
the previous `192.168.100.5` in VLAN100. The move is not verified live.
Check hostname-based DSM HTTPS and existing iSCSI target references separately;
node-to-NAS traffic will be local to VLAN400 after the move. This documentation
does not edit CSI credentials, endpoints, PVs or storage configuration.

It does not manage existing PVCs, PVs or NAS LUNs. `storage-test.yaml` is an optional
operator test and is not included in the production Kustomization.

## Ownership and ordering

- Namespace is reconciled at wave `-2`; its existing privileged Pod Security level
  is retained because the driver needs privileged host access.
- ESO login ServiceAccount/TokenRequest RBAC is wave `-1`.
- Driver RBAC, CSIDriver, StorageClass, SecretStore and ExternalSecret are wave `0`.
- Controller/node workloads are wave `1`.

The source adds `Prune=false,Delete=false` to every resource. The Application has
no cascading deletion finalizer and no automated sync/pruning. Server-side apply
is enabled; client-side apply migration is disabled. Shared Argo ownership fails
the sync instead of silently taking resources from another Application.

ESO targets the existing `synology-csi/client-info-secret`, preserving the exact
`client-info.yml` bytes. Vault data is at `home-cloud/synology-csi/client-info`;
Terraform's `eso-synology-csi` identity reads that workload prefix only. The
ExternalSecret uses Owner/Retain: ESO sets an owner reference for Argo child
visibility. Removing the ExternalSecret can garbage-collect the credential Secret;
Retain protects against Vault-entry deletion only.

Storage-backed Vault/ESO depend on functioning storage. Keep the existing retained
credential Secret during outages and keep independent Vault backups; rebuilding
an empty cluster requires a reviewed credential/storage bootstrap sequence.

## Operator-run adoption

Use the project direnv environment, including `KUBECONFIG`. Read-only preflight:

```sh
direnv reload
kubectl config current-context
kubectl -n synology-csi get statefulset,daemonset,pods
kubectl get csidriver csi.san.synology.com
kubectl get storageclass synology-block
kubectl get pvc -A
kubectl get pv
kubectl -n synology-csi get secret client-info-secret
argocd app list
```

Existing data/backups and the credential Secret must remain available. Terraform
was reported applied on 2026-10-04. Confirm ESO and its CRDs are ready and the
reviewer JWT remains valid. Do not reinstall the driver or delete storage to adopt.

Render offline and check the AppProject allows every rendered kind:

```sh
kustomize build kubernetes/synology-csi
```

Review and commit/push the source, documentation and Application rename together.
Replace the old `kubernetes/gitops/synology-csi-secrets.yaml` with
`kubernetes/gitops/synology-csi.yaml`; do not commit both declarations. Argo reads
remote Git, not the working tree.

If an older `synology-csi-secrets` Application is listed, detach it before syncing
the new Application. This **deletes only Argo Application metadata**
(`argocd/synology-csi-secrets`) and retains its managed resources:

```sh
argocd app delete synology-csi-secrets --cascade=false
```

Skip that command if the Application does not exist. Its old manifest must already
be removed from the pushed Git revision so the root will not recreate it.
Never use a cascading delete for this handoff.

These are **operator-run live adoption changes**:

```sh
argocd app sync gitops
argocd app get synology-csi --hard-refresh
argocd app diff synology-csi
```

Review the diff before syncing. Expect Argo retention/tracking annotations and ESO
resources; stop on pod-template changes, selector/image changes, credential-data
changes, StorageClass parameters/reclaim-policy changes, replacements or deletion.
The controller was observed with one ready replica and the node DaemonSet with
two ready instances on 2026-10-04. The controller stays on `talos-worker-01`; nodes
keep `storage.home.antonu.org/synology-iscsi=true` selection.

After the diff is approved locally:

```sh
argocd app sync synology-csi
```

Keep pruning disabled. Do not use force/replace or prune to resolve conflicts.
After adoption, make driver changes through Git/Argo rather than applying this
Kustomize package separately.

## Readiness and rollback

```sh
kubectl -n synology-csi wait --for=condition=Ready --timeout=180s secretstore/home-cloud-vault
kubectl -n synology-csi wait --for=condition=Ready --timeout=180s externalsecret/client-info-secret
kubectl -n synology-csi rollout status statefulset/synology-csi-controller --timeout=300s
kubectl -n synology-csi rollout status daemonset/synology-csi-node --timeout=300s
kubectl -n synology-csi get pods
kubectl get pvc -A
kubectl get pv
argocd app get synology-csi
```

Require Synced/Healthy, Ready store/ExternalSecret, ready driver workloads and
unchanged existing Bound claims. These checks do not establish backup recovery
or new-volume provisioning; no write-capable storage test is executed by this task.

On a failed adoption, stop further syncs and retain all driver/storage/credential
resources. Revert unintended changes in Git. To return lifecycle control to the
operator, first remove the Application declaration from the root's Git source,
then detach `argocd/synology-csi` with `argocd app delete synology-csi --cascade=false`.
That removes Argo metadata and retains workloads. Do not delete Namespace,
StorageClass, CSIDriver, PVCs/PVs, Secrets or NAS LUNs as rollback.

References: [Argo retention and server-side apply](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
and [non-cascading Application deletion](https://argo-cd.readthedocs.io/en/stable/user-guide/app_deletion/).

## Node startup gate

The node DaemonSet runs `wait-for-dsm` before either CSI container starts.
`startup-gate/patch.yaml` mounts the existing `client-info` Secret volume read-only
and a generated, hash-suffixed ConfigMap containing `startup-gate/wait.rb`.
Changes to the script change the pod template and trigger a DaemonSet rollout.
Vendor manifests and controller startup remain unchanged.

The gate reads every `clients` entry from `/etc/synology/client-info.yml` and uses
its `host`, `port`, `https`, `tlsCACert`, `tlsServerName` and
`insecureSkipVerify` settings. It uses the node pod's host network and
`ClusterFirstWithHostNet` DNS policy. Each pass must resolve every configured
host and receive HTTP 200 with a successful `SYNO.API.Info` response advertising
`SYNO.API.Auth` from `/webapi/query.cgi`. Redirects, login HTML, API errors and
TLS failures keep the gate closed. No DSM login or credentials are sent.
The HTTP Host header retains the configured host; certificate verification is
enabled unless the existing configuration explicitly disables it. Proxy environment
variables are ignored.

DNS resolution is bounded to five seconds; the HTTP/TLS request has a fifteen-second
overall bound and five-second connection/read/write limits. Failed passes retry
after five seconds indefinitely, re-reading the projected configuration. Logs
contain only generic failure categories. An unavailable DSM leaves new node pods
in Init rather than starting a plugin with missing DSM registration. All configured
DSMs must pass, so one unavailable DSM blocks the entire node plugin.

This mitigates the observed reboot startup race. The dependency can still fail
between the query and driver registration; API availability does not prove valid
credentials, SAN permissions, LUN health or successful mounts. An init container
does not rerun when only the CSI plugin container restarts inside an existing pod.
The new Ruby image must be available during recovery; pre-cache it before planned
node maintenance. No new firewall permissions or storage changes are required.

### Local validation

These commands use synthetic fixtures and loopback servers inside an isolated
container. The first run may download the pinned image; no cluster API is used.

```sh
docker run --rm --network none --read-only \
  --tmpfs /tmp:rw,nosuid,noexec,size=16m \
  -v "$PWD/kubernetes/synology-csi/startup-gate:/tests:ro" \
  ruby:3.3.6-alpine3.20 ruby /tests/test.rb
kustomize build kubernetes/synology-csi | ruby kubernetes/synology-csi/startup-gate/verify.rb
```

### Deployment and acceptance

Read-only preflight, after loading the project direnv environment:

```sh
kubectl config current-context
kubectl -n synology-csi get daemonset synology-csi-node
kubectl -n synology-csi get pods -o wide
kubectl get pvc -A
argocd app get synology-csi
```

Review the local Git diff and commit/push through the normal workflow. Argo reads
remote Git. Review the Argo diff privately; do not publish credential-bearing
output. Expect only the generated ConfigMap and node pod-template gate changes;
stop on PVC/PV, Secret payload, StorageClass, selector or vendor image changes.

```sh
argocd app diff synology-csi
```

**Operator-run live change:** this sync rolls the node DaemonSet and temporarily
interrupts CSI node operations. Schedule it while storage is healthy and avoid
concurrent node maintenance. Keep pruning disabled.

```sh
argocd app sync synology-csi
```

Read-only readiness and acceptance:

```sh
kubectl -n synology-csi rollout status daemonset/synology-csi-node --timeout=300s
kubectl -n synology-csi get pods -o wide
kubectl -n synology-csi logs -l app=synology-csi-node -c wait-for-dsm --prefix
kubectl get pvc -A
```

Require the gate-ready message on each node, unchanged Bound claims and working
existing application mounts. Review CSI startup logs privately for successful DSM
registration and absence of login failures; Ready/VolumeAttachment status alone
is insufficient. During a later planned single-worker reboot, confirm that the
gate waits through unavailable dependencies and existing workloads recover without
manual CSI pod recreation. Stop further maintenance if registration or mounts fail.
No reboot or write-capable storage test is part of local validation.

### Rollback

Revert only the startup-gate additions in Git, preserving unrelated changes, then
review the Argo diff. **Operator-run live rollback:** sync `synology-csi` with
pruning disabled using the command above and repeat readiness/mount checks.
This rolls the node pods back to their previous startup behavior. Generated
ConfigMaps remain retained by policy; their removal is unnecessary for rollback.
Do not delete credentials, PVCs/PVs, VolumeAttachments or NAS LUNs.
