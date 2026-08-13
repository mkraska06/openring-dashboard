# Motion Research Lab

This note summarizes the current research work on the COLMI ring accelerometer.
It explains which motion data the COLMI ring sends, how the data is currently
interpreted and which parts are implemented in the app.

## Goal

The goal of the Motion Lab deep dive is to understand the ring's motion data as
a time-based signal instead of only showing individual live numbers.

This helps answer questions such as:

- Which sensor axis points where in a given ring position?
- How stable is the sensor when the ring is at rest?
- How noisy is the sensor?
- Which movements are visible through the stock firmware at all?
- When does the measurement range clip?
- Can the raw data support movement during HR/SpO2 measurements,
position changes, simple gestures or activity patterns?

## Basics: What Does the Accelerometer Measure?

The ring sends raw data from a three-axis accelerometer: `X`, `Y`, and `Z`.
These values describe acceleration along the sensor axes inside the ring, so
their meaning depends on how the sensor is mounted and how the ring is worn or
placed.

At rest, the accelerometer still measures Earth's gravity. The combined
magnitude across all three axes is therefore usually close to `1 g`
(approximately `9.81 m/s^2`), while the individual axis values change with the
ring orientation.

## Raw Data from the COLMI Protocol

Accelerometer streaming uses the raw-sensor command `0xA1`.

| Packet prefix | Meaning |
| --- | --- |
| `a1 04 04 ...` | Start raw accelerometer stream |
| `a1 02 ...` | Stop raw sensor stream |
| `a1 03 ...` | Accelerometer data packet |

The running raw stream also showed recurring `a1 01 ...` and `a1 02 ...`
packets. These packets are logged for debugging but are not parsed as motion
data because their meaning is not verified.

A recorded accelerometer packet looked like this:

```text
a1 03 1e 89 fd f2 fb 4b 00 00 00 00 00 00 00 80
```

The axis values are stored in bytes `2..7`:

| Bytes | Axis | Decoded value |
| --- | --- | ---: |
| `1e 89` | X | `7817` |
| `fd f2` | Y | `-526` |
| `fb 4b` | Z | `-1205` |

The axis values are decoded as signed 16-bit big-endian integers because the
recorded resting sample stays close to the expected `1 g` magnitude. Decoding
the same bytes as little-endian produces values that are too large for a ring
lying still:

| Decoding | X | Y | Z | Magnitude |
| --- | ---: | ---: | ---: | ---: |
| Big-endian | `7817` | `-526` | `-1205` | `0.97 g` |
| Little-endian | `-30434` | `-3331` | `19451` | `4.43 g` |

The implementation uses:

```text
accX = signed16((byte2 << 8) | byte3)
accY = signed16((byte4 << 8) | byte5)
accZ = signed16((byte6 << 8) | byte7)
```

## Converting Counts to g

The accelerometer values from the BLE packet are stored as raw counts. For
display, they are converted to approximate `g` values.

The display scale was chosen from two observations. A ring lying still should
have a combined acceleration magnitude close to `1 g`. During fast motion, some
recordings reached the signed 16-bit limits `-32768` or `32767`. This means the
measured value was clipped at the maximum or minimum representable value instead
of continuing further.

The exact value used in the app is `8192 counts/g`. This value was chosen
because `8192` is close to the observed resting magnitude and is a typical
binary scale (`2^13`). With a signed 16-bit limit of `32768`, it also gives an
approximate `+-4 g` range.

The conversion is:

```text
xG = accX / 8192
yG = accY / 8192
zG = accZ / 8192
```

With this scale, the recorded resting sample has a magnitude of about `0.97 g`.

Raw counts remain the source of truth. The `g` values are only an approximate
conversion for display, not a calibrated sensor model. A more exact conversion
would require calibration for sensor offsets, scale errors and the ring's
mounting orientation.

## What Has Been Implemented

### 1. Correct Accelerometer Decoding

OpenRing now parses `0xA1/0x03` packets as signed 16-bit big-endian. This makes
raw values plausible for resting and moving ring positions.

The live view still shows raw values:

```text
X=7817  Y=-526  Z=-1205
```

It additionally shows the calculated `g` values and magnitude:

```text
X=0.954 g  Y=-0.064 g  Z=-0.147 g  |a|=0.968 g
```

### 2. Debug Console for Raw Sensor Packets

The BLE debug output distinguishes raw-sensor subtypes:

```text
[RX raw subtype 01] ...
[RX raw subtype 02] ...
[RX raw accel] ...
```

This makes it visible in the terminal which packets contain accelerometer
samples.

### 3. Motion Lab in the Dashboard

The dashboard contains an initial Motion Lab. It allows the user to:

- start the accelerometer stream
- assign session names
- start recording
- stop recording
- see the sample count
- plot the current or latest saved recording

Recording is intentionally separate from starting the accelerometer stream:

- `Start` activates the raw accelerometer stream.
- `Record` starts a named recording session.
- `Stop` ends only the recording session.
- The accelerometer stream can continue running.

### 4. Local Storage

Motion data is stored in SQLite.

There are two tables:

```text
motion_sessions
motion_samples
```

`motion_sessions` stores:

- session ID
- ring/device
- name
- start time
- end time

`motion_samples` stores:

- session ID
- received timestamp
- `accX`
- `accY`
- `accZ`

The raw counts are stored, not the derived `g` values.

### 5. Plot

Motion Lab shows four curves:

```text
X
Y
Z
|a|
```

The Y axis is in `g`; the X axis shows seconds since the beginning of the
session.

The `|a|` curve is the acceleration vector magnitude. It is useful for viewing
movement intensity independent of the current ring orientation.

### 6. Data Export

OpenRing now includes CSV and JSON export for selected data ranges. The export
flow can include vital values, battery snapshots, activity data, and motion
sessions. Motion export makes it possible to analyze recorded samples outside
OpenRing, for example in Python, Jupyter Notebook, Excel, or LibreOffice.

A useful motion CSV shape is:

```text
session_id,session_name,received_at,elapsed_ms,acc_x,acc_y,acc_z,x_g,y_g,z_g,mag_g
```

## First Observations from Real Recordings

Initial sessions were recorded:

- `bewegen`
- `liegen`

The `liegen` session had:

```text
duration: 67 s
samples:  66
```

This corresponds to roughly one sample per second and matches the observed stock
firmware behavior.

The magnitude of the resting session was approximately:

```text
min |a| ~= 0.831 g
avg |a| ~= 1.071 g
max |a| ~= 1.174 g
```

There were no clipped samples, which is plausible for a calm recording.

The `bewegen` session had:

```text
duration: 77 s
samples:  77
```

Several clipped samples were observed in that session. This means individual
axes reached the measurement range, for example:

```text
-32768
32767
```

This fits fast or stronger movements.

## Turntable Experiment from 2026-05-27

As a practical experiment, the ring was placed on a turntable and recorded at
`33 rpm` and `45 rpm`, each in a center and outer position.

Sessions used:

| Session | Samples | X g | Y g | Z g | Magnitude |
| --- | ---: | ---: | ---: | ---: | ---: |
| `flach_turntable_33_center` | 20 | `-1.047` | `-0.064` | `-0.143` | `1.058 g` |
| `flach_turntable_33_outer` | 20 | `-1.032` | `-0.222` | `-0.176` | `1.070 g` |
| `flach_turntable_45_center` | 20 | `-1.036` | `-0.052` | `-0.203` | `1.057 g` |
| `flach_turntable_45_outer` | 20 | `-1.026` | `0.040` | `-0.383` | `1.096 g` |

Within each of these sessions, the 20 samples were identical. Changing from
`33 rpm` to `45 rpm` also did not produce a clear time-varying pattern in the
X/Y/Z axes in the current data path.

This is an important finding. The experiment does not show that the physical
accelerometer cannot measure acceleration. It shows that the `0xA1/0x03` values
visible over BLE during calm, uniform movement update rarely or not at all.

Part of this is physically plausible. If the ring is fixed on the turntable, its
sensor coordinate system rotates with it. Gravity remains almost constant inside
the ring coordinate system. Uniform rotation creates centripetal acceleration:

```text
a = omega^2 * r
```

In the rotating sensor coordinate system, that component is also mostly
constant as long as the ring does not tilt or slide. No clean sinusoidal axis
curve is therefore expected.

The behavior also suggests a limited or filtered stock-firmware data path:

- slow or very careful movements often do not change the values
- uniform turntable rotation produces no visible time-varying signal
- jerky or faster movements produce clear changes
- individual strong movements can clip

The cautious interpretation is:

> Through the currently used BLE path, the ring does not provide continuous,
> high-resolution raw accelerometer data. The values appear to be throttled,
> filtered, or threshold-updated by firmware.

Further analysis must therefore distinguish between:

```text
physical capability of the accelerometer
vs.
data actually visible through the COLMI stock-firmware BLE path
```

The turntable is therefore less useful for direct rotational speed detection. It
is still useful for showing that uniform rotation does not automatically appear
as a periodic signal in the accelerometer stream.

## Calibration State from 2026-05-26

The following calibration recordings were made with a COLMI R03. They initially
describe this ring and this firmware state.

The goal was to place the ring in stable positions where one sensor axis
dominates. This reveals which physical ring position corresponds to which sign
of the X, Y, or Z axis.

An accidental short recording named `flach_unten` with only 2 samples was
ignored. It does not overwrite data because each recording is stored as a
separate motion session.

Sessions used:

| Session | Samples | X g | Y g | Z g | Magnitude | Rating |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `flach_oben` | 26 | `-1.032` | `-0.101` | `-0.169` | `1.051 g` | good |
| `flach_unten` | 26 | `0.951` | `-0.042` | `-0.111` | `0.958 g` | good |
| `kontakt_unten` | 26 | `-0.014` | `-1.058` | `-0.092` | `1.062 g` | good |
| `kontakt_oben` | 26 | `-0.061` | `0.930` | `-0.157` | `0.945 g` | good |
| `kontakt_links` | 10 | `-0.014` | `-0.050` | `-1.153` | `1.154 g` | good |
| `kontakt_rechts` | 10 | `-0.064` | `0.031` | `0.845` | `0.848 g` | usable |

Derived axis map:

| Physical Position | Dominant Sensor Response |
| --- | --- |
| `flach_oben` | X negative |
| `flach_unten` | X positive |
| `kontakt_unten` | Y negative |
| `kontakt_oben` | Y positive |
| `kontakt_links` | Z negative |
| `kontakt_rechts` | Z positive |

All three axes were observed with both signs. The X and Y positions are very
clean. The Z-negative position is also clean. The Z-positive position is usable
but lower than ideal at `0.845 g`. It is sufficient for the current axis map,
but a more precise calibration could repeat this position later.

The calibration confirms the current scale assumption:

```text
8192 counts ~= 1 g
```

The resting positions mostly fall between approximately `0.95 g` and `1.15 g`.
That is plausible for manually aligned consumer hardware.

The important result is that calibration turns abstract X/Y/Z values into an
interpretable ring axis map. This helps OpenRing distinguish between a different
ring orientation and actual stronger movement.

## Why the Plot Is Useful

A single live value shows only one moment:

```text
X=0.95 g, Y=-0.07 g, Z=-0.13 g
```

A plot shows the time course:

- Does the ring remain still?
- Does the position tilt?
- Does gravity move from one axis to another?
- Are there short spikes?
- Does the sensor clip?
- How regularly do samples arrive?

This turns individual numbers into a signal that can be investigated.

For the stock firmware, the sample rate is especially important. The stream
delivers roughly `1 Hz`, which means very fast movements such as short taps can
easily be missed. Slower position changes and coarse movements remain visible.

## Current Limits

Motion Lab is still a research tool and has important limits:

- `8192 counts/g` is an observed scale, not a final calibration.
- The axis orientation was mapped for one COLMI R03 and should be checked again
  for other models or firmware versions.
- The stock-firmware sample rate is low.
- There is no dedicated session browser yet.
- There is no automatic activity recognition.
- The subtypes `0xA1/0x01` and `0xA1/0x02` are not decoded.

## Gesture Data Basis for Held Hand Positions

After the initial accelerometer and axis tests, Motion Lab was extended into a
gesture data basis. The goal was not to detect fast movements or rotational
speed, but to measure stable hand positions.

The reason is the observed sample rate:

```text
roughly 1 sample per second
```

At that rate, short events such as double taps or quick swipes are unreliable.
A calmly held position is visible because gravity remains stable on the ring
axes.

### Presets

Motion Lab provides named presets for this purpose. They set the session name
and make later grouping possible.

Legacy/basic:

```text
gesture_palm_up
gesture_palm_side
gesture_palm_down
gesture_double_tap
```

Open/fist gesture space:

```text
gesture_open_down
gesture_open_side
gesture_open_up
gesture_open_vertical
gesture_fist_down
gesture_fist_side
gesture_fist_up
gesture_fist_vertical
```

The session names are intentionally used as labels. No separate gesture database
table was introduced. This keeps Motion Lab simple: a recording remains a motion
session with samples.

### Recording Workflow

Each position was recorded with this workflow:

1. Start the accelerometer stream.
2. Select the Motion Lab preset.
3. Move the hand into the desired position.
4. Let the hand settle briefly.
5. Start `Record`.
6. Hold the position for 10 to 20 seconds.
7. Press `Stop`.
8. Repeat if values look unusual or include start movement.

Important for comparable data:

- Wear the ring on the same finger.
- Keep the ring in the same orientation.
- Keep the hand as still as possible.
- Do not start recording while moving into position.
- Consider start and end movements during evaluation.

A typical session contains only about 10 to 30 samples with the observed
firmware, so every sample matters.

### Per-Session Analysis

OpenRing calculates the following for each session:

```text
sample count
duration
min/max/average for xG
min/max/average for yG
min/max/average for zG
min/max/average for |a|
axis spread
average sample-to-sample change
stability
roll angle atan2(yG, zG)
```

A held position is considered stable when it has enough samples, `|a|` is in a
plausible resting range, the axes do not spread too much, and the average
sample-to-sample change is small.

### Group Analysis

The new presets are grouped along two dimensions:

```text
hand shape: open / fist
position:   down / side / up / vertical
```

The analysis compares:

- `open` vs. `fist` in the same position
- `side` vs. `vertical`
- roll separation of `down`, `side`, and `up`

The result status is:

```text
clearly separated
uncertain
more data
```

`clearly separated` means that the groups are stable and the distance between
their centers is clearly larger than their spread.

### Current Measured Gesture Centers

The following stable centers from the current recordings are used by the Gesture
Hub. Values are `g` values.

| Session | xG | yG | zG | |a| | Roll |
| --- | ---: | ---: | ---: | ---: | ---: |
| `gesture_open_down` | `+0.101` | `-1.041` | `-0.004` | ca. `1.046` | `-90.1 deg` |
| `gesture_open_side` | `-0.141` | `-0.086` | `+0.841` | ca. `0.857` | `-5.9 deg` |
| `gesture_open_up` | `-0.160` | `+0.907` | `-0.041` | ca. `0.922` | `+92.6 deg` |
| `gesture_open_vertical` | `-1.023` | `-0.179` | `-0.072` | ca. `1.041` | `-108.0 deg` |
| `gesture_fist_down` | `+0.938` | `-0.131` | `+0.026` | ca. `0.948` | `-83.6 deg` |
| `gesture_fist_side` | `-0.121` | `+0.107` | `+0.799` | ca. `0.815` | `+7.4 deg` |
| `gesture_fist_up` | `-1.015` | `-0.190` | `-0.149` | ca. `1.044` | `-129.5 deg` |
| `gesture_fist_vertical` | `-0.027` | `-1.068` | `+0.008` | ca. `1.068` | `-89.6 deg` |

The derived product decision:

- `open_down`, `open_side`, and `open_up` are the main rotation controls.
- `open_vertical` is the mode switch.
- `fist_down` is used as the left click in mouse control.
- The other fist positions remain research data and are not used as directions
  in V1.

### Why `open_*` and `palm_*` Both Exist

`gesture_palm_up/side/down` were the first basis for held hand positions. Later,
the data basis was made more explicit:

```text
open = open hand
fist = closed hand
```

The `gesture_open_down/side/up` presets are therefore the cleaner and more
explicit variant for the current Gesture Hub. The `palm_*` presets remain usable
as legacy/basic recordings and do not interfere because every session is grouped
by name.

### Ring Orientation

The measured values assume:

- same finger
- ring not worn twisted
- same hand as during calibration
- same orientation of the ring opening

If the ring is worn differently, signs and centers can shift. The current
classifier would then fit less well. Long term, user-specific calibration would
be useful.

## Gesture Hub as Result of the Motion Work

The current Gesture Hub emerged from the Motion Lab data. It uses the measured
centers from held positions.

Current controls:

```text
scroll
volume
mouse
```

For each sample, the Gesture Hub asks one simple question:

```text
Which known held position is this right now?
```

Classification uses a nearest-center search in `xG/yG/zG` space:

```text
distance = sqrt((xG - centerX)^2 + (yG - centerY)^2 + (zG - centerZ)^2)
```

The smallest distance determines the position.

Detailed product and implementation documentation is in:

- [gesture-hub.md](gesture-hub.md)

## Useful Next Steps

### 1. Refine Calibration

The first R03 axis map is usable. Optionally, the Z-positive position can be
recorded again to get closer to `1 g`:

```text
kontakt_rechts
```

Before starting the recording, the live values should show X and Y close to
`0 g` and a dominant positive Z value.

Further goals:

- check whether the Z-positive position can be made stable and closer to `1 g`
- compare the R03 axis map with additional rings if available
- measure per-axis offset and noise more precisely

### 2. Session Browser

The dashboard currently loads the latest non-empty motion session. For deeper
analysis, a small session browser would be useful:

- list saved sessions
- name
- duration
- sample count
- start time
- open in plot
- optionally delete or export later

### 3. Movement Quality for Vital Measurements

A practical use case is rating movement during heart-rate or SpO2 measurements.

Idea:

```text
If |a| varies strongly, the optical measurement is likely less reliable.
```

This could later produce a simple quality indicator:

```text
still
slightly moving
strongly moving
```

That would be useful because optical measurements on the finger are sensitive to
movement.

### 4. Custom Movement Recognition

Only after calibration and exported data analysis does more advanced logic make
sense, such as:

- detecting position changes
- detecting coarse activity
- testing simple gestures
- comparing step or movement patterns
- evaluating the ring-as-mouse idea

These steps need real datasets. Motion Lab is the foundation for that work.

## Short Conclusion

The current state is an important intermediate result:

- Accelerometer packets are decoded plausibly.
- Raw values are stored as counts.
- `g` values and vector magnitude are calculated.
- Recordings can be stored as sessions.
- Motion curves are visible in the dashboard.
- First real datasets show clear differences between rest and movement.
- Held-position recordings provided the basis for the Gesture Hub.

OpenRing is therefore no longer only a live monitor for individual accelerometer
numbers. It is also a small local measurement lab for accelerometer data from
the ring.

## AI Assistance Disclosure

This document was revised with AI assistance. The assistance included:

- translating the original German research notes into English
- repairing character encoding artifacts in the existing text
- updating outdated statements about export support to match the current
  implementation
- improving structure and terminology while preserving measured values,
  experiment descriptions, and technical conclusions

The technical observations and conclusions were reviewed against the
implementation, tests, and recorded ring behavior by the author.
