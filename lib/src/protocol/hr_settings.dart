import 'dart:typed_data';

import 'commands.dart';
import 'packet.dart';

/// Heart-rate logging settings on the ring.
class HrLogSettings {
  /// Whether automatic HR logging is enabled.
  final bool enabled;

  /// Logging interval in minutes.
  final int intervalMinutes;

  const HrLogSettings({required this.enabled, required this.intervalMinutes});

  @override
  String toString() =>
      'HrLogSettings(enabled=$enabled, interval=${intervalMinutes}min)';
}

/// Creates a 16-byte packet to query the current HR log settings.
///
/// Packet layout:
///   Byte  0:  0x16 (CMD_HEART_RATE_LOG_SETTINGS)
///   Byte  1:  0x01 (sub-command: query)
///   Bytes 2-14: zeros
///   Byte  15: checksum
Uint8List makeHrLogSettingsQuery() => makePacket(
      Cmd.heartRateLogSettings,
      [0x01],
    );

/// Creates a 16-byte packet to update HR log settings.
///
/// Packet layout:
///   Byte  0:  0x16 (CMD_HEART_RATE_LOG_SETTINGS)
///   Byte  1:  0x02 (sub-command: set)
///   Byte  2:  enabled flag (1 = on, 2 = off)
///   Byte  3:  interval in minutes
///   Bytes 4-14: zeros
///   Byte  15: checksum
Uint8List makeHrLogSettingsSet(HrLogSettings settings) => makePacket(
      Cmd.heartRateLogSettings,
      [0x02, settings.enabled ? 1 : 2, settings.intervalMinutes],
    );

/// Parses a 16-byte HR log settings response packet.
///
/// Expected response layout:
///   Byte  0:  0x16 (CMD_HEART_RATE_LOG_SETTINGS echo)
///   Byte  1:  sub-command echo (0x01 or 0x02)
///   Byte  2:  enabled flag (1 = on, 2 = off)
///   Byte  3:  interval in minutes
///   Bytes 4-14: padding
///   Byte  15: checksum
///
/// Returns `null` if the packet is invalid or not an HR settings response.
HrLogSettings? parseHrLogSettings(List<int> data) {
  if (!validatePacket(data)) return null;
  if (data[0] != Cmd.heartRateLogSettings) return null;

  return HrLogSettings(
    enabled: data[2] == 1,
    intervalMinutes: data[3] > 0 ? data[3] : 5,
  );
}
