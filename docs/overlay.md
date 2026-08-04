# Overlay Design and Behavior

The OpenRing overlay is a compact always-on-top view for live ring values. It is
designed for people who want live ring values visible while working at the
desktop without keeping the full dashboard open.

## Integrated Overlay Mode

The overlay is implemented as a mode of the main OpenRing window. 
This keeps the dashboard and overlay on the same BLE connection.
A separate overlay process with its own BLE client would compete with the main
dashboard for the ring connection.

A separate process could theoretically receive live values from the main app,
but that would add inter-process communication for a small overlay feature. The
current approach avoids that extra complexity and avoids possible delay or
synchronization issues between two processes.

## Window Behavior

When overlay mode is activated,
[OverlayController](../lib/src/overlay/overlay_controller.dart) reconfigures the
main app window with `window_manager`.

Current overlay window behavior:

| Behavior | Purpose |
| --- | --- |
| fixed size `200 x 170` | Keeps the overlay compact and predictable |
| always on top | Keeps values visible above other windows |
| skip taskbar | Avoids an extra taskbar entry while in overlay mode |
| click-through by default | Prevents the overlay from blocking work underneath |
| saved position | Restores the user's preferred location |

## Hotkeys and Tray

| Hotkey | Action |
| --- | --- |
| `Ctrl+Shift+O` | Toggle overlay mode |
| `Ctrl+Shift+L` | Toggle interactive positioning mode while overlay is active |

When overlay mode is active, OpenRing also creates a system tray menu.

| Tray action | Result |
| --- | --- |
| Open main window | Deactivates overlay and restores the full app window |
| Edit position | Toggles interactive positioning mode |
| Quit | Deactivates overlay and closes the app |


## Displayed Values

The overlay reads the same app state as the main dashboard.

The overlay can display:

- connection status
- heart rate
- SpO2
- battery level
- step count

The overlay shows the latest value currently available in the live app state. If
no value is available yet, it displays `--`.

## Settings

Overlay settings are stored as small local app preferences, using Flutter's
`SharedPreferences` mechanism and managed in
[overlay_state.dart](../lib/src/overlay/overlay_state.dart).

The stored settings cover the overlay position, visible values, and the
heart-rate/SpO2 warning thresholds.

## AI Assistance Disclosure

This document was checked and corrected with AI assistance to ensure that the
overlay behavior description matches the existing project source code. The
content was reviewed by the author.
