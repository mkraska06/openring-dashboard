import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/data_export/export_models.dart';
import 'package:openring_v1/src/data_export/export_repository.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/protocol/battery.dart';
import 'package:openring_v1/src/protocol/steps.dart';
import 'package:openring_v1/src/storage/app_database.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';

void main() {
  test(
    'ExportRepository loads selected data types inside date range',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final storage = DriftOpenRingStorage(db);
      final repository = ExportRepository(db);
      final inside = DateTime(2026, 7, 1, 8);
      final outside = DateTime(2026, 7, 3, 8);

      await storage.setLastConnectedDevice(deviceId: 'ring-1');
      await storage.insertVitalSample(
        deviceId: 'ring-1',
        kind: vitalKindHeartRate,
        value: 72,
        unit: 'BPM',
        measuredAt: inside,
        source: sampleSourceLive,
      );
      await storage.insertVitalSample(
        deviceId: 'ring-1',
        kind: vitalKindHeartRate,
        value: 80,
        unit: 'BPM',
        measuredAt: outside,
        source: sampleSourceLive,
      );
      await storage.insertBatterySnapshot(
        deviceId: 'ring-1',
        battery: const BatteryResponse(level: 85, isCharging: true),
        measuredAt: inside.add(const Duration(minutes: 1)),
      );
      await storage.insertStepEntries(
        deviceId: 'ring-1',
        entries: [
          StepEntry(
            time: inside.add(const Duration(hours: 1)),
            steps: 100,
            calories: 4,
            distanceMeters: 80,
          ),
        ],
      );
      final session = await storage.startMotionSession(
        deviceId: 'ring-1',
        name: 'gesture_open_side',
        startedAt: inside,
      );
      await storage.appendMotionSample(
        sessionId: session.id,
        reading: const AccelerometerReading(accX: 1, accY: 2, accZ: 3),
        receivedAt: inside.add(const Duration(hours: 2)),
      );

      final bundle = await repository.load(
        ExportRequest(
          start: DateTime(2026, 7, 1),
          endExclusive: DateTime(2026, 7, 2),
          types: const {
            ExportDataType.vitals,
            ExportDataType.activity,
            ExportDataType.motion,
          },
          format: ExportFormat.csv,
        ),
      );

      expect(bundle.vitals, hasLength(1));
      expect(bundle.vitals.single.value, 72);
      expect(bundle.battery, isEmpty);
      expect(bundle.activity.single.steps, 100);
      expect(bundle.motion.single.sessionName, 'gesture_open_side');
      expect(bundle.rowCount, 3);
    },
  );
}
