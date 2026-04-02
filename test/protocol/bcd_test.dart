import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/protocol/bcd.dart';

void main() {
  group('bcdToDec', () {
    test('converts 0x00 to 0', () => expect(bcdToDec(0x00), 0));
    test('converts 0x25 to 25', () => expect(bcdToDec(0x25), 25));
    test('converts 0x99 to 99', () => expect(bcdToDec(0x99), 99));
    test('converts 0x12 to 12', () => expect(bcdToDec(0x12), 12));
    test('converts 0x09 to 9', () => expect(bcdToDec(0x09), 9));
  });

  group('decToBcd', () {
    test('converts 0 to 0x00', () => expect(decToBcd(0), 0x00));
    test('converts 25 to 0x25', () => expect(decToBcd(25), 0x25));
    test('converts 99 to 0x99', () => expect(decToBcd(99), 0x99));
    test('converts 12 to 0x12', () => expect(decToBcd(12), 0x12));
    test('converts 9 to 0x09', () => expect(decToBcd(9), 0x09));
  });

  group('round-trip', () {
    test('bcdToDec(decToBcd(n)) == n for all valid values', () {
      for (var n = 0; n <= 99; n++) {
        expect(bcdToDec(decToBcd(n)), n, reason: 'round-trip failed for $n');
      }
    });
  });
}
