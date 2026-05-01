import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Devices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get lastSeenAt => dateTime()();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class VitalSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text().references(Devices, #deviceId)();
  TextColumn get kind => text()();
  IntColumn get value => integer()();
  TextColumn get unit => text()();
  DateTimeColumn get measuredAt => dateTime()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {deviceId, kind, measuredAt, source},
  ];
}

class BatterySnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text().references(Devices, #deviceId)();
  IntColumn get level => integer()();
  BoolColumn get isCharging => boolean()();
  DateTimeColumn get measuredAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {deviceId, measuredAt},
  ];
}

class ActivityIntervals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text().references(Devices, #deviceId)();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get steps => integer()();
  IntColumn get calories => integer()();
  IntColumn get distanceMeters => integer()();
  TextColumn get source => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {deviceId, startedAt},
  ];
}

@DriftDatabase(
  tables: [
    Devices,
    AppSettings,
    VitalSamples,
    BatterySnapshots,
    ActivityIntervals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'openring.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

// Ganz unten in app_database.dart hinzufügen
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
