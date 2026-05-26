import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openring_v1/main.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/storage/app_database.dart';
import 'package:openring_v1/src/storage/motion_models.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';
import 'package:openring_v1/src/ui/scan_page_widgets.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const OpenRingApp(),
      ),
    );
    expect(find.text('OpenRing'), findsOneWidget);
  });

  testWidgets('App can switch to empty History view', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const OpenRingApp(),
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Noch kein Ring gespeichert'), findsOneWidget);
  });

  testWidgets('History renders sample HR chart controls and unit axis', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final storage = DriftOpenRingStorage(db);
    await storage.setLastConnectedDevice(deviceId: 'ring-1');
    await storage.insertVitalSample(
      deviceId: 'ring-1',
      kind: vitalKindHeartRate,
      value: 72,
      unit: 'BPM',
      measuredAt: DateTime.now().subtract(const Duration(minutes: 5)),
      source: sampleSourceLive,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const OpenRingApp(),
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump();

    expect(find.text('BPM'), findsWidgets);
    expect(find.text('1m'), findsWidgets);
    expect(find.text('5m'), findsWidgets);
    expect(find.text('10m'), findsWidgets);
    expect(find.text('30m'), findsWidgets);
    expect(find.text('2h'), findsWidgets);
    expect(find.text('Tag'), findsWidgets);
  });

  testWidgets('Motion lab renders recording controls and empty plot state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MotionLabCard(
            sessionName: 'Motion Test',
            recording: null,
            isRecording: false,
            canRecord: true,
            onNameChanged: (_) {},
            onRecord: () async {},
            onStop: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Motion Lab'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Noch keine Motion-Samples.'), findsOneWidget);
  });

  testWidgets('Motion lab renders a chart for session samples', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MotionLabCard(
            sessionName: 'Ruhe',
            recording: MotionSessionRecording(
              session: MotionSessionSummary(
                id: 7,
                deviceId: 'ring-1',
                name: 'Ruhe',
                startedAt: DateTime(2026, 5, 22, 12),
              ),
              samples: [
                MotionSamplePoint(
                  receivedAt: DateTime(2026, 5, 22, 12),
                  reading: const AccelerometerReading(
                    accX: 7817,
                    accY: -526,
                    accZ: -1205,
                  ),
                ),
                MotionSamplePoint(
                  receivedAt: DateTime(2026, 5, 22, 12, 0, 1),
                  reading: const AccelerometerReading(
                    accX: -360,
                    accY: -8515,
                    accZ: 322,
                  ),
                ),
              ],
            ),
            isRecording: false,
            canRecord: true,
            onNameChanged: (_) {},
            onRecord: () async {},
            onStop: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Letzte Session | 2 Samples'), findsOneWidget);
    expect(find.text('|a|'), findsOneWidget);
    expect(find.text('Noch keine Motion-Samples.'), findsNothing);
  });
}
