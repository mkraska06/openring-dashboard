# Measurement Scheduling

OpenRing cannot treat every live value as an independent stream. Colmi rings
use a shared optical measurement path for heart rate, SpO2, HRV, and similar
real-time readings. In practice, one live measurement should run at a time, then
the app should stop it, wait briefly, and move to the next requested value.

This document explains why OpenRing needs scheduling, how the current prototype
handles it, and what the scheduler is meant to own.

## Why Scheduling Exists

The ring exposes separate commands for starting and stopping real-time
measurements, but the underlying hardware is shared. A heart-rate measurement
and a SpO2 measurement both need the optical sensor. Starting them as if they
were parallel streams can cause missing values, hardware pauses, or confusing
responses.

The scheduler exists to make one rule explicit:

```text
Only one real-time measurement may actively use the ring at a time.
```

The UI should therefore not say "start HR and SpO2 now". It should say "these
values are desired", and the scheduler decides when each measurement gets the
sensor.

## Measurement Types

The current scheduler models three live measurement kinds:

| Scheduler kind | Protocol reading type | Typical unit |
| --- | --- | --- |
| `heartRate` | `ReadingType.heartRate` | `bpm` |
| `spo2` | `ReadingType.spo2` | `%` |
| `hrv` | `ReadingType.hrv` | `ms` |

Battery and activity data are different. They do not need the same real-time
optical measurement cycle and can be requested or synced separately.

## Desired Measurements

OpenRing's intended model is desire-based:

```text
Dashboard wants HR + SpO2
Overlay wants HR + battery
History sync wants stored logs
        |
        v
Scheduler receives desired live measurement kinds
```

The scheduler keeps a set of desired measurement kinds. If a kind is desired,
it can be queued, measured, cooled down, or retried. If it is no longer desired,
it should be stopped and removed from future cycles.

This design keeps widgets simple. They do not need to know whether the ring is
busy, cooling down, or retrying after an error.

## Scheduler States

Each measurement kind has a status:

| Status | Meaning |
| --- | --- |
| `idle` | Not requested |
| `queued` | Requested and ready to run |
| `measuring` | Currently using the ring sensor |
| `cooldown` | Recently measured or blocked by a short settle delay |
| `error` | Last attempt failed, waiting for retry/backoff |

The scheduler also tracks one `activeKind`. If `activeKind` is not empty, no
other live measurement should be started.

## Successful Measurement Flow

A normal successful live measurement looks like this:

```text
setDesired(heartRate, true)
  -> heartRate becomes queued
  -> scheduler starts heartRate
  -> status becomes measuring
  -> ring sends one or more values
  -> latest value is stored in the scheduler snapshot
  -> stream becomes silent for a short pause
  -> scheduler stops heartRate
  -> heartRate enters cooldown
  -> scheduler picks the next eligible desired kind
```

The silence pause matters because the ring may send a small burst of values
rather than exactly one response. OpenRing waits briefly before stopping the
active measurement so it can keep the latest value from the burst.

## Freshness

The scheduler stores the latest value for each measurement kind with a freshness
timestamp.

```text
MeasurementValue
  kind
  value
  measured_at
  fresh_until
```

Freshness lets UI code distinguish between a recent value and an old value. The
overlay can still display the last known value, but it can also know whether
that value should be treated as current.

Default freshness windows in the scheduler:

| Kind | Freshness |
| --- | --- |
| Heart rate | 8 seconds |
| SpO2 | 25 seconds |
| HRV | 45 seconds |

These values reflect the expected rhythm of a lightweight rotating measurement
profile: heart rate updates more often, while SpO2 and HRV can update less
often.

## Cooldowns and Backoff

After a successful measurement, the kind is not immediately started again. It
enters a success interval so other requested kinds get a chance to run.

Default success intervals:

| Kind | Success interval |
| --- | --- |
| Heart rate | 3 seconds |
| SpO2 | 15 seconds |
| HRV | 30 seconds |

After an error or timeout, the kind waits longer before retrying.

Default error backoff:

| Kind | Error backoff |
| --- | --- |
| Heart rate | 12 seconds |
| SpO2 | 25 seconds |
| HRV | 40 seconds |

The scheduler also uses a short settle delay after stopping or failing a
measurement. This gives the ring time to recover before the next start command.

## Timeouts and Errors

Each active measurement has a timeout. If the ring does not provide a valid
value in time, the scheduler stops the measurement, marks it as an error, and
sets the next retry time.

The scheduler also handles protocol-level measurement errors. If the ring
responds with a non-zero error code for the active reading type, that active
measurement is stopped and backed off.

```text
start measurement
  -> no valid value before timeout
  -> stop active measurement
  -> record error
  -> wait backoff
  -> retry if still desired
```

## Current Prototype State

There are currently two related pieces in the codebase:

| File | Role |
| --- | --- |
| [measurement_scheduler.dart](../lib/src/measurements/measurement_scheduler.dart) | Generic scheduler model with desired kinds, statuses, cooldowns, freshness, timeout, and retry behavior |
| [daily_measurement_cycle.dart](../lib/src/measurements/daily_measurement_cycle.dart) | Simple fixed rotation used by the current daily measurement prototype |

The main UI controller still contains transitional measurement orchestration for
manual live readings and the daily measurement cycle. The goal is to move more
of that behavior behind the scheduler so the dashboard and overlay can express
desired values instead of directly controlling start/stop timing.

## Daily Rotation

The current daily measurement cycle favors heart rate and checks HRV and SpO2
less often:

```text
HR -> HR -> HRV -> HR -> HR -> SpO2 -> HR -> HR -> HRV
```

That ratio is a practical overlay/dashboard profile:

- heart rate feels live and should update often
- SpO2 changes more slowly and can be measured less frequently
- HRV can be sampled occasionally

This fixed cycle is useful for the prototype, but the scheduler model is more
flexible because it can react to which measurements are currently desired.

## Target Flow

The intended long-term flow is:

```text
Dashboard / overlay
  -> declares desired live values
  -> MeasurementScheduler serializes sensor access
  -> MeasurementCommandPort sends start/stop commands
  -> ring returns real-time readings
  -> scheduler updates latest values and freshness
  -> storage persists accepted readings
  -> UI renders latest snapshot
```

`MeasurementCommandPort` is the boundary between scheduling logic and BLE
commands. The scheduler does not need to know how packets are built or which BLE
characteristic is used. It only asks for a measurement kind to start or stop.

## What Scheduling Does Not Own

The scheduler should not own every data path in the app.

It should not:

- parse raw BLE packets
- build protocol packets directly
- render dashboard or overlay widgets
- decide how history charts aggregate stored values
- manage SQLite schema or migrations
- replace ring-log sync for stored historical data

Its job is narrower: coordinate real-time access to the shared sensor and
publish the latest live measurement snapshot.

## Why This Matters

Without scheduling, every UI surface can accidentally compete for the same ring
sensor. The dashboard might request heart rate while the overlay wants SpO2, or
a manual measurement might conflict with an automatic rotation.

With scheduling, OpenRing can keep the rule in one place:

```text
UIs request values. The scheduler owns timing.
```

That makes live measurement behavior easier to test, easier to explain, and
less dependent on button timing or widget state.
