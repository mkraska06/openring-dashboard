import 'dart:async';

import '../protocol/commands.dart';
import '../protocol/real_time.dart';

enum MeasurementKind {
  heartRate(ReadingType.heartRate),
  spo2(ReadingType.spo2),
  hrv(ReadingType.hrv);

  const MeasurementKind(this.readingType);

  final int readingType;

  static MeasurementKind? fromReadingType(int readingType) {
    for (final kind in values) {
      if (kind.readingType == readingType) return kind;
    }
    return null;
  }
}

enum MeasurementStatus { idle, queued, measuring, cooldown, error }

class MeasurementValue {
  const MeasurementValue({
    required this.kind,
    required this.value,
    required this.measuredAt,
    required this.freshUntil,
  });

  final MeasurementKind kind;
  final int value;
  final DateTime measuredAt;
  final DateTime freshUntil;

  bool get isFresh => DateTime.now().isBefore(freshUntil);
}

class MeasurementSnapshot {
  const MeasurementSnapshot({
    this.values = const {},
    this.statuses = const {},
    this.errors = const {},
    this.desiredKinds = const {},
    this.activeKind,
  });

  final Map<MeasurementKind, MeasurementValue> values;
  final Map<MeasurementKind, MeasurementStatus> statuses;
  final Map<MeasurementKind, String> errors;
  final Set<MeasurementKind> desiredKinds;
  final MeasurementKind? activeKind;

  MeasurementStatus statusOf(MeasurementKind kind) {
    return statuses[kind] ?? MeasurementStatus.idle;
  }

  MeasurementValue? valueOf(MeasurementKind kind) => values[kind];

  bool isDesired(MeasurementKind kind) => desiredKinds.contains(kind);

  MeasurementSnapshot copyWith({
    Map<MeasurementKind, MeasurementValue>? values,
    Map<MeasurementKind, MeasurementStatus>? statuses,
    Map<MeasurementKind, String>? errors,
    Set<MeasurementKind>? desiredKinds,
    MeasurementKind? activeKind,
    bool clearActiveKind = false,
  }) {
    return MeasurementSnapshot(
      values: values ?? this.values,
      statuses: statuses ?? this.statuses,
      errors: errors ?? this.errors,
      desiredKinds: desiredKinds ?? this.desiredKinds,
      activeKind: clearActiveKind ? null : (activeKind ?? this.activeKind),
    );
  }
}

class MeasurementPolicy {
  const MeasurementPolicy({
    required this.successInterval,
    required this.errorBackoff,
    required this.freshness,
  });

  final Duration successInterval;
  final Duration errorBackoff;
  final Duration freshness;
}

abstract class MeasurementCommandPort {
  Future<void> startRealTime(int readingType);

  Future<void> stopRealTime(int readingType);
}

class MeasurementScheduler {
  MeasurementScheduler({
    required MeasurementCommandPort commands,
    required void Function(MeasurementSnapshot snapshot) onSnapshot,
    Duration measurementTimeout = const Duration(seconds: 45),
    Duration settleDelay = const Duration(seconds: 3),
    Duration streamPauseThreshold = const Duration(seconds: 2),
    DateTime Function()? now,
    Map<MeasurementKind, MeasurementPolicy>? policies,
  }) : _commands = commands,
       _onSnapshot = onSnapshot,
       _measurementTimeout = measurementTimeout,
       _settleDelay = settleDelay,
       _streamPauseThreshold = streamPauseThreshold,
       _now = now ?? DateTime.now,
       _policies = policies ?? _defaultPolicies;

  static const Map<MeasurementKind, MeasurementPolicy> _defaultPolicies = {
    MeasurementKind.heartRate: MeasurementPolicy(
      successInterval: Duration(seconds: 3),
      errorBackoff: Duration(seconds: 12),
      freshness: Duration(seconds: 8),
    ),
    MeasurementKind.spo2: MeasurementPolicy(
      successInterval: Duration(seconds: 15),
      errorBackoff: Duration(seconds: 25),
      freshness: Duration(seconds: 25),
    ),
    MeasurementKind.hrv: MeasurementPolicy(
      successInterval: Duration(seconds: 30),
      errorBackoff: Duration(seconds: 40),
      freshness: Duration(seconds: 45),
    ),
  };

  final MeasurementCommandPort _commands;
  final void Function(MeasurementSnapshot snapshot) _onSnapshot;
  final Duration _measurementTimeout;
  final Duration _settleDelay;
  final Duration _streamPauseThreshold;
  final DateTime Function() _now;
  final Map<MeasurementKind, MeasurementPolicy> _policies;

  MeasurementSnapshot _snapshot = const MeasurementSnapshot();
  final Map<MeasurementKind, DateTime> _nextEligibleAt = {};
  DateTime? _blockedUntil;
  Timer? _timeoutTimer;
  Timer? _silenceTimer;
  Timer? _pumpTimer;

  MeasurementSnapshot get snapshot => _snapshot;

  Future<void> setDesired(MeasurementKind kind, bool desired) async {
    final desiredKinds = Set<MeasurementKind>.from(_snapshot.desiredKinds);
    if (desired) {
      desiredKinds.add(kind);
      _nextEligibleAt.putIfAbsent(kind, _now);
    } else {
      desiredKinds.remove(kind);
      _nextEligibleAt.remove(kind);
    }

    final errors = Map<MeasurementKind, String>.from(_snapshot.errors);
    if (!desired) {
      errors.remove(kind);
    }

    _emit(_snapshot.copyWith(desiredKinds: desiredKinds, errors: errors));

    if (!desired && _snapshot.activeKind == kind) {
      await _stopActive(nextStatus: MeasurementStatus.idle, clearError: true);
      return;
    }

    _recomputeStatuses();
    _schedulePump();
  }

  Future<void> handleRealTimeReading(RealTimeReading reading) async {
    final kind = MeasurementKind.fromReadingType(reading.type);
    if (kind == null || kind != _snapshot.activeKind) return;

    if (reading.hasValue) {
      final now = _now();
      final policy = _policyFor(kind);
      final values =
          Map<MeasurementKind, MeasurementValue>.from(_snapshot.values)
            ..[kind] = MeasurementValue(
              kind: kind,
              value: reading.value,
              measuredAt: now,
              freshUntil: now.add(policy.freshness),
            );
      final errors = Map<MeasurementKind, String>.from(_snapshot.errors)
        ..remove(kind);
      _emit(_snapshot.copyWith(values: values, errors: errors));
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _armSilenceTimer(kind, policy);
      return;
    }

    if (reading.errorCode != 0) {
      await _failActive('Ring error ${reading.errorCode}');
    }
  }

  void reset() {
    _cancelTimers();
    _nextEligibleAt.clear();
    _blockedUntil = null;
    _snapshot = MeasurementSnapshot(values: _snapshot.values);
    _onSnapshot(_snapshot);
  }

  void dispose() => reset();

  MeasurementPolicy _policyFor(MeasurementKind kind) {
    return _policies[kind]!;
  }

  Future<void> _pump() async {
    _pumpTimer?.cancel();
    _pumpTimer = null;

    if (_snapshot.activeKind != null) return;

    final now = _now();
    if (_blockedUntil != null && now.isBefore(_blockedUntil!)) {
      _schedulePump(_blockedUntil!);
      _recomputeStatuses();
      return;
    }

    MeasurementKind? nextKind;
    DateTime? nextAt;
    for (final kind in MeasurementKind.values) {
      if (!_snapshot.desiredKinds.contains(kind)) continue;
      final eligibleAt = _nextEligibleAt[kind] ?? now;
      if (eligibleAt.isAfter(now)) {
        nextAt = _earlier(nextAt, eligibleAt);
        continue;
      }
      nextKind ??= kind;
      final chosenAt = _nextEligibleAt[nextKind] ?? now;
      if (eligibleAt.isBefore(chosenAt)) {
        nextKind = kind;
      }
    }

    if (nextKind == null) {
      if (nextAt != null) {
        _schedulePump(nextAt);
      }
      _recomputeStatuses();
      return;
    }

    await _start(nextKind);
  }

  Future<void> _start(MeasurementKind kind) async {
    _timeoutTimer?.cancel();
    _silenceTimer?.cancel();
    _emit(_snapshot.copyWith(activeKind: kind));
    _recomputeStatuses();

    try {
      await _commands.startRealTime(kind.readingType);
    } catch (e) {
      await _failActive('Start failed: $e');
      return;
    }

    _timeoutTimer = Timer(_measurementTimeout, () {
      _failActive('Timeout waiting for measurement');
    });
  }

  Future<void> _stopActive({
    required MeasurementStatus nextStatus,
    bool clearError = false,
  }) async {
    final kind = _snapshot.activeKind;
    if (kind == null) return;

    _timeoutTimer?.cancel();
    _silenceTimer?.cancel();
    _timeoutTimer = null;
    _silenceTimer = null;

    try {
      await _commands.stopRealTime(kind.readingType);
    } catch (_) {}

    var errors = _snapshot.errors;
    if (clearError) {
      errors = Map<MeasurementKind, String>.from(_snapshot.errors)
        ..remove(kind);
    }

    _emit(_snapshot.copyWith(errors: errors, clearActiveKind: true));
    _setStatus(
      kind,
      _snapshot.desiredKinds.contains(kind)
          ? nextStatus
          : MeasurementStatus.idle,
    );
    _recomputeStatuses();
    _schedulePump();
  }

  Future<void> _failActive(String error) async {
    final kind = _snapshot.activeKind;
    if (kind == null) return;

    final now = _now();
    _nextEligibleAt[kind] = now.add(_policyFor(kind).errorBackoff);
    _blockedUntil = now.add(_settleDelay);

    final errors = Map<MeasurementKind, String>.from(_snapshot.errors)
      ..[kind] = error;
    _emit(_snapshot.copyWith(errors: errors));
    await _stopActive(nextStatus: MeasurementStatus.error);
  }

  void _armSilenceTimer(MeasurementKind kind, MeasurementPolicy policy) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_streamPauseThreshold, () {
      if (_snapshot.activeKind != kind) return;
      final now = _now();
      _nextEligibleAt[kind] = now.add(policy.successInterval);
      _blockedUntil = now.add(_settleDelay);
      _stopActive(nextStatus: MeasurementStatus.cooldown, clearError: true);
    });
  }

  void _recomputeStatuses() {
    final now = _now();
    final statuses = <MeasurementKind, MeasurementStatus>{};

    for (final kind in MeasurementKind.values) {
      if (_snapshot.activeKind == kind) {
        statuses[kind] = MeasurementStatus.measuring;
        continue;
      }
      if (!_snapshot.desiredKinds.contains(kind)) {
        statuses[kind] = MeasurementStatus.idle;
        continue;
      }
      if (_snapshot.errors.containsKey(kind)) {
        statuses[kind] = MeasurementStatus.error;
        continue;
      }

      final eligibleAt = _nextEligibleAt[kind] ?? now;
      final isBlocked = _blockedUntil != null && now.isBefore(_blockedUntil!);
      if (eligibleAt.isAfter(now) || isBlocked) {
        statuses[kind] = MeasurementStatus.cooldown;
      } else {
        statuses[kind] = MeasurementStatus.queued;
      }
    }

    _emit(_snapshot.copyWith(statuses: statuses));
  }

  void _setStatus(MeasurementKind kind, MeasurementStatus status) {
    final statuses = Map<MeasurementKind, MeasurementStatus>.from(
      _snapshot.statuses,
    )..[kind] = status;
    _snapshot = _snapshot.copyWith(statuses: statuses);
  }

  void _schedulePump([DateTime? when]) {
    _pumpTimer?.cancel();
    final target = when ?? _earliestRelevantTime();
    if (target == null) {
      _pump();
      return;
    }

    final delay = target.difference(_now());
    if (delay <= Duration.zero) {
      _pump();
      return;
    }

    _pumpTimer = Timer(delay, () {
      _pump();
    });
  }

  DateTime? _earliestRelevantTime() {
    final now = _now();
    DateTime? earliest;

    if (_blockedUntil != null && _blockedUntil!.isAfter(now)) {
      earliest = _blockedUntil;
    }

    for (final kind in _snapshot.desiredKinds) {
      final eligibleAt = _nextEligibleAt[kind];
      if (eligibleAt == null) return now;
      if (!eligibleAt.isAfter(now)) return now;
      earliest = _earlier(earliest, eligibleAt);
    }

    return earliest;
  }

  DateTime? _earlier(DateTime? a, DateTime b) {
    if (a == null || b.isBefore(a)) return b;
    return a;
  }

  void _emit(MeasurementSnapshot snapshot) {
    _snapshot = snapshot;
    _onSnapshot(_snapshot);
  }

  void _cancelTimers() {
    _timeoutTimer?.cancel();
    _silenceTimer?.cancel();
    _pumpTimer?.cancel();
    _timeoutTimer = null;
    _silenceTimer = null;
    _pumpTimer = null;
  }
}
