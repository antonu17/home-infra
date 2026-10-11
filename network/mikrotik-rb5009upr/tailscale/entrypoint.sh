#!/bin/sh
set -eu
# Kernel routing is required; do not silently fall back to a TCP/UDP proxy.
test -c /dev/net/tun || { echo "Missing /dev/net/tun; inspect RouterOS container devices/capabilities" >&2; exit 1; }
mkdir -p /var/lib/tailscale /var/run/tailscale
sysctl -w net.ipv4.ip_forward=1 >/dev/null
# Exit-node routing requires IPv6 forwarding as well.
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
exec tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock --port=41641
