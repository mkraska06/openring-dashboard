import 'packet.dart';

/// General notification command byte used by COLMi rings for push updates.
const int cmdGeneralNotification = 0x73;

/// General notification subtype for current daily activity totals.
const int generalSubtypeStepsCaloriesDistance = 0x12;

/// Current daily activity totals pushed by the ring.
///
/// This is distinct from the historical step log command (`0x43`), which
/// returns multiple 15-minute intervals for a requested day.
class DailyActivitySnapshot {
  final int steps;
  final int calories;
  final int distanceMeters;

  const DailyActivitySnapshot({
    required this.steps,
    required this.calories,
    required this.distanceMeters,
  });

  @override
  String toString() =>
      'DailyActivity(steps=$steps, cal=$calories, dist=${distanceMeters}m)';
}

/// Parses a `0x73/0x12` daily activity notification.
///
/// Expected response layout:
///   Byte  0:     0x73 (general notification)
///   Byte  1:     0x12 (steps/calories/distance subtype)
///   Bytes 2-4:   steps, 24-bit big-endian
///   Bytes 5-7:   calories * 1000, 24-bit big-endian
///   Bytes 8-10:  distance meters, 24-bit big-endian
///   Bytes 11-14: padding or unused
///   Byte  15:    checksum
///
/// Returns `null` if the packet is invalid or is a different notification.
DailyActivitySnapshot? parseDailyActivityNotification(List<int> data) {
  if (!validatePacket(data)) return null;
  if (data[0] != cmdGeneralNotification) return null;
  if (data[1] != generalSubtypeStepsCaloriesDistance) return null;

  final steps = _uint24be(data, 2);
  final calories = _uint24be(data, 5) ~/ 1000;
  final distanceMeters = _uint24be(data, 8);

  return DailyActivitySnapshot(
    steps: steps,
    calories: calories,
    distanceMeters: distanceMeters,
  );
}

int _uint24be(List<int> data, int offset) {
  return (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];
}
