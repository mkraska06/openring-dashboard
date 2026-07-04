import 'dart:typed_data';

import 'bcd.dart';
import 'commands.dart';
import 'packet.dart';

/// A single step/activity entry for a 15-minute interval.
class StepEntry {
  final DateTime time;
  final int steps;
  final int calories;
  final int distanceMeters;

  const StepEntry({
    required this.time,
    required this.steps,
    required this.calories,
    required this.distanceMeters,
  });

  @override
  String toString() =>
      'Steps($time, steps=$steps, cal=$calories, dist=${distanceMeters}m)';
}

/// Creates a 16-byte packet to request step data for a given day.
///
/// Packet layout:
///   Byte  0:  0x43 (CMD_GET_STEPS)
///   Byte  1:  BCD-encoded year (last two digits, e.g. 26 for 2026)
///   Byte  2:  BCD-encoded month
///   Byte  3:  BCD-encoded day
///   Bytes 4-14: zeros
///   Byte  15: checksum
Uint8List makeStepsRequest(DateTime day) => makePacket(Cmd.getSteps, [
  decToBcd(day.year % 100),
  decToBcd(day.month),
  decToBcd(day.day),
]);

/// Stateful parser that assembles multi-packet step data responses.
///
/// Response packet formats:
/// - **Init** (`data[1] == 0xF0`): signals calorie protocol version
///   - `data[3] == 1` → new calorie protocol (16-bit calories)
/// - **Data**: `data[1..3]` = BCD date, `data[4]` = time index (0-95, each = 15min),
///   `data[5]` = current packet, `data[6]` = total packets,
///   `data[7..8]` = calories (16-bit LE), `data[9..10]` = steps (16-bit LE),
///   `data[11..12]` = distance meters (16-bit LE)
/// - **No data** (`data[1] == 0xFF`): no step data available
///
/// Call [processPacket] for each received packet with command byte 0x43.
/// Returns `null` until complete, then returns all entries.
class StepParser {
  bool _newCalorieProtocol = false;
  final List<StepEntry> _entries = [];

  /// Processes one step data response packet.
  ///
  /// Returns `null` until all packets are received, then returns the result.
  /// Returns an empty list if the ring reports no data.
  List<StepEntry>? processPacket(List<int> data) {
    if (!validatePacket(data)) return null;
    if (data[0] != Cmd.getSteps) return null;

    // No data available
    if (data[1] == 0xFF) {
      return const [];
    }

    // Init packet — calorie protocol version
    if (data[1] == 0xF0) {
      _newCalorieProtocol = data[3] == 1;
      return null;
    }

    // Data packet
    final year = 2000 + bcdToDec(data[1]);
    final month = bcdToDec(data[2]);
    final day = bcdToDec(data[3]);
    final timeIndex = data[4]; // 0-95, each slot = 15 min
    final currentPacket = data[5];
    final totalPackets = data[6];
    final calories = data[7] | (data[8] << 8);
    final steps = data[9] | (data[10] << 8);
    final distance = data[11] | (data[12] << 8);

    final hour = (timeIndex * 15) ~/ 60;
    final minute = (timeIndex * 15) % 60;

    final time = DateTime.utc(year, month, day, hour, minute);

    _entries.add(
      StepEntry(
        time: time,
        steps: steps,
        calories: _newCalorieProtocol ? calories : calories,
        distanceMeters: distance,
      ),
    );

    // Check if this is the last packet
    if (currentPacket >= totalPackets - 1) {
      return List.unmodifiable(_entries);
    }

    return null;
  }
}
