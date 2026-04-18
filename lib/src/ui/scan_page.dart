import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Hide BleService from universal_ble to avoid clash with our own BleService.
import 'package:universal_ble/universal_ble.dart' hide BleService;

import 'package:window_manager/window_manager.dart';

import '../ble/ble_service.dart';
import '../overlay/overlay_controller.dart';
import '../protocol/accelerometer.dart';
import '../protocol/battery.dart';
import '../protocol/commands.dart';
import '../protocol/hr_log.dart';
import '../protocol/hr_settings.dart';
import '../protocol/real_time.dart';
import '../protocol/set_time.dart';
import '../protocol/steps.dart';
import '../protocol/utility.dart';

// ---------------------------------------------------------------------------
// Page state
// ---------------------------------------------------------------------------

class ScanPageState {
  final Map<String, BleDevice> foundDevices; // keyed by deviceId, no duplicates
  final BatteryResponse? battery;

  // Real-time measurements (generic for HR, SpO2, HRV)
  final Map<int, RealTimeReading> realTimeReadings; // keyed by ReadingType
  final Set<int> runningMeasurements; // which ReadingTypes are currently active

  // Historical data
  final HrLogResult? hrLog;
  final bool hrLogLoading;
  final List<StepEntry>? steps;
  final bool stepsLoading;
  final HrLogSettings? hrLogSettings;

  // Accelerometer
  final AccelerometerReading? lastAccel;
  final bool accelRunning;

  final String? error;
  final List<String> debugLog; // on-screen TX/RX hex log

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
      hrLogSettings:
          clearHrLogSettings ? null : (hrLogSettings ?? this.hrLogSettings),
      lastAccel: clearAccel ? null : (lastAccel ?? this.lastAccel),
      accelRunning: accelRunning ?? this.accelRunning,
      error: clearError ? null : (error ?? this.error),
      debugLog: debugLog ?? this.debugLog,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ScanPageNotifier extends StateNotifier<ScanPageState> {
  ScanPageNotifier(this._service) : super(const ScanPageState()) {
    // React to unexpected disconnects (e.g. ring moves out of range).
    _statusSub = _service.statusStream.listen((status) {
      if (status == BleConnectionStatus.disconnected) {
        _onDisconnected();
      }
    });
  }

  final BleService _service;
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<Uint8List>? _packetSub;
  StreamSubscription<BleConnectionStatus>? _statusSub;

  // Per-reading-type timers for timeout and continuous restart
  final Map<int, Timer> _rtTimeouts = {};
  final Map<int, Timer> _rtRestarts = {};

  // Multi-packet stateful parsers
  HrLogParser? _hrLogParser;
  StepParser? _stepParser;

  // -- debug log ------------------------------------------------------------

  /// Max log entries kept in state (older entries are trimmed).
  static const _maxLogLines = 50;

  void _addLogLine(String line) {
    final log = [...state.debugLog, line];
    if (log.length > _maxLogLines) {
      state = state.copyWith(debugLog: log.sublist(log.length - _maxLogLines));
    } else {
      state = state.copyWith(debugLog: log);
    }
  }

  // -- scanning -------------------------------------------------------------

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
    });

    try {
      await _service.startScan();
    } catch (e) {
      state = state.copyWith(error: 'Scan failed: $e');
    }
  }

  Future<void> stopScan() async {
    _scanSub?.cancel();
    await _service.stopScan();
  }

  // -- connection -----------------------------------------------------------

  Future<void> connect(String deviceId) async {
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

    _service.onDebugLog = _addLogLine;

    try {
      await _service.connect(deviceId);
    } catch (e) {
      state = state.copyWith(error: 'Connection failed: $e');
      return;
    }

    _packetSub?.cancel();
    _packetSub = _service.packetStream.listen(_onPacket);

    await _requestBattery();
  }

  Future<void> disconnect() async {
    await _service.disconnect();
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
    _packetSub?.cancel();
    _packetSub = null;
    _service.onDebugLog = null;
    state = state.copyWith(
      runningMeasurements: const {},
      realTimeReadings: const {},
      accelRunning: false,
      clearAccel: true,
    );
  }

  // -- battery --------------------------------------------------------------

  Future<void> _requestBattery() async {
    try {
      await _service.sendPacket(makeBatteryRequest());
    } catch (e) {
      state = state.copyWith(error: 'Battery request failed: $e');
    }
  }

  // -- generic real-time measurements ---------------------------------------

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
      await _service.sendPacket(makeStartRealTimeRequest(readingType));
    } catch (e) {
      final info = readingTypeInfo[readingType];
      state = state.copyWith(
          error: '${info?.label ?? "Messung"} start failed: $e');
      return;
    }

    state = state.copyWith(
      runningMeasurements: {...state.runningMeasurements, readingType},
    );

    // 45 s timeout
    _rtTimeouts[readingType] = Timer(const Duration(seconds: 45), () {
      if (!state.runningMeasurements.contains(readingType)) return;
      _stopRealTime(readingType);
      state = state.copyWith(
        error: 'Kein Messwert erkannt — Ring richtig anlegen und erneut versuchen.',
      );
    });
  }

  Future<void> _stopRealTime(int readingType) async {
    _rtTimeouts[readingType]?.cancel();
    _rtRestarts[readingType]?.cancel();
    _rtTimeouts.remove(readingType);
    _rtRestarts.remove(readingType);

    try {
      await _service.sendPacket(makeStopRealTimeRequest(readingType));
    } catch (_) {}

    state = state.copyWith(
      runningMeasurements:
          Set<int>.from(state.runningMeasurements)..remove(readingType),
    );
  }

  void _onValidRealTimeReading(int readingType, int value) {
    _rtTimeouts[readingType]?.cancel();
    _rtRestarts[readingType]?.cancel();

    // Continuous mode: wait 3 s, then send a fresh START.
    _rtRestarts[readingType] = Timer(const Duration(seconds: 3), () async {
      if (!state.runningMeasurements.contains(readingType)) return;
      try {
        await _service.sendPacket(makeStartRealTimeRequest(readingType));
      } catch (_) {
        return;
      }
      _rtTimeouts[readingType] = Timer(const Duration(seconds: 45), () {
        if (!state.runningMeasurements.contains(readingType)) return;
        _stopRealTime(readingType);
        state = state.copyWith(
          error: 'Kein Messwert mehr erkannt — Ring prüfen.',
        );
      });
    });
  }

  // -- historical data: HR log ----------------------------------------------

  Future<void> requestHrLog(DateTime day) async {
    _hrLogParser = HrLogParser();
    state = state.copyWith(hrLogLoading: true, clearHrLog: true);

    try {
      await _service.sendPacket(makeHrLogRequest(day));
    } catch (e) {
      _hrLogParser = null;
      state = state.copyWith(hrLogLoading: false, error: 'HR-Log Fehler: $e');
    }
  }

  // -- historical data: HR settings -----------------------------------------

  Future<void> queryHrLogSettings() async {
    try {
      await _service.sendPacket(makeHrLogSettingsQuery());
    } catch (e) {
      state = state.copyWith(error: 'HR-Settings Fehler: $e');
    }
  }

  Future<void> setHrLogSettings(HrLogSettings settings) async {
    try {
      await _service.sendPacket(makeHrLogSettingsSet(settings));
      // Re-query to confirm
      await _service.sendPacket(makeHrLogSettingsQuery());
    } catch (e) {
      state = state.copyWith(error: 'HR-Settings Fehler: $e');
    }
  }

  // -- historical data: steps -----------------------------------------------

  Future<void> requestSteps(DateTime day) async {
    _stepParser = StepParser();
    state = state.copyWith(stepsLoading: true, clearSteps: true);

    try {
      await _service.sendPacket(makeStepsRequest(day));
    } catch (e) {
      _stepParser = null;
      state =
          state.copyWith(stepsLoading: false, error: 'Schritte Fehler: $e');
    }
  }

  // -- accelerometer --------------------------------------------------------

  Future<void> toggleAccelerometer() async {
    if (state.accelRunning) {
      await _stopAccelerometer();
    } else {
      await _startAccelerometer();
    }
  }

  Future<void> _startAccelerometer() async {
    try {
      await _service.sendPacket(makeAccelerometerStartRequest());
    } catch (e) {
      state = state.copyWith(error: 'Accelerometer start failed: $e');
      return;
    }
    state = state.copyWith(accelRunning: true, clearAccel: true);
  }

  Future<void> _stopAccelerometer() async {
    try {
      await _service.sendPacket(makeAccelerometerStopRequest());
    } catch (_) {}
    state = state.copyWith(accelRunning: false);
  }

  // -- utility commands -----------------------------------------------------

  Future<void> syncTime() async {
    try {
      await _service.sendPacket(makeSetTimePacket());
    } catch (e) {
      state = state.copyWith(error: 'Zeit-Sync Fehler: $e');
    }
  }

  Future<void> blinkTwice() async {
    try {
      await _service.sendPacket(makeBlinkTwicePacket());
    } catch (e) {
      state = state.copyWith(error: 'Blink Fehler: $e');
    }
  }

  Future<void> reboot() async {
    try {
      await _service.sendPacket(makeRebootPacket());
    } catch (e) {
      state = state.copyWith(error: 'Reboot Fehler: $e');
    }
  }

  // -- packet dispatcher ----------------------------------------------------

  void _onPacket(Uint8List packet) {
    switch (packet[0]) {
      case Cmd.battery:
        final resp = parseBatteryResponse(packet);
        if (resp != null) state = state.copyWith(battery: resp);

      case Cmd.startRealTime:
        final resp = parseRealTimeResponse(packet);
        if (resp != null) {
          // Update the readings map
          final updated = Map<int, RealTimeReading>.from(state.realTimeReadings)
            ..[resp.type] = resp;
          state = state.copyWith(realTimeReadings: updated);

          if (resp.hasValue) {
            _onValidRealTimeReading(resp.type, resp.value);
          }
        }

      case Cmd.readHeartRate:
        final result = _hrLogParser?.processPacket(packet);
        if (result != null) {
          _hrLogParser = null;
          state = state.copyWith(hrLog: result, hrLogLoading: false);
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
        }

      case cmdRawSensor:
        final reading = parseAccelerometerResponse(packet);
        if (reading != null) {
          state = state.copyWith(lastAccel: reading);
        }
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  // -- lifecycle ------------------------------------------------------------

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
    _service.onDebugLog = null;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final scanPageProvider =
    StateNotifierProvider<ScanPageNotifier, ScanPageState>((ref) {
  return ScanPageNotifier(ref.watch(bleServiceProvider));
});

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageState = ref.watch(scanPageProvider);
    final bleStatus = ref.watch(bleStatusProvider).valueOrNull ??
        BleConnectionStatus.disconnected;
    final notifier = ref.read(scanPageProvider.notifier);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -- custom title bar (because TitleBarStyle.hidden) ---------------
          _CustomTitleBar(
            bleStatus: bleStatus,
            onOverlay: () =>
                ref.read(overlayControllerProvider).activateOverlay(),
          ),

          // -- error banner -------------------------------------------------
          if (pageState.error != null)
            MaterialBanner(
              content: Text(pageState.error!),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(scanPageProvider.notifier).clearError(),
                  child: const Text('Dismiss'),
                ),
              ],
            ),

          // -- scan / disconnect controls -----------------------------------
          Padding(
            padding: const EdgeInsets.all(12),
            child: _ControlRow(
              status: bleStatus,
              onScan: notifier.startScan,
              onDisconnect: notifier.disconnect,
            ),
          ),

          // -- device list --------------------------------------------------
          if (bleStatus != BleConnectionStatus.connected &&
              bleStatus != BleConnectionStatus.connecting) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Found rings:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: pageState.foundDevices.isEmpty
                  ? const Center(child: Text('No rings found yet.'))
                  : ListView(
                      children: pageState.foundDevices.values
                          .map((d) => _DeviceTile(
                                device: d,
                                onTap: () => notifier.connect(d.deviceId),
                              ))
                          .toList(),
                    ),
            ),
          ],

          // -- connected panel ----------------------------------------------
          if (bleStatus == BleConnectionStatus.connected)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  // Battery
                  _BatteryCard(battery: pageState.battery),

                  // Real-time measurements
                  for (final type in ReadingType.supported)
                    _RealTimeCard(
                      readingType: type,
                      reading: pageState.realTimeReadings[type],
                      isRunning:
                          pageState.runningMeasurements.contains(type),
                      onToggle: () => notifier.toggleRealTime(type),
                    ),

                  // Accelerometer
                  _AccelerometerCard(
                    reading: pageState.lastAccel,
                    isRunning: pageState.accelRunning,
                    onToggle: notifier.toggleAccelerometer,
                  ),

                  const Divider(indent: 12, endIndent: 12),

                  // Historical data
                  _HrLogCard(
                    hrLog: pageState.hrLog,
                    isLoading: pageState.hrLogLoading,
                    onRequest: notifier.requestHrLog,
                  ),

                  _StepsCard(
                    steps: pageState.steps,
                    isLoading: pageState.stepsLoading,
                    onRequest: notifier.requestSteps,
                  ),

                  // HR Log Settings
                  _HrLogSettingsCard(
                    settings: pageState.hrLogSettings,
                    onQuery: notifier.queryHrLogSettings,
                    onSet: notifier.setHrLogSettings,
                  ),

                  const Divider(indent: 12, endIndent: 12),

                  // Utility commands
                  _UtilityCard(
                    onSyncTime: notifier.syncTime,
                    onBlink: notifier.blinkTwice,
                    onReboot: notifier.reboot,
                  ),

                  // Debug log
                  SizedBox(
                    height: 250,
                    child: _DebugLogPanel(lines: pageState.debugLog),
                  ),
                ],
              ),
            ),

          // -- connecting indicator -----------------------------------------
          if (bleStatus == BleConnectionStatus.connecting)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Custom title bar used because the native title bar is hidden (to allow
/// seamless switching to overlay mode without runtime TitleBarStyle changes).
class _CustomTitleBar extends StatelessWidget {
  const _CustomTitleBar({
    required this.bleStatus,
    required this.onOverlay,
  });

  final BleConnectionStatus bleStatus;
  final VoidCallback onOverlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      color: theme.colorScheme.primary,
      child: Row(
        children: [
          // Draggable area (acts as title bar).
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'OpenRing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          // Status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _StatusIndicator(status: bleStatus),
          ),
          // Overlay button
          if (bleStatus == BleConnectionStatus.connected)
            IconButton(
              icon: Icon(Icons.picture_in_picture_alt,
                  color: theme.colorScheme.onPrimary, size: 18),
              tooltip: 'Overlay aktivieren (Strg+Shift+O)',
              onPressed: onOverlay,
              splashRadius: 16,
            ),
          // Window control buttons
          _WindowButton(
            icon: Icons.minimize,
            onPressed: () => windowManager.minimize(),
            color: theme.colorScheme.onPrimary,
          ),
          _WindowButton(
            icon: Icons.crop_square,
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            color: theme.colorScheme.onPrimary,
          ),
          _WindowButton(
            icon: Icons.close,
            onPressed: () => windowManager.close(),
            color: theme.colorScheme.onPrimary,
            hoverColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.color,
    this.hoverColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 40,
      child: IconButton(
        icon: Icon(icon, color: color, size: 16),
        onPressed: onPressed,
        hoverColor: hoverColor?.withValues(alpha: 0.8),
        splashRadius: 0.01,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final BleConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      BleConnectionStatus.disconnected => (Colors.red, 'Getrennt'),
      BleConnectionStatus.scanning => (Colors.orange, 'Scan...'),
      BleConnectionStatus.connecting => (Colors.amber, 'Verbinde...'),
      BleConnectionStatus.connected => (Colors.green, 'Verbunden'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.status,
    required this.onScan,
    required this.onDisconnect,
  });

  final BleConnectionStatus status;
  final VoidCallback onScan;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed:
              status == BleConnectionStatus.disconnected ? onScan : null,
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Scan starten'),
        ),
        const SizedBox(width: 12),
        if (status == BleConnectionStatus.connected)
          OutlinedButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Trennen'),
          ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});

  final BleDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.watch),
      title: Text(device.name ?? '(unbekannt)'),
      subtitle: Text(device.deviceId),
      trailing: device.rssi != null
          ? Text('${device.rssi} dBm',
              style: Theme.of(context).textTheme.bodySmall)
          : null,
      onTap: onTap,
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.battery});

  final BatteryResponse? battery;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          battery == null
              ? Icons.battery_unknown
              : battery!.isCharging
                  ? Icons.battery_charging_full
                  : Icons.battery_full,
        ),
        title: const Text('Batterie'),
        trailing: Text(
          battery == null
              ? '\u2014'
              : '${battery!.level}%${battery!.isCharging ? " (laedt)" : ""}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

// -- Generic real-time card -------------------------------------------------

class _RealTimeCard extends StatelessWidget {
  const _RealTimeCard({
    required this.readingType,
    required this.reading,
    required this.isRunning,
    required this.onToggle,
  });

  final int readingType;
  final RealTimeReading? reading;
  final bool isRunning;
  final VoidCallback onToggle;

  IconData get _icon {
    return switch (readingType) {
      ReadingType.heartRate => Icons.favorite,
      ReadingType.spo2 => Icons.air,
      ReadingType.hrv => Icons.show_chart,
      _ => Icons.sensors,
    };
  }

  Color get _iconColor {
    return switch (readingType) {
      ReadingType.heartRate => Colors.red,
      ReadingType.spo2 => Colors.blue,
      ReadingType.hrv => Colors.purple,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final info = readingTypeInfo[readingType];
    final label = info?.label ?? 'Messung';
    final unit = info?.unit ?? '';

    final String mainText;
    if (isRunning) {
      mainText =
          reading != null && reading!.hasValue ? '${reading!.value} $unit' : 'Messe...';
    } else {
      mainText = reading != null && reading!.hasValue
          ? '${reading!.value} $unit (gestoppt)'
          : '\u2014';
    }

    final String? debugText;
    if (isRunning && reading != null) {
      debugText = 'raw: err=${reading!.errorCode} val=${reading!.value}';
    } else {
      debugText = null;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(_icon, color: _iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(mainText,
                      style: Theme.of(context).textTheme.titleLarge),
                  if (debugText != null)
                    Text(debugText,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onToggle,
              style: isRunning
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700)
                  : null,
              child: Text(isRunning ? 'Stoppen' : 'Starten'),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Accelerometer card -----------------------------------------------------

class _AccelerometerCard extends StatelessWidget {
  const _AccelerometerCard({
    required this.reading,
    required this.isRunning,
    required this.onToggle,
  });

  final AccelerometerReading? reading;
  final bool isRunning;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final String mainText;
    if (isRunning && reading != null) {
      mainText = 'X=${reading!.accX}  Y=${reading!.accY}  Z=${reading!.accZ}';
    } else if (isRunning) {
      mainText = 'Warte auf Daten...';
    } else {
      mainText = '\u2014';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.screen_rotation, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Accelerometer'),
                  Text(mainText,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (isRunning)
                    Text('~1 Hz (Stock Firmware)',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onToggle,
              style: isRunning
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700)
                  : null,
              child: Text(isRunning ? 'Stoppen' : 'Starten'),
            ),
          ],
        ),
      ),
    );
  }
}

// -- HR Log card ------------------------------------------------------------

class _HrLogCard extends StatelessWidget {
  const _HrLogCard({
    required this.hrLog,
    required this.isLoading,
    required this.onRequest,
  });

  final HrLogResult? hrLog;
  final bool isLoading;
  final Future<void> Function(DateTime day) onRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.red),
                const SizedBox(width: 8),
                const Text('HR-Verlauf'),
                const Spacer(),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          // Request today's data
                          onRequest(DateTime.now());
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Heute laden'),
                ),
              ],
            ),
            if (hrLog != null) ...[
              const SizedBox(height: 8),
              Text(
                '${hrLog!.entries.length} Eintr\u00e4ge (Intervall: ${hrLog!.intervalMinutes} min)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (hrLog!.entries.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: hrLog!.entries.length,
                    itemBuilder: (_, i) {
                      final e = hrLog!.entries[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${e.bpm}',
                                style: const TextStyle(fontSize: 10)),
                            Container(
                              width: 6,
                              height: (e.bpm.clamp(40, 180) - 40) * 0.5,
                              color: Colors.red.shade400,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (hrLog!.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Keine Daten f\u00fcr diesen Tag.'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// -- Steps card -------------------------------------------------------------

class _StepsCard extends StatelessWidget {
  const _StepsCard({
    required this.steps,
    required this.isLoading,
    required this.onRequest,
  });

  final List<StepEntry>? steps;
  final bool isLoading;
  final Future<void> Function(DateTime day) onRequest;

  @override
  Widget build(BuildContext context) {
    final totalSteps =
        steps?.fold<int>(0, (sum, e) => sum + e.steps) ?? 0;
    final totalCal =
        steps?.fold<int>(0, (sum, e) => sum + e.calories) ?? 0;
    final totalDist =
        steps?.fold<int>(0, (sum, e) => sum + e.distanceMeters) ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Schritte'),
                const Spacer(),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => onRequest(DateTime.now()),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Heute laden'),
                ),
              ],
            ),
            if (steps != null) ...[
              const SizedBox(height: 8),
              if (steps!.isEmpty)
                const Text('Keine Daten f\u00fcr diesen Tag.')
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                        label: 'Schritte', value: '$totalSteps'),
                    _StatColumn(
                        label: 'Kalorien', value: '$totalCal kcal'),
                    _StatColumn(
                        label: 'Distanz', value: '${totalDist}m'),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// -- HR Log Settings card ---------------------------------------------------

class _HrLogSettingsCard extends StatelessWidget {
  const _HrLogSettingsCard({
    required this.settings,
    required this.onQuery,
    required this.onSet,
  });

  final HrLogSettings? settings;
  final Future<void> Function() onQuery;
  final Future<void> Function(HrLogSettings settings) onSet;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.settings, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HR-Log Einstellungen'),
                  if (settings != null)
                    Text(
                      '${settings!.enabled ? "Aktiv" : "Inaktiv"} \u2014 alle ${settings!.intervalMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (settings == null)
              OutlinedButton(
                onPressed: onQuery,
                child: const Text('Abfragen'),
              )
            else
              OutlinedButton(
                onPressed: () {
                  onSet(HrLogSettings(
                    enabled: !settings!.enabled,
                    intervalMinutes: settings!.intervalMinutes,
                  ));
                },
                child: Text(settings!.enabled ? 'Deaktivieren' : 'Aktivieren'),
              ),
          ],
        ),
      ),
    );
  }
}

// -- Utility card -----------------------------------------------------------

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({
    required this.onSyncTime,
    required this.onBlink,
    required this.onReboot,
  });

  final VoidCallback onSyncTime;
  final VoidCallback onBlink;
  final VoidCallback onReboot;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Befehle'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onSyncTime,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Zeit sync'),
                ),
                OutlinedButton.icon(
                  onPressed: onBlink,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Blinken'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Ring neustarten?'),
                        content: const Text(
                            'Der Ring wird neu gestartet und die Verbindung getrennt.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abbrechen'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onReboot();
                            },
                            child: const Text('Neustarten'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Neustart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -- Debug log panel --------------------------------------------------------

class _DebugLogPanel extends StatefulWidget {
  const _DebugLogPanel({required this.lines});

  final List<String> lines;

  @override
  State<_DebugLogPanel> createState() => _DebugLogPanelState();
}

class _DebugLogPanelState extends State<_DebugLogPanel> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _DebugLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines.length > oldWidget.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'Debug Log (${widget.lines.length})',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Expanded(
            child: widget.lines.isEmpty
                ? const Center(
                    child: Text('Keine Pakete.',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: widget.lines.length,
                    itemBuilder: (_, i) {
                      final line = widget.lines[i];
                      final isTx = line.startsWith('[TX]');
                      return Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontFamilyFallback: const [
                            'monospace',
                            'Courier New',
                          ],
                          fontSize: 11,
                          color: isTx ? Colors.lightGreenAccent : Colors.cyanAccent,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
