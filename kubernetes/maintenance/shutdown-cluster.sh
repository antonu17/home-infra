#!/usr/bin/env bash
# Operator-run: gracefully shut down the home-cloud cluster before NAS maintenance.
set -euo pipefail

: "${KUBECONFIG:?Load the repository direnv environment first}"
: "${TALOSCONFIG:?Load the repository direnv environment first}"
command -v kubectl >/dev/null
command -v talosctl >/dev/null

# Prevent workloads moving onto another node that is about to shut down.
kubectl cordon talos-worker-02 talos-worker-03 talos-worker-01 talos-cp-01

# Keep worker-01 (CSI controller) and cp-01 (API/etcd) running until last.
for node in 192.168.40.41 192.168.40.42 192.168.40.40 192.168.40.21; do
    printf '\nGracefully shutting down %s\n' "$node"
    talosctl --endpoints 192.168.40.21 --nodes "$node" shutdown --wait --timeout 15m
done

printf '\nShutdown requests completed. Confirm all nodes are halted and both VMM guests are off before rebooting DSM.\n'
