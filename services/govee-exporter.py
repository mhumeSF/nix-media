"""Export H5075 advertisements using the decoder pinned by Nixpkgs."""

import asyncio
import time

from bleak import BleakScanner
from govee_ble.parser import decode_temp_humid_battery_error
from prometheus_client import CollectorRegistry, Gauge, write_to_textfile


METRICS_FILE = "/var/lib/microvms/k3s/persist/govee-metrics/govee.prom"


class GoveeMetrics:
    def __init__(self, registry=None):
        options = {} if registry is None else {"registry": registry}
        self.metrics = [
            Gauge(name, description, ["sensor"], **options)
            for name, description in [
                ("govee_temperature_celsius", "Temperature in degrees Celsius"),
                ("govee_humidity_percent", "Relative humidity in percent"),
                ("govee_battery_percent", "Battery remaining in percent"),
                ("govee_rssi_dbm", "Bluetooth signal strength in dBm"),
                ("govee_last_seen_timestamp_seconds", "Unix time of last valid reading"),
            ]
        ]

    def advertisement(self, device, advertisement):
        name = advertisement.local_name or device.name or ""
        if not name.startswith("GVH5075_"):
            return
        payload = advertisement.manufacturer_data.get(0xEC88, b"")
        if len(payload) != 6:
            return
        temperature, humidity, battery, error = decode_temp_humid_battery_error(
            payload[1:5]
        )
        if error or not (-40 <= temperature <= 100 and 0 <= humidity <= 100 and 0 <= battery <= 100):
            return
        for metric, value in zip(
            self.metrics, (temperature, humidity, battery, advertisement.rssi, time.time())
        ):
            metric.labels(sensor=name).set(value)


async def main():
    registry = CollectorRegistry()
    metrics = GoveeMetrics(registry)
    heartbeat = Gauge(
        "govee_exporter_last_write_timestamp_seconds",
        "Unix time the Bluetooth collector last wrote its metrics",
        registry=registry,
    )
    # BlueZ performs discovery; no pairing, cloud account or GATT connection.
    async with BleakScanner(metrics.advertisement, adapter="hci0"):
        while True:
            heartbeat.set(time.time())
            # Atomic replacement keeps node exporter from reading a partial file.
            write_to_textfile(METRICS_FILE, registry)
            await asyncio.sleep(15)


if __name__ == "__main__":
    asyncio.run(main())
