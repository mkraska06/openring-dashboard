# Testing

This document describes how OpenRing Desktop tests are organized and what kind
of behavior should be covered when the project changes.

OpenRing is a desktop app that talks to real BLE hardware, but most of the
important behavior can still be tested without a ring. The test suite should
therefore focus on deterministic logic, protocol compatibility, persistence
rules, and scheduling behavior. Hardware-specific behavior should be kept behind
small boundaries and validated manually until reliable integration testing is in
place.

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
flutter test test/measurements
flutter test test/motion
flutter test test/gesture_hub
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
| [test/measurements/](../test/measurements/) | Measurement scheduler sequencing, cooldowns, retries, timeouts, and desired-measurement state |
| [test/motion/](../test/motion/) | Motion-session statistics, held-position stability, and gesture-space grouping |
| [test/gesture_hub/](../test/gesture_hub/) | Gesture classification, control switching, volume, scroll, and mouse-control behavior |
| [test/widget_test.dart](../test/widget_test.dart) | Basic Flutter widget smoke coverage |

## Current Coverage Focus

The strongest automated coverage is around logic that should behave the same on
every machine:

- Colmi packet length, checksums, and command bytes
- golden protocol packets copied from the Python reference implementation
- battery, real-time, heart-rate log, settings, step, activity, and
  accelerometer parsing
- storage idempotency for samples, battery snapshots, and activity intervals
- history-day loading for the last connected ring
- reconstruction of live heart-rate timestamps for charts
- measurement scheduler ordering, cooldown, timeout, and retry behavior
- Motion Lab gesture preset parsing, session statistics, and stability checks
- Gesture Hub held-position classification and control actions

These areas are good candidates for tests whenever behavior is added or
changed, because regressions there can break ring communication or stored data
without being obvious in the UI.

## What To Test

Add or update automated tests when a change touches:

- protocol packet bytes, parsing rules, or checksum behavior
- command builders sent to the ring
- multi-packet log parsers or timestamp reconstruction
- database schema, repository inserts, deduplication, or history queries
- chart-model calculations, date filtering, or value aggregation
- measurement scheduling, retry timing, cooldowns, or active-measurement state
- controller or use-case logic that decides which BLE commands are sent
- Gesture Hub mappings for scroll, volume, mouse movement, or click behavior
- Motion Lab gesture preset parsing or gesture-space analysis

Prefer small tests with explicit input bytes, dates, and expected values. For
protocol code, golden packets are especially valuable because they protect
compatibility with observed Colmi behavior.

## What Is Not Fully Automated Yet

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

## Test Naming And Documentation

Tests should document behavior through clear names first. Comments are useful
only when the reason for a test is not obvious from the input and expectation,
for example:

- a golden packet copied from a reference implementation
- a firmware quirk discovered on real hardware
- a regression case that looks unusual without context
- a timing assumption in scheduler tests

Avoid maintaining a separate document for every test case. This file documents
the overall strategy; individual test files should stay readable through group
names, test names, compact fixtures, and a few targeted comments.

## Manual Test Notes

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
