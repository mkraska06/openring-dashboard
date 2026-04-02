/// Command byte constants for the Colmi R02 ring protocol.
///
/// Each command occupies byte 0 of the 16-byte packet.
/// Values are taken from the Python colmi_r02_client reference implementation.
abstract class Cmd {
  /// Set the ring's date/time (payload: BCD-encoded date + language flag).
  static const int setTime = 0x01;

  /// Request battery level and charging status (no payload needed).
  static const int battery = 0x03;

  /// Reboot the ring (payload: [0x01]).
  static const int reboot = 0x08;

  /// Make the ring's LEDs blink twice (no payload).
  static const int blinkTwice = 0x10;

  /// Read stored heart-rate log for a given day
  /// (payload: 4-byte Unix timestamp, little-endian).
  static const int readHeartRate = 0x15;

  /// Query or set heart-rate logging settings
  /// (sub-command in byte 1: 0x01 = query, 0x02 = set).
  static const int heartRateLogSettings = 0x16;

  /// Read step/activity data for a given day.
  static const int getSteps = 0x43;

  /// Start or continue a real-time measurement
  /// (payload: [readingType, action]).
  static const int startRealTime = 0x69;

  /// Stop a running real-time measurement
  /// (payload: [readingType, 0, 0]).
  static const int stopRealTime = 0x6A;
}

/// Types of real-time readings the ring can perform.
///
/// Used as byte 1 of the payload for [Cmd.startRealTime] / [Cmd.stopRealTime].
///
/// Only types backed by real hardware sensors are included here.
/// The ring's protocol also defines bloodPressure (2), fatigue (4),
/// healthCheck (5), ecg (7), pressure (8), and bloodSugar (9) — these are
/// firmware-estimated values without dedicated sensors and are intentionally
/// excluded.
abstract class ReadingType {
  static const int heartRate = 1;
  static const int spo2 = 3;
  static const int hrv = 10;

  /// All supported reading types for iteration.
  static const List<int> supported = [heartRate, spo2, hrv];
}

/// Display metadata for a [ReadingType].
class ReadingTypeInfo {
  final String label;
  final String unit;

  const ReadingTypeInfo({required this.label, required this.unit});
}

/// Human-readable info for each supported [ReadingType].
const Map<int, ReadingTypeInfo> readingTypeInfo = {
  ReadingType.heartRate: ReadingTypeInfo(label: 'Herzfrequenz', unit: 'BPM'),
  ReadingType.spo2: ReadingTypeInfo(label: 'SpO2', unit: '%'),
  ReadingType.hrv: ReadingTypeInfo(label: 'HRV', unit: 'ms'),
};

/// Actions for real-time measurement control.
///
/// Used as byte 2 of the payload for [Cmd.startRealTime].
abstract class RealTimeAction {
  static const int start = 1;
  static const int pause = 2;
  static const int cont = 3; // "continue" is a reserved word in Dart
  static const int stop = 4;
}
