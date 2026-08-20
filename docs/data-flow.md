# Data Flow

This document focuses on the concrete runtime data paths in OpenRing Desktop.
The broader module overview is documented in [architecture.md](architecture.md).

## Incoming Data

The ring sends data as BLE notifications on its Nordic UART-style TX
characteristic. [BleService](../lib/src/ble/ble_service.dart) receives those
raw bytes, validates packet length and checksum with
[validatePacket](../lib/src/protocol/packet.dart), and emits only valid
16-byte packets through its packet stream.

```text
UniversalBle notification
  -> BleService.characteristicValueStream(...)
  -> validatePacket(...)
  -> BleService.packetStream
```

At this point the data is still a protocol packet.

## Packet Parsing

After a successful connection,
[ScanPageNotifier](../lib/src/ui/scan_page_controller.dart) starts listening to
the packet stream exposed by `BleService`. For each packet, it checks the
command byte and delegates to the matching parser in
[lib/src/protocol/](../lib/src/protocol/).

Examples:

| Incoming packet | Parser |
| --- | --- |
| Battery data | [parseBatteryResponse](../lib/src/protocol/battery.dart) |
| Live vital reading | [parseRealTimeResponse](../lib/src/protocol/real_time.dart) |
| Heart-rate history | [HrLogParser](../lib/src/protocol/hr_log.dart) |
| Step/activity history | [StepParser](../lib/src/protocol/steps.dart) |
| Daily activity notification | [parseDailyActivityNotification](../lib/src/protocol/activity.dart) |
| Accelerometer data | [parseAccelerometerResponse](../lib/src/protocol/accelerometer.dart) |

## State Updates

After parsing, `ScanPageNotifier` updates `ScanPageState`. That state is the
current live model used by the dashboard and overlay.

This live state contains the values that can change while the ring is connected,
such as current vital readings, battery status, step data, accelerometer data and
Motion Lab recording state. The dashboard and overlay read from this state
directly, while the history view loads stored data separately from SQLite.

## Local Storage

When a parsed value should become history, the controller writes it through the
local storage repository.

```text
parsed value
  -> ScanPageNotifier
  -> local storage repository
  -> Drift
  -> SQLite
```

The storage methods are implemented in
[storage_repository.dart](../lib/src/storage/storage_repository.dart).

The full SQLite schema is documented in
[database-schema.md](database-schema.md).

## History Flow

The history view does not read packets directly. It loads already stored data
from SQLite through the storage repository.

[HistoryPageNotifier](../lib/src/history/history_page_controller.dart) handles
the selected day and triggers history loading.

```text
History page
  -> HistoryPageNotifier
  -> OpenRingStorage.loadHistoryDay(...)
  -> SQLite rows
  -> HistoryDay model
  -> chart models/widgets
```

[loadHistoryDay](../lib/src/storage/storage_repository.dart) resolves the
selected ring, loads vital samples and activity intervals for the selected local
day, and maps them into history models.

Live heart-rate samples need special display handling because the ring reports
values in measurement blocks. That timestamp reconstruction is documented in
[live-heart-rate-history.md](live-heart-rate-history.md).


## Overlay Flow

The overlay does not open a second BLE connection and does not own a separate
data pipeline. It reads the same application state as the main dashboard.

```text
ScanPageState
  -> OverlayWidget
  -> HR / SpO2 / battery / steps display
```

This is important because Colmi rings support only one active BLE connection.
OpenRing keeps one connection alive and changes the window mode instead of
creating a second app or second BLE client.

The [OverlayWidget](../lib/src/overlay/overlay_widget.dart) currently reads:

- connection status from `bleStatusProvider`
- heart rate and SpO2 from `realTimeReadings`
- battery state from `battery`
- steps from `dailyActivity` or synced step entries
- display preferences from `overlaySettingsProvider`

## Outgoing Commands

User actions start as widget callbacks. Widgets call the controller, and the
controller calls [ScanPageUseCases](../lib/src/ui/scan_page_use_cases.dart).
The use-case layer builds or sends the appropriate command through
`BleService`.

```text
Button press
  -> ScanPageNotifier method
  -> ScanPageUseCases method
  -> protocol command builder
  -> BleService.sendPacket(...)
  -> ring RX characteristic
```

Examples:

| User intent | Flow |
| --- | --- |
| Scan for rings | widget -> [startScan](../lib/src/ui/scan_page_controller.dart) -> `BleService.startScan` |
| Connect ring | widget -> [connect](../lib/src/ui/scan_page_controller.dart) -> `BleService.connect` |
| Request battery | controller -> [requestBattery](../lib/src/ui/scan_page_use_cases.dart) -> battery packet |
| Start real-time HR | controller -> [startRealTime](../lib/src/ui/scan_page_use_cases.dart) -> real-time packet |
| Sync ring time | controller -> [syncTime](../lib/src/ui/scan_page_controller.dart) -> set-time packet |
| Blink ring | controller -> [blinkTwice](../lib/src/ui/scan_page_controller.dart) -> utility packet |
| Reboot ring | controller -> [reboot](../lib/src/ui/scan_page_controller.dart) -> utility packet |
