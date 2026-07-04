import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../protocol/accelerometer.dart';
import '../ui/scan_page_controller.dart';
import 'system_mouse_service.dart';
import 'system_scroll_service.dart';
import 'system_volume_service.dart';

enum GestureHubControl { volume, scroll, mouse }

enum GestureHubPosition { palmDown, palmSide, palmUp, palmVertical, fistDown }

enum GestureHubMouseAxis { vertical, horizontal }

class GestureHubState {
  const GestureHubState({
    this.selectedControl = GestureHubControl.scroll,
    this.isActive = false,
    this.startedAccelerometer = false,
    this.position,
    this.mouseAxis = GestureHubMouseAxis.vertical,
    this.volume,
    this.volumeIntensity,
    this.status = 'Inactive',
    this.error,
  });

  final GestureHubControl selectedControl;
  final bool isActive;
  final bool startedAccelerometer;
  final GestureHubPosition? position;
  final GestureHubMouseAxis mouseAxis;
  final double? volume;
  final String? volumeIntensity;
  final String status;
  final String? error;

  GestureHubState copyWith({
    GestureHubControl? selectedControl,
    bool? isActive,
    bool? startedAccelerometer,
    GestureHubPosition? position,
    bool clearPosition = false,
    GestureHubMouseAxis? mouseAxis,
    double? volume,
    bool clearVolume = false,
    String? volumeIntensity,
    bool clearVolumeIntensity = false,
    String? status,
    String? error,
    bool clearError = false,
  }) {
    return GestureHubState(
      selectedControl: selectedControl ?? this.selectedControl,
      isActive: isActive ?? this.isActive,
      startedAccelerometer: startedAccelerometer ?? this.startedAccelerometer,
      position: clearPosition ? null : (position ?? this.position),
      mouseAxis: mouseAxis ?? this.mouseAxis,
      volume: clearVolume ? null : (volume ?? this.volume),
      volumeIntensity: clearVolumeIntensity
          ? null
          : (volumeIntensity ?? this.volumeIntensity),
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class GestureHubController extends StateNotifier<GestureHubState> {
  GestureHubController(
    this._ref,
    this._volumeService, {
    SystemScrollService scrollService = const SystemScrollService(),
    SystemMouseService mouseService = const SystemMouseService(),
    Duration adjustmentInterval = const Duration(seconds: 1),
    Duration neutralTimeout = const Duration(seconds: 9),
    Duration sampleTimeout = const Duration(seconds: 6),
    Duration controlSwitchHold = const Duration(milliseconds: 1200),
    Duration mouseAxisSwitchHold = const Duration(milliseconds: 900),
  }) : _scrollService = scrollService,
       _mouseService = mouseService,
       _adjustmentInterval = adjustmentInterval,
       _neutralTimeout = neutralTimeout,
       _sampleTimeout = sampleTimeout,
       _controlSwitchHold = controlSwitchHold,
       _mouseAxisSwitchHold = mouseAxisSwitchHold,
       super(const GestureHubState());

  final Ref _ref;
  final SystemVolumeService _volumeService;
  final SystemScrollService _scrollService;
  final SystemMouseService _mouseService;
  final Duration _adjustmentInterval;
  final Duration _neutralTimeout;
  final Duration _sampleTimeout;
  final Duration _controlSwitchHold;
  final Duration _mouseAxisSwitchHold;

  DateTime? _lastActionAt;
  DateTime? _verticalStartedAt;
  DateTime? _mouseSideStartedAt;
  Timer? _neutralTimer;
  Timer? _sampleTimer;
  bool _hotkeyRegistered = false;
  bool _verticalSwitchArmed = true;
  bool _mouseAxisSwitchArmed = true;
  bool _mouseClickArmed = true;

  final _hotkeyToggleGestureHub = HotKey(
    key: PhysicalKeyboardKey.keyM,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  void selectControl(GestureHubControl control) {
    if (state.isActive) return;
    state = state.copyWith(selectedControl: control, clearError: true);
  }

  Future<void> toggle() async {
    if (state.isActive) {
      await deactivate();
    } else {
      await activate();
    }
  }

  Future<void> activate() async {
    if (state.isActive) return;

    final scanState = _ref.read(scanPageProvider);
    final startedAccelerometer = !scanState.accelRunning;
    state = state.copyWith(
      isActive: true,
      startedAccelerometer: startedAccelerometer,
      clearPosition: true,
      mouseAxis: GestureHubMouseAxis.vertical,
      clearVolumeIntensity: true,
      status: startedAccelerometer ? 'Starting sensor' : 'Ready',
      clearError: true,
    );
    _lastActionAt = null;
    _leaveVertical();
    _leaveMouseSide();
    _mouseClickArmed = true;

    if (state.selectedControl == GestureHubControl.volume) {
      await _refreshVolume();
    }

    if (startedAccelerometer) {
      await _ref.read(scanPageProvider.notifier).toggleAccelerometer();
    }

    _restartSampleTimeout();
    state = state.copyWith(status: 'Waiting for gesture');
  }

  Future<void> deactivate() async {
    _neutralTimer?.cancel();
    _sampleTimer?.cancel();
    _neutralTimer = null;
    _sampleTimer = null;
    final shouldStopAccelerometer = state.startedAccelerometer;
    state = state.copyWith(
      isActive: false,
      startedAccelerometer: false,
      clearPosition: true,
      mouseAxis: GestureHubMouseAxis.vertical,
      clearVolumeIntensity: true,
      status: 'Inactive',
    );
    _lastActionAt = null;
    _verticalStartedAt = null;
    _mouseSideStartedAt = null;
    _verticalSwitchArmed = true;
    _mouseAxisSwitchArmed = true;
    _mouseClickArmed = true;

    final scanState = _ref.read(scanPageProvider);
    if (shouldStopAccelerometer &&
        scanState.accelRunning &&
        !scanState.accelStopping) {
      await _ref.read(scanPageProvider.notifier).toggleAccelerometer();
    }
  }

  Future<void> onAccelerometerReading(AccelerometerReading reading) async {
    if (!state.isActive) return;

    _restartSampleTimeout();
    final position = classifyGestureHubPosition(reading);
    state = state.copyWith(position: position);

    switch (position) {
      case GestureHubPosition.palmUp:
        _leaveVertical();
        _leaveMouseSide();
        _mouseClickArmed = true;
        _neutralTimer?.cancel();
        await _runPositionAction(
          reading: reading,
          scrollDelta: 120,
          scrollStatus: 'Up',
        );
      case GestureHubPosition.palmDown:
        _leaveVertical();
        _leaveMouseSide();
        _mouseClickArmed = true;
        _neutralTimer?.cancel();
        await _runPositionAction(
          reading: reading,
          scrollDelta: -120,
          scrollStatus: 'Down',
        );
      case GestureHubPosition.palmSide:
        _leaveVertical();
        _mouseClickArmed = true;
        if (state.selectedControl == GestureHubControl.mouse) {
          await _handleMouseSideHold();
        } else {
          state = state.copyWith(status: 'Neutral', volumeIntensity: 'Neutral');
          _startNeutralTimeout();
        }
      case GestureHubPosition.palmVertical:
        _leaveMouseSide();
        _mouseClickArmed = true;
        _neutralTimer?.cancel();
        await _handleVerticalHold();
      case GestureHubPosition.fistDown:
        _leaveVertical();
        _leaveMouseSide();
        _neutralTimer?.cancel();
        await _handleFistDown();
    }
  }

  Future<void> _runPositionAction({
    required AccelerometerReading reading,
    required int scrollDelta,
    required String scrollStatus,
  }) async {
    switch (state.selectedControl) {
      case GestureHubControl.volume:
        await _adjustVolumeFromRoll(reading);
      case GestureHubControl.scroll:
        await _scroll(scrollDelta, scrollStatus);
      case GestureHubControl.mouse:
        await _moveMouse(scrollDelta.isNegative ? -1 : 1);
    }
  }

  Future<void> _adjustVolumeFromRoll(AccelerometerReading reading) async {
    final delta = volumeDeltaForGestureHubRoll(reading);
    if (delta == 0) {
      state = state.copyWith(status: 'Neutral', volumeIntensity: 'Neutral');
      _startNeutralTimeout();
      return;
    }

    final status = _volumeStatusForDelta(delta);
    final now = DateTime.now();
    final last = _lastActionAt;
    if (last != null && now.difference(last) < _adjustmentInterval) {
      state = state.copyWith(status: status, volumeIntensity: status);
      return;
    }

    _lastActionAt = now;
    try {
      final current = state.volume ?? await _volumeService.getVolume();
      final next = await _volumeService.setVolume(
        (current + delta).clamp(0.0, 1.0).toDouble(),
      );
      state = state.copyWith(
        volume: next,
        status: status,
        volumeIntensity: status,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to set volume: $e');
    }
  }

  Future<void> _scroll(int wheelDelta, String status) async {
    final now = DateTime.now();
    final last = _lastActionAt;
    if (last != null && now.difference(last) < _adjustmentInterval) {
      state = state.copyWith(status: status);
      return;
    }

    _lastActionAt = now;
    try {
      await _scrollService.scrollVertical(wheelDelta);
      state = state.copyWith(status: status, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to scroll: $e');
    }
  }

  Future<void> _moveMouse(int direction) async {
    final now = DateTime.now();
    final last = _lastActionAt;
    final status = _mouseMoveStatus(state.mouseAxis, direction);
    if (last != null && now.difference(last) < _adjustmentInterval) {
      state = state.copyWith(status: status);
      return;
    }

    _lastActionAt = now;
    final (dx, dy) = switch (state.mouseAxis) {
      GestureHubMouseAxis.vertical => (0, direction > 0 ? -80 : 80),
      GestureHubMouseAxis.horizontal => (direction > 0 ? -80 : 80, 0),
    };
    try {
      await _mouseService.moveRelative(dx: dx, dy: dy);
      state = state.copyWith(status: status, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to move mouse: $e');
    }
  }

  void _startNeutralTimeout() {
    _neutralTimer ??= Timer(_neutralTimeout, () {
      unawaited(deactivate());
    });
  }

  void _restartSampleTimeout() {
    _sampleTimer?.cancel();
    _sampleTimer = Timer(_sampleTimeout, () {
      state = state.copyWith(status: 'No sensor data');
      unawaited(deactivate());
    });
  }

  void _leaveVertical() {
    _verticalStartedAt = null;
    _verticalSwitchArmed = true;
  }

  void _leaveMouseSide() {
    _mouseSideStartedAt = null;
    _mouseAxisSwitchArmed = true;
  }

  Future<void> _handleVerticalHold() async {
    final now = DateTime.now();
    _verticalStartedAt ??= now;
    final heldLongEnough =
        now.difference(_verticalStartedAt!) >= _controlSwitchHold;
    if (!_verticalSwitchArmed || !heldLongEnough) {
      state = state.copyWith(status: 'Hold to switch control');
      return;
    }

    _verticalSwitchArmed = false;
    _lastActionAt = null;
    final nextControl = switch (state.selectedControl) {
      GestureHubControl.scroll => GestureHubControl.volume,
      GestureHubControl.volume => GestureHubControl.mouse,
      GestureHubControl.mouse => GestureHubControl.scroll,
    };
    state = state.copyWith(
      selectedControl: nextControl,
      mouseAxis: nextControl == GestureHubControl.mouse
          ? GestureHubMouseAxis.vertical
          : state.mouseAxis,
      status: '${_controlLabel(nextControl)} active',
      clearVolumeIntensity: true,
      clearError: true,
    );

    if (nextControl == GestureHubControl.volume) {
      await _refreshVolume();
    }
  }

  Future<void> _handleMouseSideHold() async {
    final now = DateTime.now();
    _mouseSideStartedAt ??= now;
    final heldLongEnough =
        now.difference(_mouseSideStartedAt!) >= _mouseAxisSwitchHold;
    if (!_mouseAxisSwitchArmed || !heldLongEnough) {
      state = state.copyWith(status: 'Mouse stop');
      return;
    }

    _mouseAxisSwitchArmed = false;
    final nextAxis = switch (state.mouseAxis) {
      GestureHubMouseAxis.vertical => GestureHubMouseAxis.horizontal,
      GestureHubMouseAxis.horizontal => GestureHubMouseAxis.vertical,
    };
    state = state.copyWith(
      mouseAxis: nextAxis,
      status: 'Axis ${_mouseAxisLabel(nextAxis)}',
      clearError: true,
    );
  }

  Future<void> _handleFistDown() async {
    if (state.selectedControl != GestureHubControl.mouse) {
      _mouseClickArmed = true;
      state = state.copyWith(status: 'Neutral');
      return;
    }
    if (!_mouseClickArmed) {
      state = state.copyWith(status: 'Click');
      return;
    }

    _mouseClickArmed = false;
    try {
      await _mouseService.leftClick();
      state = state.copyWith(status: 'Click', clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to click: $e');
    }
  }

  Future<void> _refreshVolume() async {
    try {
      final volume = await _volumeService.getVolume();
      state = state.copyWith(volume: volume);
    } catch (e) {
      state = state.copyWith(error: 'Failed to read volume: $e');
    }
  }

  Future<void> registerGlobalHotkey() async {
    if (_hotkeyRegistered) return;
    _hotkeyRegistered = true;
    try {
      await hotKeyManager.register(
        _hotkeyToggleGestureHub,
        keyDownHandler: (_) => toggle(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Gesture Hub hotkey failed: $e');
    }
  }

  @override
  void dispose() {
    _neutralTimer?.cancel();
    _sampleTimer?.cancel();
    if (_hotkeyRegistered) {
      unawaited(hotKeyManager.unregister(_hotkeyToggleGestureHub));
    }
    super.dispose();
  }
}

GestureHubPosition classifyGestureHubPosition(AccelerometerReading reading) {
  final centers = {
    GestureHubPosition.palmDown: _GestureCenter(0.101, -1.041, -0.004),
    GestureHubPosition.palmSide: _GestureCenter(-0.141, -0.086, 0.841),
    GestureHubPosition.palmUp: _GestureCenter(-0.160, 0.907, -0.041),
    GestureHubPosition.palmVertical: _GestureCenter(-1.023, -0.179, -0.072),
    GestureHubPosition.fistDown: _GestureCenter(0.938, -0.131, 0.026),
  };

  var best = GestureHubPosition.palmSide;
  var bestDistance = double.infinity;
  for (final entry in centers.entries) {
    final dx = reading.xG - entry.value.x;
    final dy = reading.yG - entry.value.y;
    final dz = reading.zG - entry.value.z;
    final distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz));
    if (distance < bestDistance) {
      bestDistance = distance;
      best = entry.key;
    }
  }
  return best;
}

double gestureHubRollDegrees(AccelerometerReading reading) {
  return math.atan2(reading.yG, reading.zG) * 180 / math.pi;
}

double volumeDeltaForGestureHubRoll(AccelerometerReading reading) {
  final roll = gestureHubRollDegrees(reading);
  const sideRoll = -5.9;
  const deadzoneDegrees = 18.0;
  const maxUsefulDegrees = 95.0;
  final offset = roll - sideRoll;
  final magnitude = offset.abs();
  if (magnitude <= deadzoneDegrees) return 0;

  final normalized =
      ((magnitude - deadzoneDegrees) / (maxUsefulDegrees - deadzoneDegrees))
          .clamp(0.0, 1.0);
  final step = 0.02 + (normalized * 0.08);
  return offset.isNegative ? -step : step;
}

String _volumeStatusForDelta(double delta) {
  final direction = delta.isNegative ? 'down' : 'up';
  final magnitude = delta.abs();
  if (magnitude >= 0.08) return 'fast $direction';
  if (magnitude >= 0.045) return direction;
  return 'slow $direction';
}

String _controlLabel(GestureHubControl control) {
  return switch (control) {
    GestureHubControl.volume => 'Volume',
    GestureHubControl.scroll => 'Scroll',
    GestureHubControl.mouse => 'Mouse',
  };
}

String _mouseAxisLabel(GestureHubMouseAxis axis) {
  return switch (axis) {
    GestureHubMouseAxis.vertical => 'Vertical',
    GestureHubMouseAxis.horizontal => 'Horizontal',
  };
}

String _mouseMoveStatus(GestureHubMouseAxis axis, int direction) {
  return switch (axis) {
    GestureHubMouseAxis.vertical => direction > 0 ? 'Mouse up' : 'Mouse down',
    GestureHubMouseAxis.horizontal =>
      direction > 0 ? 'Mouse left' : 'Mouse right',
  };
}

class _GestureCenter {
  const _GestureCenter(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

final gestureHubControllerProvider =
    StateNotifierProvider<GestureHubController, GestureHubState>((ref) {
      return GestureHubController(
        ref,
        ref.watch(systemVolumeServiceProvider),
        scrollService: ref.watch(systemScrollServiceProvider),
        mouseService: ref.watch(systemMouseServiceProvider),
      );
    });
