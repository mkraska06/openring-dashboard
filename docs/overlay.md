# Overlay Design and Behavior

The OpenRing overlay is a compact always-on-top view for live ring values. It is
designed for people who want health data visible while working at the desktop
without keeping the full dashboard open.

The overlay is not a separate application. It is an integrated mode of the main
OpenRing window.

## Why It Is Integrated

Colmi rings support only one active BLE connection. If OpenRing used a separate
overlay process or a second window with its own BLE client, the dashboard and
overlay would compete for the same ring.

OpenRing avoids that by keeping one app process and one BLE connection:

```text
Full dashboard mode
  -> same app window is resized and reconfigured
  -> overlay mode
  -> same BLE service and same live state
```

This lets the overlay reuse the current connection, live readings, battery
state, and activity data.

## Window Behavior

When overlay mode is activated, `OverlayController` reconfigures the main app
window with `window_manager`.

Current overlay window behavior:

| Behavior | Purpose |
| --- | --- |
| fixed size `200 x 170` | Keeps the overlay compact and predictable |
| always on top | Keeps values visible above other windows |
| skip taskbar | Avoids an extra taskbar entry while in overlay mode |
| no shadow | Makes the overlay feel like a lightweight desktop panel |
| click-through by default | Prevents the overlay from blocking work underneath |
| saved position | Restores the user's preferred location |

When overlay mode is deactivated, OpenRing restores the full window size,
resizability, taskbar behavior, shadow, and normal mouse handling.

## Passive and Interactive Modes

The overlay has two interaction states.

| Mode | Behavior |
| --- | --- |
| Passive overlay | Click-through, always-on-top, intended for normal use |
| Interactive overlay | Mouse input enabled, draggable, shows a visual edit border |

Passive mode is the default because the overlay should not interrupt the user's
desktop workflow. Interactive mode exists so the user can reposition it.

The current interactive behavior:

```text
Ctrl+Shift+L
  -> toggle interactive mode
  -> enable mouse input
  -> user drags overlay
  -> toggle back
  -> save position
  -> return to click-through mode
```

## Hotkeys and Tray

The overlay can be controlled without returning to the full dashboard.

Current hotkeys:

| Hotkey | Action |
| --- | --- |
| `Ctrl+Shift+O` | Toggle overlay mode |
| `Ctrl+Shift+L` | Toggle interactive positioning mode while overlay is active |

When overlay mode is active, OpenRing also creates a system tray menu.

Current tray actions:

| Tray action | Result |
| --- | --- |
| Open main window | Deactivates overlay and restores the full app window |
| Edit position | Toggles interactive positioning mode |
| Quit | Deactivates overlay and closes the app |

On Windows, the tray icon is loaded from the bundled
[assets/app_icon.ico](../assets/app_icon.ico) inside the release output.

## Displayed Values

The overlay reads the same app state as the main dashboard. It does not request
or parse BLE packets directly.

Current displayed values:

| Value | Source |
| --- | --- |
| Connection status | `bleStatusProvider` |
| Heart rate | `ScanPageState.realTimeReadings[heartRate]` |
| SpO2 | `ScanPageState.realTimeReadings[spo2]` |
| Battery | `ScanPageState.battery` |
| Steps | `ScanPageState.dailyActivity` or synced step entries |

If a value is not available, the overlay displays `--` instead of inventing a
reading.

## Visual Rules

The overlay should be readable at a glance. It uses a weak dark background and
fully visible foreground text/icons.

Important visual rule:

```text
Do not make the whole window transparent to create the background effect.
```

Whole-window opacity fades the values too. That makes BPM, SpO2, and battery
harder to read. The preferred style is a translucent background color with
normal-opacity text and icons.

The current overlay uses:

- compact rows with icon, value, and unit
- white values for normal readings
- red heart-rate value above the configured high threshold
- red SpO2 value below the configured low threshold
- green/gray connection dot
- amber border only in interactive positioning mode

## Settings

Overlay settings are stored with `SharedPreferences`.

Current persisted settings:

| Setting | Purpose |
| --- | --- |
| `overlay_pos_x`, `overlay_pos_y` | Saved overlay position |
| `overlay_show_hr` | Show/hide heart rate |
| `overlay_show_spo2` | Show/hide SpO2 |
| `overlay_show_battery` | Show/hide battery |
| `overlay_show_steps` | Show/hide steps |
| `overlay_hr_threshold` | High heart-rate warning threshold |
| `overlay_spo2_threshold` | Low SpO2 warning threshold |

The state model also contains an opacity setting, but the current default keeps
window opacity at `1.0` to preserve text readability.

## Data Ownership

The overlay is a consumer of live state. It should not own BLE transport,
protocol parsing, or measurement timing.

```text
BleService / protocol parsers
  -> ScanPageState
  -> OverlayWidget
```

Measurement timing should be handled by the measurement scheduler, not by the
overlay widget. The overlay can request or imply desired values, but the
scheduler should decide when HR, SpO2, or HRV is actually measured.

This keeps the overlay lightweight and prevents it from fighting with the main
dashboard for the ring sensor.

## Failure Behavior

The overlay should remain useful when the ring is disconnected or when a value
is stale.

Current behavior:

- connection dot becomes gray when disconnected
- unavailable values display `--`
- overlay window can still be moved or closed from tray/hotkey controls

Future scheduler integration should make stale values more explicit, for
example by dimming or marking readings whose freshness window has expired.
