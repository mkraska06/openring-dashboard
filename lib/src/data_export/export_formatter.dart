import 'dart:convert';

import 'export_models.dart';

String formatExportBundle(ExportBundle bundle, ExportFormat format) {
  return switch (format) {
    ExportFormat.csv => formatExportCsv(bundle),
    ExportFormat.json => formatExportJson(bundle),
  };
}

String formatExportCsv(ExportBundle bundle) {
  final rows = <List<Object?>>[
    const [
      'record_type',
      'device_id',
      'timestamp',
      'kind',
      'value',
      'unit',
      'source',
      'is_charging',
      'steps',
      'calories',
      'distance_meters',
      'session_id',
      'session_name',
      'acc_x',
      'acc_y',
      'acc_z',
    ],
    for (final row in bundle.vitals)
      [
        'vital',
        row.deviceId,
        _time(row.measuredAt),
        row.kind,
        row.value,
        row.unit,
        row.source,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ],
    for (final row in bundle.battery)
      [
        'battery',
        row.deviceId,
        _time(row.measuredAt),
        null,
        row.level,
        '%',
        null,
        row.isCharging,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ],
    for (final row in bundle.activity)
      [
        'activity',
        row.deviceId,
        _time(row.startedAt),
        null,
        null,
        null,
        row.source,
        null,
        row.steps,
        row.calories,
        row.distanceMeters,
        null,
        null,
        null,
        null,
        null,
      ],
    for (final row in bundle.motion)
      [
        'motion',
        row.deviceId,
        _time(row.receivedAt),
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        row.sessionId,
        row.sessionName,
        row.accX,
        row.accY,
        row.accZ,
      ],
  ];

  return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
}

String formatExportJson(ExportBundle bundle) {
  final document = {
    'metadata': {
      'start': _time(bundle.start),
      'endExclusive': _time(bundle.endExclusive),
      'includedTypes': [for (final type in bundle.types) type.name],
      'rowCount': bundle.rowCount,
    },
    'vitals': [
      for (final row in bundle.vitals)
        {
          'deviceId': row.deviceId,
          'kind': row.kind,
          'value': row.value,
          'unit': row.unit,
          'measuredAt': _time(row.measuredAt),
          'source': row.source,
        },
    ],
    'battery': [
      for (final row in bundle.battery)
        {
          'deviceId': row.deviceId,
          'level': row.level,
          'isCharging': row.isCharging,
          'measuredAt': _time(row.measuredAt),
        },
    ],
    'activity': [
      for (final row in bundle.activity)
        {
          'deviceId': row.deviceId,
          'startedAt': _time(row.startedAt),
          'steps': row.steps,
          'calories': row.calories,
          'distanceMeters': row.distanceMeters,
          'source': row.source,
        },
    ],
    'motion': [
      for (final row in bundle.motion)
        {
          'deviceId': row.deviceId,
          'sessionId': row.sessionId,
          'sessionName': row.sessionName,
          'receivedAt': _time(row.receivedAt),
          'accX': row.accX,
          'accY': row.accY,
          'accZ': row.accZ,
        },
    ],
  };

  return const JsonEncoder.withIndent('  ').convert(document);
}

String _time(DateTime value) => value.toIso8601String();

String _csvCell(Object? value) {
  if (value == null) return '';
  final text = '$value';
  if (!text.contains(',') &&
      !text.contains('"') &&
      !text.contains('\n') &&
      !text.contains('\r')) {
    return text;
  }
  return '"${text.replaceAll('"', '""')}"';
}
