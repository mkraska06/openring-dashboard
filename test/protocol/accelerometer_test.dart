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
        0, 100, // accX = 100 (BE)
        0, 200, // accY = 200 (BE)
        1, 44, // accZ = 300 (BE: 0x012C)
      ]);
      final r = parseAccelerometerResponse(packet);
      expect(r, isNotNull);
      expect(r!.accX, 100);
      expect(r.accY, 200);
      expect(r.accZ, 300);
    });

    test('parses negative values (signed 16-bit)', () {
      // accZ = -100 -> 0xFF9C in unsigned 16-bit BE = [0xFF, 0x9C]
      final packet = makePacket(cmdRawSensor, [
        0x03,
        0, 0, // accX = 0
        0, 0, // accY = 0
        0xFF, 0x9C, // accZ = -100
      ]);
      final r = parseAccelerometerResponse(packet);
      expect(r!.accZ, -100);
    });

    test('parses observed resting ring samples as big-endian axes', () {
      final lyingFlat = parseAccelerometerResponse([
        0xA1,
        0x03,
        0x1E,
        0x89,
        0xFD,
        0xF2,
        0xFB,
        0x4B,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0x80,
      ]);
      final standing = parseAccelerometerResponse([
        0xA1,
        0x03,
        0xFE,
        0x98,
        0xDE,
        0xBD,
        0x01,
        0x42,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0x18,
      ]);

      expect(lyingFlat, isNotNull);
      expect(lyingFlat!.accX, 7817);
      expect(lyingFlat.accY, -526);
      expect(lyingFlat.accZ, -1205);
      expect(lyingFlat.xG, closeTo(0.954, 0.001));
      expect(lyingFlat.yG, closeTo(-0.064, 0.001));
      expect(lyingFlat.zG, closeTo(-0.147, 0.001));
      expect(lyingFlat.magnitudeG, closeTo(0.968, 0.001));

      expect(standing, isNotNull);
      expect(standing!.accX, -360);
      expect(standing.accY, -8515);
      expect(standing.accZ, 322);
    });

    test('returns null for non-data sub-type', () {
      final packet = makePacket(cmdRawSensor, [0x01, 0, 0, 0, 0, 0, 0]);
      expect(parseAccelerometerResponse(packet), isNull);
    });

    test('returns null for wrong command', () {
      final packet = makePacket(0x03, [0x03, 0, 100, 0, 200, 1, 44]);
      expect(parseAccelerometerResponse(packet), isNull);
    });

    test('returns null for bad checksum', () {
      final p = makePacket(cmdRawSensor, [
        0x03,
        0,
        100,
        0,
        200,
        1,
        44,
      ]).toList();
      p[15] ^= 0xFF;
      expect(parseAccelerometerResponse(p), isNull);
    });
  });
}
