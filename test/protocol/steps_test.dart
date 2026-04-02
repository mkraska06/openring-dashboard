import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/packet.dart';
import 'package:openring_v1/src/protocol/steps.dart';

void main() {
  group('makeStepsRequest', () {
    test('produces valid 16-byte packet', () {
      final p = makeStepsRequest(DateTime(2026, 4, 1));
      expect(p.length, 16);
      expect(p[0], Cmd.getSteps);
      expect(validatePacket(p), isTrue);
    });

    test('encodes date as BCD', () {
      final p = makeStepsRequest(DateTime(2026, 4, 1));
      expect(p[1], 0x26); // year 26
      expect(p[2], 0x04); // month 4
      expect(p[3], 0x01); // day 1
    });

    test('encodes December 25 correctly', () {
      final p = makeStepsRequest(DateTime(2025, 12, 25));
      expect(p[1], 0x25); // year 25
      expect(p[2], 0x12); // month 12
      expect(p[3], 0x25); // day 25
    });
  });

  group('StepParser', () {
    test('returns empty list on 0xFF (no data)', () {
      final parser = StepParser();
      final packet = makePacket(Cmd.getSteps, [0xFF]);
      final result = parser.processPacket(packet);
      expect(result, isNotNull);
      expect(result, isEmpty);
    });

    test('handles init packet then data packet', () {
      final parser = StepParser();

      // Init packet
      final init = makePacket(Cmd.getSteps, [0xF0, 0, 1]); // new calorie protocol
      expect(parser.processPacket(init), isNull);

      // Data packet: BCD date 26/04/01, timeIndex=4 (1:00), packet 0/1,
      // calories=50 (LE), steps=100 (LE), distance=80 (LE)
      final data = makePacket(Cmd.getSteps, [
        0x26, 0x04, 0x01, // BCD date
        4, // time index (4 * 15min = 1:00)
        0, 1, // current=0, total=1
        50, 0, // calories LE
        100, 0, // steps LE
        80, 0, // distance LE
      ]);
      final result = parser.processPacket(data);
      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result[0].steps, 100);
      expect(result[0].calories, 50);
      expect(result[0].distanceMeters, 80);
      expect(result[0].time.hour, 1);
      expect(result[0].time.minute, 0);
    });
  });
}
