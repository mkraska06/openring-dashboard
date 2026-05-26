import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../protocol/battery.dart';
import '../protocol/accelerometer.dart';
import '../protocol/commands.dart';
import '../protocol/hr_log.dart';
import '../protocol/real_time.dart';
import '../protocol/steps.dart';
import 'app_database.dart';
import 'history_models.dart';
import 'motion_models.dart';

const lastConnectedDeviceSettingKey = 'last_connected_device_id';

abstract class OpenRingStorage {
  Future<void> upsertDevice({
    required String deviceId,
    String? name,
    DateTime? seenAt,
  });

  Future<void> setLastConnectedDevice({
    required String deviceId,
    String? name,
    DateTime? connectedAt,
  });

  Future<String?> getLastConnectedDeviceId();

  Future<HistoryDay?> loadHistoryDay({required DateTime day, String? deviceId});

  Future<void> insertVitalSample({
    required String deviceId,
    required String kind,
    required int value,
    required String unit,
    required DateTime measuredAt,
    required String source,
  });

  Future<void> insertBatterySnapshot({
    required String deviceId,
    required BatteryResponse battery,
    DateTime? measuredAt,
  });

  Future<void> insertHrLogEntries({
    required String deviceId,
    required List<HrLogEntry> entries,
  });

  Future<void> insertStepEntries({
    required String deviceId,
    required List<StepEntry> entries,
  });

  Future<MotionSessionSummary> startMotionSession({
    required String deviceId,
    required String name,
    DateTime? startedAt,
  });

  Future<void> appendMotionSample({
    required int sessionId,
    required AccelerometerReading reading,
    DateTime? receivedAt,
  });

  Future<void> stopMotionSession({required int sessionId, DateTime? endedAt});

  Future<MotionSessionRecording?> loadLatestMotionSession({
    required String deviceId,
  });
}

class DriftOpenRingStorage implements OpenRingStorage {
  const DriftOpenRingStorage(this._db);

  final AppDatabase _db;

  @override
  Future<void> upsertDevice({
    required String deviceId,
    String? name,
    DateTime? seenAt,
  }) async {
    final now = seenAt ?? DateTime.now().toUtc();
    await _db
        .into(_db.devices)
        .insertOnConflictUpdate(
          DevicesCompanion(
            deviceId: Value(deviceId),
            name: Value(name),
            lastSeenAt: Value(now),
          ),
        );
  }

  @override
  Future<void> setLastConnectedDevice({
    required String deviceId,
    String? name,
    DateTime? connectedAt,
  }) async {
    final now = connectedAt ?? DateTime.now().toUtc();
    await _db.transaction(() async {
      await _db
          .into(_db.devices)
          .insertOnConflictUpdate(
            DevicesCompanion(
              deviceId: Value(deviceId),
              name: Value(name),
              lastSeenAt: Value(now),
              lastConnectedAt: Value(now),
            ),
          );
      await _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: lastConnectedDeviceSettingKey,
              value: deviceId,
            ),
          );
    });
  }

  @override
  Future<String?> getLastConnectedDeviceId() async {
    final row =
        await (_db.select(_db.appSettings)
              ..where((s) => s.key.equals(lastConnectedDeviceSettingKey)))
            .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<HistoryDay?> loadHistoryDay({
    required DateTime day,
    String? deviceId,
  }) async {
    final resolvedDeviceId = deviceId ?? await getLastConnectedDeviceId();
    if (resolvedDeviceId == null) return null;

    final startLocal = DateTime(day.year, day.month, day.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();

    final sampleRows =
        await (_db.select(_db.vitalSamples)
              ..where(
                (s) =>
                    s.deviceId.equals(resolvedDeviceId) &
                    s.measuredAt.isBiggerOrEqualValue(startUtc) &
                    s.measuredAt.isSmallerThanValue(endUtc),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.measuredAt)]))
            .get();

    final intervalRows =
        await (_db.select(_db.activityIntervals)
              ..where(
                (a) =>
                    a.deviceId.equals(resolvedDeviceId) &
                    a.startedAt.isBiggerOrEqualValue(startUtc) &
                    a.startedAt.isSmallerThanValue(endUtc),
              )
              ..orderBy([(a) => OrderingTerm.asc(a.startedAt)]))
            .get();

    final grouped = <String, List<VitalHistoryPoint>>{};
    final units = <String, String>{};
    for (final row in sampleRows) {
      grouped
          .putIfAbsent(row.kind, () => [])
          .add(
            VitalHistoryPoint(
              measuredAt: row.measuredAt.toLocal(),
              value: row.value,
              source: row.source,
            ),
          );
      units[row.kind] = row.unit;
    }

    final vitals = <String, VitalHistorySeries>{
      for (final entry in grouped.entries)
        entry.key: VitalHistorySeries(
          kind: entry.key,
          unit: units[entry.key] ?? '',
          points: List.unmodifiable(_correctLiveHistoryTimes(entry.value)),
        ),
    };

    final activity = ActivityDaySummary(
      points: [
        for (final row in intervalRows)
          ActivityHistoryPoint(
            startedAt: row.startedAt.toLocal(),
            steps: row.steps,
            calories: row.calories,
            distanceMeters: row.distanceMeters,
          ),
      ],
    );

    return HistoryDay(
      deviceId: resolvedDeviceId,
      day: startLocal,
      vitals: vitals,
      activity: activity,
    );
  }

  @override
  Future<void> insertVitalSample({
    required String deviceId,
    required String kind,
    required int value,
    required String unit,
    required DateTime measuredAt,
    required String source,
  }) async {
    await upsertDevice(deviceId: deviceId, seenAt: measuredAt);
    await _db
        .into(_db.vitalSamples)
        .insert(
          VitalSamplesCompanion.insert(
            deviceId: deviceId,
            kind: kind,
            value: value,
            unit: unit,
            measuredAt: measuredAt.toUtc(),
            source: source,
            createdAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<void> insertBatterySnapshot({
    required String deviceId,
    required BatteryResponse battery,
    DateTime? measuredAt,
  }) async {
    final time = (measuredAt ?? DateTime.now()).toUtc();
    await upsertDevice(deviceId: deviceId, seenAt: time);
    await _db
        .into(_db.batterySnapshots)
        .insert(
          BatterySnapshotsCompanion.insert(
            deviceId: deviceId,
            level: battery.level,
            isCharging: battery.isCharging,
            measuredAt: time,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<void> insertHrLogEntries({
    required String deviceId,
    required List<HrLogEntry> entries,
  }) async {
    if (entries.isEmpty) return;
    await upsertDevice(deviceId: deviceId, seenAt: DateTime.now().toUtc());
    await _db.batch((batch) {
      batch.insertAll(_db.vitalSamples, [
        for (final entry in entries)
          VitalSamplesCompanion.insert(
            deviceId: deviceId,
            kind: vitalKindForReadingType(ReadingType.heartRate)!,
            value: entry.bpm,
            unit: unitForReadingType(ReadingType.heartRate)!,
            measuredAt: entry.time.toUtc(),
            source: sampleSourceRingLog,
            createdAt: DateTime.now().toUtc(),
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  @override
  Future<void> insertStepEntries({
    required String deviceId,
    required List<StepEntry> entries,
  }) async {
    if (entries.isEmpty) return;
    await upsertDevice(deviceId: deviceId, seenAt: DateTime.now().toUtc());
    await _db.batch((batch) {
      batch.insertAll(_db.activityIntervals, [
        for (final entry in entries)
          ActivityIntervalsCompanion.insert(
            deviceId: deviceId,
            startedAt: entry.time.toUtc(),
            steps: entry.steps,
            calories: entry.calories,
            distanceMeters: entry.distanceMeters,
            source: sampleSourceRingLog,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  @override
  Future<MotionSessionSummary> startMotionSession({
    required String deviceId,
    required String name,
    DateTime? startedAt,
  }) async {
    final time = (startedAt ?? DateTime.now()).toUtc();
    await upsertDevice(deviceId: deviceId, seenAt: time);
    final sessionId = await _db
        .into(_db.motionSessions)
        .insert(
          MotionSessionsCompanion.insert(
            deviceId: deviceId,
            name: name,
            startedAt: time,
          ),
        );
    return MotionSessionSummary(
      id: sessionId,
      deviceId: deviceId,
      name: name,
      startedAt: time.toLocal(),
    );
  }

  @override
  Future<void> appendMotionSample({
    required int sessionId,
    required AccelerometerReading reading,
    DateTime? receivedAt,
  }) {
    return _db
        .into(_db.motionSamples)
        .insert(
          MotionSamplesCompanion.insert(
            sessionId: sessionId,
            receivedAt: (receivedAt ?? DateTime.now()).toUtc(),
            accX: reading.accX,
            accY: reading.accY,
            accZ: reading.accZ,
          ),
        );
  }

  @override
  Future<void> stopMotionSession({required int sessionId, DateTime? endedAt}) {
    return (_db.update(
      _db.motionSessions,
    )..where((session) => session.id.equals(sessionId))).write(
      MotionSessionsCompanion(
        endedAt: Value((endedAt ?? DateTime.now()).toUtc()),
      ),
    );
  }

  @override
  Future<MotionSessionRecording?> loadLatestMotionSession({
    required String deviceId,
  }) async {
    final sessions =
        await (_db.select(_db.motionSessions)
              ..where((row) => row.deviceId.equals(deviceId))
              ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]))
            .get();

    for (final session in sessions) {
      final sampleRows =
          await (_db.select(_db.motionSamples)
                ..where((sample) => sample.sessionId.equals(session.id))
                ..orderBy([(sample) => OrderingTerm.asc(sample.receivedAt)]))
              .get();
      if (sampleRows.isEmpty) continue;

      return MotionSessionRecording(
        session: MotionSessionSummary(
          id: session.id,
          deviceId: session.deviceId,
          name: session.name,
          startedAt: session.startedAt.toLocal(),
          endedAt: session.endedAt?.toLocal(),
        ),
        samples: [
          for (final sample in sampleRows)
            MotionSamplePoint(
              receivedAt: sample.receivedAt.toLocal(),
              reading: AccelerometerReading(
                accX: sample.accX,
                accY: sample.accY,
                accZ: sample.accZ,
              ),
            ),
        ],
      );
    }

    return null;
  }
}

const sampleSourceLive = 'live';
const sampleSourceRingLog = 'ring_log';
const vitalKindHeartRate = 'heart_rate';
const vitalKindSpo2 = 'spo2';
const vitalKindHrv = 'hrv';

String? vitalKindForReadingType(int readingType) {
  return switch (readingType) {
    ReadingType.heartRate => vitalKindHeartRate,
    ReadingType.spo2 => vitalKindSpo2,
    ReadingType.hrv => vitalKindHrv,
    _ => null,
  };
}

String? unitForReadingType(int readingType) {
  return readingTypeInfo[readingType]?.unit;
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final openRingStorageProvider = Provider<OpenRingStorage>((ref) {
  return DriftOpenRingStorage(ref.watch(appDatabaseProvider));
});

Future<void> persistRealTimeReading({
  required OpenRingStorage storage,
  required String deviceId,
  required RealTimeReading reading,
  DateTime? measuredAt,
}) async {
  if (!reading.hasValue) return;
  final kind = vitalKindForReadingType(reading.type);
  final unit = unitForReadingType(reading.type);
  if (kind == null || unit == null) return;

  await storage.insertVitalSample(
    deviceId: deviceId,
    kind: kind,
    value: reading.value,
    unit: unit,
    measuredAt: (measuredAt ?? DateTime.now()).toUtc(),
    source: sampleSourceLive,
  );
}

const _liveBlockGap = Duration(seconds: 6);
const _liveBlockPause = Duration(seconds: 4);
const _liveBlockFallbackDuration = Duration(seconds: 30);
const _liveBlockPreviousWindow = Duration(minutes: 1);

List<VitalHistoryPoint> _correctLiveHistoryTimes(
  List<VitalHistoryPoint> points,
) {
  if (points.length < 2) return points;

  final livePoints = points
      .where((point) => point.source == sampleSourceLive)
      .toList();
  if (livePoints.length < 2) return points;

  final correctedLivePoints = <VitalHistoryPoint>[];
  DateTime? previousBlockEnd;

  final blocks = _liveMeasurementBlocks(livePoints);
  for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
    final block = blocks[blockIndex];
    final rawBlockEnd = block.first.measuredAt;
    var blockEnd = rawBlockEnd;
    DateTime blockStart;

    if (previousBlockEnd != null &&
        rawBlockEnd.difference(previousBlockEnd) <= _liveBlockPreviousWindow) {
      blockStart = previousBlockEnd.add(_liveBlockPause);
      if (!blockEnd.isAfter(blockStart)) {
        blockEnd = blockStart;
      }
    } else {
      blockStart = blockEnd.subtract(_liveBlockFallbackDuration);
    }

    correctedLivePoints.addAll(
      _spreadHistoryBlock(
        block,
        start: blockStart,
        end: blockEnd,
        liveBlockId: blockIndex,
      ),
    );
    previousBlockEnd = blockEnd;
  }

  final corrected = <VitalHistoryPoint>[
    for (final point in points)
      if (point.source != sampleSourceLive) point,
    ...correctedLivePoints,
  ]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  return corrected;
}

List<List<VitalHistoryPoint>> _liveMeasurementBlocks(
  List<VitalHistoryPoint> points,
) {
  final blocks = <List<VitalHistoryPoint>>[];
  var current = <VitalHistoryPoint>[points.first];

  for (final point in points.skip(1)) {
    final gap = point.measuredAt.difference(current.last.measuredAt);
    if (gap <= _liveBlockGap) {
      current.add(point);
    } else {
      blocks.add(current);
      current = <VitalHistoryPoint>[point];
    }
  }

  blocks.add(current);
  return blocks;
}

List<VitalHistoryPoint> _spreadHistoryBlock(
  List<VitalHistoryPoint> block, {
  required DateTime start,
  required DateTime end,
  required int liveBlockId,
}) {
  if (block.length == 1) {
    return [
      VitalHistoryPoint(
        measuredAt: end,
        value: block.single.value,
        source: block.single.source,
        liveBlockId: liveBlockId,
      ),
    ];
  }

  final span = end.difference(start).inMicroseconds;
  final step = span / (block.length - 1);

  return [
    for (var i = 0; i < block.length; i++)
      VitalHistoryPoint(
        measuredAt: start.add(Duration(microseconds: (step * i).round())),
        value: block[i].value,
        source: block[i].source,
        liveBlockId: liveBlockId,
      ),
  ];
}
