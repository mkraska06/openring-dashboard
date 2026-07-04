import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/battery.dart';
import 'package:openring_v1/src/protocol/packet.dart';

// Helper: build a syntactically valid battery response with given values.
// The ring echoes command 0x03 in byte 0, level in byte 1, charging in byte 2.
Uint8List _buildResponse(int level, int chargingFlag) {
  return makePacket(0x03, [level, chargingFlag]);
}

void main() {
  group('makeBatteryRequest', () {
    // Python reference: make_packet(CMD_BATTERY=3, None)
    // → b'\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03'
    test('matches Python golden packet exactly', () {
      final golden = Uint8List.fromList([
        0x03,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x03,
      ]);
      expect(makeBatteryRequest(), golden);
    });

    test('is 16 bytes long', () {
      expect(makeBatteryRequest().length, 16);
    });

    test('has a valid checksum', () {
      expect(validatePacket(makeBatteryRequest()), isTrue);
    });
  });

  group('parseBatteryResponse – valid packets', () {
    test('parses battery level 64%, not charging', () {
      final resp = parseBatteryResponse(_buildResponse(64, 0));
      expect(resp, isNotNull);
      expect(resp!.level, 64);
      expect(resp.isCharging, isFalse);
    });

    test('parses battery level 85%, charging', () {
      final resp = parseBatteryResponse(_buildResponse(85, 1));
      expect(resp, isNotNull);
      expect(resp!.level, 85);
      expect(resp.isCharging, isTrue);
    });

    test('any non-zero charging flag means charging', () {
      expect(parseBatteryResponse(_buildResponse(50, 2))!.isCharging, isTrue);
      expect(parseBatteryResponse(_buildResponse(50, 255))!.isCharging, isTrue);
    });

    test('level 0 is valid (fully depleted / unknown)', () {
      final resp = parseBatteryResponse(_buildResponse(0, 0));
      expect(resp!.level, 0);
    });

    test('level 100 is valid (fully charged)', () {
      final resp = parseBatteryResponse(_buildResponse(100, 0));
      expect(resp!.level, 100);
    });

    test('toString – not charging', () {
      final resp = parseBatteryResponse(_buildResponse(64, 0))!;
      expect(resp.toString(), 'Battery(64%)');
    });

    test('toString – charging', () {
      final resp = parseBatteryResponse(_buildResponse(85, 1))!;
      expect(resp.toString(), 'Battery(85%, charging)');
    });
  });

  group('parseBatteryResponse – invalid packets', () {
    test('returns null for wrong command byte', () {
      // Build a packet that looks valid but has command 0x69 instead of 0x03
      final wrongCmd = makePacket(0x69, [64, 0]);
      expect(parseBatteryResponse(wrongCmd), isNull);
    });

    test('returns null for bad checksum', () {
      final p = _buildResponse(64, 0).toList();
      p[15] ^= 0xFF; // corrupt the checksum
      expect(parseBatteryResponse(p), isNull);
    });

    test('returns null for packet shorter than 16 bytes', () {
      expect(parseBatteryResponse(List.filled(15, 0x03)), isNull);
    });

    test('returns null for empty list', () {
      expect(parseBatteryResponse([]), isNull);
    });
  });
}
