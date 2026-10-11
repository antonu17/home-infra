FROM ghcr.io/tailscale/tailscale:v1.102.5@sha256:472c549d2ef8cebc000de2c8a94061bbdc864d2454177b2ada713262475449ef
COPY entrypoint.sh /usr/local/bin/home-tailscale
COPY configure.sh /usr/local/bin/configure-tailscale
ENTRYPOINT ["/bin/sh", "/usr/local/bin/home-tailscale"]
