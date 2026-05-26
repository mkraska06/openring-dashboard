# Database Schema

OpenRing stores ring data locally in SQLite. The database is accessed through
Drift, so the schema is defined in Dart in
[lib/src/storage/app_database.dart](../lib/src/storage/app_database.dart)
and generated into SQLite tables.

The schema is built around one central device table. Time-based data references
the ring by `device_id`, which allows OpenRing to store values from more than
one ring without mixing their histories.

The renderable PlantUML source for this schema lives in
[database-schema.puml](database-schema.puml). It can be exported to PNG, SVG, or PDF for
presentations and written documentation.

## Overview

```text
devices
  device_id (PK)
      |
      |-- vital_samples.device_id (FK)
      |-- battery_snapshots.device_id (FK)
      |-- activity_intervals.device_id (FK)

app_settings
  key (PK)
```

`app_settings` is independent from the measurement tables. It stores small
application-level values, for example the id of the last connected ring.

## Tables

| Table | Purpose |
| --- | --- |
| `devices` | Known rings, their display name, last seen time, and last connected time |
| `app_settings` | Small key/value settings, such as the last connected ring |
| `vital_samples` | Heart rate, SpO2, and HRV samples with timestamp, unit, and source |
| `battery_snapshots` | Battery level and charging state at a point in time |
| `activity_intervals` | Step, calorie, and distance values for activity intervals |

## `devices`

Stores rings that OpenRing has seen or connected to.

| Column | Type | Notes |
| --- | --- | --- |
| `device_id` | text | Primary key. Usually the BLE device identifier used by the app |
| `name` | text, nullable | Advertised or displayed ring name |
| `last_seen_at` | datetime | Last time the ring was discovered or used |
| `last_connected_at` | datetime, nullable | Last successful connection time |

## `app_settings`

Stores small application settings as key/value rows.

| Column | Type | Notes |
| --- | --- | --- |
| `key` | text | Primary key |
| `value` | text | Stored setting value |

Example: `last_connected_device_id` stores which ring should be treated as the
current ring for history loading.

## `vital_samples`

Stores time-series vital measurements.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | integer | Auto-increment primary key |
| `device_id` | text | Foreign key to `devices.device_id` |
| `kind` | text | Measurement kind, such as `heart_rate`, `spo2`, or `hrv` |
| `value` | integer | Numeric measurement value |
| `unit` | text | Unit, such as `bpm`, `%`, or `ms` |
| `measured_at` | datetime | Measurement timestamp |
| `source` | text | Origin of the sample, such as `live` or `ring_log` |
| `created_at` | datetime | Time when OpenRing stored the row |

Unique key:

```text
device_id + kind + measured_at + source
```

This prevents duplicate vital samples while still allowing OpenRing to keep
live readings and synced ring-log readings separate.

## `battery_snapshots`

Stores battery state over time.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | integer | Auto-increment primary key |
| `device_id` | text | Foreign key to `devices.device_id` |
| `level` | integer | Battery percentage |
| `is_charging` | boolean | Whether the ring reports that it is charging |
| `measured_at` | datetime | Snapshot timestamp |

Unique key:

```text
device_id + measured_at
```

## `activity_intervals`

Stores activity values for a specific time interval.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | integer | Auto-increment primary key |
| `device_id` | text | Foreign key to `devices.device_id` |
| `started_at` | datetime | Start of the activity interval |
| `steps` | integer | Step count for the interval |
| `calories` | integer | Calories for the interval |
| `distance_meters` | integer | Distance for the interval |
| `source` | text | Origin of the data, such as `ring_log` |

Unique key:

```text
device_id + started_at
```

## Why This Shape

The schema separates different kinds of time-series data instead of putting
everything into one generic table. Vital samples, battery snapshots, and
activity intervals have different fields and different update behavior, so
separate tables keep the data easier to query and explain.

The shared `device_id` relationship keeps the schema simple while still making
multi-ring history possible.
