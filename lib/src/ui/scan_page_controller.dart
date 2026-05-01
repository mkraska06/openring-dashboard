import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;

import '../ble/ble_service.dart';
import '../protocol/accelerometer.dart';
import '../protocol/battery.dart';
import '../protocol/commands.dart';
import '../protocol/hr_log.dart';
import '../protocol/hr_settings.dart';
import '../protocol/real_time.dart';
import '../protocol/steps.dart';
import '../history/history_page_controller.dart';
import '../storage/storage_repository.dart';
import 'scan_page_use_cases.dart';

class ScanPageState {
  final Map<String, BleDevice> foundDevices;
  final BatteryResponse? battery;
  final Map<int, RealTimeReading> realTimeReadings;
  final Set<int> runningMeasurements;
  final HrLogResult? hrLog;
  final bool hrLogLoading;
  final List<StepEntry>? steps;
  final bool stepsLoading;
  final HrLogSettings? hrLogSettings;
  final AccelerometerReading? lastAccel;
  final bool accelRunning;
  final String? error;
  final List<String> debugLog;

  const ScanPageState({
    this.foundDevices = const {},
    this.battery,
    this.realTimeReadings = const {},
    this.runningMeasurements = const {},
    this.hrLog,
    this.hrLogLoading = false,
    this.steps,
    this.stepsLoading = false,
    this.hrLogSettings,
    this.lastAccel,
    this.accelRunning = false,
    this.error,
    this.debugLog = const [],
  });

  ScanPageState copyWith({
    Map<String, BleDevice>? foundDevices,
    BatteryResponse? battery,
    bool clearBattery = false,
    Map<int, RealTimeReading>? realTimeReadings,
    Set<int>? runningMeasurements,
    HrLogResult? hrLog,
    bool clearHrLog = false,
    bool? hrLogLoading,
    List<StepEntry>? steps,
    bool clearSteps = false,
    bool? stepsLoading,
    HrLogSettings? hrLogSettings,
    bool clearHrLogSettings = false,
    AccelerometerReading? lastAccel,
    bool clearAccel = false,
    bool? accelRunning,
    String? error,
    bool clearError = false,
    List<String>? debugLog,
  }) {
    return ScanPageState(
      foundDevices: foundDevices ?? this.foundDevices,
      battery: clearBattery ? null : (battery ?? this.battery),
      realTimeReadings: realTimeReadings ?? this.realTimeReadings,
      runningMeasurements: runningMeasurements ?? this.runningMeasurements,
      hrLog: clearHrLog ? null : (hrLog ?? this.hrLog),
      hrLogLoading: hrLogLoading ?? this.hrLogLoading,
      steps: clearSteps ? null : (steps ?? this.steps),
      stepsLoading: stepsLoading ?? this.stepsLoading,
      hrLogSettings: clearHrLogSettings
          ? null
          : (hrLogSettings ?? this.hrLogSettings),
      lastAccel: clearAccel ? null : (lastAccel ?? this.lastAccel),
      accelRunning: accelRunning ?? this.accelRunning,
      error: clearError ? null : (error ?? this.error),
      debugLog: debugLog ?? this.debugLog,
    );
  }
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
  HrLogParser? _hrLogParser;
  StepParser? _stepParser;
  String? _connectedDeviceId;

  static const _maxLogLines = 50;

  void _addLogLine(String line) {
    final log = [...state.debugLog, line];
    if (log.length > _maxLogLines) {
      state = state.copyWith(debugLog: log.sublist(log.length - _maxLogLines));
    } else {
      state = state.copyWith(debugLog: log);
    }
  }

  Future<void> startScan() async {
    state = state.copyWith(
      foundDevices: const {},
      clearBattery: true,
      realTimeReadings: const {},
      runningMeasurements: const {},
      clearHrLog: true,
      clearSteps: true,
      clearHrLogSettings: true,
      clearAccel: true,
      accelRunning: false,
      clearError: true,
      debugLog: const [],
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
      clearHrLog: true,
      clearSteps: true,
      clearHrLogSettings: true,
      clearAccel: true,
      accelRunning: false,
      clearError: true,
      debugLog: const [],
    );
    await _scanSub?.cancel();

    _useCases.onDebugLog = _addLogLine;

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
    _hrLogParser = null;
    _stepParser = null;
    _connectedDeviceId = null;
    _packetSub?.cancel();
    _packetSub = null;
    _useCases.onDebugLog = null;
    state = state.copyWith(
      runningMeasurements: const {},
      realTimeReadings: const {},
      accelRunning: false,
      clearAccel: true,
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
    if (state.runningMeasurements.contains(readingType)) {
      await _stopRealTime(readingType);
    } else {
      await _startRealTime(readingType);
    }
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
    try {
      await _useCases.stopAccelerometer();
    } catch (_) {}
    state = state.copyWith(accelRunning: false);
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
          final updated = Map<int, RealTimeReading>.from(state.realTimeReadings)
            ..[resp.type] = resp;
          state = state.copyWith(realTimeReadings: updated);

          if (resp.hasValue) {
            _onValidRealTimeReading(resp.type, resp.value);
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

      case cmdRawSensor:
        final reading = parseAccelerometerResponse(packet);
        if (reading != null) {
          state = state.copyWith(lastAccel: reading);
        }
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _persist(Future<void> Function() write) {
    unawaited(
      write()
          .then((_) {
            _onHistoryDataChanged();
          })
          .catchError((Object e, StackTrace _) {
            _addLogLine('[DB] $e');
            state = state.copyWith(error: 'DB speichern fehlgeschlagen: $e');
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
    _useCases.onDebugLog = null;
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
