# Pi-hole on Synology

Pi-hole provides DNS filtering and a web administration interface. This project
is prepared configuration, not confirmation of a live deployment.

| Setting | Configuration |
|---|---|
| Image | `pihole/pihole:2026.09.0` |
| DNS | NAS port 53, both TCP and UDP |
| Admin UI | `http://NAS-IP:8081/admin/` → container HTTP port 80 |
| Persistent config/databases | `./etc-pihole` → `/etc/pihole` |
| Timezone | `Europe/Berlin` |
| Admin password | Private `ADMIN_PASSWORD` in `.env` |
| Restart | `unless-stopped` |

The pinned [2026.09.0 release](https://github.com/pi-hole/docker-pi-hole/releases/tag/2026.09.0)
contains Pi-hole FTL v6.7.1. The
[official Docker example](https://docs.pi-hole.net/docker/)
requires DNS listening mode `ALL` for Docker bridge networking; Compose sets it
explicitly. Ports and persistent storage retain the supplied project's layout.
RouterOS remains the DHCP authority. This project publishes no DHCP/NTP ports
and adds no host administration capabilities.

## Password and configuration

For a fresh installation, copy `.env.example` to `.env` and privately set a
non-empty `ADMIN_PASSWORD`. Existing installations can reuse their existing
private `.env`; it is not overwritten. Compose refuses to start without the
password. The previously embedded Compose password has been removed; replace
it with a private password if it was used live.

Pi-hole receives the password through `FTLCONF_webserver_api_password`, as
supported by its [configuration guide](https://docs.pi-hole.net/docker/configuration/).
Environment-controlled settings cannot be changed through the web UI; change
`.env`/Compose and recreate the container instead. Other settings, such as
upstream DNS, blocklists and local records, persist under `etc-pihole/`.
Avoid printing expanded Compose configuration or container environment: they
include the password. Keep `.env` and runtime contents outside Git; query
history and local DNS records may also be sensitive.

## Preflight and existing installation

All NAS commands and changes below are **operator-run**.

1. Verify no DSM DNS service or other container occupies TCP/UDP 53, and that
   TCP 8081 is free. Identify the existing DNS server before replacing anything.
   The [addressing plan](../../docs/addressing.md) lists Home DNS at
   `192.168.100.2`, while the Synology NAS is `192.168.100.5`. Publishing port 53
   on the NAS does not transfer `.2` or update client DHCP settings. Confirm the
   intended endpoint; preserve the existing resolver during validation.
2. For an existing Pi-hole, record its image version/digest and Compose settings.
   Export settings with Teleporter and keep an independent private backup of its
   full `/etc/pihole` storage and `.env`. Stop the old project before copying that
   storage into this project's `etc-pihole/`, preserving ownership and permissions.
   Keep the original data for rollback; never replace it with the empty example.
3. If upgrading from v5, follow the
   [official v5-to-v6 migration guide](https://docs.pi-hole.net/docker/upgrading/v5-v6/).
   Preserve and temporarily mount the old `/etc/dnsmasq.d` directory when required
   for custom settings and enable `FTLCONF_misc_etc_dnsmasq_d: 'true'`. This project
   does not include that optional migration mount. Validate migrated settings
   before removing it; do not assume v6 data can be used by v5.
4. Upload Compose, the private `.env`, and the persistent directory. Check NAS
   ACLs permit the container to manage it; do not force a container `user` or
   broad recursive permissions without evidence. Review upstream resolvers in
   the UI after startup. Avoid forwarding to a router that forwards back to
   Pi-hole, which creates a DNS loop.

## Start and verify

From the NAS project directory, or through Container Manager:

```sh
docker compose config --quiet
docker compose up -d
docker compose ps
```

Open `http://NAS-IP:8081/admin/` and log in with the private password. Confirm FTL
is healthy, configured upstreams work, and existing lists/local records survived.
From a client with `dig`, replace `NAS-IP` with the intended NAS address:

```sh
dig @NAS-IP example.org
dig +tcp @NAS-IP example.org
```

Check both UDP and TCP answers and confirm the queries appear in Pi-hole's query
log. Also query a known local record and a domain explicitly blocked by your
existing lists; check the blocking result in the UI because response types depend
on the selected blocking mode. Only after acceptance should the operator switch
client/router DNS using the established network procedure. Keep RouterOS/PXE DNS
and DHCP ownership intact.

Ports 53 and 8081 are published on all host interfaces. Permit DNS only from
intended client networks and admin access only from trusted clients; `ALL` is
needed inside the bridge but is not an access control. Keep both ports off the
public internet. The supplied UI endpoint is HTTP; use an existing trusted HTTPS
frontend when administering across networks. No frontend or firewall is changed
by this project. Direct Docker bridge networking may also hide individual client
addresses behind the gateway; verify attribution before relying on client groups.

## Backup and rollback

Retain private Teleporter exports and consistent filesystem backups of
`etc-pihole/` taken with Pi-hole stopped, plus `.env` and the deployed image
reference. Keep an encrypted off-NAS copy. Pi-hole generates and persists its own
runtime state; no external key initializer is needed.

If startup, DNS or migration fails, stop this project and restore the previous
Compose/image and pre-change data. Restore the prior client DNS target if you
changed it. Preserve both data copies; never delete storage to force startup or
run an older major version against migrated data without a compatible backup.

## Validation

On 2026-10-08, local Compose parsing and structural checks passed for the pinned
image, required password input, bridge listening mode, timezone, DNS/UI ports
and relative directory mount. Missing password input was checked to fail closed.
No Pi-hole container, NAS port availability, DNS traffic, upstream resolution,
firewall, migration or live admin login was tested.
