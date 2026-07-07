import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/data_export/export_controller.dart';
import 'package:openring_v1/src/data_export/export_models.dart';
import 'package:openring_v1/src/data_export/export_repository.dart';
import 'package:openring_v1/src/storage/app_database.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  test('DataExportNotifier saves export into selected directory', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final storage = DriftOpenRingStorage(db);
    final exportDir = Directory(
      p.join(
        Directory.current.path,
        'build',
        'test_exports',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    addTearDown(() async {
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
    });

    await storage.setLastConnectedDevice(deviceId: 'ring-1');
    await storage.insertVitalSample(
      deviceId: 'ring-1',
      kind: vitalKindHeartRate,
      value: 64,
      unit: 'BPM',
      measuredAt: DateTime(2026, 7, 1, 9),
      source: sampleSourceLive,
    );

    final notifier = DataExportNotifier(
      ExportRepository(db),
      chooseDirectory: () async => exportDir.path,
      now: () => DateTime(2026, 7, 1, 12),
    );

    await notifier.export(
      ExportRequest(
        start: DateTime(2026, 7),
        endExclusive: DateTime(2026, 7, 2),
        types: const {ExportDataType.vitals},
        format: ExportFormat.csv,
      ),
    );

    final expectedPath = p.join(
      exportDir.path,
      'openring_export_20260701_120000.csv',
    );
    final file = File(expectedPath);

    expect(notifier.state.error, isNull);
    expect(notifier.state.isExporting, isFalse);
    expect(notifier.state.lastFilePath, expectedPath);
    expect(notifier.state.lastRowCount, 1);
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), contains('heart_rate'));
  });

  test(
    'DataExportNotifier treats directory picker cancellation as no-op',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final notifier = DataExportNotifier(
        ExportRepository(db),
        chooseDirectory: () async => null,
      );

      await notifier.export(
        ExportRequest(
          start: DateTime(2026, 7),
          endExclusive: DateTime(2026, 7, 2),
          types: const {ExportDataType.vitals},
          format: ExportFormat.json,
        ),
      );

      expect(notifier.state.error, isNull);
      expect(notifier.state.isExporting, isFalse);
      expect(notifier.state.lastFilePath, isNull);
      expect(notifier.state.lastRowCount, isNull);
    },
  );
}
