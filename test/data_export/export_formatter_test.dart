import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/data_export/export_formatter.dart';
import 'package:openring_v1/src/data_export/export_models.dart';

void main() {
  final bundle = ExportBundle(
    start: DateTime(2026, 7, 1),
    endExclusive: DateTime(2026, 7, 2),
    types: const {
      ExportDataType.vitals,
      ExportDataType.battery,
      ExportDataType.activity,
      ExportDataType.motion,
    },
    vitals: [
      ExportVitalRow(
        deviceId: 'ring-1',
        kind: 'heart_rate',
        value: 72,
        unit: 'BPM',
        measuredAt: DateTime(2026, 7, 1, 8, 30),
        source: 'live',
      ),
    ],
    battery: [
      ExportBatteryRow(
        deviceId: 'ring-1',
        level: 85,
        isCharging: true,
        measuredAt: DateTime(2026, 7, 1, 8, 31),
      ),
    ],
    activity: [
      ExportActivityRow(
        deviceId: 'ring-1',
        startedAt: DateTime(2026, 7, 1, 9),
        steps: 120,
        calories: 4,
        distanceMeters: 80,
        source: 'ring_log',
      ),
    ],
    motion: [
      ExportMotionRow(
        deviceId: 'ring-1',
        sessionId: 7,
        sessionName: 'gesture, quoted',
        receivedAt: DateTime(2026, 7, 1, 10),
        accX: 1,
        accY: -2,
        accZ: 3,
      ),
    ],
  );

  test('formatExportCsv emits one normalized table with escaped values', () {
    final csv = formatExportCsv(bundle);

    expect(csv, contains('record_type,device_id,timestamp'));
    expect(csv, contains('vital,ring-1,2026-07-01T08:30:00.000'));
    expect(csv, contains('battery,ring-1,2026-07-01T08:31:00.000'));
    expect(csv, contains('activity,ring-1,2026-07-01T09:00:00.000'));
    expect(csv, contains('"gesture, quoted"'));
  });

  test('formatExportJson emits metadata and typed arrays', () {
    final decoded =
        jsonDecode(formatExportJson(bundle)) as Map<String, dynamic>;

    expect(decoded['metadata']['rowCount'], 4);
    expect(decoded['vitals'][0]['kind'], 'heart_rate');
    expect(decoded['battery'][0]['isCharging'], isTrue);
    expect(decoded['activity'][0]['steps'], 120);
    expect(decoded['motion'][0]['sessionName'], 'gesture, quoted');
  });
}
