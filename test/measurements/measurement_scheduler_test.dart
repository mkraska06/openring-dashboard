import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/measurements/measurement_scheduler.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/real_time.dart';

void main() {
  group('MeasurementScheduler', () {
    test(
      'desired measurement starts immediately and is marked active',
      () async {
        final commands = _FakeMeasurementCommands();
        final snapshots = <MeasurementSnapshot>[];
        final scheduler = MeasurementScheduler(
          commands: commands,
          onSnapshot: snapshots.add,
          measurementTimeout: const Duration(seconds: 5),
          settleDelay: const Duration(milliseconds: 10),
          streamPauseThreshold: const Duration(milliseconds: 15),
        );

        await scheduler.setDesired(MeasurementKind.heartRate, true);

        expect(commands.calls, ['start:${ReadingType.heartRate}']);
        expect(scheduler.snapshot.activeKind, MeasurementKind.heartRate);
        expect(scheduler.snapshot.isDesired(MeasurementKind.heartRate), isTrue);
        expect(
          scheduler.snapshot.statusOf(MeasurementKind.heartRate),
          MeasurementStatus.measuring,
        );
        expect(snapshots, isNotEmpty);

        scheduler.dispose();
      },
    );

    test('second desired kind waits while the first is measuring', () async {
      final commands = _FakeMeasurementCommands();
      final scheduler = MeasurementScheduler(
        commands: commands,
        onSnapshot: (_) {},
        measurementTimeout: const Duration(seconds: 5),
        settleDelay: const Duration(milliseconds: 10),
        streamPauseThreshold: const Duration(milliseconds: 15),
      );

      await scheduler.setDesired(MeasurementKind.heartRate, true);
      await scheduler.setDesired(MeasurementKind.spo2, true);

      expect(commands.calls, ['start:${ReadingType.heartRate}']);
      expect(
        scheduler.snapshot.statusOf(MeasurementKind.spo2),
        MeasurementStatus.queued,
      );

      scheduler.dispose();
    });

    test(
      'live burst updates the visible value and stops after a pause',
      () async {
        final commands = _FakeMeasurementCommands();
        var now = DateTime(2026, 4, 28, 12, 0, 0);
        final scheduler = MeasurementScheduler(
          commands: commands,
          onSnapshot: (_) {},
          measurementTimeout: const Duration(seconds: 5),
          settleDelay: const Duration(milliseconds: 5),
          streamPauseThreshold: const Duration(milliseconds: 15),
          now: () => now,
          policies: const {
            MeasurementKind.heartRate: MeasurementPolicy(
              successInterval: Duration(milliseconds: 20),
              errorBackoff: Duration(milliseconds: 30),
              freshness: Duration(seconds: 1),
            ),
            MeasurementKind.spo2: MeasurementPolicy(
              successInterval: Duration(milliseconds: 40),
              errorBackoff: Duration(milliseconds: 50),
              freshness: Duration(seconds: 1),
            ),
            MeasurementKind.hrv: MeasurementPolicy(
              successInterval: Duration(milliseconds: 60),
              errorBackoff: Duration(milliseconds: 70),
              freshness: Duration(seconds: 1),
            ),
          },
        );

        await scheduler.setDesired(MeasurementKind.heartRate, true);
        await scheduler.handleRealTimeReading(
          const RealTimeReading(
            type: ReadingType.heartRate,
            value: 72,
            errorCode: 0,
          ),
        );
        now = now.add(const Duration(milliseconds: 5));
        await scheduler.handleRealTimeReading(
          const RealTimeReading(
            type: ReadingType.heartRate,
            value: 74,
            errorCode: 0,
          ),
        );

        expect(commands.calls, ['start:${ReadingType.heartRate}']);
        expect(
          scheduler.snapshot.valueOf(MeasurementKind.heartRate)?.value,
          74,
        );
        expect(scheduler.snapshot.activeKind, MeasurementKind.heartRate);

        now = now.add(const Duration(milliseconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(commands.calls, [
          'start:${ReadingType.heartRate}',
          'stop:${ReadingType.heartRate}',
        ]);
        expect(
          scheduler.snapshot.statusOf(MeasurementKind.heartRate),
          MeasurementStatus.cooldown,
        );

        scheduler.dispose();
      },
    );

    test('successful burst restarts after the configured interval', () async {
      final commands = _FakeMeasurementCommands();
      var now = DateTime(2026, 4, 28, 12, 0, 0);
      final scheduler = MeasurementScheduler(
        commands: commands,
        onSnapshot: (_) {},
        measurementTimeout: const Duration(seconds: 5),
        settleDelay: const Duration(milliseconds: 5),
        streamPauseThreshold: const Duration(milliseconds: 15),
        now: () => now,
        policies: const {
          MeasurementKind.heartRate: MeasurementPolicy(
            successInterval: Duration(milliseconds: 20),
            errorBackoff: Duration(milliseconds: 30),
            freshness: Duration(seconds: 1),
          ),
          MeasurementKind.spo2: MeasurementPolicy(
            successInterval: Duration(milliseconds: 40),
            errorBackoff: Duration(milliseconds: 50),
            freshness: Duration(seconds: 1),
          ),
          MeasurementKind.hrv: MeasurementPolicy(
            successInterval: Duration(milliseconds: 60),
            errorBackoff: Duration(milliseconds: 70),
            freshness: Duration(seconds: 1),
          ),
        },
      );

      await scheduler.setDesired(MeasurementKind.heartRate, true);
      await scheduler.handleRealTimeReading(
        const RealTimeReading(
          type: ReadingType.heartRate,
          value: 72,
          errorCode: 0,
        ),
      );
      now = now.add(const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      now = now.add(const Duration(milliseconds: 30));
      await Future<void>.delayed(const Duration(milliseconds: 35));

      expect(commands.calls, [
        'start:${ReadingType.heartRate}',
        'stop:${ReadingType.heartRate}',
        'start:${ReadingType.heartRate}',
      ]);

      scheduler.dispose();
    });

    test(
      'another desired kind starts only after the live burst has ended',
      () async {
        final commands = _FakeMeasurementCommands();
        var now = DateTime(2026, 4, 28, 12, 0, 0);
        final scheduler = MeasurementScheduler(
          commands: commands,
          onSnapshot: (_) {},
          measurementTimeout: const Duration(seconds: 5),
          settleDelay: const Duration(milliseconds: 15),
          streamPauseThreshold: const Duration(milliseconds: 15),
          now: () => now,
          policies: const {
            MeasurementKind.heartRate: MeasurementPolicy(
              successInterval: Duration(milliseconds: 50),
              errorBackoff: Duration(milliseconds: 30),
              freshness: Duration(seconds: 1),
            ),
            MeasurementKind.spo2: MeasurementPolicy(
              successInterval: Duration(milliseconds: 50),
              errorBackoff: Duration(milliseconds: 30),
              freshness: Duration(seconds: 1),
            ),
            MeasurementKind.hrv: MeasurementPolicy(
              successInterval: Duration(milliseconds: 50),
              errorBackoff: Duration(milliseconds: 30),
              freshness: Duration(seconds: 1),
            ),
          },
        );

        await scheduler.setDesired(MeasurementKind.heartRate, true);
        await scheduler.setDesired(MeasurementKind.spo2, true);
        await scheduler.handleRealTimeReading(
          const RealTimeReading(
            type: ReadingType.heartRate,
            value: 70,
            errorCode: 0,
          ),
        );

        expect(commands.calls, ['start:${ReadingType.heartRate}']);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(commands.calls, [
          'start:${ReadingType.heartRate}',
          'stop:${ReadingType.heartRate}',
        ]);

        now = now.add(const Duration(milliseconds: 80));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(commands.calls, [
          'start:${ReadingType.heartRate}',
          'stop:${ReadingType.heartRate}',
          'start:${ReadingType.spo2}',
        ]);

        scheduler.dispose();
      },
    );

    test('turning a desired measurement off stops further restarts', () async {
      final commands = _FakeMeasurementCommands();
      var now = DateTime(2026, 4, 28, 12, 0, 0);
      final scheduler = MeasurementScheduler(
        commands: commands,
        onSnapshot: (_) {},
        measurementTimeout: const Duration(seconds: 5),
        settleDelay: const Duration(milliseconds: 5),
        streamPauseThreshold: const Duration(milliseconds: 15),
        now: () => now,
        policies: const {
          MeasurementKind.heartRate: MeasurementPolicy(
            successInterval: Duration(milliseconds: 20),
            errorBackoff: Duration(milliseconds: 30),
            freshness: Duration(seconds: 1),
          ),
          MeasurementKind.spo2: MeasurementPolicy(
            successInterval: Duration(milliseconds: 20),
            errorBackoff: Duration(milliseconds: 30),
            freshness: Duration(seconds: 1),
          ),
          MeasurementKind.hrv: MeasurementPolicy(
            successInterval: Duration(milliseconds: 20),
            errorBackoff: Duration(milliseconds: 30),
            freshness: Duration(seconds: 1),
          ),
        },
      );

      await scheduler.setDesired(MeasurementKind.heartRate, true);
      await scheduler.handleRealTimeReading(
        const RealTimeReading(
          type: ReadingType.heartRate,
          value: 69,
          errorCode: 0,
        ),
      );
      now = now.add(const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await scheduler.setDesired(MeasurementKind.heartRate, false);
      now = now.add(const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 45));

      expect(commands.calls, [
        'start:${ReadingType.heartRate}',
        'stop:${ReadingType.heartRate}',
      ]);
      expect(scheduler.snapshot.isDesired(MeasurementKind.heartRate), isFalse);
      expect(
        scheduler.snapshot.statusOf(MeasurementKind.heartRate),
        MeasurementStatus.idle,
      );

      scheduler.dispose();
    });

    test(
      'timeout stops active measurement and records retryable error',
      () async {
        final commands = _FakeMeasurementCommands();
        final scheduler = MeasurementScheduler(
          commands: commands,
          onSnapshot: (_) {},
          measurementTimeout: const Duration(milliseconds: 10),
          settleDelay: const Duration(milliseconds: 10),
          streamPauseThreshold: const Duration(milliseconds: 15),
        );

        await scheduler.setDesired(MeasurementKind.hrv, true);
        await Future<void>.delayed(const Duration(milliseconds: 25));

        expect(commands.calls, [
          'start:${ReadingType.hrv}',
          'stop:${ReadingType.hrv}',
        ]);
        expect(
          scheduler.snapshot.statusOf(MeasurementKind.hrv),
          MeasurementStatus.error,
        );
        expect(
          scheduler.snapshot.errors[MeasurementKind.hrv],
          contains('Timeout'),
        );

        scheduler.dispose();
      },
    );

    test('reset clears desired state but keeps last values', () async {
      final commands = _FakeMeasurementCommands();
      final now = DateTime(2026, 4, 28, 12, 0, 0);
      final scheduler = MeasurementScheduler(
        commands: commands,
        onSnapshot: (_) {},
        measurementTimeout: const Duration(seconds: 5),
        settleDelay: const Duration(milliseconds: 10),
        streamPauseThreshold: const Duration(milliseconds: 15),
        now: () => now,
      );

      await scheduler.setDesired(MeasurementKind.heartRate, true);
      await scheduler.handleRealTimeReading(
        const RealTimeReading(
          type: ReadingType.heartRate,
          value: 70,
          errorCode: 0,
        ),
      );
      scheduler.reset();

      expect(scheduler.snapshot.activeKind, isNull);
      expect(scheduler.snapshot.desiredKinds, isEmpty);
      expect(scheduler.snapshot.valueOf(MeasurementKind.heartRate)?.value, 70);

      scheduler.dispose();
    });
  });
}

class _FakeMeasurementCommands implements MeasurementCommandPort {
  final List<String> calls = [];

  @override
  Future<void> startRealTime(int readingType) async {
    calls.add('start:$readingType');
  }

  @override
  Future<void> stopRealTime(int readingType) async {
    calls.add('stop:$readingType');
  }
}
