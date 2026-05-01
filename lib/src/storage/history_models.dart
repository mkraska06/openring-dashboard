class VitalHistoryPoint {
  const VitalHistoryPoint({
    required this.measuredAt,
    required this.value,
    required this.source,
  });

  final DateTime measuredAt;
  final int value;
  final String source;
}

class VitalHistorySeries {
  const VitalHistorySeries({
    required this.kind,
    required this.unit,
    required this.points,
  });

  final String kind;
  final String unit;
  final List<VitalHistoryPoint> points;

  bool get isEmpty => points.isEmpty;

  int? get min {
    if (points.isEmpty) return null;
    return points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
  }

  int? get max {
    if (points.isEmpty) return null;
    return points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
  }

  double? get average {
    if (points.isEmpty) return null;
    final sum = points.fold<int>(0, (total, point) => total + point.value);
    return sum / points.length;
  }

  int? get latest => points.isEmpty ? null : points.last.value;

  VitalHistoryPoint? get latestPoint => points.isEmpty ? null : points.last;
}

class ActivityHistoryPoint {
  const ActivityHistoryPoint({
    required this.startedAt,
    required this.steps,
    required this.calories,
    required this.distanceMeters,
  });

  final DateTime startedAt;
  final int steps;
  final int calories;
  final int distanceMeters;
}

class ActivityDaySummary {
  const ActivityDaySummary({required this.points});

  final List<ActivityHistoryPoint> points;

  int get totalSteps => points.fold<int>(0, (sum, point) => sum + point.steps);

  int get totalCalories =>
      points.fold<int>(0, (sum, point) => sum + point.calories);

  int get totalDistanceMeters =>
      points.fold<int>(0, (sum, point) => sum + point.distanceMeters);

  bool get isEmpty => points.isEmpty;

  ActivityHistoryPoint? get latestPoint => points.isEmpty ? null : points.last;
}

class HistoryDay {
  const HistoryDay({
    required this.deviceId,
    required this.day,
    required this.vitals,
    required this.activity,
  });

  final String deviceId;
  final DateTime day;
  final Map<String, VitalHistorySeries> vitals;
  final ActivityDaySummary activity;

  VitalHistorySeries? series(String kind) => vitals[kind];
}
