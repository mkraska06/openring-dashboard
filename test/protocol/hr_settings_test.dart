import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/hr_settings.dart';
import 'package:openring_v1/src/protocol/packet.dart';

void main() {
  group('makeHrLogSettingsQuery', () {
    test('produces valid packet with sub-command 0x01', () {
      final p = makeHrLogSettingsQuery();
      expect(p[0], Cmd.heartRateLogSettings);
      expect(p[1], 0x01);
      expect(p.length, 16);
      expect(validatePacket(p), isTrue);
    });
  });

  group('makeHrLogSettingsSet', () {
    test('encodes enabled=true, interval=5', () {
      final p = makeHrLogSettingsSet(
          const HrLogSettings(enabled: true, intervalMinutes: 5));
      expect(p[0], Cmd.heartRateLogSettings);
      expect(p[1], 0x02); // set sub-command
      expect(p[2], 1); // enabled = 1
      expect(p[3], 5); // interval
      expect(validatePacket(p), isTrue);
    });

    test('encodes enabled=false', () {
      final p = makeHrLogSettingsSet(
          const HrLogSettings(enabled: false, intervalMinutes: 10));
      expect(p[2], 2); // disabled = 2
      expect(p[3], 10);
    });
  });

  group('parseHrLogSettings', () {
    test('parses enabled response', () {
      final packet =
          makePacket(Cmd.heartRateLogSettings, [0x01, 1, 5]); // query, on, 5min
      final s = parseHrLogSettings(packet);
      expect(s, isNotNull);
      expect(s!.enabled, isTrue);
      expect(s.intervalMinutes, 5);
    });

    test('parses disabled response', () {
      final packet = makePacket(Cmd.heartRateLogSettings, [0x01, 2, 10]);
      final s = parseHrLogSettings(packet);
      expect(s!.enabled, isFalse);
      expect(s.intervalMinutes, 10);
    });

    test('returns null for wrong command', () {
      final packet = makePacket(Cmd.battery, [0x01, 1, 5]);
      expect(parseHrLogSettings(packet), isNull);
    });

    test('returns null for bad checksum', () {
      final p = makePacket(Cmd.heartRateLogSettings, [0x01, 1, 5]).toList();
      p[15] ^= 0xFF;
      expect(parseHrLogSettings(p), isNull);
    });
  });
}
