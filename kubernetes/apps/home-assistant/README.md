# Home Assistant on Kubernetes

This is the Argo CD source for a fresh Home Assistant Container installation.
It does not contain or migrate configuration from the existing HAOS Raspberry Pi,
and it does not deploy Supervisor add-ons.

## Architecture and ownership

```text
Git -> Argo CD home-cloud root -> home-assistant Application
    -> HTTPRoute -> gateway/home-cloud (TLS) -> ClusterIP:8123
    -> StatefulSet (one replica) -> /config -> Synology iSCSI PVC
```

Argo CD owns the namespace and every resource in this directory. The application
uses official image `ghcr.io/home-assistant/home-assistant:2026.9.2`, normal Cilium
pod networking, and no host devices, additional capabilities, or service account
token. Requests are `250m` CPU and `512Mi` memory, with no limits so startup,
database work, and integrations may burst. TCP probes avoid relying on a private
HTTP health endpoint and allow up to ten minutes for startup.

The `home-assistant-config` claim requests 20 GiB, `ReadWriteOnce`, from existing
StorageClass `synology-block` and mounts at `/config`. That StorageClass has PV
reclaim policy `Retain`. Both the Namespace and PVC have Argo sync option
`Prune=false`: removing either from Git makes the application OutOfSync instead of
cascading namespace deletion into application data loss. Retirement therefore
requires a separately reviewed manual namespace/PVC/PV action and an independent
backup.

The ClusterIP Service exposes TCP/8123. The HTTPRoute serves exactly
`hass.home.antonu.org`, attaches to the `https` listener on
`gateway/home-cloud`, and relies on `gateway/home-antonu-org-tls` for TLS
termination. The shared Gateway must be synced with its accompanying namespace
allow-list change. DNS must ultimately resolve the hostname to `10.40.0.10`;
ExternalDNS is managed separately.

## First start and reverse proxy

The expected data volume is empty, so first start presents normal onboarding.
Home Assistant 2026.9 manages HTTP server settings in **Settings -> System ->
Network**. Enable **Trust X-Forwarded-For** and add only the measured source
address or network used by the Cilium Gateway. Do not guess a pod CIDR or trust
all RFC1918 networks. Upstream requires both settings behind a traditional reverse
proxy. If Gateway requests are rejected before this is set, temporarily
port-forward the Service for onboarding, measure the proxy source in Home Assistant
logs, configure and confirm the setting, then stop the tunnel.

Older Home Assistant releases expressed the same minimum in
`/config/configuration.yaml` as:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - <measured Cilium Gateway source address or network>
```

This is documentation only and is intentionally not written into the new PVC.
From Home Assistant 2026.8 it is imported into the UI and should then be removed
from YAML.

`hostNetwork` is intentionally disabled. mDNS, SSDP, multicast, Bluetooth, USB,
Zigbee, Matter, hardware placement, and cross-VLAN discovery are deferred until
this fresh instance is proven healthy. Existing HAOS configuration, state, and
add-ons remain untouched; add-ons must later be assessed as separate workloads.

## Manual GitOps flow

No application has automated sync, prune, or self-heal. A push alone does not
deploy these resources. After reviewing, committing, and pushing:

1. Apply the updated bootstrap Kustomization so `home-cloud` AppProject permits
   the namespace and resource kinds.
2. Sync root application `home-cloud` to register the child.
3. Sync `home-cloud-gateway` so its listener permits the new namespace.
4. Review and sync `home-assistant`.

```sh
kubectl apply -k kubernetes/gitops/bootstrap
argocd app sync home-cloud
argocd app sync home-cloud-gateway
argocd app sync home-assistant
```

These are operator commands for after commit/push; they have not been run here.
Do not apply this application directory separately because Argo CD is its owner.

## Verification after reconciliation

```sh
argocd app get home-cloud
argocd app get home-cloud-gateway
argocd app get home-assistant
argocd app diff home-assistant

kubectl -n home-assistant get pods,statefulset,pvc,svc,httproute
kubectl -n home-assistant describe pod home-assistant-0
kubectl -n home-assistant logs statefulset/home-assistant
kubectl -n home-assistant get httproute home-assistant \
  -o jsonpath='{range .status.parents[*].conditions[*]}{.type}{"="}{.status}{" reason="}{.reason}{"\n"}{end}'
kubectl get gateway -A
kubectl -n gateway get gateway home-cloud \
  -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" reason="}{.reason}{"\n"}{end}'
kubectl get httproute -A
kubectl -n home-assistant port-forward service/home-assistant 8123:8123
```

Require Gateway `Accepted=True` and `Programmed=True`, and route
`Accepted=True` and `ResolvedRefs=True`. Confirm the PVC is Bound, the StatefulSet
has one Ready replica, and logs show no repeated startup failure. Use port-forward
only for controlled onboarding or diagnostics; normal access is
`https://hass.home.antonu.org` after proxy trust and DNS are correct.

## Evidence and missing information

Nodes use VLAN400 (`192.168.40.0/24`); Synology management/storage is VLAN100
(`192.168.100.5`). VLAN300 (`192.168.30.0/24`) is intended for IoT. The checked-in
router export predates the implemented 300/400 and BGP setup and cannot establish
current firewall, multicast relay or IPv6 behavior. Aruba/ether7 historically
carries only SSIDs/VLAN100 and 200; do not silently add VLAN400 or move devices.

Previous HA screenshots show Cast, Apple TV, Matter/Thread, deCONZ, ESPHome and
Bluetooth integrations. The installed apps include Matter Server, SSH and Studio
Code. HA Container has no Supervisor app lifecycle: those dependencies need an
explicit migration plan. A missing visible DB file does not establish the recorder
backend. Determine the actual database and back it up before migration.

## Networking decision gate

| Traffic | What must work |
|---|---|
| Browser/API | Gateway HTTPS → HA Service; measured, narrow trusted proxy configuration |
| Ordinary device API | Routed unicast with integration-specific firewall permissions and callbacks |
| mDNS / Zeroconf | UDP5353 multicast discovery across required interfaces; ordinary BGP unicast does not relay it |
| SSDP | UDP1900 multicast searches/announcements plus unicast replies; mDNS reflection does not solve this |
| Matter / Thread | Matter Server, IPv6 reachability, border-router access and discovery; validate separately |
| Bluetooth / USB Zigbee | Network proxy or deliberate device passthrough and placement; PVCs cannot migrate hardware |

Start with a discovery inventory, not a networking workaround. Use explicit
addresses where integrations support them, but Cast in the existing setup is a
concrete reason not to promise ordinary pod networking will suffice: upstream
requires host networking for its container discovery support.

Recommended experiment after the foundation: a disposable discovery probe on the
worker's host network, with no production HA credentials. `hostNetwork: true`
places it on VLAN400, **not VLAN300**; it still requires a carefully scoped mDNS
reflector and a separate SSDP solution between the actual device VLAN and 400.
First inspect current RouterOS version/config and any existing relay to avoid
duplicates/loops. Do not reflect guest VLAN200 or open all inter-VLAN traffic.
SSDP may be avoided only where all relevant integrations support explicit setup.
Host-network pods also need `ClusterFirstWithHostNet`; understand Cilium host
firewall/policy behavior rather than assuming ordinary pod policy isolates them.

If discovery tests establish host networking is required, use a single replica on
an iSCSI-capable worker, with controlled replacement (no simultaneous old/new HA
instance), and document the extra network exposure. Host networking is not HA and
does not solve multicast across VLANs. If reliable relaying/IPv6 cannot be proven,
keep production HAOS running; do not force the migration. Do not add Multus or
another CNI as a speculative first step.

## Migration checklist for a later task

1. Supply sanitized live bridge/VLAN, firewall, DNS/mDNS and IPv6 configuration;
   inventory each device's current VLAN and discovery requirements. No Pi changes.
2. Test discovery and callbacks across real boundaries (including Matter IPv6),
   not just ping. Capture traffic from a diagnostic tool, not a Talos shell.
3. Back up HA and app/Matter data securely; restore to an isolated test instance.
   Never run two active production automations/coordinators against the same home.
4. Restore a Synology PVC backup into a distinct test volume. Existing write/reboot
   persistence tests are not backup recovery or abrupt power-loss validation.
5. Validate independent backup and restore for the retained `synology-block` PVC.
   CSI placement is currently worker-01; do not conflate a retained LUN with backup.
6. Inventory external apps, USB/Bluetooth, recorder, WebSocket/proxy behavior, and
   LAN discovery before any later cutover. Preserve the old HAOS instance as a
   stopped rollback copy.

Sources: [Cast](https://www.home-assistant.io/integrations/cast/),
[Zeroconf](https://www.home-assistant.io/integrations/zeroconf/),
[SSDP](https://www.home-assistant.io/integrations/ssdp/),
[Matter](https://www.home-assistant.io/integrations/matter/),
[HTTP / reverse proxy settings](https://www.home-assistant.io/integrations/http/),
[Container installation](https://www.home-assistant.io/installation/linux#install-home-assistant-container),
[Core releases](https://github.com/home-assistant/core/releases).
