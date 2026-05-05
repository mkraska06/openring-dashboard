import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/battery.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/hr_log.dart';
import 'package:openring_v1/src/protocol/real_time.dart';
import 'package:openring_v1/src/protocol/steps.dart';
import 'package:openring_v1/src/storage/app_database.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';

void main() {
  late AppDatabase db;
  late DriftOpenRingStorage storage;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storage = DriftOpenRingStorage(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'device upsert updates last seen and stores last connected ring',
    () async {
      final firstSeen = DateTime.utc(2026, 4, 1, 10);
      final connectedAt = DateTime.utc(2026, 4, 1, 11);

      await storage.upsertDevice(
        deviceId: 'ring-1',
        name: 'R02_1234',
        seenAt: firstSeen,
      );
      await storage.setLastConnectedDevice(
        deviceId: 'ring-1',
        name: 'R02_1234',
        connectedAt: connectedAt,
      );

      final devices = await db.select(db.devices).get();
      expect(devices, hasLength(1));
      expect(devices.single.deviceId, 'ring-1');
      expect(devices.single.name, 'R02_1234');
      expect(devices.single.lastSeenAt.isAtSameMomentAs(connectedAt), isTrue);
      expect(
        devices.single.lastConnectedAt?.isAtSameMomentAs(connectedAt),
        isTrue,
      );
      expect(await storage.getLastConnectedDeviceId(), 'ring-1');
    },
  );

  test('vital samples are inserted idempotently by unique key', () async {
    final measuredAt = DateTime.utc(2026, 4, 1, 12);

    await storage.insertVitalSample(
      deviceId: 'ring-1',
      kind: 'heart_rate',
      value: 72,
      unit: 'BPM',
      measuredAt: measuredAt,
      source: sampleSourceLive,
    );
    await storage.insertVitalSample(
      deviceId: 'ring-1',
      kind: 'heart_rate',
      value: 72,
      unit: 'BPM',
      measuredAt: measuredAt,
      source: sampleSourceLive,
    );

    final samples = await db.select(db.vitalSamples).get();
    expect(samples, hasLength(1));
    expect(samples.single.kind, 'heart_rate');
    expect(samples.single.value, 72);
    expect(samples.single.unit, 'BPM');
    expect(samples.single.source, sampleSourceLive);
  });

  test(
    'pending live readings are ignored and valid readings persist',
    () async {
      final pending = const RealTimeReading(
        type: ReadingType.heartRate,
        value: 0,
        errorCode: 0,
      );
      final valid = const RealTimeReading(
        type: ReadingType.spo2,
        value: 98,
        errorCode: 0,
      );

      await persistRealTimeReading(
        storage: storage,
        deviceId: 'ring-1',
        reading: pending,
        measuredAt: DateTime.utc(2026, 4, 1, 12),
      );
      await persistRealTimeReading(
        storage: storage,
        deviceId: 'ring-1',
        reading: valid,
        measuredAt: DateTime.utc(2026, 4, 1, 12, 1),
      );

      final samples = await db.select(db.vitalSamples).get();
      expect(samples, hasLength(1));
      expect(samples.single.kind, 'spo2');
      expect(samples.single.value, 98);
      expect(samples.single.unit, '%');
    },
  );

  test(
    'battery snapshots store level and charging state idempotently',
    () async {
      final measuredAt = DateTime.utc(2026, 4, 1, 12);
      const battery = BatteryResponse(level: 85, isCharging: true);

      await storage.insertBatterySnapshot(
        deviceId: 'ring-1',
        battery: battery,
        measuredAt: measuredAt,
      );
      await storage.insertBatterySnapshot(
        deviceId: 'ring-1',
        battery: battery,
        measuredAt: measuredAt,
      );

      final snapshots = await db.select(db.batterySnapshots).get();
      expect(snapshots, hasLength(1));
      expect(snapshots.single.level, 85);
      expect(snapshots.single.isCharging, isTrue);
    },
  );

  test('HR log and step batches are idempotent', () async {
    final hrTime = DateTime.utc(2026, 4, 1, 12);
    final stepTime = DateTime.utc(2026, 4, 1, 12, 15);
    final hrEntries = [
      HrLogEntry(time: hrTime, bpm: 70),
      HrLogEntry(time: hrTime.add(const Duration(minutes: 5)), bpm: 73),
    ];
    final stepEntries = [
      StepEntry(time: stepTime, steps: 120, calories: 4, distanceMeters: 95),
    ];

    await storage.insertHrLogEntries(deviceId: 'ring-1', entries: hrEntries);
    await storage.insertHrLogEntries(deviceId: 'ring-1', entries: hrEntries);
    await storage.insertStepEntries(deviceId: 'ring-1', entries: stepEntries);
    await storage.insertStepEntries(deviceId: 'ring-1', entries: stepEntries);

    final samples = await db.select(db.vitalSamples).get();
    final intervals = await db.select(db.activityIntervals).get();
    expect(samples, hasLength(2));
    expect(samples.map((s) => s.source).toSet(), {sampleSourceRingLog});
    expect(intervals, hasLength(1));
    expect(intervals.single.steps, 120);
    expect(intervals.single.calories, 4);
    expect(intervals.single.distanceMeters, 95);
  });

  test(
    'history day filters vitals by selected local day and sorts by time',
    () async {
      await storage.setLastConnectedDevice(deviceId: 'ring-1');
      await storage.insertVitalSample(
        deviceId: 'ring-1',
        kind: vitalKindHeartRate,
        value: 65,
        unit: 'BPM',
        measuredAt: DateTime.utc(2026, 3, 31, 20),
        source: sampleSourceLive,
      );
      await storage.insertVitalSample(
        deviceId: 'ring-1',
        kind: vitalKindHeartRate,
        value: 72,
        unit: 'BPM',
        measuredAt: DateTime.utc(2026, 4, 1, 12, 5),
        source: sampleSourceLive,
      );
      await storage.insertVitalSample(
        deviceId: 'ring-1',
        kind: vitalKindHeartRate,
        value: 70,
        unit: 'BPM',
        measuredAt: DateTime.utc(2026, 4, 1, 12),
        source: sampleSourceLive,
      );
      await storage.insertVitalSample(
        deviceId: 'ring-1',
        kind: vitalKindHeartRate,
        value: 80,
        unit: 'BPM',
        measuredAt: DateTime.utc(2026, 4, 1, 23),
        source: sampleSourceLive,
      );

      final history = await storage.loadHistoryDay(day: DateTime(2026, 4, 1));
      final hr = history!.series(vitalKindHeartRate)!;

      expect(hr.points.map((p) => p.value), [70, 72]);
      expect(hr.min, 70);
      expect(hr.max, 72);
      expect(hr.average, 71);
    },
  );

  test(
    'history day spreads one live block over fallback measurement duration',
    () async {
      await storage.setLastConnectedDevice(deviceId: 'ring-1');
      final rawStart = DateTime.utc(2026, 4, 1, 12);

      for (var i = 0; i < 6; i++) {
        await storage.insertVitalSample(
          deviceId: 'ring-1',
          kind: vitalKindHeartRate,
          value: 70 + i,
          unit: 'BPM',
          measuredAt: rawStart.add(Duration(seconds: i)),
          source: sampleSourceLive,
        );
      }

      final history = await storage.loadHistoryDay(day: DateTime(2026, 4, 1));
      final hr = history!.series(vitalKindHeartRate)!;

      expect(hr.points.map((p) => p.value), [70, 71, 72, 73, 74, 75]);
      expect(
        hr.points.first.measuredAt.toUtc(),
        rawStart.subtract(const Duration(seconds: 30)),
      );
      expect(hr.points.last.measuredAt.toUtc(), rawStart);
    },
  );

  test(
    'history day uses previous live block and pause for next block within one minute',
    () async {
      await storage.setLastConnectedDevice(deviceId: 'ring-1');
      final firstRawStart = DateTime.utc(2026, 4, 1, 12);
      final secondRawStart = DateTime.utc(2026, 4, 1, 12, 0, 20);

      for (var i = 0; i < 6; i++) {
        await storage.insertVitalSample(
          deviceId: 'ring-1',
          kind: vitalKindHeartRate,
          value: 70 + i,
          unit: 'BPM',
          measuredAt: firstRawStart.add(Duration(seconds: i)),
          source: sampleSourceLive,
        );
        await storage.insertVitalSample(
          deviceId: 'ring-1',
          kind: vitalKindHeartRate,
          value: 80 + i,
          unit: 'BPM',
          measuredAt: secondRawStart.add(Duration(seconds: i)),
          source: sampleSourceLive,
        );
      }

      final history = await storage.loadHistoryDay(day: DateTime(2026, 4, 1));
      final hr = history!.series(vitalKindHeartRate)!;
      final secondBlock = hr.points.where((p) => p.value >= 80).toList();

      expect(
        secondBlock.first.measuredAt.toUtc(),
        firstRawStart.add(const Duration(seconds: 4)),
      );
      expect(secondBlock.last.measuredAt.toUtc(), secondRawStart);
    },
  );

  test(
    'history day keeps adjacent live block identity for chart aggregation',
    () async {
      await storage.setLastConnectedDevice(deviceId: 'ring-1');
      final firstRawStart = DateTime.utc(2026, 4, 1, 12);
      final secondRawStart = DateTime.utc(2026, 4, 1, 12, 0, 20);

      for (var i = 0; i < 6; i++) {
        await storage.insertVitalSample(
          deviceId: 'ring-1',
          kind: vitalKindHeartRate,
          value: 70 + i,
          unit: 'BPM',
          measuredAt: firstRawStart.add(Duration(seconds: i)),
          source: sampleSourceLive,
        );
        await storage.insertVitalSample(
          deviceId: 'ring-1',
          kind: vitalKindHeartRate,
          value: 80 + i,
          unit: 'BPM',
          measuredAt: secondRawStart.add(Duration(seconds: i)),
          source: sampleSourceLive,
        );
      }

      final history = await storage.loadHistoryDay(day: DateTime(2026, 4, 1));
      final hr = history!.series(vitalKindHeartRate)!;
      final firstBlockIds = hr.points
          .where((p) => p.value < 80)
          .map((p) => p.liveBlockId)
          .toSet();
      final secondBlockIds = hr.points
          .where((p) => p.value >= 80)
          .map((p) => p.liveBlockId)
          .toSet();

      expect(firstBlockIds, {0});
      expect(secondBlockIds, {1});
    },
  );

  test(
    'history day falls back to thirty seconds when previous live block is older than one minute',
    () async {
      await storage.setLastConnectedDevice(deviceId: 'ring-1');
      final firstRawStart = DateTime.utc(2026, 4, 1, 12);
      final secondRawStart = DateTime.utc(2026, 4, 1, 12, 2);

      for (var i = 0; i < 6; i++) {
        await storage.insertVitalSample(
          deviceId: 'ring-1',
          kind: vitalKindHeartRate,
          value: 70 + i,
          unit: 'BPM',
          measuredAt: firstRawStart.add(Duration(seconds: i)),
          source: sampleSourceLive,
        );
        await storage.insertVitalSample(
          deviceId: 'ring-1',
          kind: vitalKindHeartRate,
          value: 80 + i,
          unit: 'BPM',
          measuredAt: secondRawStart.add(Duration(seconds: i)),
          source: sampleSourceLive,
        );
      }

      final history = await storage.loadHistoryDay(day: DateTime(2026, 4, 1));
      final hr = history!.series(vitalKindHeartRate)!;
      final secondBlock = hr.points.where((p) => p.value >= 80).toList();

      expect(
        secondBlock.first.measuredAt.toUtc(),
        secondRawStart.subtract(const Duration(seconds: 30)),
      );
      expect(secondBlock.last.measuredAt.toUtc(), secondRawStart);
    },
  );

  test('history day does not adjust ring log samples', () async {
    await storage.setLastConnectedDevice(deviceId: 'ring-1');
    final rawStart = DateTime.utc(2026, 4, 1, 12);

    for (var i = 0; i < 6; i++) {
      await storage.insertVitalSample(
        deviceId: 'ring-1',
        kind: vitalKindHeartRate,
        value: 70 + i,
        unit: 'BPM',
        measuredAt: rawStart.add(Duration(seconds: i)),
        source: sampleSourceRingLog,
      );
    }

    final history = await storage.loadHistoryDay(day: DateTime(2026, 4, 1));
    final hr = history!.series(vitalKindHeartRate)!;

    expect(hr.points.map((p) => p.measuredAt.toUtc()), [
      for (var i = 0; i < 6; i++) rawStart.add(Duration(seconds: i)),
    ]);
  });

  test(
    'history day sums activity intervals and uses last connected ring',
    () async {
      await storage.setLastConnectedDevice(deviceId: 'ring-1');
      await storage.insertStepEntries(
        deviceId: 'ring-1',
        entries: [
          StepEntry(
            time: DateTime.utc(2026, 4, 1, 8),
            steps: 100,
            calories: 3,
            distanceMeters: 80,
          ),
          StepEntry(
            time: DateTime.utc(2026, 4, 1, 8, 15),
            steps: 150,
            calories: 4,
            distanceMeters: 120,
          ),
          StepEntry(
            time: DateTime.utc(2026, 4, 2),
            steps: 999,
            calories: 9,
            distanceMeters: 999,
          ),
        ],
      );

      final history = await storage.loadHistoryDay(day: DateTime(2026, 4, 1));

      expect(history!.deviceId, 'ring-1');
      expect(history.activity.points, hasLength(2));
      expect(history.activity.totalSteps, 250);
      expect(history.activity.totalCalories, 7);
      expect(history.activity.totalDistanceMeters, 200);
    },
  );

  test('history day returns null when no last connected ring exists', () async {
    expect(await storage.loadHistoryDay(day: DateTime(2026, 4, 1)), isNull);
  });
}
