import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/hr_log.dart';
import 'package:openring_v1/src/protocol/packet.dart';

void main() {
  group('makeHrLogRequest', () {
    test('produces valid 16-byte packet', () {
      final p = makeHrLogRequest(DateTime.utc(2026, 4, 1));
      expect(p.length, 16);
      expect(p[0], Cmd.readHeartRate);
      expect(validatePacket(p), isTrue);
    });

    test('encodes timestamp as 4-byte LE', () {
      final day = DateTime.utc(2026, 4, 1);
      final ts = day.millisecondsSinceEpoch ~/ 1000;
      final p = makeHrLogRequest(day);
      final decoded = p[1] | (p[2] << 8) | (p[3] << 16) | (p[4] << 24);
      expect(decoded, ts);
    });
  });

  group('HrLogParser', () {
    test('returns empty result on 0xFF (no data)', () {
      final parser = HrLogParser();
      final packet = makePacket(Cmd.readHeartRate, [0xFF]);
      final result = parser.processPacket(packet);
      expect(result, isNotNull);
      expect(result!.entries, isEmpty);
    });

    test('assembles a simple two-packet sequence', () {
      final parser = HrLogParser();

      // Metadata packet: 3 total packets, 5 min interval
      final meta = makePacket(Cmd.readHeartRate, [0, 3, 5]);
      expect(parser.processPacket(meta), isNull);

      // First data packet: base timestamp = 1000000 (LE), 9 HR values
      final ts = 1000000;
      final data1 = makePacket(Cmd.readHeartRate, [
        1, // sub-type 1
        ts & 0xFF, (ts >> 8) & 0xFF, (ts >> 16) & 0xFF, (ts >> 24) & 0xFF,
        72, 75, 68, 0, 0, 0, 0, 80, 65,
      ]);
      expect(parser.processPacket(data1), isNull);

      // Second data packet (final): sub-type 2, 13 HR values
      final data2 = makePacket(Cmd.readHeartRate, [
        2, // sub-type 2
        70, 71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ]);
      final result = parser.processPacket(data2);
      expect(result, isNotNull);
      expect(result!.intervalMinutes, 5);
      // Non-zero values: 72, 75, 68, 80, 65, 70, 71 = 7 entries
      expect(result.entries.length, 7);
      expect(result.entries[0].bpm, 72);
      expect(result.entries[1].bpm, 75);
    });
  });
}
