"""Select the three container interfaces by IPv4 subnet; run SSDP only."""
import fcntl
import ipaddress
import os
import socket
import struct
import time

NETWORKS = (ipaddress.ip_network("192.168.100.0/24"),
            ipaddress.ip_network("192.168.30.0/24"),
            ipaddress.ip_network("192.168.40.0/24"))


def discover_interfaces():
    found = {network: [] for network in NETWORKS}
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        for _, name in socket.if_nameindex():
            try:
                request = struct.pack("256s", name.encode()[:15])
                result = fcntl.ioctl(sock.fileno(), 0x8915, request)  # SIOCGIFADDR
                address = ipaddress.ip_address(socket.inet_ntoa(result[20:24]))
            except OSError:
                continue
            for network in NETWORKS:
                if address in network:
                    found[network].append(name)
    if any(len(names) > 1 for names in found.values()):
        raise RuntimeError("Ambiguous relay interfaces; refusing to start")
    return [found[network][0] for network in NETWORKS] if all(found.values()) else None


def main():
    # DHCP can complete after container startup. No address, route or bridge changes.
    while True:
        interfaces = discover_interfaces()
        if interfaces:
            break
        time.sleep(2)
    os.execvp("python3", ["python3", "/app/multicast-relay.py", "--foreground",
                         "--noMDNS", "--noSonosDiscovery",
                         "--noRemoteRelay", "--interfaces", *interfaces])


if __name__ == "__main__":
    main()
