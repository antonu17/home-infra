import importlib.util
import ipaddress
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location("rio_sync", Path(__file__).with_name("sync.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FakeRouter:
    def __init__(self, rows):
        self.rows = rows
        self.calls = []

    def request(self, method, path="", body=None):
        self.calls.append((method, path, body))
        return self.rows if method == "GET" else None


class Tests(unittest.TestCase):
    def test_rio_validation(self):
        header = b"\x86\0" + bytes(14)
        option = struct.pack("!BBBBI", 24, 2, 64, 0, 1800) + bytes.fromhex("fd9772fcf25f0001")
        prefix = ipaddress.IPv6Network("fd97:72fc:f25f:1::/64")
        self.assertEqual(module.parse(header + option), {prefix: 1800})
        self.assertEqual(module.parse(header + option[:-1]), {})
        self.assertEqual(module.parse(header + option + option), {})
        self.assertEqual(module.parse(header + bytes([24, 0])), {})
        withdrawn = option[:4] + bytes(4) + option[8:]
        self.assertEqual(module.parse(header + withdrawn), {prefix: 0})

    def test_restart_cleanup_preserves_manual_routes(self):
        comment = module.OWNER + "old"
        router = FakeRouter([{".id": "*1", "comment": "manual"},
                             {".id": "*2", "comment": comment}])
        module.sync(router, {}, set(), float("inf"))
        self.assertEqual(len(router.calls), 1)
        module.sync(router, {}, set(), 0)
        self.assertEqual(router.calls[-1], ("DELETE", "/*2", None))

    def test_creation_and_disabled_route_reconciliation(self):
        comment = module.OWNER + "new"
        desired = {comment: {"distance": "10"}}
        router = FakeRouter([])
        module.sync(router, desired, set())
        self.assertEqual(router.calls[-1][0], "PUT")
        router = FakeRouter([{".id": "*2", "comment": comment, "distance": "10", "disabled": "true"}])
        module.sync(router, desired, set())
        self.assertEqual(router.calls[-1], ("PATCH", "/*2", {"distance": "10", "disabled": "false"}))


if __name__ == "__main__":
    unittest.main()
