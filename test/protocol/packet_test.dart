import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/packet.dart';

void main() {
  group('makePacket – basics', () {
    test('always produces exactly 16 bytes', () {
      expect(makePacket(0x03).length, 16);
      expect(makePacket(0x69, [0x01, 0x01]).length, 16);
      expect(makePacket(0xFF, List.filled(14, 0xAA)).length, 16);
    });

    test('byte 0 is the command', () {
      expect(makePacket(0x03)[0], 0x03);
      expect(makePacket(0x69)[0], 0x69);
      expect(makePacket(0x00)[0], 0x00);
    });

    test('bytes 1-14 are zero when subData is null', () {
      final p = makePacket(0x03);
      for (var i = 1; i <= 14; i++) {
        expect(p[i], 0x00, reason: 'byte $i should be zero');
      }
    });

    test('subData is placed starting at byte 1', () {
      final p = makePacket(0x69, [0x01, 0x02, 0x03]);
      expect(p[1], 0x01);
      expect(p[2], 0x02);
      expect(p[3], 0x03);
    });

    test('bytes after subData are zero-padded', () {
      final p = makePacket(0x69, [0x01, 0x02]);
      // bytes 3-14 must be zero
      for (var i = 3; i <= 14; i++) {
        expect(p[i], 0x00, reason: 'byte $i should be zero-padded');
      }
    });
  });

  group('makePacket – checksum', () {
    test('all-zero command → checksum 0x00', () {
      // sum of 15 zeros = 0 → & 0xFF = 0
      final p = makePacket(0x00);
      expect(p[15], 0x00);
    });

    test('battery request → checksum 0x03', () {
      // Only byte 0 = 0x03, rest zeros → sum = 3 → & 0xFF = 0x03
      final p = makePacket(0x03);
      expect(p[15], 0x03);
    });

    test('HR start request → checksum 0x6B', () {
      // byte 0 = 0x69, byte 1 = 0x01, byte 2 = 0x01 → sum = 0x6B
      final p = makePacket(0x69, [0x01, 0x01]);
      expect(p[15], 0x6B);
    });

    test('checksum wraps at 256 (& 0xFF)', () {
      // 14 bytes of 0xFF + command 0xFF → sum = 15 * 255 = 3825
      // 3825 & 0xFF = 0xF1
      final p = makePacket(0xFF, List.filled(14, 0xFF));
      expect(p[15], (15 * 0xFF) & 0xFF);
    });

    // Golden packet from the Python colmi_r02_client reference implementation.
    // Python: make_packet(CMD_BATTERY, None)
    // → b'\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03'
    test('golden: battery request matches Python reference bytes', () {
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
      expect(makePacket(0x03), golden);
    });

    // Python: make_packet(CMD_START_REAL_TIME=0x69, bytes([ReadingType.HEART_RATE=1, Action.START=1]))
    // → b'\x69\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x6b'
    test('golden: HR start request matches Python reference bytes', () {
      final golden = Uint8List.fromList([
        0x69,
        0x01,
        0x01,
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
        0x6B,
      ]);
      expect(makePacket(0x69, [0x01, 0x01]), golden);
    });

    // Python: make_packet(CMD_STOP_REAL_TIME=0x6A, bytes([ReadingType.HEART_RATE=1, 0, 0]))
    // → sum = 0x6A + 0x01 = 0x6B → checksum 0x6B
    test('golden: HR stop request matches Python reference bytes', () {
      final golden = Uint8List.fromList([
        0x6A,
        0x01,
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
        0x6B,
      ]);
      expect(makePacket(0x6A, [0x01, 0x00, 0x00]), golden);
    });
  });

  group('validatePacket', () {
    test('accepts any packet built with makePacket', () {
      expect(validatePacket(makePacket(0x03)), isTrue);
      expect(validatePacket(makePacket(0x69, [0x01, 0x01])), isTrue);
      expect(validatePacket(makePacket(0xFF, List.filled(14, 0xFF))), isTrue);
    });

    test('rejects packet with wrong checksum', () {
      final p = makePacket(0x03).toList();
      p[15] ^= 0xFF; // flip checksum bits
      expect(validatePacket(p), isFalse);
    });

    test('rejects packet shorter than 16 bytes', () {
      expect(validatePacket(List.filled(15, 0)), isFalse);
      expect(validatePacket([]), isFalse);
    });

    test('rejects packet longer than 16 bytes', () {
      final p = makePacket(0x03).toList()..add(0x00);
      expect(validatePacket(p), isFalse);
    });

    test('accepts golden battery request', () {
      final golden = [
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
      ];
      expect(validatePacket(golden), isTrue);
    });
  });
}
