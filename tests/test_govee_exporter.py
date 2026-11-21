"""Exercise advertisement filtering and the real pinned Govee decoder."""

import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

from prometheus_client import CollectorRegistry

spec = importlib.util.spec_from_file_location(
    "govee_exporter", Path(__file__).parents[1] / "services/govee-exporter.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AdvertisementTests(unittest.TestCase):
    def setUp(self):
        self.registry = CollectorRegistry()
        self.metrics = module.GoveeMetrics(self.registry)
        self.device = SimpleNamespace(name="GVH5075_TEST")

    def send(self, temperature=23.4, humidity=56.7, battery=87, **overrides):
        packed = round(abs(temperature) * 10) * 1000 + round(humidity * 10)
        if temperature < 0:
            packed |= 0x800000
        advertisement = dict(
            local_name=self.device.name,
            manufacturer_data={0xEC88: b"\x00" + packed.to_bytes(3, "big") + bytes([battery, 0])},
            rssi=-65,
        )
        advertisement.update(overrides)
        self.metrics.advertisement(self.device, SimpleNamespace(**advertisement))

    def value(self, name):
        return self.registry.get_sample_value(name, {"sensor": "GVH5075_TEST"})

    def test_positive_temperature_and_humidity_are_independent(self):
        self.send()
        self.assertEqual(self.value("govee_temperature_celsius"), 23.4)
        self.assertEqual(self.value("govee_humidity_percent"), 56.7)
        self.assertEqual(self.value("govee_battery_percent"), 87)
        self.assertGreater(self.value("govee_last_seen_timestamp_seconds"), 0)

    def test_negative_temperature(self):
        self.send(temperature=-12.3)
        self.assertEqual(self.value("govee_temperature_celsius"), -12.3)

    def test_ignored_packets_do_not_refresh_last_seen(self):
        for overrides in [
            {"manufacturer_data": {}},
            {"manufacturer_data": {0xEC88: b"\x00"}},
            {"local_name": "unrelated"},
        ]:
            self.send(**overrides)
        self.send(battery=0x80 | 87)  # Sensor error flag.
        self.send(temperature=100.1)
        self.send(battery=101)
        self.assertIsNone(self.value("govee_last_seen_timestamp_seconds"))

    def test_nameless_advertisement(self):
        self.device.name = None
        self.metrics.advertisement(
            self.device, SimpleNamespace(local_name=None, manufacturer_data={}, rssi=-65)
        )


if __name__ == "__main__":
    unittest.main()
