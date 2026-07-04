import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_database.dart';
import '../storage/storage_repository.dart';
import 'export_models.dart';

class ExportRepository {
  const ExportRepository(this._db);

  final AppDatabase _db;

  Future<ExportBundle> load(ExportRequest request) async {
    final startUtc = request.start.toUtc();
    final endUtc = request.endExclusive.toUtc();

    final vitals = request.types.contains(ExportDataType.vitals)
        ? await _loadVitals(startUtc, endUtc)
        : const <ExportVitalRow>[];
    final battery = request.types.contains(ExportDataType.battery)
        ? await _loadBattery(startUtc, endUtc)
        : const <ExportBatteryRow>[];
    final activity = request.types.contains(ExportDataType.activity)
        ? await _loadActivity(startUtc, endUtc)
        : const <ExportActivityRow>[];
    final motion = request.types.contains(ExportDataType.motion)
        ? await _loadMotion(startUtc, endUtc)
        : const <ExportMotionRow>[];

    return ExportBundle(
      start: request.start,
      endExclusive: request.endExclusive,
      types: request.types,
      vitals: vitals,
      battery: battery,
      activity: activity,
      motion: motion,
    );
  }

  Future<List<ExportVitalRow>> _loadVitals(DateTime start, DateTime end) async {
    final rows =
        await (_db.select(_db.vitalSamples)
              ..where(
                (row) =>
                    row.measuredAt.isBiggerOrEqualValue(start) &
                    row.measuredAt.isSmallerThanValue(end),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.measuredAt)]))
            .get();

    return [
      for (final row in rows)
        ExportVitalRow(
          deviceId: row.deviceId,
          kind: row.kind,
          value: row.value,
          unit: row.unit,
          measuredAt: row.measuredAt.toLocal(),
          source: row.source,
        ),
    ];
  }

  Future<List<ExportBatteryRow>> _loadBattery(
    DateTime start,
    DateTime end,
  ) async {
    final rows =
        await (_db.select(_db.batterySnapshots)
              ..where(
                (row) =>
                    row.measuredAt.isBiggerOrEqualValue(start) &
                    row.measuredAt.isSmallerThanValue(end),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.measuredAt)]))
            .get();

    return [
      for (final row in rows)
        ExportBatteryRow(
          deviceId: row.deviceId,
          level: row.level,
          isCharging: row.isCharging,
          measuredAt: row.measuredAt.toLocal(),
        ),
    ];
  }

  Future<List<ExportActivityRow>> _loadActivity(
    DateTime start,
    DateTime end,
  ) async {
    final rows =
        await (_db.select(_db.activityIntervals)
              ..where(
                (row) =>
                    row.startedAt.isBiggerOrEqualValue(start) &
                    row.startedAt.isSmallerThanValue(end),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.startedAt)]))
            .get();

    return [
      for (final row in rows)
        ExportActivityRow(
          deviceId: row.deviceId,
          startedAt: row.startedAt.toLocal(),
          steps: row.steps,
          calories: row.calories,
          distanceMeters: row.distanceMeters,
          source: row.source,
        ),
    ];
  }

  Future<List<ExportMotionRow>> _loadMotion(
    DateTime start,
    DateTime end,
  ) async {
    final rows =
        await (_db.select(_db.motionSamples).join([
                innerJoin(
                  _db.motionSessions,
                  _db.motionSessions.id.equalsExp(_db.motionSamples.sessionId),
                ),
              ])
              ..where(
                _db.motionSamples.receivedAt.isBiggerOrEqualValue(start) &
                    _db.motionSamples.receivedAt.isSmallerThanValue(end),
              )
              ..orderBy([OrderingTerm.asc(_db.motionSamples.receivedAt)]))
            .get();

    return [
      for (final row in rows)
        ExportMotionRow(
          deviceId: row.readTable(_db.motionSessions).deviceId,
          sessionId: row.readTable(_db.motionSessions).id,
          sessionName: row.readTable(_db.motionSessions).name,
          receivedAt: row.readTable(_db.motionSamples).receivedAt.toLocal(),
          accX: row.readTable(_db.motionSamples).accX,
          accY: row.readTable(_db.motionSamples).accY,
          accZ: row.readTable(_db.motionSamples).accZ,
        ),
    ];
  }
}

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(ref.watch(appDatabaseProvider));
});
