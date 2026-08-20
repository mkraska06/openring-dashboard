# Live Measurement Scheduling

Live heart rate, SpO2 and HRV measurements use the ring's optical sensor. These
measurements should not be treated as independent streams that can run in
parallel.

The app therefore runs live measurements one after another:

```text
start measurement -> collect valid values -> stop measurement -> wait briefly
```

Only one real-time measurement should actively use the ring sensor at a time.

## Current Measurement Cycle

The current daily measurement cycle favors heart rate and checks HRV and SpO2
less often:

```text
HR -> HR -> HRV -> HR -> HR -> SpO2 -> HR -> HR -> HRV
```

This ratio is used because heart rate is expected to update more often, while
SpO2 and HRV can be sampled less frequently.

Battery and activity data are separate from this real-time optical measurement
cycle. They can be requested or synced independently.

## Implementation Reference

| File | Purpose |
| --- | --- |
| [measurement_scheduler.dart](../lib/src/measurements/measurement_scheduler.dart) | Scheduling model with cooldown, retry, timeout, and freshness handling |
| [daily_measurement_cycle.dart](../lib/src/measurements/daily_measurement_cycle.dart) | Fixed live measurement rotation used by the current daily measurement cycle |

The behavior is covered by focused tests in
[test/measurements/](../test/measurements/).
