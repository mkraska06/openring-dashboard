# Architecture

This document describes the current architecture of OpenRing Desktop and the
direction the project is moving toward. It is intended as a high-level map for
contributors and future maintainers, not as a full implementation reference for
every class.

OpenRing is still an early prototype, so some parts of the architecture are
already in place while others are transitional. The main goal is to keep the
BLE, protocol, storage, UI, and overlay layers understandable and independently
testable as the app grows.

## Design Goals

OpenRing is built around a few core design goals:

- keep health data local by default
- avoid cloud or account dependencies
- keep protocol parsing deterministic and well tested
- route UI intent through controller, use-case, or service layers
- avoid sending BLE commands directly from widgets
- keep the overlay integrated with the main app instead of opening a second BLE
  pipeline
- make hardware and protocol assumptions explicit

## High-Level Flow

At a high level, live data flows through the app like this:

```text
Colmi ring
  -> BLE notification
  -> BleService packet stream
  -> protocol parser
  -> page controller / measurement scheduler
  -> storage repository
  -> dashboard, history view, or overlay
```

Commands flow in the opposite direction:

```text
User action
  -> widget callback
  -> page controller
  -> UI-facing use case
  -> BleService
  -> protocol command packet
  -> Colmi ring
```

This separation keeps widgets focused on presentation and keeps protocol logic
independent from Flutter UI code.

A renderable PlantUML diagram for module ownership is available in
[architecture-module-boundaries.puml](architecture-module-boundaries.puml).

## Module Map

| Path | Responsibility |
| --- | --- |
| [lib/src/ble/](../lib/src/ble/) | Low-level BLE scanning, connection handling, notification stream, and packet sending |
| [lib/src/protocol/](../lib/src/protocol/) | Pure packet builders, packet validators, and protocol parsers |
| [lib/src/ui/](../lib/src/ui/) | Main dashboard composition, page state, and UI-facing command orchestration |
| [lib/src/storage/](../lib/src/storage/) | Drift/SQLite database schema, persistence, and history loading |
| [lib/src/history/](../lib/src/history/) | History page state, chart models, chart widgets, and history UI behavior |
| [lib/src/overlay/](../lib/src/overlay/) | Overlay state, native window control, tray menu, hotkeys, and overlay widget |
| [lib/src/measurements/](../lib/src/measurements/) | Measurement sequencing and scheduler logic |
| [lib/src/gesture_hub/](../lib/src/gesture_hub/) | Gesture-based system controls using held accelerometer positions |

## BLE Layer

The BLE layer lives in [lib/src/ble/](../lib/src/ble/).

`BleService` owns the low-level Bluetooth interaction:

- scanning for nearby devices
- filtering likely Colmi rings by advertised name
- connecting and disconnecting
- discovering the Nordic UART Service used by the ring
- subscribing to notification packets
- sending validated command packets
- exposing packet and connection-status streams

The BLE layer should not contain UI behavior, charting logic, storage decisions,
or interpretation-heavy business rules. Its job is transport: move packets
between the desktop app and the ring.

## Protocol Layer

The protocol layer lives in [lib/src/protocol/](../lib/src/protocol/).

This layer contains deterministic packet builders and parsers for known Colmi
commands and responses. It should remain independent from Flutter widgets,
Riverpod providers, database code, and platform-specific window behavior.

Examples of protocol responsibilities:

- packet checksum validation
- command packet construction
- battery response parsing
- real-time reading parsing
- heart-rate log parsing
- heart-rate settings parsing
- step/activity log parsing
- accelerometer parsing
- utility commands such as time sync, blink, and reboot

Protocol behavior should be covered by focused tests whenever a packet format is
added or changed.

## UI Layer

The main dashboard UI lives in [lib/src/ui/](../lib/src/ui/).

The current UI split is:

- [scan_page.dart](../lib/src/ui/scan_page.dart) for page composition and navigation between dashboard and
  history
- [scan_page_widgets.dart](../lib/src/ui/scan_page_widgets.dart) for reusable dashboard widgets and cards
- [scan_page_controller.dart](../lib/src/ui/scan_page_controller.dart) for page state and orchestration
- [scan_page_use_cases.dart](../lib/src/ui/scan_page_use_cases.dart) for UI-facing BLE command operations

Widgets should remain presentation-focused. When a user presses a button, the
widget should call the controller or a use-case abstraction instead of sending a
BLE packet directly.

This keeps the app easier to test and prevents protocol or transport logic from
leaking into UI components.

## Storage Layer

The storage layer lives in [lib/src/storage/](../lib/src/storage/).

OpenRing currently uses Drift with SQLite for local persistence. The database
stores:

- known devices
- app settings
- vital samples
- battery snapshots
- activity intervals

The storage repository maps parsed ring data into local models that can be used
by history views and future export features.

The current storage layer is intentionally local-first. There is no cloud
backend and no account system.

Future storage work should include:

- schema migrations
- CSV and JSON export paths
- clearer database location documentation
- stronger deduplication rules where needed
- possibly a dedicated storage document once the schema becomes more stable

## History Layer

The history layer lives in [lib/src/history/](../lib/src/history/).

It is responsible for loading local data and rendering historical views for:

- heart rate
- SpO2
- HRV
- activity intervals

Chart calculation is kept separate from widgets where practical, so model-level
behavior can be tested without launching the full UI.

Live heart-rate samples need special handling because the ring reports values in
blocks rather than as a simple stream of independent point measurements. The
current visualization heuristic is documented separately in:

- [live-heart-rate-history.md](live-heart-rate-history.md)

## Overlay Architecture

The overlay lives in [lib/src/overlay/](../lib/src/overlay/).

OpenRing uses an integrated overlay mode instead of a separate app or second
window pipeline. This is an important architectural choice because the ring
supports only one active BLE connection.

When overlay mode is active, the main app window is resized and reconfigured
using `window_manager`. The overlay controller manages:

- always-on-top behavior
- skip-taskbar behavior
- click-through mode
- interactive positioning mode
- opacity
- tray menu integration
- global hotkeys

The visual overlay should use a weak dark background while keeping text and
icons fully visible. Low whole-window opacity should be used carefully because
it fades the values as well as the background.

## Measurement Scheduling

Real-time measurements are a shared sensor resource. The ring cannot reliably
measure heart rate, SpO2, HRV, and similar values all at the same time.

The intended architecture is to route live measurement requests through a
measurement coordinator or scheduler. Instead of UI components directly
starting and stopping each sensor command, they should express desired
measurements. The scheduler can then serialize access to the ring.

The scheduler direction is:

- maintain the set of desired measurements
- run only one active measurement at a time
- apply cooldowns after successful measurements
- retry after errors or hardware pauses
- publish latest values with freshness timestamps
- support a lightweight rotating profile for overlay mode

Some scheduler logic already exists in [lib/src/measurements/](../lib/src/measurements/), but integration
with the main live UI and overlay is still a work in progress.

## Gesture Hub

The Gesture Hub lives in [lib/src/gesture_hub/](../lib/src/gesture_hub/).

It turns held accelerometer positions into coarse desktop controls:

- scrolling
- relative volume changes
- mouse movement and left click

The Gesture Hub deliberately avoids fast tap or swipe detection because the
observed stock-firmware accelerometer stream is roughly `1 Hz`. Instead, it
uses calibrated held positions from Motion Lab recordings. The detailed
gesture data collection, control mapping, and native Windows input services
are documented in:

- [gesture-hub.md](gesture-hub.md)
- [motion-research-lab.md](motion-research-lab.md)

## Testing Strategy

OpenRing should favor focused tests around deterministic logic and high-risk
behavior.

Current and expected test areas include:

- packet validation and parsing
- command packet building
- storage repository behavior
- history chart model calculations
- live heart-rate timestamp reconstruction
- measurement scheduler sequencing

BLE behavior and native window behavior are harder to unit test directly, so
they should be kept behind narrow boundaries where possible.

The detailed test layout, commands, and documentation rules are described in
[testing.md](testing.md).

## Known Architectural Gaps

The current architecture still has several known gaps:

- reconnect behavior is not robust yet
- measurement scheduling is not fully integrated into all live UI paths
- export flows do not exist yet
- database migrations are not defined beyond the initial schema
- hardware compatibility documentation is still missing
- Linux-specific BLE setup and troubleshooting need validation
- release packaging is not defined
- sleep data support is not implemented

These gaps should be addressed incrementally without collapsing module
boundaries or moving protocol and BLE logic into widgets.

## Related Documents

- [README.md](../README.md)
- [protocol.md](protocol.md)
- [live-heart-rate-history.md](live-heart-rate-history.md)
- [architecture-module-boundaries.puml](architecture-module-boundaries.puml)
- [database-schema.md](database-schema.md)
- [data-flow.md](data-flow.md)
- [measurement-scheduling.md](measurement-scheduling.md)
- [overlay.md](overlay.md)
- [gesture-hub.md](gesture-hub.md)
- [testing.md](testing.md)
- [specs/initial-requirements.md](specs/initial-requirements.md)
- [specs/use-case-diagram.puml](specs/use-case-diagram.puml)
