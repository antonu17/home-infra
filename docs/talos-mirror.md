# Talos mirror on Synology

The Synology NAS serves versioned Talos kernel and initramfs assets over HTTP.
The RB5009 remains the sole DHCP authority and serves only the small iPXE
bootstrap files over TFTP.

## Address and flow

Web Station publishes the container through this name-based portal:

```text
http://talos.home.antonu.org
```

Add the mirror name to RouterOS DNS:

```routeros
/ip dns static add address=192.168.100.5 comment="Synology Talos mirror" name=talos.home.antonu.org type=A
```

The same command is stored in `mikrotik/talos-mirror-dns.rsc` for review.

VLAN 100 clients use Pi-hole at `192.168.100.2`; add the same name and address
there as a local DNS record so trusted-network workstations resolve the mirror.

VLAN 400 currently has routed access to the trusted network. If inter-VLAN
policy is tightened later, allow TCP port 80 from `192.168.40.0/24` to
`192.168.100.5`.

## Synology Container Manager deployment

Copy the complete `synology/talos-mirror` directory to the Synology project
directory:

```text
/volume3/labs/talos-mirror
```

The directory must include the downloaded `assets` tree. In Container Manager:

1. Open **Project** and create a new project named `talos-mirror`.
2. Select `/volume3/labs/talos-mirror` as its path.
3. Use the existing `compose.yaml` file.
4. Enable **Set up web portal via Web Station** for the project.
5. Build and start the project.

In Web Station, create or edit the project portal:

1. Select the `talos-mirror` project service and its exposed port `8080`.
2. Choose a **Name-based** portal.
3. Set the hostname to `talos.home.antonu.org`.
4. Enable HTTP on port 80. HTTPS can be added later with a certificate trusted
   by the iPXE build.

The container uses NGINX's verified, version-pinned unprivileged Alpine image.
Compose explicitly publishes NAS port 18080 to container port 8080 so Container
Manager can offer the service in the Web Station portal picker. Nginx runs
without root, writes temporary state only under an in-memory `/tmp`, has a
read-only root filesystem and asset mount, and drops all Linux capabilities.
Web Station remains the normal client-facing endpoint on TCP port 80.

If the portal picker shows **No match found**, confirm that the project has
been recreated after adding the `18080:8080` port mapping. Stopping and starting
an existing container is insufficient because Docker port mappings are fixed
when the container is created.

If DSM Firewall is enabled, permit TCP 80 from `192.168.40.0/24`. Port 18080 is
only a Web Station backend and should not be allowed from client networks.

## Verify before changing iPXE

From a client with access to the NAS:

```sh
curl --fail http://talos.home.antonu.org/healthz
curl --fail --output /dev/null http://talos.home.antonu.org/v1.14.1/kernel-amd64
curl --fail --output /dev/null http://talos.home.antonu.org/v1.14.1/initramfs-amd64.xz
```

Expected health response:

```text
ok
```

Only after these checks pass, upload the repository's updated `boot.ipxe` to
`flash/pxe/boot.ipxe` on the RB5009. The menu retains a public Image Factory
fallback for recovery.

## Mirror another Talos release

Run the supplied script from the Synology directory or another Unix host with
write access to the assets directory:

```sh
./sync.sh v1.14.1
```

The script downloads into temporary files, atomically moves completed assets
into place and records local SHA-256 checksums. Updating the mirror does not
change what machines boot: the version in `boot.ipxe` must be changed and
reviewed separately.
