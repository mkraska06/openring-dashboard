import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/ble/ble_service.dart';
import 'package:openring_v1/src/ui/scan_page_widgets.dart';

void main() {
  testWidgets('ScanStatusIndicator uses high contrast disconnected colors', (
    tester,
  ) async {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colorScheme),
        home: ColoredBox(
          color: colorScheme.primary,
          child: const ScanStatusIndicator(
            status: BleConnectionStatus.disconnected,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Disconnected'));
    expect(text.style?.color, colorScheme.errorContainer);
    expect(text.style?.fontWeight, FontWeight.w600);

    final dot = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ScanStatusIndicator),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = dot.decoration! as BoxDecoration;
    expect(decoration.color, colorScheme.errorContainer);
  });
}
