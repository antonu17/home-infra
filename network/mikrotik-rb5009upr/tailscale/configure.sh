#!/bin/sh
set -eu
# Run after interactive authentication. These preferences persist in the state mount.
exec tailscale set --hostname=home-rb5009 --accept-dns=false --accept-routes=false \
  --advertise-routes=10.40.0.0/24,192.168.40.0/24,192.168.100.0/24 \
  --snat-subnet-routes=true --advertise-exit-node=true
