import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openring_v1/main.dart';
import 'package:openring_v1/src/storage/app_database.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';

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
}
