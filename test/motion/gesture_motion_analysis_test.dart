import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/storage/motion_models.dart';

void main() {
  group('analyzeMotionSession', () {
    test('calculates min max average and stability for held position', () {
      final recording = _recording(
        name: 'gesture_palm_up',
        readings: const [
          AccelerometerReading(accX: -8192, accY: 0, accZ: 0),
          AccelerometerReading(accX: -8100, accY: 50, accZ: -40),
          AccelerometerReading(accX: -8200, accY: 40, accZ: -30),
          AccelerometerReading(accX: -8150, accY: 30, accZ: -20),
          AccelerometerReading(accX: -8120, accY: 20, accZ: -10),
        ],
      );

      final stats = analyzeMotionSession(recording);

      expect(stats, isNotNull);
      expect(stats!.sampleCount, 5);
      expect(stats.x.min, closeTo(-1.001, 0.001));
      expect(stats.x.max, closeTo(-0.989, 0.001));
      expect(stats.x.average, closeTo(-0.995, 0.001));
      expect(stats.dominantAxis, 'X');
      expect(stats.isStable, isTrue);
    });

    test('does not mark short or jumpy sessions as stable', () {
      final short = analyzeMotionSession(
        _recording(
          name: 'gesture_palm_side',
          readings: const [
            AccelerometerReading(accX: 0, accY: 8192, accZ: 0),
            AccelerometerReading(accX: 0, accY: 8100, accZ: 0),
          ],
        ),
      );
      final jumpy = analyzeMotionSession(
        _recording(
          name: 'gesture_palm_down',
          readings: const [
            AccelerometerReading(accX: 8192, accY: 0, accZ: 0),
            AccelerometerReading(accX: 2000, accY: 7500, accZ: 0),
            AccelerometerReading(accX: 8192, accY: 0, accZ: 0),
            AccelerometerReading(accX: 2000, accY: 7500, accZ: 0),
            AccelerometerReading(accX: 8192, accY: 0, accZ: 0),
          ],
        ),
      );

      expect(short!.isStable, isFalse);
      expect(jumpy!.isStable, isFalse);
    });
  });

  group('analyzeGestureCalibration', () {
    test('finds separating axis and classifies held positions', () {
      final calibration = analyzeGestureCalibration([
        _recording(
          name: 'gesture_palm_up',
          readings: const [
            AccelerometerReading(accX: -8192, accY: 0, accZ: 0),
            AccelerometerReading(accX: -8100, accY: 20, accZ: -10),
            AccelerometerReading(accX: -8200, accY: 10, accZ: 10),
          ],
        ),
        _recording(
          name: 'gesture_palm_side',
          readings: const [
            AccelerometerReading(accX: 0, accY: 8192, accZ: 0),
            AccelerometerReading(accX: 20, accY: 8100, accZ: -10),
            AccelerometerReading(accX: -10, accY: 8200, accZ: 10),
          ],
        ),
        _recording(
          name: 'gesture_palm_down',
          readings: const [
            AccelerometerReading(accX: 8192, accY: 0, accZ: 0),
            AccelerometerReading(accX: 8100, accY: 20, accZ: -10),
            AccelerometerReading(accX: 8200, accY: -10, accZ: 10),
          ],
        ),
      ]);

      expect(calibration.ready, isTrue);
      expect(calibration.bestAxis, 'X');
      expect(
        classifyHeldGesturePosition(
          const AccelerometerReading(accX: -8150, accY: 30, accZ: 0),
          calibration,
        ),
        GestureMotionPreset.palmUp,
      );
      expect(
        classifyHeldGesturePosition(
          const AccelerometerReading(accX: 8150, accY: 10, accZ: 0),
          calibration,
        ),
        GestureMotionPreset.palmDown,
      );
    });

    test('does not become ready without all three position groups', () {
      final calibration = analyzeGestureCalibration([
        _recording(
          name: 'gesture_palm_up',
          readings: const [AccelerometerReading(accX: -8192, accY: 0, accZ: 0)],
        ),
      ]);

      expect(calibration.ready, isFalse);
      expect(
        classifyHeldGesturePosition(
          const AccelerometerReading(accX: -8192, accY: 0, accZ: 0),
          calibration,
        ),
        isNull,
      );
    });
  });

  group('analyzeGesturePoseSpace', () {
    test('parses new open fist and vertical preset session names', () {
      expect(
        gestureSessionName(GestureMotionPreset.openDown),
        'gesture_open_down',
      );
      expect(
        gesturePoseKeyForSessionName('gesture_fist_vertical_test'),
        const GesturePoseKey(
          shape: GestureHandShape.fist,
          pose: GestureHandPose.vertical,
        ),
      );
      expect(gesturePoseKeyForSessionName('gesture_palm_up'), isNull);
    });

    test('detects clear open fist separation for same pose', () {
      final summary = analyzeGesturePoseSpace([
        _recording(
          name: 'gesture_open_side',
          readings: const [
            AccelerometerReading(accX: 0, accY: 0, accZ: 8192),
            AccelerometerReading(accX: 20, accY: 0, accZ: 8100),
            AccelerometerReading(accX: -20, accY: 10, accZ: 8200),
            AccelerometerReading(accX: 10, accY: -10, accZ: 8180),
            AccelerometerReading(accX: 0, accY: 20, accZ: 8150),
          ],
        ),
        _recording(
          name: 'gesture_fist_side',
          readings: const [
            AccelerometerReading(accX: 4096, accY: 0, accZ: 7000),
            AccelerometerReading(accX: 4050, accY: 20, accZ: 7050),
            AccelerometerReading(accX: 4100, accY: -20, accZ: 6980),
            AccelerometerReading(accX: 4070, accY: 10, accZ: 7020),
            AccelerometerReading(accX: 4120, accY: 0, accZ: 7010),
          ],
        ),
      ]);

      final comparison = summary.openFistComparisons.firstWhere(
        (c) => c.label == 'Open/Fist side',
      );

      expect(summary.groups.length, 2);
      expect(comparison.status, GestureSeparationStatus.clear);
      expect(comparison.distanceG, greaterThan(0.25));
    });

    test('marks overlapping open fist groups as uncertain', () {
      final summary = analyzeGesturePoseSpace([
        _recording(
          name: 'gesture_open_side',
          readings: const [
            AccelerometerReading(accX: 0, accY: 0, accZ: 8192),
            AccelerometerReading(accX: 20, accY: 0, accZ: 8100),
            AccelerometerReading(accX: -20, accY: 10, accZ: 8200),
            AccelerometerReading(accX: 10, accY: -10, accZ: 8180),
            AccelerometerReading(accX: 0, accY: 20, accZ: 8150),
          ],
        ),
        _recording(
          name: 'gesture_fist_side',
          readings: const [
            AccelerometerReading(accX: 30, accY: 0, accZ: 8180),
            AccelerometerReading(accX: 10, accY: 20, accZ: 8120),
            AccelerometerReading(accX: -10, accY: -10, accZ: 8200),
            AccelerometerReading(accX: 20, accY: 10, accZ: 8160),
            AccelerometerReading(accX: 0, accY: 0, accZ: 8190),
          ],
        ),
      ]);

      final comparison = summary.openFistComparisons.firstWhere(
        (c) => c.label == 'Open/Fist side',
      );

      expect(comparison.status, GestureSeparationStatus.uncertain);
      expect(summary.overallStatus, GestureSeparationStatus.uncertain);
    });

    test('marks missing vertical comparison as more data', () {
      final summary = analyzeGesturePoseSpace([
        _recording(
          name: 'gesture_open_side',
          readings: const [
            AccelerometerReading(accX: 0, accY: 0, accZ: 8192),
            AccelerometerReading(accX: 20, accY: 0, accZ: 8100),
            AccelerometerReading(accX: -20, accY: 10, accZ: 8200),
            AccelerometerReading(accX: 10, accY: -10, accZ: 8180),
            AccelerometerReading(accX: 0, accY: 20, accZ: 8150),
          ],
        ),
      ]);

      final comparison = summary.verticalComparisons.firstWhere(
        (c) => c.label == 'open side/vertical',
      );

      expect(comparison.status, GestureSeparationStatus.moreData);
    });

    test('detects roll separation between down side and up', () {
      final summary = analyzeGesturePoseSpace([
        _recording(
          name: 'gesture_open_down',
          readings: const [
            AccelerometerReading(accX: 0, accY: -8192, accZ: 0),
            AccelerometerReading(accX: 10, accY: -8100, accZ: 10),
            AccelerometerReading(accX: -10, accY: -8200, accZ: -10),
            AccelerometerReading(accX: 0, accY: -8150, accZ: 0),
            AccelerometerReading(accX: 20, accY: -8170, accZ: 10),
          ],
        ),
        _recording(
          name: 'gesture_open_side',
          readings: const [
            AccelerometerReading(accX: 0, accY: 0, accZ: 8192),
            AccelerometerReading(accX: 20, accY: 0, accZ: 8100),
            AccelerometerReading(accX: -20, accY: 10, accZ: 8200),
            AccelerometerReading(accX: 10, accY: -10, accZ: 8180),
            AccelerometerReading(accX: 0, accY: 20, accZ: 8150),
          ],
        ),
        _recording(
          name: 'gesture_open_up',
          readings: const [
            AccelerometerReading(accX: 0, accY: 8192, accZ: 0),
            AccelerometerReading(accX: 10, accY: 8100, accZ: 10),
            AccelerometerReading(accX: -10, accY: 8200, accZ: -10),
            AccelerometerReading(accX: 0, accY: 8150, accZ: 0),
            AccelerometerReading(accX: 20, accY: 8170, accZ: 10),
          ],
        ),
      ]);

      final comparison = summary.rollComparisons.firstWhere(
        (c) => c.label == 'open roll',
      );

      expect(comparison.status, GestureSeparationStatus.clear);
      expect(comparison.distanceG, greaterThan(80));
    });
  });
}

MotionSessionRecording _recording({
  required String name,
  required List<AccelerometerReading> readings,
}) {
  final start = DateTime(2026, 6, 9, 12);
  return MotionSessionRecording(
    session: MotionSessionSummary(
      id: name.hashCode,
      deviceId: 'ring-1',
      name: name,
      startedAt: start,
      endedAt: start.add(Duration(seconds: readings.length - 1)),
    ),
    samples: [
      for (var i = 0; i < readings.length; i++)
        MotionSamplePoint(
          receivedAt: start.add(Duration(seconds: i)),
          reading: readings[i],
        ),
    ],
  );
}
