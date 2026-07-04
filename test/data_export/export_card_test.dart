import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/main.dart';
import 'package:openring_v1/src/data_export/export_card.dart';
import 'package:openring_v1/src/data_export/export_models.dart';
import 'package:openring_v1/src/storage/app_database.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';

void main() {
  testWidgets('Export section is reachable from app navigation', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const OpenRingApp(),
      ),
    );

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Data export'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
  });

  testWidgets('DataExportCard changes format and toggles data type filters', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: DataExportCard())),
      ),
    );

    expect(_chip(tester, 'Vitals').selected, isTrue);
    await tester.tap(find.text('Vitals'));
    await tester.pump();
    expect(_chip(tester, 'Vitals').selected, isFalse);

    await tester.tap(find.text('JSON'));
    await tester.pump();
    final segmentedButton = tester.widget<SegmentedButton<ExportFormat>>(
      find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<ExportFormat>,
      ),
    );
    expect(segmentedButton.selected, {ExportFormat.json});
  });

  testWidgets('DataExportCard validates empty data type selection', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: DataExportCard())),
      ),
    );

    for (final label in ['Vitals', 'Battery', 'Activity', 'Motion']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(find.text('Select at least one data type.'), findsOneWidget);
  });
}

FilterChip _chip(WidgetTester tester, String label) {
  return tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
}
