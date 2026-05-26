import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/activity.dart';
import 'package:openring_v1/src/protocol/packet.dart';

void main() {
  group('parseDailyActivityNotification', () {
    test('parses 0x73/0x12 steps, calories, and distance notification', () {
      final packet = makePacket(cmdGeneralNotification, [
        generalSubtypeStepsCaloriesDistance,
        0x00,
        0x0B,
        0xEF,
        0x02,
        0x22,
        0x09,
        0x00,
        0x07,
        0xCF,
      ]);

      final activity = parseDailyActivityNotification(packet);

      expect(activity, isNotNull);
      expect(activity!.steps, 3055);
      expect(activity.calories, 139);
      expect(activity.distanceMeters, 1999);
    });

    test('parses CitizenOneX example packet', () {
      final packet = [
        115,
        18,
        0,
        11,
        239,
        2,
        34,
        9,
        0,
        7,
        207,
        0,
        0,
        0,
        0,
        130,
      ];

      final activity = parseDailyActivityNotification(packet);

      expect(activity, isNotNull);
      expect(activity!.steps, 3055);
      expect(activity.calories, 139);
      expect(activity.distanceMeters, 1999);
    });

    test('returns null for a different general notification subtype', () {
      final packet = makePacket(cmdGeneralNotification, [0x0C, 70, 0]);

      expect(parseDailyActivityNotification(packet), isNull);
    });

    test('returns null for wrong command byte', () {
      final packet = makePacket(0x03, [generalSubtypeStepsCaloriesDistance]);

      expect(parseDailyActivityNotification(packet), isNull);
    });

    test('returns null for bad checksum', () {
      final packet = makePacket(cmdGeneralNotification, [
        generalSubtypeStepsCaloriesDistance,
        0,
        0,
        1,
      ]).toList();
      packet[15] ^= 0xFF;

      expect(parseDailyActivityNotification(packet), isNull);
    });
  });
}
