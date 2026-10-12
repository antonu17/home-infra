# Production incident postmortems

These postmortems document incidents in my home network. I administer the
infrastructure and record how I investigate failures, restore service and verify
recovery. Loss of media access, home automation or storage is a service outage.
These records distinguish observed failures, confirmed recovery, hypotheses and
remaining work. They are historical evidence, not current health reports.

| Incident date (Europe/Berlin) | Incident | Outcome |
|---|---|---|
| 2026-10-10 | [Pulsar DLNA discovery unavailable across VLANs](2026-10-10-pulsar-dlna-discovery.md) | I verified TV and Mac discovery |
| 2026-10-10 | [Home Assistant and Matter storage mounts failed](2026-10-10-synology-csi-dns-startup.md) | I verified recovery; original DNS timeout cause remains unknown |
| 2026-10-10 | [ExternalDNS could not reach router REST](2026-10-10-external-dns-router-rest.md) | Empty allow-list confirmed; remediation prepared, recovery unconfirmed |
| 2026-10-12 | [Samsung cross-subnet SSDP discovery](2026-10-12-samsung-ssdp-source-subnet.md) | SNAT restores wired/Wi-Fi discovery; wired playback/seek confirmed; permanent configuration imported |

For future records, record service impact, evidence, cause, recovery, validation,
contributing factors and follow-up work. Use local times with the timezone stated;
mark unknown start/end times and duration rather than estimating them. Do not
commit raw router exports, credential-bearing logs or Secret contents.
