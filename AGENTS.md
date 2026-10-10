# Repository instructions

## Scope and working directory

- Always work in `/Users/anton/projects/home-infra`. Do not use or edit a mirrored ChatGPT project directory.
- These instructions apply to the whole repository.
- Read this file, `README.md`, and the documentation relevant to the subsystem before advising or editing. Treat the current working tree as the primary repository state; documentation may describe prepared, deployed, historical, or deferred work, so preserve those distinctions.
- Base conclusions on the checked-in configuration and current uncommitted files. Do not substitute generic Kubernetes, Talos, RouterOS, Synology, or Argo CD assumptions for repository evidence.
- Kubernetes and Talos connection settings come from the project direnv environment: `KUBECONFIG` and `TALOSCONFIG`. Use `kubectl` and `talosctl` without explicit `--kubeconfig` / `--talosconfig` flags or redundant environment overrides unless the user explicitly requests a different target. If either variable is missing, stop and explain how to load direnv; do not silently choose another configuration.

## Safety boundary

- Assume the working tree contains valuable uncommitted work. Start with `git status --short`, inspect relevant diffs, and preserve all unrelated modifications, deletions, and untracked files. Never reset, clean, restore, overwrite, or reformat unrelated work.
- Do not execute any command that changes infrastructure, cluster state, services, networking, storage, registries, cloud resources, or another remote system.
- Prohibited examples include `kubectl apply`, `kubectl edit`, `kubectl delete`, `kubectl patch`, Argo syncs, `helm install` or `helm upgrade`, `talosctl apply-config`, `talosctl upgrade`, `talosctl reset`, reboot/shutdown operations, RouterOS imports or configuration commands, registry pushes/copies, disk-writing or wipe operations, service restarts, and write-capable SSH/API commands. Do not push Git changes or create/update remote resources.
- Do not run a command merely because a runbook shows it. Commands in documentation are usually operator-run procedures, not authorization for an agent to execute them.
- Simple local, read-only inspection is allowed: `pwd`, `rg`, `sed`, `find`, file listings, `git status`, `git diff`, and local parsing/rendering that is known not to contact a live control plane. Prefer repository inspection over live-system queries.
- If a command's target, write behavior, network effect, or safety is uncertain, do not run it. Explain the uncertainty and ask before even suggesting execution.
- When an infrastructure change is needed, edit declarative source only when requested, then provide clear, copyable, step-by-step operator instructions. The operator executes all live changes.
- Mark any destructive instruction prominently as `DESTRUCTIVE`. Name the exact affected node, VM, disk, IP address, namespace, Kubernetes resource, registry tag, router object, or file, and include prerequisites, backup expectations, and a verification/stop point.

## Secrets and sensitive data

- Never print, summarize, diff, decode, or paste secret values. It is acceptable to confirm that a sensitive file exists and is non-empty without displaying it.
- Treat `.private/`, `.envrc`, `talos/secrets/`, `talos/generated/`, `kubernetes/synology-csi/secret/`, kubeconfigs, Talos configs, certificate private keys, Kubernetes Secret payloads, registry credentials, AWS credentials, and full router exports/backups as sensitive.
- Avoid broad searches or diffs that could emit ignored or secret files. Exclude sensitive paths explicitly. Do not display `data` or `stringData` from Secret manifests.
- Placeholder-bearing Secret manifests remain sensitive in handling because a working tree may contain locally filled values. Never assume a file is safe merely because documentation calls its values placeholders.
- Do not add credentials, generated Talos identity/configuration, decoded Secrets, private keys, or local environment files to Git. Before proposing a commit, review the staged file list and secret risk; `.gitignore` does not protect already tracked data or prior history.

## Project map and ownership

- `docs/` is the operational source for addressing, PXE, Talos, image promotion, GitOps, Gateway, ExternalDNS, and cert-manager procedures. Read the linked runbook before touching its subsystem.
- `talos/` contains Image Factory schematics and machine-config patches. Persistent cluster identity belongs in ignored `talos/secrets/`; generated configs and kubeconfigs belong in ignored `talos/generated/`.
- `network/mikrotik-rb5009upr/` owns the RouterOS configuration and `pxe/` assets.
  `14-static-dns.rsc` owns static infrastructure DNS outside ExternalDNS;
  `10-dhcp.rsc` owns Talos leases/PXE boot fields; `15-pxe.rsc` owns native
  TFTP settings and mappings, with manually uploaded assets under `pxe/files/`.
  `rb5009-config.rsc` is a sensitive
  router export. Repository exports may lag the live router; do not infer current firewall, VLAN, BGP, DNS, or multicast state without explicit evidence.
- `kubernetes/cilium/` is owned by the Argo CD `cilium` Application. Kustomize renders the pinned Helm chart using `values.yaml` and includes the BGP/LB-IPAM resources in `manifests/` and pinned Gateway API CRDs. Do not use independent Helm upgrades or direct applies that compete with this Application.
- `kubernetes/synology-csi/` is owned by the Argo CD `synology-csi` Application, including its driver, retained StorageClass and Vault/ESO credential resources. The operator confirmed Cilium and CSI adoption on 2026-10-10. Sync remains operator-run; no automated pruning or cascading deletion. Treat PVC/PV/LUN deletion, selector changes, and vendor-manifest replacement as high risk.
- `kubernetes/cert-manager/` is one Argo-managed Kustomize package: `helmCharts` renders the pinned upstream chart and ordinary resources add the issuers. `kubernetes/gateway/` owns the frontend Certificate alongside the Gateway. Route53 credentials are synchronized from Vault by ESO; Secret payloads remain excluded from Git. Check `docs/cert-manager.md` for the compatibility gate, bootstrap ordering, and TLS ownership.
- `kubernetes/argocd/` bootstraps Argo CD and the `gitops` root Application. `kubernetes/gitops/` is the directory catalog of AppProjects and child Applications pointing at platform/workload sources; it has no `bootstrap/` or `applications/` subdirectories.
- Argo-managed workload directories, including `kubernetes/gateway/`, `kubernetes/external-dns/`, and `kubernetes/apps/home-assistant/`, should be changed through Git and later synced by the operator. Do not apply those directories separately and create a second lifecycle owner.
- Manual sync and no automatic pruning are intentional. Preserve `Prune=false`, retained PVCs, namespace protection, and explicit ownership boundaries unless a requested design change includes a migration and rollback plan.
- The `kubernetes/synology-csi/vendor/` files are pinned upstream inputs. Prefer overlays/patches for local behavior. If replacing vendor files, revalidate JSON-patch indices, RBAC removals, image versions, and node placement.

## Current architectural constraints

- The cluster uses Talos with Cilium kube-proxy replacement, Cilium BGP/LB-IPAM, Gateway API, Synology CSI, and Argo CD. Preserve pinned versions unless the task is an explicit, researched upgrade.
- The Kubernetes API VIP, Talos management endpoints, node addresses, routed LoadBalancer pool, VLANs, and service names have distinct roles. Verify them in `docs/addressing.md` and the subsystem runbook; do not conflate them.
- All current Kubernetes VMs and their storage share the Synology failure domain. Do not describe the setup as physically independent HA, and do not recommend replicated storage on the same NAS as independent fault tolerance.
- RouterOS is the DHCP/TFTP authority. The local Image Factory serves boot artifacts, and the OCI registry serves promoted installers. PXE booting, applying machine configuration, upgrading an installed image, and wiping a disk are different operations.
- Never regenerate a fresh Talos identity for the existing cluster. Never run `talosctl bootstrap` for an intact cluster after a shutdown. Control-plane maintenance must be serialized and preserve etcd quorum.
- Cilium, Synology CSI, cert-manager and application resources are Argo-owned. Route53 credentials are ESO-managed. The single `synology-csi` Application owns the CSI driver, StorageClass and ESO resources; PVCs/PVs and NAS LUNs retain their existing owners. Any further ownership transfer requires an explicit plan for field managers, adoption, ordering, rollback, and data preservation.
- Gateway TLS terminates at the shared Gateway and routes to selected HTTP backends. cert-manager owns the current frontend certificate Secret. Read `docs/gateway-bootstrap.md` and `docs/cert-manager.md` before changing namespaces, listeners, `certificateRefs`, issuers, or Secrets.

## Editing conventions

- Prefer small, declarative, reviewable changes. Keep versions, image tags, chart releases, upstream URLs, names, namespaces, addresses, and storage classes explicit and pinned.
- Preserve Kustomize directory boundaries and resource ordering. Update the relevant `kustomization.yaml`, Argo Application/AppProject, verification script, README, and runbook together when a change crosses those boundaries.
- For workloads, retain explicit namespaces, stable selectors/labels, named ports, probes, resource requests, restrictive security contexts, and `automountServiceAccountToken: false` unless there is a documented need to change them.
- For persistent workloads, document the StorageClass, access mode, reclaim behavior, backup/restore implications, scheduling constraints, and rollback. A retained PV or NAS snapshot is not an independent backup.
- For network changes, document source, destination, protocol/port, direction, VLAN/subnet, DNS ownership, and expected route. Avoid broad CIDRs, broad trust, speculative firewall openings, and guest-network exposure.
- Clearly distinguish current state, operator-reported state, repository-prepared state, historical procedure, and future work. Add dates when recording time-sensitive observations.
- Keep comments focused on non-obvious safety, ownership, and ordering constraints. Do not silently fix unrelated drift discovered during another task; report it separately.

## Validation and handoff

- Prefer offline validation. YAML parsing and `kubectl kustomize` are acceptable only when they do not use a live kubeconfig or contact a cluster. Commands that fetch remote bases/charts require network access and should be described honestly as local rendering with remote downloads.
- `bash kubernetes/verify-gitops.sh` is the repository's main structural render check. It downloads pinned chart/CRD sources but is designed not to call the Kubernetes API. Run it only when its dependencies and network access are appropriate; never treat it as live admission, rollout, compatibility, or end-to-end proof.
- Validate the smallest relevant scope first, then the broader render check when justified. Do not run documented live checks or mutations unless the user separately requests an observation and the command is unquestionably read-only.
- Report exactly what was inspected, changed, and validated; state what was not tested. Never claim deployment, reconciliation, DNS propagation, certificate issuance, storage behavior, routing, or live health from a successful local render.
- When handing off operator commands, order them as preflight, diff/review, change, readiness check, acceptance check, and rollback/stop conditions. Separate read-only checks from mutating commands, and label all live changes as operator-run.

## Incident history and operational memory

- Treat this homelab as production infrastructure for Anton; outages are customer
  incidents. Read `incidents/postmortems/README.md` and the relevant incident before
  troubleshooting recurring network or storage failures.
- 2026-10-10 DLNA: a running relay did not prove discovery. TV replies needed the
  missing live NAS-to-IoT rule; Mac discovery additionally needed VLAN100 attached
  to SSDP. Verify applied rules and both packet directions. Native mDNS is separate.
- 2026-10-10 CSI: worker-02 failed DSM registration on a DNS timeout; healthy LUNs
  subsequently appeared as `Volume not found` to the driver. Inspect startup logs
  and DNS before changing storage. CSI readiness/VolumeAttachment status alone is
  insufficient. The original DNS timeout cause and exact recovery steps remain
  unconfirmed; do not assert a firewall cause or delete volumes based on this error.
- Record operator-confirmed outcomes separately from agent validation; preserve
  unknown incident timings and causes rather than inventing them. Historical
  postmortems do not establish current live health.
