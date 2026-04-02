import 'dart:typed_data';

import 'commands.dart';
import 'packet.dart';

/// Parsed battery status from the ring.
class BatteryResponse {
  /// Battery level in percent (0-100).
  final int level;

  /// Whether the ring is currently charging.
  final bool isCharging;

  const BatteryResponse({required this.level, required this.isCharging});

  @override
  String toString() => 'Battery($level%${isCharging ? ", charging" : ""})';
}

/// Creates a 16-byte battery request packet.
///
/// Packet layout:
///   Byte  0:     0x03 (CMD_BATTERY)
///   Bytes 1-14:  all zeros (no payload needed)
///   Byte  15:    checksum
Uint8List makeBatteryRequest() => makePacket(Cmd.battery);

/// Parses a 16-byte battery response packet.
///
/// Expected response layout:
///   Byte  0:  0x03 (CMD_BATTERY echo)
///   Byte  1:  Battery level (0-100)
///   Byte  2:  Charging status (0 = not charging, non-zero = charging)
///   Bytes 3-14: padding (zeros)
///   Byte  15: checksum
///
/// Returns `null` if the packet is invalid or not a battery response.
BatteryResponse? parseBatteryResponse(List<int> data) {
  if (!validatePacket(data)) return null;
  if (data[0] != Cmd.battery) return null;

  return BatteryResponse(
    level: data[1],
    isCharging: data[2] != 0,
  );
}
