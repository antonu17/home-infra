# Pi-hole TLS and certificate renewal

Pi-hole terminates TLS for `pihole.home.antonu.org`. Synology's existing
acme.sh ECC certificate for `home.antonu.org` / `*.home.antonu.org` supplies
the leaf, chain and key. RouterOS's certificate store is not involved.

File21 sets:

| Environment | Value |
| --- | --- |
| `FTLCONF_webserver_domain` | `pihole.home.antonu.org` |
| `FTLCONF_webserver_port` | `80r,443s` |
| `FTLCONF_webserver_tls_cert` | `/etc/pihole/tls.pem` |
| `FTLCONF_webserver_tls_validity` | `0` |

`80r` redirects HTTP to HTTPS. Both ports are mandatory. Pi-hole's initial
self-signed bundle is replaced by the wildcard bundle. Use the hostname:
the wildcard does not cover the container IP or `pi.hole`.

`pihole_mikrotik.sh` is an acme.sh deploy hook installed in
`~/.acme.sh/deploy/`. Before upload it checks chain trust, hostname, expiry,
key matching and the fullchain leaf. It uploads fullchain followed by private
key to `flash/volumes/pihole/tls.pem.next` over SFTP, then invokes the managed
`pihole-install-cert` RouterOS script. The script stops Pi-hole, waits up to
30 seconds, renames the old bundle to `tls.pem.previous`, installs the staged
bundle and starts Pi-hole. DNS readiness is checked before reporting success;
the hook also verifies HTTPS chain, hostname and the deployed public key
from Synology. A successful
hook requires both checks; failures return nonzero to acme.sh. Existing renewal
logging/notification handles that result; no new scheduler is installed.

Renewal briefly interrupts DNS because the container restarts to load the
certificate. Router DNS stays pointed at Pi-hole. Synology availability is
needed for renewal, not ongoing DNS or TLS serving. The wildcard private key
is duplicated onto router flash; protect router access and encrypted backups.
RouterOS RBAC does not restrict this account to one directory or script:
`ssh,ftp,read,write,test` permits broader file/configuration operations. Source
IP restriction, a dedicated key and scoped firewall access bound this trust.

## Deployment (live changes)

Key/configuration setup runs as `anton`, who owns the existing `~/.acme.sh`.
Certificate deployment runs as root: the DSM hook creates a temporary admin
user. Pass all acme.sh paths explicitly; `--force` bypasses its sudo guard
without reissuing a certificate during `--deploy`. The Pi-hole hook explicitly
loads SSH config, identity and known_hosts from `.ssh` beside the acme.sh
installation, including when the process HOME is `/root`.
Require OpenSSH `ssh`/`sftp`, OpenSSL with `verify -verify_hostname`, and curl
with `--pinnedpubkey` support and a working system CA bundle. Check versions before registration; missing
CA trust or an unsupported OpenSSL option stops deployment before upload.

Generate a dedicated key on Synology, retaining an existing key if present:

```sh
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ ! -e "$HOME/.ssh/pihole-acme" ] && [ ! -e "$HOME/.ssh/pihole-acme.pub" ]; then
    ssh-keygen -t ed25519 -N '' -f "$HOME/.ssh/pihole-acme" -C pihole-acme
fi
chmod 600 "$HOME/.ssh/pihole-acme"
```

Upload only `pihole-acme.pub` from Synology to the router's top-level file
list. Upload the updated files09/21 and new file23 from this directory.
File23 creates a disabled account with a random password, imports the public
key if no key is registered and enables the account only when a key exists.
Repeat imports retain the key and password. No private key is uploaded.

```routeros
/import file-name=09-firewall-filter.rsc verbose=yes dry-run
/import file-name=09-firewall-filter.rsc
/import file-name=23-pihole-tls.rsc verbose=yes dry-run
/import file-name=23-pihole-tls.rsc
/ip service print detail where name="ssh"
```

File23 adds exactly NAS `192.168.40.5` → router `192.168.40.1` TCP22 input and
NAS → Pi-hole `172.31.254.2` TCP443 forward rules. File09 preserves them ahead
of default deny. The SSH service must be enabled on port22 and its service
address restriction must permit `192.168.40.5/32`; file23 does not broaden a
shared SSH service restriction automatically. Keep SSH password login disabled
for accounts with imported keys (`/ip ssh` default `always-allow-password-login=no`).

Append the stanza from `ssh-config.example` to Synology `~/.ssh/config`,
preserving other hosts. Set mode600. Establish and verify the router host key
once through a trusted local session; compare its fingerprint before adding
it to `~/.ssh/known_hosts`. Do not use `StrictHostKeyChecking=no` or blindly
trust `ssh-keyscan` output. The alias is `rb5009-pihole-acme`.

Apply file21 during a brief DNS maintenance window:

```routeros
/container stop [find where name="pihole"]
/container print detail where name="pihole"
```

Wait for STOPPED, then:

```routeros
/import file-name=21-pihole-container.rsc
/container start [find where name="pihole"]
```

Copy `pihole_mikrotik.sh` to Synology `~/.acme.sh/deploy/pihole_mikrotik.sh`
and set mode700. Existing issuance, DNS-provider credentials and scheduling
remain in the current acme.sh configuration. Register both the existing hook(s)
and the new hook in the same command. First inspect only the hook-list field:

```sh
sed -n '/^Le_DeployHook=/p' "$HOME/.acme.sh/home.antonu.org_ecc/home.antonu.org.conf"
```

If the existing hook is `synology_dsm`, registration is:

```sh
sudo "$HOME/.acme.sh/acme.sh" \
    --home "$HOME/.acme.sh" \
    --config-home "$HOME/.acme.sh" \
    --cert-home "$HOME/.acme.sh" \
    --deploy -d home.antonu.org --ecc \
    --deploy-hook synology_dsm,pihole_mikrotik --force
```

For a different existing list, retain every hook and append `pihole_mikrotik`.
Do not register only the new hook: acme.sh replaces the saved deploy-hook list.
This deploys the existing certificate immediately and saves the list for future
successful renewals; no reissue is needed. Renewal scheduling must run with
root privileges and these same explicit paths when using DSM temporary-admin
authentication; verify the existing task rather than creating a second schedule. The existing DSM hook
also runs, so its credentials and target must still be valid. If installation
uses a reload command rather than a deploy hook, preserve that reload command
and register `pihole_mikrotik` as the deploy hook. Do not print full account or
domain configuration files: they can contain deployment credentials.

## Verification (read-only)

From Home:

```sh
curl -I http://pihole.home.antonu.org/admin/
curl -I https://pihole.home.antonu.org/admin/
dig example.com
```

HTTP must return a redirect with an HTTPS Location. HTTPS must validate without
`-k` and show the wildcard certificate's current expiry. DNS must still resolve
through the router. Compare the public leaf fingerprint served by Pi-hole with
`~/.acme.sh/home.antonu.org_ecc/home.antonu.org.cer` after initial deployment
and renewal. Do not inspect or paste the combined PEM; it contains the private key.

## Rollback (live changes)

If certificate activation or HTTPS verification fails, `tls.pem.previous`
contains the prior bundle. If file activation itself fails, the install script
attempts to restore it automatically. DNS readiness or HTTPS failures retain
both bundles for inspection and explicit rollback. Interrupted SSH sessions can
leave uncertain remote state; inspect container status and filenames before retry.
Do not rerun the hook until deciding whether to restore the prior bundle, since
another activation rotates the backup. A killed hook can leave the Synology
`~/.acme.sh/.pihole-mikrotik.lock` directory; remove it only after confirming no
deployment process is active.

Stop Pi-hole and wait for STOPPED. Require `tls.pem.previous` and no existing
`tls.pem.failed`, then preserve the failed bundle and restore the previous one:

```routeros
/file set [find where name="flash/volumes/pihole/tls.pem"] name="flash/volumes/pihole/tls.pem.failed"
/file set [find where name="flash/volumes/pihole/tls.pem.previous"] name="flash/volumes/pihole/tls.pem"
/container start [find where name="pihole"]
```

Verify DNS and HTTPS. To retire renewal, remove only `pihole_mikrotik` from the
saved deploy-hook list through acme.sh registration while retaining existing
hooks, and disable `pihole-acme`. Preserve the installed certificate until its
replacement is serving successfully. Re-importing file23 enables an account
with a registered key, so do not re-import it during retirement.

## References and validation

- [Pi-hole TLS and custom certificates](https://docs.pi-hole.net/api/tls/)
- [Pi-hole webserver ports and TLS settings](https://docs.pi-hole.net/ftldns/configfile/#webserver)
- [acme.sh deploy hooks](https://github.com/acmesh-official/acme.sh/wiki/deployhooks)
- [RouterOS user policy and SSH keys](https://help.mikrotik.com/docs/spaces/ROS/pages/8978504/User)

Shell syntax, certificate validation failures and local mocked delivery are
checked offline. RouterOS import, SFTP permissions, certificate activation and
renewal execution require acceptance on the router/Synology installation.
