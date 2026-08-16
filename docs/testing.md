# Testing

This document describes how automated and manual tests are organized.

OpenRing Desktop communicates with BLE hardware, but much of the important
logic can be tested without a ring. The automated test suite focuses on logic, protocol 
compatibility, persistence rules, chart preparation, UI controller behavior and 
measurement scheduling. Hardware-specific behavior is validated manually where it 
depends on BLE stacks.

The mapping between requirements and test coverage is tracked in
[specs/requirements-test-matrix.md](specs/requirements-test-matrix.md).

## Running Tests

Run all automated tests from the repository root:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

Run the Windows build after native runner changes, such as system volume,
scroll, or mouse input channels:

```bash
flutter build windows
```

Run a focused test folder while working on one area:

```bash
flutter test test/protocol
flutter test test/storage
flutter test test/history
flutter test test/ui
flutter test test/data_export
flutter test test/measurements
flutter test test/motion
flutter test test/gesture_hub
flutter test test/overlay
```

Generated Drift code should be refreshed after schema changes:

```bash
dart run build_runner build
```

## Test Layout

| Path | Purpose |
| --- | --- |
| [test/protocol/](../test/protocol/) | Packet builders, checksum validation, response parsers, and multi-packet protocol assembly |
| [test/storage/](../test/storage/) | Drift-backed repository behavior, idempotent inserts, history loading, and local-day filtering |
| [test/history/](../test/history/) | Chart window calculation, axis bounds, tooltip formatting, and history view models |
| [test/ui/](../test/ui/) | Scan-page controller behavior, status indicator rendering, and accelerometer stop flow |
| [test/data_export/](../test/data_export/) | Export repository loading, formatting, controller behavior, and export widget coverage |
| [test/measurements/](../test/measurements/) | Measurement scheduler sequencing, cooldowns, retries, timeouts, and desired-measurement state |
| [test/motion/](../test/motion/) | Motion-session statistics, held-position stability, and gesture-space grouping |
| [test/gesture_hub/](../test/gesture_hub/) | Gesture classification, control switching, volume, scroll, and mouse-control behavior |
| [test/overlay/](../test/overlay/) | Overlay widget rendering and overlay settings persistence |
| [test/widget_test.dart](../test/widget_test.dart) | Basic Flutter widget smoke coverage |

## Automated Coverage

The strongest automated coverage is around logic that should behave the same on
every machine:

- Colmi packet length, checksums, and command bytes
- known reference packets from the Python implementation
- battery, real-time, heart-rate log, settings, step, activity, and
  accelerometer parsing
- storage idempotency for samples, battery snapshots, and activity intervals
- history-day loading for the last connected ring
- reconstruction of live heart-rate timestamps for charts
- data export loading, formatting, and controller state
- scan-page controller behavior for scanning, connection, measurements, and
  accelerometer stop handling
- measurement scheduler ordering, cooldown, timeout, and retry behavior
- Motion Lab gesture preset parsing, session statistics, and stability checks
- Gesture Hub held-position classification and control actions
- overlay rendering and overlay settings persistence

## Manual Validation

Some behavior still needs manual validation because it depends on platform BLE
stacks, native windows, or real ring firmware:

- BLE scanning, connection, reconnect, and notification behavior
- Windows and Linux Bluetooth setup differences
- always-on-top overlay behavior, tray integration, and global hotkeys
- native Windows input effects such as actual mouse movement, click delivery,
  scroll delivery, and system volume behavior
- real-device compatibility across ring models and firmware versions
- packaged release behavior

Code in these areas should stay behind narrow service or controller boundaries
so the decision-making logic can be unit tested even when the platform side is
validated manually.

When validating behavior with a real ring, record findings in the relevant
feature document if they change project assumptions. Good places are:

- [protocol.md](protocol.md) for packet formats, firmware quirks, and command behavior
- [measurement-scheduling.md](measurement-scheduling.md) for live measurement timing
- [overlay.md](overlay.md) for desktop window behavior
- [gesture-hub.md](gesture-hub.md) for Gesture Hub control mappings and manual
  usability findings
- [database-schema.md](database-schema.md) for persisted data changes

Hardware notes should include the ring model, platform, and observed behavior
when possible.
