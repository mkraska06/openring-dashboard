import 'dart:typed_data';

import 'bcd.dart';
import 'commands.dart';
import 'packet.dart';

/// Creates a 16-byte packet to set the ring's date and time.
///
/// The time is converted to UTC before encoding, matching the Python
/// reference client's behavior.
///
/// Packet layout:
///   Byte  0:  0x01 (CMD_SET_TIME)
///   Byte  1:  BCD year (last two digits, e.g. 0x26 for 2026)
///   Byte  2:  BCD month
///   Byte  3:  BCD day
///   Byte  4:  BCD hour
///   Byte  5:  BCD minute
///   Byte  6:  BCD second
///   Byte  7:  language flag (1 = English)
///   Bytes 8-14: zeros
///   Byte  15: checksum
Uint8List makeSetTimePacket([DateTime? time]) {
  final t = (time ?? DateTime.now()).toUtc();
  return makePacket(Cmd.setTime, [
    decToBcd(t.year % 100),
    decToBcd(t.month),
    decToBcd(t.day),
    decToBcd(t.hour),
    decToBcd(t.minute),
    decToBcd(t.second),
    1, // English
  ]);
}
