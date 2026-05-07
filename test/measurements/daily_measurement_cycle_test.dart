import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/measurements/daily_measurement_cycle.dart';
import 'package:openring_v1/src/protocol/commands.dart';

void main() {
  group('dailyMeasurementCycle', () {
    test('uses the editable 6:2:1 order with HR pairs', () {
      expect(dailyMeasurementCycle, const [
        ReadingType.heartRate,
        ReadingType.heartRate,
        ReadingType.hrv,
        ReadingType.heartRate,
        ReadingType.heartRate,
        ReadingType.spo2,
        ReadingType.heartRate,
        ReadingType.heartRate,
        ReadingType.hrv,
      ]);
    });

    test('cursor wraps after the last entry', () {
      final cursor = DailyMeasurementCycleCursor();
      final seen = <int>[];

      for (var i = 0; i < dailyMeasurementCycle.length + 1; i++) {
        seen.add(cursor.current);
        cursor.advance();
      }

      expect(seen.first, ReadingType.heartRate);
      expect(seen.last, ReadingType.heartRate);
      expect(cursor.index, 1);
    });
  });
}
