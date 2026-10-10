# Production incident postmortems

This homelab is production infrastructure for its owner/customer, Anton.
Loss of access to media, home automation or persistent storage is customer impact.
These records distinguish observed failures, confirmed recovery, hypotheses and
remaining work. They are historical evidence, not current health reports.

| Incident date (Europe/Berlin) | Incident | Outcome |
|---|---|---|
| 2026-10-10 | [Pulsar DLNA discovery unavailable across VLANs](2026-10-10-pulsar-dlna-discovery.md) | TV and Mac discovery confirmed working by the operator |
| 2026-10-10 | [Home Assistant and Matter storage mounts failed](2026-10-10-synology-csi-dns-startup.md) | Operator confirmed recovery; original DNS timeout cause remains unknown |

For future records, capture customer impact, evidence, cause, recovery, validation,
contributing factors and follow-up work. Use local times with the timezone stated;
mark unknown start/end times and duration rather than estimating them. Do not
commit raw router exports, credential-bearing logs or Secret contents.
