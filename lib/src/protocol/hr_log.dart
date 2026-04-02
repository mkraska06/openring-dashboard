import 'dart:typed_data';

import 'commands.dart';
import 'packet.dart';

/// A single heart-rate log entry with timestamp.
class HrLogEntry {
  final DateTime time;
  final int bpm;

  const HrLogEntry({required this.time, required this.bpm});

  @override
  String toString() => 'HrLog($time, $bpm bpm)';
}

/// Result of a complete HR log read for one day.
class HrLogResult {
  /// The logging interval in minutes (typically 5).
  final int intervalMinutes;

  /// All log entries for the requested day.
  final List<HrLogEntry> entries;

  const HrLogResult({required this.intervalMinutes, required this.entries});
}

/// Creates a 16-byte packet to request the HR log for a given day.
///
/// [day] should be a DateTime representing the target day.
/// The ring expects a 4-byte little-endian Unix timestamp.
///
/// Packet layout:
///   Byte  0:     0x15 (CMD_READ_HEART_RATE)
///   Bytes 1-4:   Unix timestamp (little-endian)
///   Bytes 5-14:  zeros
///   Byte  15:    checksum
Uint8List makeHrLogRequest(DateTime day) {
  final ts = day.toUtc().millisecondsSinceEpoch ~/ 1000;
  return makePacket(Cmd.readHeartRate, [
    ts & 0xFF,
    (ts >> 8) & 0xFF,
    (ts >> 16) & 0xFF,
    (ts >> 24) & 0xFF,
  ]);
}

/// Stateful parser that assembles multi-packet HR log responses.
///
/// The ring sends HR log data as a sequence of packets:
/// - **Sub-type 0** (metadata): byte 2 = total packets, byte 3 = interval (min)
/// - **Sub-type 1** (first data): bytes 2-5 = base timestamp (4-byte LE),
///   bytes 6-14 = 9 HR values
/// - **Sub-type 2+** (continuation): bytes 2-14 = 13 HR values
/// - **Sub-type 255**: no data available
///
/// Call [processPacket] for each received packet with command byte 0x15.
/// Returns `null` until the final packet, then returns the assembled [HrLogResult].
class HrLogParser {
  int? _expectedPackets;
  int _receivedPackets = 0;
  int _intervalMinutes = 5;
  int? _baseTimestamp;
  final List<int> _rawValues = [];

  /// Processes one HR log response packet.
  ///
  /// Returns `null` until all packets are received, then returns the result.
  /// Returns an empty result if the ring reports no data (sub-type 255).
  HrLogResult? processPacket(List<int> data) {
    if (!validatePacket(data)) return null;
    if (data[0] != Cmd.readHeartRate) return null;

    final subType = data[1];

    // No data available
    if (subType == 0xFF) {
      return HrLogResult(intervalMinutes: _intervalMinutes, entries: const []);
    }

    // Metadata packet
    if (subType == 0) {
      _expectedPackets = data[2];
      _intervalMinutes = data[3] > 0 ? data[3] : 5;
      return null;
    }

    // First data packet (contains base timestamp)
    if (subType == 1) {
      _baseTimestamp = data[2] |
          (data[3] << 8) |
          (data[4] << 16) |
          (data[5] << 24);
      // 9 HR values in bytes 6-14
      for (var i = 6; i <= 14; i++) {
        _rawValues.add(data[i]);
      }
    } else {
      // Continuation packets: 13 HR values in bytes 2-14
      for (var i = 2; i <= 14; i++) {
        _rawValues.add(data[i]);
      }
    }

    _receivedPackets++;

    // Check if this is the final data packet
    final isDone = _expectedPackets != null &&
        (_receivedPackets >= _expectedPackets! - 1 || subType == 23);

    if (!isDone) return null;

    return _buildResult();
  }

  HrLogResult _buildResult() {
    final baseTs = _baseTimestamp ?? 0;
    final entries = <HrLogEntry>[];

    for (var i = 0; i < _rawValues.length; i++) {
      if (_rawValues[i] == 0) continue; // skip empty slots
      final time = DateTime.fromMillisecondsSinceEpoch(
        (baseTs + i * _intervalMinutes * 60) * 1000,
        isUtc: true,
      );
      entries.add(HrLogEntry(time: time, bpm: _rawValues[i]));
    }

    return HrLogResult(intervalMinutes: _intervalMinutes, entries: entries);
  }
}
