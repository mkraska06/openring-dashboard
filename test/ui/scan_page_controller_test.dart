import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/real_time.dart';
import 'package:openring_v1/src/ui/scan_page_controller.dart';

void main() {
  group('mergeRealTimeReadingForDisplay', () {
    test(
      'keeps the last valid heart-rate reading when a pending packet arrives',
      () {
        const validHeartRate = RealTimeReading(
          type: ReadingType.heartRate,
          value: 72,
          errorCode: 0,
        );
        const pendingHeartRate = RealTimeReading(
          type: ReadingType.heartRate,
          value: 0,
          errorCode: 0,
        );

        final readings = mergeRealTimeReadingForDisplay({
          ReadingType.heartRate: validHeartRate,
        }, pendingHeartRate);

        expect(readings[ReadingType.heartRate], same(validHeartRate));
      },
    );

    test('stores the first pending reading when no valid value exists yet', () {
      const pendingSpo2 = RealTimeReading(
        type: ReadingType.spo2,
        value: 0,
        errorCode: 0,
      );

      final readings = mergeRealTimeReadingForDisplay(const {}, pendingSpo2);

      expect(readings[ReadingType.spo2], same(pendingSpo2));
    });

    test('replaces an older valid reading with a newer valid reading', () {
      const previousHeartRate = RealTimeReading(
        type: ReadingType.heartRate,
        value: 72,
        errorCode: 0,
      );
      const nextHeartRate = RealTimeReading(
        type: ReadingType.heartRate,
        value: 75,
        errorCode: 0,
      );

      final readings = mergeRealTimeReadingForDisplay({
        ReadingType.heartRate: previousHeartRate,
      }, nextHeartRate);

      expect(readings[ReadingType.heartRate], same(nextHeartRate));
    });
  });
}
