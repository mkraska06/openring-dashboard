import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/protocol/packet.dart';

void main() {
  group('makeAccelerometerStartRequest', () {
    test('has correct command and sub-data', () {
      final p = makeAccelerometerStartRequest();
      expect(p[0], cmdRawSensor);
      expect(p[1], 0x04);
      expect(p[2], 0x04);
      expect(p.length, 16);
      expect(validatePacket(p), isTrue);
    });
  });

  group('makeAccelerometerStopRequest', () {
    test('has correct command and sub-data', () {
      final p = makeAccelerometerStopRequest();
      expect(p[0], cmdRawSensor);
      expect(p[1], 0x02);
      expect(validatePacket(p), isTrue);
    });
  });

  group('parseAccelerometerResponse', () {
    test('parses positive values', () {
      // accX=100, accY=200, accZ=300
      final packet = makePacket(cmdRawSensor, [
        0x03, // data sub-type
        100, 0, // accX = 100 (LE)
        200, 0, // accY = 200 (LE)
        44, 1, // accZ = 300 (LE: 0x012C)
      ]);
      final r = parseAccelerometerResponse(packet);
      expect(r, isNotNull);
      expect(r!.accX, 100);
      expect(r.accY, 200);
      expect(r.accZ, 300);
    });

    test('parses negative values (signed 16-bit)', () {
      // accZ = -100 → 0xFF9C in unsigned 16-bit LE = [0x9C, 0xFF]
      final packet = makePacket(cmdRawSensor, [
        0x03,
        0, 0, // accX = 0
        0, 0, // accY = 0
        0x9C, 0xFF, // accZ = -100
      ]);
      final r = parseAccelerometerResponse(packet);
      expect(r!.accZ, -100);
    });

    test('returns null for non-data sub-type', () {
      final packet = makePacket(cmdRawSensor, [0x01, 0, 0, 0, 0, 0, 0]);
      expect(parseAccelerometerResponse(packet), isNull);
    });

    test('returns null for wrong command', () {
      final packet = makePacket(0x03, [0x03, 100, 0, 200, 0, 44, 1]);
      expect(parseAccelerometerResponse(packet), isNull);
    });

    test('returns null for bad checksum', () {
      final p = makePacket(cmdRawSensor, [0x03, 100, 0, 200, 0, 44, 1]).toList();
      p[15] ^= 0xFF;
      expect(parseAccelerometerResponse(p), isNull);
    });
  });
}
