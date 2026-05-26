import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/history/history_page_controller.dart';
import 'package:openring_v1/src/protocol/battery.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/protocol/hr_log.dart';
import 'package:openring_v1/src/protocol/steps.dart';
import 'package:openring_v1/src/storage/history_models.dart';
import 'package:openring_v1/src/storage/motion_models.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';

void main() {
  test('initial load uses the initial day', () async {
    final storage = _FakeStorage(
      historyDay: HistoryDay(
        deviceId: 'ring-1',
        day: DateTime(2026, 4, 1),
        vitals: const {},
        activity: const ActivityDaySummary(points: []),
      ),
    );

    final notifier = HistoryPageNotifier(
      storage,
      initialDay: DateTime(2026, 4, 1, 18),
    );
    await _settle();

    expect(storage.loadedDays, [DateTime(2026, 4, 1)]);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.historyDay?.deviceId, 'ring-1');
  });

  test('previous and next day reload database data', () async {
    final storage = _FakeStorage();
    final notifier = HistoryPageNotifier(
      storage,
      initialDay: DateTime(2026, 4, 2),
    );
    await _settle();

    await notifier.previousDay();
    await notifier.nextDay();

    expect(storage.loadedDays, [
      DateTime(2026, 4, 2),
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 2),
    ]);
  });

  test('empty database becomes empty state without error', () async {
    final storage = _FakeStorage();
    final notifier = HistoryPageNotifier(
      storage,
      initialDay: DateTime(2026, 4, 1),
    );
    await _settle();

    expect(notifier.state.historyDay, isNull);
    expect(notifier.state.error, isNull);
    expect(notifier.state.isLoading, isFalse);
  });

  test('silent reload keeps existing history visible while loading', () async {
    final firstDay = HistoryDay(
      deviceId: 'ring-1',
      day: DateTime(2026, 4, 1),
      vitals: const {},
      activity: const ActivityDaySummary(points: []),
    );
    final storage = _QueuedStorage([firstDay, null]);
    final notifier = HistoryPageNotifier(
      storage,
      initialDay: DateTime(2026, 4, 1),
    );
    await _settle();

    final loadFuture = notifier.load(silent: true);

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.historyDay, firstDay);

    await loadFuture;
    expect(notifier.state.historyDay, isNull);
  });
}

Future<void> _settle() {
  return Future<void>.delayed(Duration.zero);
}

class _FakeStorage implements OpenRingStorage {
  _FakeStorage({this.historyDay});

  final HistoryDay? historyDay;
  final loadedDays = <DateTime>[];

  @override
  Future<HistoryDay?> loadHistoryDay({
    required DateTime day,
    String? deviceId,
  }) async {
    loadedDays.add(DateTime(day.year, day.month, day.day));
    return historyDay;
  }

  @override
  Future<String?> getLastConnectedDeviceId() async => historyDay?.deviceId;

  @override
  Future<void> insertBatterySnapshot({
    required String deviceId,
    required BatteryResponse battery,
    DateTime? measuredAt,
  }) async {}

  @override
  Future<void> insertHrLogEntries({
    required String deviceId,
    required List<HrLogEntry> entries,
  }) async {}

  @override
  Future<void> insertStepEntries({
    required String deviceId,
    required List<StepEntry> entries,
  }) async {}

  @override
  Future<void> insertVitalSample({
    required String deviceId,
    required String kind,
    required int value,
    required String unit,
    required DateTime measuredAt,
    required String source,
  }) async {}

  @override
  Future<void> appendMotionSample({
    required int sessionId,
    required AccelerometerReading reading,
    DateTime? receivedAt,
  }) async {}

  @override
  Future<MotionSessionRecording?> loadLatestMotionSession({
    required String deviceId,
  }) async => null;

  @override
  Future<void> setLastConnectedDevice({
    required String deviceId,
    String? name,
    DateTime? connectedAt,
  }) async {}

  @override
  Future<void> upsertDevice({
    required String deviceId,
    String? name,
    DateTime? seenAt,
  }) async {}

  @override
  Future<MotionSessionSummary> startMotionSession({
    required String deviceId,
    required String name,
    DateTime? startedAt,
  }) async {
    return MotionSessionSummary(
      id: 1,
      deviceId: deviceId,
      name: name,
      startedAt: startedAt ?? DateTime.now(),
    );
  }

  @override
  Future<void> stopMotionSession({
    required int sessionId,
    DateTime? endedAt,
  }) async {}
}

class _QueuedStorage extends _FakeStorage {
  _QueuedStorage(this._days);

  final List<HistoryDay?> _days;

  @override
  Future<HistoryDay?> loadHistoryDay({
    required DateTime day,
    String? deviceId,
  }) async {
    loadedDays.add(DateTime(day.year, day.month, day.day));
    return _days.removeAt(0);
  }
}
