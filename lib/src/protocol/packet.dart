import 'dart:typed_data';

/// Fixed packet size for all Colmi R02 communication.
///
/// Every packet sent to or received from the ring is exactly 16 bytes:
///   Byte  0:     Command identifier
///   Bytes 1-14:  Sub-data / payload (zero-padded if shorter than 14 bytes)
///   Byte  15:    Checksum — lowest 8 bits of the sum of bytes 0-14
const int packetLength = 16;

/// Builds a 16-byte packet for the Colmi R02 ring protocol.
///
/// [command] — the command byte (byte 0), e.g. 0x03 for battery.
/// [subData] — optional payload bytes (bytes 1-14). If shorter than 14 bytes
///             the remaining positions are zero-filled. If null, the entire
///             payload is zeros.
///
/// Returns a [Uint8List] of exactly 16 bytes with a valid checksum at byte 15.
///
/// Packet layout:
///   [command] [subData padded to 14 bytes] [checksum]
Uint8List makePacket(int command, [List<int>? subData]) {
  assert(command >= 0x00 && command <= 0xFF, 'Command must be a single byte');
  assert(
    subData == null || subData.length <= 14,
    'Sub-data must be at most 14 bytes',
  );

  final packet = Uint8List(packetLength); // all zeros by default
  packet[0] = command;

  // Copy sub-data into bytes 1..14
  if (subData != null) {
    for (var i = 0; i < subData.length; i++) {
      packet[1 + i] = subData[i] & 0xFF;
    }
  }

  // Byte 15: checksum = (sum of bytes 0-14) & 0xFF
  var sum = 0;
  for (var i = 0; i < packetLength - 1; i++) {
    sum += packet[i];
  }
  packet[packetLength - 1] = sum & 0xFF;

  return packet;
}

/// Validates the checksum of a received 16-byte packet.
///
/// The checksum at byte 15 must equal the lowest 8 bits of the sum of
/// bytes 0 through 14. Returns `true` if the packet is valid.
///
/// Also returns `false` if the packet is not exactly 16 bytes long.
bool validatePacket(List<int> data) {
  if (data.length != packetLength) return false;

  var sum = 0;
  for (var i = 0; i < packetLength - 1; i++) {
    sum += data[i];
  }
  return (sum & 0xFF) == data[packetLength - 1];
}
