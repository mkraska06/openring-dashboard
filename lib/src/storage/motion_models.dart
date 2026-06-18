import 'dart:math' as math;

import '../protocol/accelerometer.dart';

enum GestureMotionPreset {
  palmUp('gesture_palm_up', 'Palm up'),
  palmSide('gesture_palm_side', 'Palm side'),
  palmDown('gesture_palm_down', 'Palm down'),
  openDown('gesture_open_down', 'Open down'),
  openSide('gesture_open_side', 'Open side'),
  openUp('gesture_open_up', 'Open up'),
  openVertical('gesture_open_vertical', 'Open vertical'),
  fistDown('gesture_fist_down', 'Fist down'),
  fistSide('gesture_fist_side', 'Fist side'),
  fistUp('gesture_fist_up', 'Fist up'),
  fistVertical('gesture_fist_vertical', 'Fist vertical'),
  doubleTap('gesture_double_tap', 'Double tap');

  const GestureMotionPreset(this.sessionPrefix, this.label);

  final String sessionPrefix;
  final String label;
}

enum GestureHandShape { open, fist }

enum GestureHandPose { down, side, up, vertical }

enum GestureSeparationStatus {
  clear('klar trennbar'),
  uncertain('unsicher'),
  moreData('mehr Daten');

  const GestureSeparationStatus(this.label);

  final String label;
}

class GesturePoseKey {
  const GesturePoseKey({required this.shape, required this.pose});

  final GestureHandShape shape;
  final GestureHandPose pose;

  String get label => '${shape.name} ${pose.name}';

  @override
  bool operator ==(Object other) {
    return other is GesturePoseKey &&
        other.shape == shape &&
        other.pose == pose;
  }

  @override
  int get hashCode => Object.hash(shape, pose);
}

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

class MotionAxisStats {
  const MotionAxisStats({
    required this.min,
    required this.max,
    required this.average,
    required this.spread,
  });

  final double min;
  final double max;
  final double average;
  final double spread;
}

class MotionSessionStats {
  const MotionSessionStats({
    required this.sampleCount,
    required this.duration,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.averageSampleDeltaG,
    required this.isStable,
  });

  final int sampleCount;
  final Duration duration;
  final MotionAxisStats x;
  final MotionAxisStats y;
  final MotionAxisStats z;
  final MotionAxisStats magnitude;
  final double averageSampleDeltaG;
  final bool isStable;

  String get dominantAxis {
    final values = {
      'X': x.average.abs(),
      'Y': y.average.abs(),
      'Z': z.average.abs(),
    };
    return values.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class GesturePositionSummary {
  const GesturePositionSummary({
    required this.preset,
    required this.sessionCount,
    required this.sampleCount,
    required this.averageX,
    required this.averageY,
    required this.averageZ,
    required this.averageMagnitude,
  });

  final GestureMotionPreset preset;
  final int sessionCount;
  final int sampleCount;
  final double averageX;
  final double averageY;
  final double averageZ;
  final double averageMagnitude;
}

class GestureCalibrationSummary {
  const GestureCalibrationSummary({
    required this.positions,
    required this.bestAxis,
    required this.axisSeparationG,
    required this.ready,
  });

  final Map<GestureMotionPreset, GesturePositionSummary> positions;
  final String? bestAxis;
  final double axisSeparationG;
  final bool ready;
}

class GesturePoseSummary {
  const GesturePoseSummary({
    required this.key,
    required this.sessionCount,
    required this.sampleCount,
    required this.duration,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.averageSampleDeltaG,
    required this.isStable,
    required this.averageRollDegrees,
  });

  final GesturePoseKey key;
  final int sessionCount;
  final int sampleCount;
  final Duration duration;
  final MotionAxisStats x;
  final MotionAxisStats y;
  final MotionAxisStats z;
  final MotionAxisStats magnitude;
  final double averageSampleDeltaG;
  final bool isStable;
  final double averageRollDegrees;

  double distanceTo(GesturePoseSummary other) {
    final dx = x.average - other.x.average;
    final dy = y.average - other.y.average;
    final dz = z.average - other.z.average;
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz));
  }

  double get maxSpread => [
    x.spread,
    y.spread,
    z.spread,
    magnitude.spread,
  ].reduce((a, b) => a > b ? a : b);
}

class GesturePoseComparison {
  const GesturePoseComparison({
    required this.label,
    required this.status,
    required this.distanceG,
    required this.spreadG,
  });

  final String label;
  final GestureSeparationStatus status;
  final double distanceG;
  final double spreadG;
}

class GesturePoseAnalysisSummary {
  const GesturePoseAnalysisSummary({
    required this.groups,
    required this.openFistComparisons,
    required this.verticalComparisons,
    required this.rollComparisons,
    required this.overallStatus,
  });

  final Map<GesturePoseKey, GesturePoseSummary> groups;
  final List<GesturePoseComparison> openFistComparisons;
  final List<GesturePoseComparison> verticalComparisons;
  final List<GesturePoseComparison> rollComparisons;
  final GestureSeparationStatus overallStatus;
}

GestureMotionPreset? gesturePresetForSessionName(String name) {
  for (final preset in GestureMotionPreset.values) {
    if (name.startsWith(preset.sessionPrefix)) return preset;
  }
  return null;
}

String gestureSessionName(GestureMotionPreset preset) {
  return preset.sessionPrefix;
}

GesturePoseKey? gesturePoseKeyForSessionName(String name) {
  final preset = gesturePresetForSessionName(name);
  return switch (preset) {
    GestureMotionPreset.openDown => const GesturePoseKey(
      shape: GestureHandShape.open,
      pose: GestureHandPose.down,
    ),
    GestureMotionPreset.openSide => const GesturePoseKey(
      shape: GestureHandShape.open,
      pose: GestureHandPose.side,
    ),
    GestureMotionPreset.openUp => const GesturePoseKey(
      shape: GestureHandShape.open,
      pose: GestureHandPose.up,
    ),
    GestureMotionPreset.openVertical => const GesturePoseKey(
      shape: GestureHandShape.open,
      pose: GestureHandPose.vertical,
    ),
    GestureMotionPreset.fistDown => const GesturePoseKey(
      shape: GestureHandShape.fist,
      pose: GestureHandPose.down,
    ),
    GestureMotionPreset.fistSide => const GesturePoseKey(
      shape: GestureHandShape.fist,
      pose: GestureHandPose.side,
    ),
    GestureMotionPreset.fistUp => const GesturePoseKey(
      shape: GestureHandShape.fist,
      pose: GestureHandPose.up,
    ),
    GestureMotionPreset.fistVertical => const GesturePoseKey(
      shape: GestureHandShape.fist,
      pose: GestureHandPose.vertical,
    ),
    _ => null,
  };
}

MotionSessionStats? analyzeMotionSession(MotionSessionRecording recording) {
  final samples = recording.samples;
  if (samples.isEmpty) return null;

  return MotionSessionStats(
    sampleCount: samples.length,
    duration: samples.last.receivedAt.difference(samples.first.receivedAt),
    x: _axisStats(samples.map((s) => s.reading.xG)),
    y: _axisStats(samples.map((s) => s.reading.yG)),
    z: _axisStats(samples.map((s) => s.reading.zG)),
    magnitude: _axisStats(samples.map((s) => s.reading.magnitudeG)),
    averageSampleDeltaG: _averageSampleDeltaG(samples),
    isStable: _isStableHeldPosition(samples),
  );
}

GestureCalibrationSummary analyzeGestureCalibration(
  List<MotionSessionRecording> recordings,
) {
  final positions = <GestureMotionPreset, GesturePositionSummary>{};
  for (final preset in const [
    GestureMotionPreset.palmUp,
    GestureMotionPreset.palmSide,
    GestureMotionPreset.palmDown,
  ]) {
    final points = <MotionSamplePoint>[
      for (final recording in recordings)
        if (gesturePresetForSessionName(recording.session.name) == preset)
          ...recording.samples,
    ];
    if (points.isEmpty) continue;

    positions[preset] = GesturePositionSummary(
      preset: preset,
      sessionCount: recordings
          .where((r) => gesturePresetForSessionName(r.session.name) == preset)
          .length,
      sampleCount: points.length,
      averageX: _average(points.map((s) => s.reading.xG)),
      averageY: _average(points.map((s) => s.reading.yG)),
      averageZ: _average(points.map((s) => s.reading.zG)),
      averageMagnitude: _average(points.map((s) => s.reading.magnitudeG)),
    );
  }

  final (bestAxis, separation) = _bestSeparatingAxis(positions.values);
  return GestureCalibrationSummary(
    positions: positions,
    bestAxis: bestAxis,
    axisSeparationG: separation,
    ready: positions.length == 3 && separation >= 0.25,
  );
}

GestureMotionPreset? classifyHeldGesturePosition(
  AccelerometerReading reading,
  GestureCalibrationSummary calibration,
) {
  if (!calibration.ready) return null;

  GestureMotionPreset? bestPreset;
  var bestDistance = double.infinity;
  for (final position in calibration.positions.values) {
    final dx = reading.xG - position.averageX;
    final dy = reading.yG - position.averageY;
    final dz = reading.zG - position.averageZ;
    final distance = dx * dx + dy * dy + dz * dz;
    if (distance < bestDistance) {
      bestDistance = distance;
      bestPreset = position.preset;
    }
  }
  return bestPreset;
}

GesturePoseAnalysisSummary analyzeGesturePoseSpace(
  List<MotionSessionRecording> recordings,
) {
  final groups = <GesturePoseKey, GesturePoseSummary>{};
  for (final key in _gesturePoseKeys) {
    final matching = recordings
        .where((r) => gesturePoseKeyForSessionName(r.session.name) == key)
        .toList();
    final points = [for (final recording in matching) ...recording.samples];
    if (points.isEmpty) continue;

    groups[key] = _poseSummary(key: key, recordings: matching, points: points);
  }

  final openFist = [
    for (final pose in GestureHandPose.values)
      _compareGroups(
        label: 'Open/Fist ${pose.name}',
        a: groups[GesturePoseKey(shape: GestureHandShape.open, pose: pose)],
        b: groups[GesturePoseKey(shape: GestureHandShape.fist, pose: pose)],
      ),
  ];
  final vertical = [
    for (final shape in GestureHandShape.values)
      _compareGroups(
        label: '${shape.name} side/vertical',
        a: groups[GesturePoseKey(shape: shape, pose: GestureHandPose.side)],
        b: groups[GesturePoseKey(shape: shape, pose: GestureHandPose.vertical)],
      ),
  ];
  final roll = [
    for (final shape in GestureHandShape.values)
      _compareRoll(shape: shape, groups: groups),
  ];

  final comparisons = [...openFist, ...vertical, ...roll];
  return GesturePoseAnalysisSummary(
    groups: groups,
    openFistComparisons: openFist,
    verticalComparisons: vertical,
    rollComparisons: roll,
    overallStatus: _overallStatus(comparisons),
  );
}

MotionAxisStats _axisStats(Iterable<double> values) {
  final list = values.toList();
  final min = list.reduce((a, b) => a < b ? a : b);
  final max = list.reduce((a, b) => a > b ? a : b);
  return MotionAxisStats(
    min: min,
    max: max,
    average: _average(list),
    spread: max - min,
  );
}

GesturePoseSummary _poseSummary({
  required GesturePoseKey key,
  required List<MotionSessionRecording> recordings,
  required List<MotionSamplePoint> points,
}) {
  final first = points.first.receivedAt;
  final last = points.last.receivedAt;
  return GesturePoseSummary(
    key: key,
    sessionCount: recordings.length,
    sampleCount: points.length,
    duration: last.difference(first),
    x: _axisStats(points.map((s) => s.reading.xG)),
    y: _axisStats(points.map((s) => s.reading.yG)),
    z: _axisStats(points.map((s) => s.reading.zG)),
    magnitude: _axisStats(points.map((s) => s.reading.magnitudeG)),
    averageSampleDeltaG: _averageSampleDeltaG(points),
    isStable: _isStableHeldPosition(points),
    averageRollDegrees: _average(points.map((s) => _rollDegrees(s.reading))),
  );
}

GesturePoseComparison _compareGroups({
  required String label,
  required GesturePoseSummary? a,
  required GesturePoseSummary? b,
}) {
  if (a == null || b == null || !a.isStable || !b.isStable) {
    return GesturePoseComparison(
      label: label,
      status: GestureSeparationStatus.moreData,
      distanceG: 0,
      spreadG: 0,
    );
  }

  final distance = a.distanceTo(b);
  final spread = a.maxSpread > b.maxSpread ? a.maxSpread : b.maxSpread;
  return GesturePoseComparison(
    label: label,
    status: distance >= 0.25 && distance >= spread * 2
        ? GestureSeparationStatus.clear
        : GestureSeparationStatus.uncertain,
    distanceG: distance,
    spreadG: spread,
  );
}

GesturePoseComparison _compareRoll({
  required GestureHandShape shape,
  required Map<GesturePoseKey, GesturePoseSummary> groups,
}) {
  final down = groups[GesturePoseKey(shape: shape, pose: GestureHandPose.down)];
  final side = groups[GesturePoseKey(shape: shape, pose: GestureHandPose.side)];
  final up = groups[GesturePoseKey(shape: shape, pose: GestureHandPose.up)];
  if (down == null ||
      side == null ||
      up == null ||
      !down.isStable ||
      !side.isStable ||
      !up.isStable) {
    return GesturePoseComparison(
      label: '${shape.name} roll',
      status: GestureSeparationStatus.moreData,
      distanceG: 0,
      spreadG: 0,
    );
  }

  final rolls = [
    down.averageRollDegrees,
    side.averageRollDegrees,
    up.averageRollDegrees,
  ]..sort();
  final separation = math.min(
    (rolls[1] - rolls[0]).abs(),
    (rolls[2] - rolls[1]).abs(),
  );
  return GesturePoseComparison(
    label: '${shape.name} roll',
    status: separation >= 25
        ? GestureSeparationStatus.clear
        : GestureSeparationStatus.uncertain,
    distanceG: separation,
    spreadG: 0,
  );
}

GestureSeparationStatus _overallStatus(
  List<GesturePoseComparison> comparisons,
) {
  if (comparisons.every((c) => c.status == GestureSeparationStatus.moreData)) {
    return GestureSeparationStatus.moreData;
  }
  if (comparisons.any((c) => c.status == GestureSeparationStatus.uncertain)) {
    return GestureSeparationStatus.uncertain;
  }
  if (comparisons.any((c) => c.status == GestureSeparationStatus.clear)) {
    return GestureSeparationStatus.clear;
  }
  return GestureSeparationStatus.moreData;
}

double _rollDegrees(AccelerometerReading reading) {
  return math.atan2(reading.yG, reading.zG) * 180 / math.pi;
}

const _gesturePoseKeys = [
  GesturePoseKey(shape: GestureHandShape.open, pose: GestureHandPose.down),
  GesturePoseKey(shape: GestureHandShape.open, pose: GestureHandPose.side),
  GesturePoseKey(shape: GestureHandShape.open, pose: GestureHandPose.up),
  GesturePoseKey(shape: GestureHandShape.open, pose: GestureHandPose.vertical),
  GesturePoseKey(shape: GestureHandShape.fist, pose: GestureHandPose.down),
  GesturePoseKey(shape: GestureHandShape.fist, pose: GestureHandPose.side),
  GesturePoseKey(shape: GestureHandShape.fist, pose: GestureHandPose.up),
  GesturePoseKey(shape: GestureHandShape.fist, pose: GestureHandPose.vertical),
];

double _average(Iterable<double> values) {
  var count = 0;
  var sum = 0.0;
  for (final value in values) {
    count++;
    sum += value;
  }
  return count == 0 ? 0 : sum / count;
}

double _averageSampleDeltaG(List<MotionSamplePoint> samples) {
  if (samples.length < 2) return 0;

  var sum = 0.0;
  for (var i = 1; i < samples.length; i++) {
    final previous = samples[i - 1].reading;
    final current = samples[i].reading;
    sum +=
        (current.xG - previous.xG).abs() +
        (current.yG - previous.yG).abs() +
        (current.zG - previous.zG).abs();
  }
  return sum / (samples.length - 1);
}

bool _isStableHeldPosition(List<MotionSamplePoint> samples) {
  if (samples.length < 5) return false;
  final stats = MotionSessionStats(
    sampleCount: samples.length,
    duration: samples.last.receivedAt.difference(samples.first.receivedAt),
    x: _axisStats(samples.map((s) => s.reading.xG)),
    y: _axisStats(samples.map((s) => s.reading.yG)),
    z: _axisStats(samples.map((s) => s.reading.zG)),
    magnitude: _axisStats(samples.map((s) => s.reading.magnitudeG)),
    averageSampleDeltaG: _averageSampleDeltaG(samples),
    isStable: false,
  );
  return stats.magnitude.average >= 0.75 &&
      stats.magnitude.average <= 1.35 &&
      stats.x.spread <= 0.35 &&
      stats.y.spread <= 0.35 &&
      stats.z.spread <= 0.35 &&
      stats.averageSampleDeltaG <= 0.25;
}

(String?, double) _bestSeparatingAxis(Iterable<GesturePositionSummary> values) {
  final positions = values.toList();
  if (positions.length < 3) return (null, 0);

  final axes = <String, List<double>>{
    'X': [for (final p in positions) p.averageX],
    'Y': [for (final p in positions) p.averageY],
    'Z': [for (final p in positions) p.averageZ],
  };

  String? bestAxis;
  var bestSeparation = 0.0;
  for (final entry in axes.entries) {
    final sorted = [...entry.value]..sort();
    final separation = [
      (sorted[1] - sorted[0]).abs(),
      (sorted[2] - sorted[1]).abs(),
    ].reduce((a, b) => a < b ? a : b);
    if (separation > bestSeparation) {
      bestSeparation = separation;
      bestAxis = entry.key;
    }
  }
  return (bestAxis, bestSeparation);
}
