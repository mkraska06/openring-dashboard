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

At this point the data is still a protocol packet. It has not yet become a
heart-rate value, battery snapshot, or activity record.

## Packet Parsing

[ScanPageNotifier](../lib/src/ui/scan_page_controller.dart) subscribes to the
packet stream after a successful connection. For each packet, it checks the
command byte and delegates to the matching parser in
[lib/src/protocol/](../lib/src/protocol/).

Examples:

| Packet type | Parser/output |
| --- | --- |
| Battery response | [parseBatteryResponse](../lib/src/protocol/battery.dart) -> `BatteryResponse` |
| Real-time reading | [parseRealTimeResponse](../lib/src/protocol/real_time.dart) -> `RealTimeReading` |
| Heart-rate log | [HrLogParser](../lib/src/protocol/hr_log.dart) -> `HrLogResult` |
| Step/activity log | [StepParser](../lib/src/protocol/steps.dart) -> `StepEntry` list |
| Daily activity notification | [parseDailyActivityNotification](../lib/src/protocol/activity.dart) -> `DailyActivitySnapshot` |
| Accelerometer packet | [parseAccelerometerResponse](../lib/src/protocol/accelerometer.dart) -> `AccelerometerReading` |

The protocol layer stays deterministic: it receives bytes and returns parsed
values or `null`. It does not know about widgets, windows, or the database.

## State Updates

After parsing, [ScanPageNotifier](../lib/src/ui/scan_page_controller.dart)
updates `ScanPageState`. That state is the current live model used by the
dashboard and overlay.

Examples:

- `battery` is updated after a battery response.
- `realTimeReadings` is updated after a heart-rate, SpO2, or HRV response.
- `steps` is updated after step log sync.
- `dailyActivity` is updated after a daily activity notification.
- `lastAccel` is updated after an accelerometer packet.
- `motionRecording` and `motionRecordings` are updated while Motion Lab
  recordings are started, loaded, or extended with accelerometer samples.

This means the live UI can react immediately, before or independently of any
history view reload.

## Persistence

When a parsed value should become history, the controller writes it through
[OpenRingStorage](../lib/src/storage/storage_repository.dart). Storage writes
are intentionally separated from packet parsing.

```text
parsed value
  -> ScanPageNotifier
  -> OpenRingStorage
  -> Drift
  -> SQLite
```

Current persistence behavior:

| Data | Storage path |
| --- | --- |
| Discovered or connected ring | [upsertDevice / setLastConnectedDevice](../lib/src/storage/storage_repository.dart) |
| Battery response | [insertBatterySnapshot](../lib/src/storage/storage_repository.dart) |
| Live HR, SpO2, HRV | [persistRealTimeReading](../lib/src/storage/storage_repository.dart) -> `insertVitalSample` |
| Heart-rate log entries | [insertHrLogEntries](../lib/src/storage/storage_repository.dart) -> `vital_samples` |
| Step log entries | [insertStepEntries](../lib/src/storage/storage_repository.dart) -> `activity_intervals` |
| Motion recording start | [startMotionSession](../lib/src/storage/storage_repository.dart) -> `motion_sessions` |
| Motion sample | [appendMotionSample](../lib/src/storage/storage_repository.dart) -> `motion_samples` |
| Motion recording stop | [stopMotionSession](../lib/src/storage/storage_repository.dart) -> `motion_sessions.ended_at` |

Storage writes are fire-and-forget from the controller. If a write fails, the
error is surfaced in the page state, but the BLE packet stream can continue
running.

## History Flow

The history view does not read packets directly. It loads already persisted data
from SQLite through the storage repository.

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

## Data Export Flow

The export feature does not read live BLE packets. It loads already stored rows
from SQLite, maps them into export models, and formats the selected result for
the user.

```text
Export request
  -> DataExportNotifier
  -> ExportRepository
  -> SQLite rows
  -> ExportBundle
  -> formatExportBundle(...)
  -> CSV / JSON file
```

The [ExportRepository](../lib/src/data_export/export_repository.dart) can load
vital samples, battery snapshots, activity intervals, and motion samples for the
selected date range. The formatter in
[lib/src/data_export/export_formatter.dart](../lib/src/data_export/export_formatter.dart)
then converts the loaded bundle to CSV or JSON. This keeps export behavior
independent from the active ring connection.

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
[BleService](../lib/src/ble/ble_service.dart).

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


## AI Assistance Disclosure

This document was checked and corrected with AI assistance to ensure that the
data-flow description matches the existing project source code. The content was
reviewed by the author.
