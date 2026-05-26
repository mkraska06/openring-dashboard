import '../protocol/accelerometer.dart';

class MotionSessionSummary {
  const MotionSessionSummary({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.startedAt,
    this.endedAt,
  });

  final int id;
  final String deviceId;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
}

class MotionSamplePoint {
  const MotionSamplePoint({required this.receivedAt, required this.reading});

  final DateTime receivedAt;
  final AccelerometerReading reading;
}

class MotionSessionRecording {
  const MotionSessionRecording({required this.session, required this.samples});

  final MotionSessionSummary session;
  final List<MotionSamplePoint> samples;
}
