enum ExportFormat {
  csv('CSV', 'csv'),
  json('JSON', 'json');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}

enum ExportDataType {
  vitals('Vitals'),
  battery('Battery'),
  activity('Activity'),
  motion('Motion');

  const ExportDataType(this.label);

  final String label;
}

class ExportRequest {
  const ExportRequest({
    required this.start,
    required this.endExclusive,
    required this.types,
    required this.format,
  });

  final DateTime start;
  final DateTime endExclusive;
  final Set<ExportDataType> types;
  final ExportFormat format;
}

class ExportBundle {
  const ExportBundle({
    required this.start,
    required this.endExclusive,
    required this.types,
    required this.vitals,
    required this.battery,
    required this.activity,
    required this.motion,
  });

  final DateTime start;
  final DateTime endExclusive;
  final Set<ExportDataType> types;
  final List<ExportVitalRow> vitals;
  final List<ExportBatteryRow> battery;
  final List<ExportActivityRow> activity;
  final List<ExportMotionRow> motion;

  int get rowCount =>
      vitals.length + battery.length + activity.length + motion.length;
}

class ExportVitalRow {
  const ExportVitalRow({
    required this.deviceId,
    required this.kind,
    required this.value,
    required this.unit,
    required this.measuredAt,
    required this.source,
  });

  final String deviceId;
  final String kind;
  final int value;
  final String unit;
  final DateTime measuredAt;
  final String source;
}

class ExportBatteryRow {
  const ExportBatteryRow({
    required this.deviceId,
    required this.level,
    required this.isCharging,
    required this.measuredAt,
  });

  final String deviceId;
  final int level;
  final bool isCharging;
  final DateTime measuredAt;
}

class ExportActivityRow {
  const ExportActivityRow({
    required this.deviceId,
    required this.startedAt,
    required this.steps,
    required this.calories,
    required this.distanceMeters,
    required this.source,
  });

  final String deviceId;
  final DateTime startedAt;
  final int steps;
  final int calories;
  final int distanceMeters;
  final String source;
}

class ExportMotionRow {
  const ExportMotionRow({
    required this.deviceId,
    required this.sessionId,
    required this.sessionName,
    required this.receivedAt,
    required this.accX,
    required this.accY,
    required this.accZ,
  });

  final String deviceId;
  final int sessionId;
  final String sessionName;
  final DateTime receivedAt;
  final int accX;
  final int accY;
  final int accZ;
}
