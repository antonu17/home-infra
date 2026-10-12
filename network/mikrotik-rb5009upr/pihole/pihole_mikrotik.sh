#!/bin/sh
# acme.sh deploy hook: full chain + private key -> RouterOS Pi-hole data mount.
pihole_mikrotik_deploy() (
    # acme.sh logging helpers allow unset optional configuration variables.
    set -e
    umask 077
    for binary in openssl ssh sftp curl cmp mktemp; do
        command -v "$binary" >/dev/null 2>&1 || { _err "Missing dependency: $binary"; exit 1; }
    done
    # The existing certificate's deploy-hook list owns renewal scheduling.
    # A dedicated SSH alias carries identity and pinned host-key configuration.
    workdir=${LE_WORKING_DIR:-"$HOME/.acme.sh"}
    # DSM deploy runs as root; resolve SSH files beside the acme.sh installation.
    # Do not rely on the process HOME or root's implicit OpenSSH configuration.
    sshdir=$(cd "$workdir/.." && pwd)/.ssh
    for file in "$sshdir/config" "$sshdir/pihole-acme" "$sshdir/known_hosts"; do
        [ -s "$file" ] || { _err "Missing dedicated SSH configuration/key/known_hosts"; exit 1; }
    done
    lock="$workdir/.pihole-mikrotik.lock"
    mkdir "$lock" 2>/dev/null || { _err "Pi-hole certificate deployment is already locked: $lock"; exit 1; }
    tmp=''
    cleanup() { [ -z "$tmp" ] || rm -rf "$tmp"; rmdir "$lock"; }
    trap cleanup EXIT
    trap 'exit 1' HUP INT TERM
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/pihole-acme.XXXXXX") || exit 1
    [ "$#" -ge 5 ] || { _err "Expected at least domain/key/cert/CA/fullchain arguments"; exit 1; }
    key=$2
    cert=$3
    ca=$4
    fullchain=$5
    for file in "$key" "$cert" "$ca" "$fullchain"; do
        [ -s "$file" ] || { _err "Missing certificate input"; exit 1; }
    done
    openssl x509 -in "$cert" -checkend 86400 -noout >/dev/null 2>&1 || { _err "Certificate expires within 24 hours"; exit 1; }
    openssl verify -purpose sslserver -verify_hostname pihole.home.antonu.org -untrusted "$ca" "$cert" >/dev/null 2>&1 || { _err "Certificate chain/hostname validation failed"; exit 1; }
    openssl pkey -in "$key" -passin pass: -pubout -outform DER -out "$tmp/key.pub" 2>/dev/null || { _err "Certificate parsing failed"; exit 1; }
    openssl x509 -in "$cert" -pubkey -noout > "$tmp/cert.pub.pem" || { _err "Certificate parsing failed"; exit 1; }
    openssl pkey -pubin -in "$tmp/cert.pub.pem" -outform DER -out "$tmp/cert.pub" 2>/dev/null || { _err "Certificate parsing failed"; exit 1; }
    cmp -s "$tmp/key.pub" "$tmp/cert.pub" || { _err "Certificate and private key do not match"; exit 1; }
    # Ensure acme.sh's fullchain starts with the validated leaf certificate.
    openssl x509 -in "$cert" -outform DER -out "$tmp/leaf.der" || { _err "Certificate parsing failed"; exit 1; }
    openssl x509 -in "$fullchain" -outform DER -out "$tmp/chain-leaf.der" || { _err "Certificate parsing failed"; exit 1; }
    cmp -s "$tmp/leaf.der" "$tmp/chain-leaf.der" || { _err "Fullchain leaf mismatch"; exit 1; }
    cat "$fullchain" > "$tmp/tls.pem" || exit 1
    printf '\n' >> "$tmp/tls.pem" || exit 1
    cat "$key" >> "$tmp/tls.pem" || exit 1
    # SSH host-key checking and key-only authentication are also forced here.
    if ! sftp -F "$sshdir/config" -i "$sshdir/pihole-acme" -oUserKnownHostsFile="$sshdir/known_hosts" -oBatchMode=yes -oStrictHostKeyChecking=yes -oPasswordAuthentication=no -b - rb5009-pihole-acme <<EOF
put "$tmp/tls.pem" "flash/volumes/pihole/tls.pem.next"
EOF
    then
        _err "SFTP upload failed; certificate unchanged"
        exit 1
    fi
    ssh -F "$sshdir/config" -i "$sshdir/pihole-acme" -oUserKnownHostsFile="$sshdir/known_hosts" -oBatchMode=yes -oStrictHostKeyChecking=yes -oPasswordAuthentication=no rb5009-pihole-acme '/system script run pihole-install-cert' > "$tmp/router-result" || { _err "Router SSH activation failed; inspect remote state"; exit 1; }
    grep -q '^PIHOLE_TLS_INSTALLED' "$tmp/router-result" || { _err "Router certificate installation/readiness failed; inspect pihole-install-cert"; exit 1; }
    # Pin the container IP; renewal does not depend on current DNS caches.
    ready=0
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        if curl --pinnedpubkey "$tmp/cert.pub.pem" --noproxy '*' --silent --fail --connect-timeout 3 --max-time 5 --resolve pihole.home.antonu.org:443:172.31.254.2 https://pihole.home.antonu.org/admin/ -o /dev/null; then
            ready=1
            break
        fi
        sleep 2
    done
    [ "$ready" -eq 1 ] || { _err "Pi-hole HTTPS validation failed; tls.pem.previous retained for rollback"; exit 1; }
    _info "Pi-hole TLS deployed and verified"
)
