import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/packet.dart';
import 'package:openring_v1/src/protocol/real_time.dart';

void main() {
  group('makeStartRealTimeRequest', () {
    test('HR start matches existing golden packet', () {
      final p = makeStartRealTimeRequest(ReadingType.heartRate);
      expect(p[0], Cmd.startRealTime);
      expect(p[1], ReadingType.heartRate);
      expect(p[2], RealTimeAction.start);
      expect(p.length, 16);
      expect(validatePacket(p), isTrue);
    });

    test('SpO2 start has correct type', () {
      final p = makeStartRealTimeRequest(ReadingType.spo2);
      expect(p[0], Cmd.startRealTime);
      expect(p[1], ReadingType.spo2);
      expect(p[2], RealTimeAction.start);
      expect(validatePacket(p), isTrue);
    });

    test('HRV start has correct type', () {
      final p = makeStartRealTimeRequest(ReadingType.hrv);
      expect(p[1], ReadingType.hrv);
    });
  });

  group('makeStopRealTimeRequest', () {
    test('HR stop matches golden packet', () {
      final p = makeStopRealTimeRequest(ReadingType.heartRate);
      expect(p[0], Cmd.stopRealTime);
      expect(p[1], ReadingType.heartRate);
      expect(p[2], 0);
      expect(p[3], 0);
      expect(validatePacket(p), isTrue);
    });
  });

  group('parseRealTimeResponse', () {
    test('parses valid HR response with value', () {
      final packet = makePacket(Cmd.startRealTime, [
        ReadingType.heartRate,
        0,
        72,
      ]);
      final r = parseRealTimeResponse(packet);
      expect(r, isNotNull);
      expect(r!.type, ReadingType.heartRate);
      expect(r.errorCode, 0);
      expect(r.value, 72);
      expect(r.hasValue, isTrue);
    });

    test('parses pending HR response (value 0)', () {
      final packet = makePacket(Cmd.startRealTime, [
        ReadingType.heartRate,
        0,
        0,
      ]);
      final r = parseRealTimeResponse(packet);
      expect(r!.hasValue, isFalse);
    });

    test('parses SpO2 response', () {
      final packet = makePacket(Cmd.startRealTime, [ReadingType.spo2, 0, 98]);
      final r = parseRealTimeResponse(packet);
      expect(r!.type, ReadingType.spo2);
      expect(r.value, 98);
      expect(r.hasValue, isTrue);
    });

    test('parses HRV response', () {
      final packet = makePacket(Cmd.startRealTime, [ReadingType.hrv, 0, 45]);
      final r = parseRealTimeResponse(packet);
      expect(r!.type, ReadingType.hrv);
      expect(r.value, 45);
    });

    test('reports error code', () {
      final packet = makePacket(Cmd.startRealTime, [
        ReadingType.heartRate,
        3,
        0,
      ]);
      final r = parseRealTimeResponse(packet);
      expect(r!.errorCode, 3);
      expect(r.hasValue, isFalse);
    });

    test('returns null for wrong command byte', () {
      final packet = makePacket(Cmd.battery, [ReadingType.heartRate, 0, 72]);
      expect(parseRealTimeResponse(packet), isNull);
    });

    test('returns null for bad checksum', () {
      final p = makePacket(Cmd.startRealTime, [
        ReadingType.heartRate,
        0,
        72,
      ]).toList();
      p[15] ^= 0xFF;
      expect(parseRealTimeResponse(p), isNull);
    });
  });
}
