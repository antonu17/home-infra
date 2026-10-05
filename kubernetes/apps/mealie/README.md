# mealie

Prepared on 2026-10-05; not deployed. Follow [the shared migration procedure](../migration-tools/README.md), choosing `APP=mealie`.

Source container: `quantum-infra-mealie-1` on Docker context `quantum`.
Image: `ghcr.io/mealie-recipes/mealie:v3.22.0`, keeping the observed source version.
Source storage: Docker volume `pi-mealie_mealie-data` at `/app/data` (~24 MiB).

The complete source directory is copied, including SQLite, assets and settings;
application credentials stay inside the private data archive and PVC, not Git.
No Vault/ExternalSecret is needed for the observed environment: there are no
external service credentials to move. Mealie signup remains disabled.

A retained 5 GiB RWO `synology-block` claim backs `/app/data` via
PVC subdirectory `mealie`. One replica with Recreate prevents ordinary
rollouts from starting two writers. Placement requires the existing iSCSI node
label, not the Pi's hardware labels. Both images support amd64 and arm64.
Mealie runs as UID/GID 1000; its upstream entrypoint skips root-only account setup when the running UID matches PUID.

Initially replicas are zero solely for data migration, with an additional database
existence guard. HTTPRoutes are prepared but excluded until acceptance testing.
No workload sync waves, automated sync/pruning, or PVC deletion are introduced.
The existing wildcard certificate covers `mealie.home.antonu.org`.
ExternalDNS currently has no legacy exclusions; review old record ownership
before enabling the route. DNS cutover remains operator-run.

A retained LUN/NAS snapshot is not an independent backup. Keep the final
stopped-source archive outside the NAS and keep quantum's source intact.
Rollback requires stopping the Kubernetes writer before starting the old one;
after new writes, reconcile data first rather than silently reverting to stale data.
