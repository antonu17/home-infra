# Cluster shutdown before NAS reboot

Run from `/Users/anton/projects/home-infra` with direnv loaded:

```sh
bash kubernetes/maintenance/shutdown-cluster.sh
```

**Live change: shuts down all four nodes.** The helper cordons the nodes, then
uses normal Talos shutdown with cordon/drain, waiting for each node:

1. worker-02 — `192.168.40.41`
2. worker-03 — `192.168.40.42`
3. worker-01 — `192.168.40.40` (NAS VM, CSI controller)
4. cp-01 — `192.168.40.21` (NAS VM, sole control plane)

The NAS and CSI controller remain available while physical workers stop and
unmount their iSCSI volumes. The script stops on the first error or timeout;
do not reboot DSM if shutdown fails. Check the affected node before continuing.
Confirm both VMM guests are off and physical workers are halted, then reboot DSM
manually. The Pis need manual power-on afterward.

After DSM and SAN are ready, start cp-01, worker-01 and the Pis. Once Kubernetes
is available, re-enable scheduling:

```sh
kubectl uncordon talos-cp-01 talos-worker-01 talos-worker-02 talos-worker-03
kubectl get nodes
kubectl -n synology-csi get pods -o wide
```

No replica changes, saved state or backup/restore workflow. Normal Talos shutdown
is used without force. Only shell syntax and local CLI options were checked;
cluster shutdown was not executed.
