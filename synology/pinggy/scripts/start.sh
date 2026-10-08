#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${TELEGRAM_BOT_TOKEN:?Set TELEGRAM_BOT_TOKEN privately}"
test -s /mnt/ssh/authorized_keys || { echo "Missing authorized_keys" >&2; exit 1; }
test -s /mnt/ssh/config || { echo "Missing SSH client config" >&2; exit 1; }
key=/var/lib/ssh-host-keys/ssh_host_ed25519_key
if [ ! -e "$key" ]; then
    ssh-keygen -q -t ed25519 -N '' -f "$key"
fi
mkdir -p /run/sshd /run/pinggy
# Uploaded scripts may be root-only on DSM. Copy only code into private runtime
# storage; leave host ownership and ACLs unchanged.
chmod 0755 /run/pinggy
cp /app/pinggy.py /run/pinggy/pinggy.py
chmod 0644 /run/pinggy/pinggy.py
su-exec tunnel:tunnel test -r /run/pinggy/pinggy.py || { echo "Runtime script is unreadable" >&2; exit 1; }
# Copy read-only NAS SSH material into ephemeral storage with container ownership.
# Refuse symlinks so copies cannot unexpectedly reference files outside this mount.
if [ -n "$(find /mnt/ssh -type l -print -quit)" ]; then
    echo "SSH source contains symlinks; supply regular files instead" >&2
    exit 1
fi
mkdir -p /run/pinggy/ssh
cp -R /mnt/ssh/. /run/pinggy/ssh/
# Reclaim a runtime copy left by an earlier process before setting modes.
chown -R root:root /run/pinggy/ssh
# Set modes while root owns the copy; CAP_FOWNER is intentionally absent.
find /run/pinggy/ssh -type d -exec chmod 0700 {} +
find /run/pinggy/ssh -type f -exec chmod 0600 {} +
chown -R tunnel:tunnel /run/pinggy/ssh
/usr/sbin/sshd -t
/usr/sbin/sshd -D -e &
sshd_pid=$!
su-exec tunnel:tunnel python3 -B /run/pinggy/pinggy.py &
tunnel_pid=$!
cleanup() {
    trap - TERM INT EXIT
    kill -TERM "$tunnel_pid" "$sshd_pid" 2>/dev/null || true
    wait "$tunnel_pid" 2>/dev/null || true
    wait "$sshd_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT
set +e
wait -n "$sshd_pid" "$tunnel_pid"
result=$?
exit "$result"
