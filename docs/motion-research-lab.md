# Motion Research Lab

This note summarizes the current research work on the COLMI ring accelerometer.
It explains which motion data the COLMI ring sends, how the data is currently
interpreted and which parts are implemented in the app.

## Goal

The goal of the Motion Lab deep dive is to understand the ring's motion data as
a time-based signal.

This helps answer questions such as:

- Which sensor axis points where in a given ring position?
- How stable is the sensor when the ring is at rest?
- How noisy is the sensor?
- Which movements are visible at all?
- When does the measurement range clip?
- Can the raw data support simple gestures?

## Summary of Results

- The COLMI R03 exposes accelerometer data through `0xA1/0x03` packets.
- Axis values are decoded as signed 16-bit big-endian integers.
- The `g` conversion uses an empirical `8192 counts/g` display scale, not a
  calibrated sensor model.
- The stock-firmware BLE path does not expose small accelerometer changes as a
  continuous high-resolution stream.
- Stable held positions are visible enough to support the current Gesture Hub.
- The results were measured with one COLMI R03 and may shift with other models,
  firmware versions or ring orientations.

## Basics: What Does the Accelerometer Measure?

The ring sends raw data from a three-axis accelerometer: `X`, `Y` and `Z`.
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

## Implemented Motion Lab Features

Based on the decoded accelerometer stream, Motion Lab provides recording,
storage, and visualization features.

### 1. Recording and Storage

Motion Lab can record named accelerometer sessions and store them locally in
SQLite. Motion recordings use `motion_sessions` and `motion_samples`.

### 2. Visualization

Recorded sessions can be plotted as X, Y, Z and magnitude curves. This makes it
possible to compare held positions and inspect movement intensity over time.

## Turntable Experiment from 2026-05-27

The ring was placed on a turntable and recorded at `33 rpm` and `45 rpm`, each
in a center and outer position.

| Session | Samples | X g | Y g | Z g | Magnitude |
| --- | ---: | ---: | ---: | ---: | ---: |
| `flach_turntable_33_center` | 20 | `-1.047` | `-0.064` | `-0.143` | `1.058 g` |
| `flach_turntable_33_outer` | 20 | `-1.032` | `-0.222` | `-0.176` | `1.070 g` |
| `flach_turntable_45_center` | 20 | `-1.036` | `-0.052` | `-0.203` | `1.057 g` |
| `flach_turntable_45_outer` | 20 | `-1.026` | `0.040` | `-0.383` | `1.096 g` |

Within each session, the 20 samples were identical. Changing from `33 rpm` to
`45 rpm` did not produce a clear time-varying pattern in the X/Y/Z axes.

A low sample rate alone does not fully explain this result. If the firmware only reduced a continuous 
sensor stream to one value per second, some changes would still be expected between samples. 
The identical samples therefore suggest that the current stock-firmware BLE path does not expose 
every small accelerometer change as a new value.

This conclusion only applies to the current BLE data path. Smooth, steady
rotation was not visible as a continuous high-resolution accelerometer signal.

## Axis Calibration from 2026-05-26

Calibration recordings were made with a COLMI R03 in stable positions where one
sensor axis dominates.

| Dominant axis | Samples | X g | Y g | Z g | Magnitude | Rating |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| X negative | 26 | `-1.032` | `-0.101` | `-0.169` | `1.051 g` | good |
| X positive | 26 | `0.951` | `-0.042` | `-0.111` | `0.958 g` | good |
| Y negative | 26 | `-0.014` | `-1.058` | `-0.092` | `1.062 g` | good |
| Y positive | 26 | `-0.061` | `0.930` | `-0.157` | `0.945 g` | good |
| Z negative | 10 | `-0.014` | `-0.050` | `-1.153` | `1.154 g` | good |
| Z positive | 10 | `-0.064` | `0.031` | `0.845` | `0.848 g` | usable |

The calibration confirms that each axis can produce both positive and negative values.
It also makes the raw X/Y/Z values interpretable as ring orientations, which is
needed before they can be used for held-position controls.

## Gesture Data Basis

The low sample rate makes short events such as double taps or quick swipes
unreliable. Motion Lab therefore uses stable held positions as the basis for
gesture experiments.

### Held-Position Recording Method

Each hand position was recorded in Motion Lab with a matching session name, for
example `gesture_open_side`. The accelerometer stream was started first. Then
the hand was moved into the target position, held still for a short moment and
recorded for a few seconds.

The recordings were checked by looking at the X, Y and Z curves and the
calculated `g` values. Recordings with enough stable samples were used for the
gesture centers. For each position, the average `xG`, `yG` and `zG` values were
taken as the center of that position.

To make the recordings comparable, the ring was worn on the same finger and in
the same orientation.

The following measured centers are used by Gesture Hub. Values are `g` values.

| Session | xG | yG | zG | Magnitude | Roll |
| --- | ---: | ---: | ---: | ---: | ---: |
| `gesture_open_down` | `+0.101` | `-1.041` | `-0.004` | ca. `1.046` | `-90.1 deg` |
| `gesture_open_side` | `-0.141` | `-0.086` | `+0.841` | ca. `0.857` | `-5.9 deg` |
| `gesture_open_up` | `-0.160` | `+0.907` | `-0.041` | ca. `0.922` | `+92.6 deg` |
| `gesture_open_vertical` | `-1.023` | `-0.179` | `-0.072` | ca. `1.041` | `-108.0 deg` |
| `gesture_fist_down` | `+0.938` | `-0.131` | `+0.026` | ca. `0.948` | `-83.6 deg` |
| `gesture_fist_side` | `-0.121` | `+0.107` | `+0.799` | ca. `0.815` | `+7.4 deg` |
| `gesture_fist_up` | `-1.015` | `-0.190` | `-0.149` | ca. `1.044` | `-129.5 deg` |
| `gesture_fist_vertical` | `-0.027` | `-1.068` | `+0.008` | ca. `1.068` | `-89.6 deg` |

Gesture Hub classifies live samples by comparing the current `xG/yG/zG` value
with these measured centers. Detailed product and implementation documentation
is in [gesture-hub.md](gesture-hub.md).
