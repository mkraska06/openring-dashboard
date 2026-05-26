# Data Flow

This document explains how data moves through OpenRing Desktop: from the Colmi
ring into the app, into local storage, and finally into the dashboard, history
view, or overlay.

OpenRing keeps the flow explicit because the app talks directly to hardware.
BLE transport, packet parsing, persistence, and widgets each have a different
job and should not be mixed together.

## High-Level Flow

```text
Colmi ring
  -> BLE notification
  -> BleService
  -> protocol parser
  -> ScanPageNotifier
  -> OpenRingStorage
  -> dashboard / history / overlay
```

Commands travel in the opposite direction:

```text
User action
  -> widget callback
  -> ScanPageNotifier
  -> ScanPageUseCases
  -> BleService
  -> protocol command packet
  -> Colmi ring
```

The important rule is that widgets do not build packets and do not send BLE
commands directly. They express user intent, and the controller/use-case layer
turns that intent into protocol commands.

## Incoming Data

The ring sends data as BLE notifications on its Nordic UART-style TX
characteristic. `BleService` receives those raw bytes, validates packet length
and checksum, and emits only valid 16-byte packets through its packet stream.

```text
UniversalBle notification
  -> BleService.characteristicValueStream(...)
  -> validatePacket(...)
  -> BleService.packetStream
```

At this point the data is still a protocol packet. It has not yet become a
heart-rate value, battery snapshot, or activity record.

## Packet Parsing

`ScanPageNotifier` subscribes to the packet stream after a successful
connection. For each packet, it checks the command byte and delegates to the
matching parser in [lib/src/protocol/](../lib/src/protocol/).

Examples:

| Packet type | Parser/output |
| --- | --- |
| Battery response | `parseBatteryResponse` -> `BatteryResponse` |
| Real-time reading | `parseRealTimeResponse` -> `RealTimeReading` |
| Heart-rate log | `HrLogParser` -> `HrLogResult` |
| Step/activity log | `StepParser` -> `StepEntry` list |
| Daily activity notification | `parseDailyActivityNotification` -> `DailyActivitySnapshot` |
| Accelerometer packet | `parseAccelerometerResponse` -> `AccelerometerReading` |

The protocol layer stays deterministic: it receives bytes and returns parsed
values or `null`. It does not know about widgets, windows, or the database.

## State Updates

After parsing, `ScanPageNotifier` updates `ScanPageState`. That state is the
current live model used by the dashboard and overlay.

Examples:

- `battery` is updated after a battery response.
- `realTimeReadings` is updated after a heart-rate, SpO2, or HRV response.
- `steps` is updated after step log sync.
- `dailyActivity` is updated after a daily activity notification.
- `lastAccel` is updated after an accelerometer packet.

This means the live UI can react immediately, before or independently of any
history view reload.

## Persistence

When a parsed value should become history, the controller writes it through
`OpenRingStorage`. Storage writes are intentionally separated from packet
parsing.

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
| Discovered or connected ring | `upsertDevice` / `setLastConnectedDevice` |
| Battery response | `insertBatterySnapshot` |
| Live HR, SpO2, HRV | `persistRealTimeReading` -> `insertVitalSample` |
| Heart-rate log entries | `insertHrLogEntries` -> `vital_samples` |
| Step log entries | `insertStepEntries` -> `activity_intervals` |

Storage writes are fire-and-forget from the controller. If a write fails, the
error is surfaced in the page state and debug log, but the BLE packet stream can
continue running.

## History Flow

The history view does not read packets directly. It loads already persisted data
from SQLite through the storage repository.

```text
History page
  -> HistoryPageController
  -> OpenRingStorage.loadHistoryDay(...)
  -> SQLite rows
  -> HistoryDay model
  -> chart models/widgets
```

`loadHistoryDay` resolves the selected ring, loads vital samples and activity
intervals for the selected local day, and maps them into history models.

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

The overlay currently reads:

- connection status from `bleStatusProvider`
- heart rate and SpO2 from `realTimeReadings`
- battery state from `battery`
- steps from `dailyActivity` or synced step entries
- display preferences from `overlaySettingsProvider`

## Outgoing Commands

User actions start as widget callbacks. Widgets call the controller, and the
controller calls `ScanPageUseCases`. The use-case layer builds or sends the
appropriate command through `BleService`.

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
| Scan for rings | widget -> `startScan` -> `BleService.startScan` |
| Connect ring | widget -> `connect` -> `BleService.connect` |
| Request battery | controller -> `requestBattery` -> battery packet |
| Start real-time HR | controller -> `startRealTime(heartRate)` -> real-time packet |
| Sync ring time | controller -> `syncTime` -> set-time packet |
| Blink ring | controller -> `blinkTwice` -> utility packet |

## Why This Shape

OpenRing keeps this separation so each part can stay understandable:

- BLE code transports packets.
- Protocol code parses and builds deterministic packets.
- Controller code coordinates state, timers, and persistence.
- Storage code owns SQLite writes and history loading.
- Widgets render state and send user intent upward.

That boundary matters for reliability. When a Colmi packet format changes, the
protocol parser can be tested without touching widgets. When the overlay changes
visually, it does not need to know how BLE packets are built. When history views
change, they can load from local storage instead of depending on a live ring.
