import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;

import '../ble/ble_service.dart';
import '../measurements/daily_measurement_cycle.dart';
import '../protocol/accelerometer.dart';
import '../protocol/activity.dart';
import '../protocol/battery.dart';
import '../protocol/commands.dart';
import '../protocol/hr_log.dart';
import '../protocol/hr_settings.dart';
import '../protocol/real_time.dart';
import '../protocol/steps.dart';
import '../history/history_page_controller.dart';
import '../storage/storage_repository.dart';
import '../storage/motion_models.dart';
import 'scan_page_use_cases.dart';

class ScanPageState {
  final Map<String, BleDevice> foundDevices;
  final BatteryResponse? battery;
  final Map<int, RealTimeReading> realTimeReadings;
  final Set<int> runningMeasurements;
  final bool dailyMeasurementRunning;
  final HrLogResult? hrLog;
  final bool hrLogLoading;
  final List<StepEntry>? steps;
  final DailyActivitySnapshot? dailyActivity;
  final bool stepsLoading;
  final HrLogSettings? hrLogSettings;
  final AccelerometerReading? lastAccel;
  final bool accelRunning;
  final String motionSessionName;
  final MotionSessionRecording? motionRecording;
  final bool motionRecordingActive;
  final String? error;

  const ScanPageState({
    this.foundDevices = const {},
    this.battery,
    this.realTimeReadings = const {},
    this.runningMeasurements = const {},
    this.dailyMeasurementRunning = false,
    this.hrLog,
    this.hrLogLoading = false,
    this.steps,
    this.dailyActivity,
    this.stepsLoading = false,
    this.hrLogSettings,
    this.lastAccel,
    this.accelRunning = false,
    this.motionSessionName = '',
    this.motionRecording,
    this.motionRecordingActive = false,
    this.error,
  });

  ScanPageState copyWith({
    Map<String, BleDevice>? foundDevices,
    BatteryResponse? battery,
    bool clearBattery = false,
    Map<int, RealTimeReading>? realTimeReadings,
    Set<int>? runningMeasurements,
    bool? dailyMeasurementRunning,
    HrLogResult? hrLog,
    bool clearHrLog = false,
    bool? hrLogLoading,
    List<StepEntry>? steps,
    bool clearSteps = false,
    DailyActivitySnapshot? dailyActivity,
    bool clearDailyActivity = false,
    bool? stepsLoading,
    HrLogSettings? hrLogSettings,
    bool clearHrLogSettings = false,
    AccelerometerReading? lastAccel,
    bool clearAccel = false,
    bool? accelRunning,
    String? motionSessionName,
    MotionSessionRecording? motionRecording,
    bool clearMotionRecording = false,
    bool? motionRecordingActive,
    String? error,
    bool clearError = false,
  }) {
    return ScanPageState(
      foundDevices: foundDevices ?? this.foundDevices,
      battery: clearBattery ? null : (battery ?? this.battery),
      realTimeReadings: realTimeReadings ?? this.realTimeReadings,
      runningMeasurements: runningMeasurements ?? this.runningMeasurements,
      dailyMeasurementRunning:
          dailyMeasurementRunning ?? this.dailyMeasurementRunning,
      hrLog: clearHrLog ? null : (hrLog ?? this.hrLog),
      hrLogLoading: hrLogLoading ?? this.hrLogLoading,
      steps: clearSteps ? null : (steps ?? this.steps),
      dailyActivity: clearDailyActivity
          ? null
          : (dailyActivity ?? this.dailyActivity),
      stepsLoading: stepsLoading ?? this.stepsLoading,
      hrLogSettings: clearHrLogSettings
          ? null
          : (hrLogSettings ?? this.hrLogSettings),
      lastAccel: clearAccel ? null : (lastAccel ?? this.lastAccel),
      accelRunning: accelRunning ?? this.accelRunning,
      motionSessionName: motionSessionName ?? this.motionSessionName,
      motionRecording: clearMotionRecording
          ? null
          : (motionRecording ?? this.motionRecording),
      motionRecordingActive:
          motionRecordingActive ?? this.motionRecordingActive,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

Map<int, RealTimeReading> mergeRealTimeReadingForDisplay(
  Map<int, RealTimeReading> readings,
  RealTimeReading next,
) {
  final previous = readings[next.type];
  if (!next.hasValue && previous != null && previous.hasValue) {
    return readings;
  }

  return Map<int, RealTimeReading>.from(readings)..[next.type] = next;
}

class ScanPageNotifier extends StateNotifier<ScanPageState> {
  ScanPageNotifier(
    BleService service,
    OpenRingStorage storage,
    void Function() onHistoryDataChanged,
  ) : _service = service,
      _storage = storage,
      _onHistoryDataChanged = onHistoryDataChanged,
      _useCases = ScanPageUseCases(service),
      super(const ScanPageState()) {
    _statusSub = _service.statusStream.listen((status) {
      if (status == BleConnectionStatus.disconnected) {
        _onDisconnected();
      }
    });
  }

  final BleService _service;
  final OpenRingStorage _storage;
  final void Function() _onHistoryDataChanged;
  final ScanPageUseCases _useCases;
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<Uint8List>? _packetSub;
  StreamSubscription<BleConnectionStatus>? _statusSub;
  final Map<int, Timer> _rtTimeouts = {};
  final Map<int, Timer> _rtRestarts = {};
  final DailyMeasurementCycleCursor _dailyCycle = DailyMeasurementCycleCursor();
  Timer? _dailyMeasurementTimeout;
  Timer? _dailyMeasurementSilenceTimer;
  int? _dailyActiveReadingType;
  bool _dailyAdvancing = false;
  HrLogParser? _hrLogParser;
  StepParser? _stepParser;
  String? _connectedDeviceId;
  int? _activeMotionSessionId;

  Future<void> startScan() async {
    state = state.copyWith(
      foundDevices: const {},
      clearBattery: true,
      realTimeReadings: const {},
      runningMeasurements: const {},
      dailyMeasurementRunning: false,
      clearHrLog: true,
      clearSteps: true,
      clearDailyActivity: true,
      clearHrLogSettings: true,
      clearAccel: true,
      accelRunning: false,
      motionRecordingActive: false,
      clearError: true,
    );

    _scanSub?.cancel();
    _scanSub = _service.scanResults.listen((device) {
      final updated = Map<String, BleDevice>.from(state.foundDevices)
        ..[device.deviceId] = device;
      state = state.copyWith(foundDevices: updated);
      _persist(
        () =>
            _storage.upsertDevice(deviceId: device.deviceId, name: device.name),
      );
    });

    try {
      await _useCases.startScan();
    } catch (e) {
      state = state.copyWith(error: 'Scan failed: $e');
    }
  }

  Future<void> stopScan() async {
    _scanSub?.cancel();
    await _useCases.stopScan();
  }

  Future<void> connect(String deviceId) async {
    final deviceName = state.foundDevices[deviceId]?.name;
    state = state.copyWith(
      clearBattery: true,
      realTimeReadings: const {},
      runningMeasurements: const {},
      dailyMeasurementRunning: false,
      clearHrLog: true,
      clearSteps: true,
      clearDailyActivity: true,
      clearHrLogSettings: true,
      clearAccel: true,
      accelRunning: false,
      motionRecordingActive: false,
      clearError: true,
    );
    await _scanSub?.cancel();

    try {
      await _useCases.connect(deviceId);
    } catch (e) {
      state = state.copyWith(error: 'Connection failed: $e');
      return;
    }

    _connectedDeviceId = deviceId;
    _persist(
      () =>
          _storage.setLastConnectedDevice(deviceId: deviceId, name: deviceName),
    );

    _packetSub?.cancel();
    _packetSub = _useCases.packetStream.listen(_onPacket);

    await _requestBattery();
    await _loadLatestMotionSession(deviceId);
  }

  Future<void> disconnect() async {
    await _useCases.disconnect();
  }

  void _onDisconnected() {
    for (final t in _rtTimeouts.values) {
      t.cancel();
    }
    for (final t in _rtRestarts.values) {
      t.cancel();
    }
    _rtTimeouts.clear();
    _rtRestarts.clear();
    _dailyMeasurementTimeout?.cancel();
    _dailyMeasurementSilenceTimer?.cancel();
    _dailyMeasurementTimeout = null;
    _dailyMeasurementSilenceTimer = null;
    _dailyActiveReadingType = null;
    _dailyAdvancing = false;
    _dailyCycle.reset();
    _hrLogParser = null;
    _stepParser = null;
    _connectedDeviceId = null;
    final activeMotionSessionId = _activeMotionSessionId;
    _activeMotionSessionId = null;
    if (activeMotionSessionId != null) {
      unawaited(_storage.stopMotionSession(sessionId: activeMotionSessionId));
    }
    _packetSub?.cancel();
    _packetSub = null;
    state = state.copyWith(
      runningMeasurements: const {},
      realTimeReadings: const {},
      dailyMeasurementRunning: false,
      accelRunning: false,
      clearAccel: true,
      motionRecordingActive: false,
    );
  }

  Future<void> _requestBattery() async {
    try {
      await _useCases.requestBattery();
    } catch (e) {
      state = state.copyWith(error: 'Battery request failed: $e');
    }
  }

  Future<void> toggleRealTime(int readingType) async {
    if (state.dailyMeasurementRunning) return;

    if (state.runningMeasurements.contains(readingType)) {
      await _stopRealTime(readingType);
    } else {
      await _startRealTime(readingType);
    }
  }

  Future<void> toggleDailyMeasurement() async {
    if (state.dailyMeasurementRunning) {
      await _stopDailyMeasurement();
    } else {
      await _startDailyMeasurement();
    }
  }

  Future<void> _startDailyMeasurement() async {
    for (final readingType in state.runningMeasurements.toList()) {
      await _stopRealTime(readingType);
    }
    _dailyMeasurementTimeout?.cancel();
    _dailyMeasurementSilenceTimer?.cancel();
    _dailyCycle.reset();
    _dailyActiveReadingType = null;
    _dailyAdvancing = false;
    state = state.copyWith(
      dailyMeasurementRunning: true,
      runningMeasurements: const {},
      clearError: true,
    );
    await _startDailyMeasurementStep();
  }

  Future<void> _stopDailyMeasurement() async {
    _dailyMeasurementTimeout?.cancel();
    _dailyMeasurementSilenceTimer?.cancel();
    _dailyMeasurementTimeout = null;
    _dailyMeasurementSilenceTimer = null;
    final active = _dailyActiveReadingType;
    _dailyActiveReadingType = null;
    _dailyAdvancing = false;
    _dailyCycle.reset();

    if (active != null) {
      try {
        await _useCases.stopRealTime(active);
      } catch (_) {}
    }

    state = state.copyWith(
      dailyMeasurementRunning: false,
      runningMeasurements: const {},
    );
  }

  Future<void> _startDailyMeasurementStep() async {
    if (!state.dailyMeasurementRunning) return;

    final readingType = _dailyCycle.current;
    _dailyActiveReadingType = readingType;
    _dailyMeasurementTimeout?.cancel();
    _dailyMeasurementSilenceTimer?.cancel();

    try {
      await _useCases.startRealTime(readingType);
    } catch (e) {
      final info = readingTypeInfo[readingType];
      await _advanceDailyMeasurement(
        error: '${info?.label ?? "Messung"} start failed: $e',
      );
      return;
    }

    state = state.copyWith(runningMeasurements: {readingType});
    _dailyMeasurementTimeout = Timer(const Duration(seconds: 45), () {
      final info = readingTypeInfo[readingType];
      unawaited(
        _advanceDailyMeasurement(
          error:
              '${info?.label ?? "Messung"} Timeout - naechste Messung startet.',
        ),
      );
    });
  }

  Future<void> _advanceDailyMeasurement({String? error}) async {
    if (!state.dailyMeasurementRunning || _dailyAdvancing) return;
    _dailyAdvancing = true;

    _dailyMeasurementTimeout?.cancel();
    _dailyMeasurementSilenceTimer?.cancel();
    _dailyMeasurementTimeout = null;
    _dailyMeasurementSilenceTimer = null;
    final active = _dailyActiveReadingType;
    _dailyActiveReadingType = null;

    if (active != null) {
      try {
        await _useCases.stopRealTime(active);
      } catch (_) {}
    }

    _dailyCycle.advance();
    if (!state.dailyMeasurementRunning) {
      _dailyAdvancing = false;
      return;
    }

    state = state.copyWith(
      runningMeasurements: const {},
      error: error,
      clearError: error == null,
    );
    _dailyAdvancing = false;
    await _startDailyMeasurementStep();
  }

  void _onDailyMeasurementValue() {
    _dailyMeasurementTimeout?.cancel();
    _dailyMeasurementTimeout = null;
    _dailyMeasurementSilenceTimer?.cancel();
    _dailyMeasurementSilenceTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_advanceDailyMeasurement());
    });
  }

  Future<void> _startRealTime(int readingType) async {
    _rtTimeouts[readingType]?.cancel();
    _rtRestarts[readingType]?.cancel();

    try {
      await _useCases.startRealTime(readingType);
    } catch (e) {
      final info = readingTypeInfo[readingType];
      state = state.copyWith(
        error: '${info?.label ?? "Messung"} start failed: $e',
      );
      return;
    }

    state = state.copyWith(
      runningMeasurements: {...state.runningMeasurements, readingType},
    );

    _rtTimeouts[readingType] = Timer(const Duration(seconds: 45), () {
      if (!state.runningMeasurements.contains(readingType)) return;
      _stopRealTime(readingType);
      state = state.copyWith(
        error:
            'Kein Messwert erkannt - Ring richtig anlegen und erneut versuchen.',
      );
    });
  }

  Future<void> _stopRealTime(int readingType) async {
    _rtTimeouts[readingType]?.cancel();
    _rtRestarts[readingType]?.cancel();
    _rtTimeouts.remove(readingType);
    _rtRestarts.remove(readingType);

    try {
      await _useCases.stopRealTime(readingType);
    } catch (_) {}

    state = state.copyWith(
      runningMeasurements: Set<int>.from(state.runningMeasurements)
        ..remove(readingType),
    );
  }

  void _onValidRealTimeReading(int readingType, int value) {
    _rtTimeouts[readingType]?.cancel();
    _rtRestarts[readingType]?.cancel();

    _rtRestarts[readingType] = Timer(const Duration(seconds: 3), () async {
      if (!state.runningMeasurements.contains(readingType)) return;
      try {
        await _useCases.startRealTime(readingType);
      } catch (_) {
        return;
      }
      _rtTimeouts[readingType] = Timer(const Duration(seconds: 45), () {
        if (!state.runningMeasurements.contains(readingType)) return;
        _stopRealTime(readingType);
        state = state.copyWith(
          error: 'Kein Messwert mehr erkannt - Ring pruefen.',
        );
      });
    });
  }

  Future<void> requestHrLog(DateTime day) async {
    _hrLogParser = HrLogParser();
    state = state.copyWith(hrLogLoading: true, clearHrLog: true);

    try {
      await _useCases.requestHrLog(day);
    } catch (e) {
      _hrLogParser = null;
      state = state.copyWith(hrLogLoading: false, error: 'HR-Log Fehler: $e');
    }
  }

  Future<void> queryHrLogSettings() async {
    try {
      await _useCases.queryHrLogSettings();
    } catch (e) {
      state = state.copyWith(error: 'HR-Settings Fehler: $e');
    }
  }

  Future<void> setHrLogSettings(HrLogSettings settings) async {
    try {
      await _useCases.setHrLogSettings(settings);
      await _useCases.queryHrLogSettings();
    } catch (e) {
      state = state.copyWith(error: 'HR-Settings Fehler: $e');
    }
  }

  Future<void> requestSteps(DateTime day) async {
    _stepParser = StepParser();
    state = state.copyWith(stepsLoading: true, clearSteps: true);

    try {
      await _useCases.requestSteps(day);
    } catch (e) {
      _stepParser = null;
      state = state.copyWith(stepsLoading: false, error: 'Schritte Fehler: $e');
    }
  }

  Future<void> toggleAccelerometer() async {
    if (state.accelRunning) {
      await _stopAccelerometer();
    } else {
      await _startAccelerometer();
    }
  }

  Future<void> _startAccelerometer() async {
    try {
      await _useCases.startAccelerometer();
    } catch (e) {
      state = state.copyWith(error: 'Accelerometer start failed: $e');
      return;
    }
    state = state.copyWith(accelRunning: true, clearAccel: true);
  }

  Future<void> _stopAccelerometer() async {
    if (state.motionRecordingActive) {
      await stopMotionRecording();
    }
    try {
      await _useCases.stopAccelerometer();
    } catch (_) {}
    state = state.copyWith(accelRunning: false);
  }

  void setMotionSessionName(String value) {
    state = state.copyWith(motionSessionName: value);
  }

  Future<void> startMotionRecording() async {
    final deviceId = _connectedDeviceId;
    if (deviceId == null || !state.accelRunning) return;

    final name = state.motionSessionName.trim().isEmpty
        ? _defaultMotionSessionName()
        : state.motionSessionName.trim();

    try {
      final session = await _storage.startMotionSession(
        deviceId: deviceId,
        name: name,
      );
      _activeMotionSessionId = session.id;
      state = state.copyWith(
        motionSessionName: name,
        motionRecording: MotionSessionRecording(
          session: session,
          samples: const [],
        ),
        motionRecordingActive: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: 'Motion-Aufnahme fehlgeschlagen: $e');
    }
  }

  Future<void> stopMotionRecording() async {
    final sessionId = _activeMotionSessionId;
    if (sessionId == null) return;

    try {
      await _storage.stopMotionSession(sessionId: sessionId);
      _activeMotionSessionId = null;
      final recording = state.motionRecording;
      state = state.copyWith(
        motionRecording: recording == null
            ? null
            : MotionSessionRecording(
                session: MotionSessionSummary(
                  id: recording.session.id,
                  deviceId: recording.session.deviceId,
                  name: recording.session.name,
                  startedAt: recording.session.startedAt,
                  endedAt: DateTime.now(),
                ),
                samples: recording.samples,
              ),
        motionRecordingActive: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Motion-Aufnahme stoppen fehlgeschlagen: $e',
      );
    }
  }

  Future<void> syncTime() async {
    try {
      await _useCases.syncTime();
    } catch (e) {
      state = state.copyWith(error: 'Zeit-Sync Fehler: $e');
    }
  }

  Future<void> blinkTwice() async {
    try {
      await _useCases.blinkTwice();
    } catch (e) {
      state = state.copyWith(error: 'Blink Fehler: $e');
    }
  }

  Future<void> reboot() async {
    try {
      await _useCases.reboot();
    } catch (e) {
      state = state.copyWith(error: 'Reboot Fehler: $e');
    }
  }

  void _onPacket(Uint8List packet) {
    switch (packet[0]) {
      case Cmd.battery:
        final resp = parseBatteryResponse(packet);
        if (resp != null) {
          state = state.copyWith(battery: resp);
          final deviceId = _connectedDeviceId;
          if (deviceId != null) {
            _persist(
              () => _storage.insertBatterySnapshot(
                deviceId: deviceId,
                battery: resp,
              ),
            );
          }
        }

      case Cmd.startRealTime:
        final resp = parseRealTimeResponse(packet);
        if (resp != null) {
          state = state.copyWith(
            realTimeReadings: mergeRealTimeReadingForDisplay(
              state.realTimeReadings,
              resp,
            ),
          );

          if (resp.hasValue) {
            if (state.dailyMeasurementRunning &&
                resp.type == _dailyActiveReadingType) {
              _onDailyMeasurementValue();
            } else {
              _onValidRealTimeReading(resp.type, resp.value);
            }
            final deviceId = _connectedDeviceId;
            if (deviceId != null) {
              _persist(
                () => persistRealTimeReading(
                  storage: _storage,
                  deviceId: deviceId,
                  reading: resp,
                ),
              );
            }
          } else if (state.dailyMeasurementRunning &&
              resp.type == _dailyActiveReadingType &&
              resp.errorCode != 0) {
            unawaited(
              _advanceDailyMeasurement(
                error:
                    'Ring Fehler ${resp.errorCode} - naechste Messung startet.',
              ),
            );
          }
        }

      case Cmd.readHeartRate:
        final result = _hrLogParser?.processPacket(packet);
        if (result != null) {
          _hrLogParser = null;
          state = state.copyWith(hrLog: result, hrLogLoading: false);
          final deviceId = _connectedDeviceId;
          if (deviceId != null) {
            _persist(
              () => _storage.insertHrLogEntries(
                deviceId: deviceId,
                entries: result.entries,
              ),
            );
          }
        }

      case Cmd.heartRateLogSettings:
        final settings = parseHrLogSettings(packet);
        if (settings != null) {
          state = state.copyWith(hrLogSettings: settings);
        }

      case Cmd.getSteps:
        final result = _stepParser?.processPacket(packet);
        if (result != null) {
          _stepParser = null;
          state = state.copyWith(steps: result, stepsLoading: false);
          final deviceId = _connectedDeviceId;
          if (deviceId != null) {
            _persist(
              () => _storage.insertStepEntries(
                deviceId: deviceId,
                entries: result,
              ),
            );
          }
        }

      case cmdGeneralNotification:
        final activity = parseDailyActivityNotification(packet);
        if (activity != null) {
          state = state.copyWith(dailyActivity: activity);
        }

      case cmdRawSensor:
        final reading = parseAccelerometerResponse(packet);
        if (reading != null) {
          state = state.copyWith(lastAccel: reading);
          _appendMotionSample(reading);
        }
    }
  }

  Future<void> _loadLatestMotionSession(String deviceId) async {
    try {
      final recording = await _storage.loadLatestMotionSession(
        deviceId: deviceId,
      );
      state = state.copyWith(
        motionRecording: recording,
        clearMotionRecording: recording == null,
        motionSessionName:
            recording?.session.name ?? _defaultMotionSessionName(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Motion-Session laden fehlgeschlagen: $e');
    }
  }

  void _appendMotionSample(AccelerometerReading reading) {
    final sessionId = _activeMotionSessionId;
    final recording = state.motionRecording;
    if (sessionId == null ||
        recording == null ||
        !state.motionRecordingActive) {
      return;
    }

    final sample = MotionSamplePoint(
      receivedAt: DateTime.now(),
      reading: reading,
    );
    state = state.copyWith(
      motionRecording: MotionSessionRecording(
        session: recording.session,
        samples: [...recording.samples, sample],
      ),
    );
    _persistMotion(
      () => _storage.appendMotionSample(
        sessionId: sessionId,
        reading: reading,
        receivedAt: sample.receivedAt,
      ),
    );
  }

  String _defaultMotionSessionName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Motion ${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _persist(Future<void> Function() write) {
    unawaited(
      write()
          .then((_) {
            _onHistoryDataChanged();
          })
          .catchError((Object e, StackTrace _) {
            state = state.copyWith(error: 'DB speichern fehlgeschlagen: $e');
          }),
    );
  }

  void _persistMotion(Future<void> Function() write) {
    unawaited(
      write().catchError((Object e, StackTrace _) {
        state = state.copyWith(error: 'Motion speichern fehlgeschlagen: $e');
      }),
    );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _packetSub?.cancel();
    _statusSub?.cancel();
    for (final t in _rtTimeouts.values) {
      t.cancel();
    }
    for (final t in _rtRestarts.values) {
      t.cancel();
    }
    _dailyMeasurementTimeout?.cancel();
    _dailyMeasurementSilenceTimer?.cancel();
    super.dispose();
  }
}

final scanPageProvider = StateNotifierProvider<ScanPageNotifier, ScanPageState>(
  (ref) {
    return ScanPageNotifier(
      ref.watch(bleServiceProvider),
      ref.watch(openRingStorageProvider),
      () {
        ref.read(historyRefreshTickProvider.notifier).state++;
      },
    );
  },
);
