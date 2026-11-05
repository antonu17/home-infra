import base64
import ipaddress
import json
import logging
import os
import socket
import struct
import time
import urllib.parse
import urllib.request

OWNER = "thread-rio-sync/v1 "
ROUTERS = {"fe80::4a27:e2ff:fed2:9e08": 10, "fe80::1821:9359:33fb:fa36": 20}
ULA = ipaddress.IPv6Network("fc00::/7")


def parse(packet):
    if len(packet) < 16 or packet[:2] != b"\x86\0":
        return {}
    routes = {}
    offset = 16
    while offset < len(packet):
        if offset + 2 > len(packet):
            return {}
        kind, units = packet[offset:offset + 2]
        end = offset + 8 * units
        if units == 0 or end > len(packet):
            return {}
        if kind == 24 and units in (2, 3):
            length, flags, lifetime = struct.unpack_from("!BBI", packet, offset + 2)
            if length == 64 and (flags & 0x18) != 0x10:
                prefix = ipaddress.IPv6Network((packet[offset + 8:offset + 16] + bytes(8), 64))
                if prefix.subnet_of(ULA):
                    if prefix in routes:
                        return {}
                    routes[prefix] = lifetime
        offset = end
    return routes


class Router:
    def __init__(self):
        url = urllib.parse.urlsplit(os.environ["ROS_URL"])
        if url.scheme != "https" or not url.hostname or url.username or url.path not in ("", "/") or url.query or url.fragment:
            raise ValueError("ROS_URL must be an HTTPS origin")
        self.url = f"https://{url.netloc}/rest/ipv6/route"
        credentials = os.environ["ROS_USER"] + ":" + os.environ["ROS_PASSWORD"]
        self.auth = "Basic " + base64.b64encode(credentials.encode()).decode()
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, method, path="", body=None):
        request = urllib.request.Request(
            self.url + path, method=method,
            headers={"Authorization": self.auth, "Content-Type": "application/json"},
            data=None if body is None else json.dumps(body).encode(),
        )
        with self.opener.open(request, timeout=3) as response:
            data = response.read()
        return json.loads(data) if data else None


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def sync(router, desired, expired, startup_deadline=None):
    owned = {}
    for row in router.request("GET"):
        comment = row.get("comment", "")
        if comment.startswith(OWNER):
            if comment in owned:
                raise ValueError("duplicate managed route: " + comment)
            owned[comment] = row
    if startup_deadline is not None and time.monotonic() >= startup_deadline:
        expired.update(set(owned) - set(desired))
    for comment, fields in desired.items():
        row = owned.get(comment)
        if row is None:
            router.request("PUT", body={**fields, "comment": comment})
            logging.info("added %s", comment)
        elif any(str(row.get(key)) != value for key, value in fields.items()) or row.get("disabled") in ("true", True):
            router.request("PATCH", "/" + urllib.parse.quote(row[".id"], safe="*"),
                           {**fields, "disabled": "false"})
            logging.info("reconciled %s", comment)
    for comment in expired:
        row = owned.get(comment)
        if row:
            router.request("DELETE", "/" + urllib.parse.quote(row[".id"], safe="*"))
            logging.info("removed %s", comment)


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    router = Router() if os.environ.get("RIO_APPLY") == "1" else None
    index = socket.if_nametoindex(os.environ.get("RIO_INTERFACE", "veth-thread-rio"))
    group = socket.inet_pton(socket.AF_INET6, "ff02::1")
    sock = socket.socket(socket.AF_INET6, socket.SOCK_RAW, socket.IPPROTO_ICMPV6)
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_RECVHOPLIMIT, 1)
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_RECVPKTINFO, 1)
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_JOIN_GROUP, group + struct.pack("=I", index))
    sock.settimeout(1)
    leases, expired = {}, set()
    previous = None
    next_sync = 0
    startup_deadline = time.monotonic() + 1800
    while True:
        try:
            packet, ancillary, flags, peer = sock.recvmsg(65535, 256)
        except TimeoutError:
            packet = None
        if packet and not flags & (socket.MSG_TRUNC | socket.MSG_CTRUNC):
            metadata = {kind: data for level, kind, data in ancillary if level == socket.IPPROTO_IPV6}
            hop = metadata.get(socket.IPV6_HOPLIMIT, b"")
            info = metadata.get(socket.IPV6_PKTINFO, b"")
            source = peer[0].split("%", 1)[0]
            if source in ROUTERS and hop == struct.pack("=i", 255) and info[16:] == struct.pack("=I", index):
                for prefix, lifetime in parse(packet).items():
                    key = (prefix, source)
                    leases[key] = time.monotonic() + lifetime
        now = time.monotonic()
        if now < next_sync:
            continue
        next_sync = now + 5
        desired = {}
        for (prefix, source), deadline in list(leases.items()):
            comment = OWNER + f"{prefix} via {source}"
            if deadline <= now:
                expired.add(comment)
                del leases[prefix, source]
            else:
                expired.discard(comment)
                desired[comment] = {
                    "dst-address": str(prefix), "gateway": source + "%vlan300-iot",
                    "routing-table": "main", "distance": str(ROUTERS[source]),
                }
        if set(desired) != previous:
            logging.info("desired routes: %s", sorted(desired))
            previous = set(desired)
        try:
            if router:
                sync(router, desired, expired, startup_deadline)
            expired.clear()
        except (OSError, ValueError) as exc:
            logging.error("route sync failed: %s", exc)


if __name__ == "__main__":
    main()
