import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/ble/ble_service.dart';
import 'package:openring_v1/src/gesture_hub/gesture_hub_controller.dart';
import 'package:openring_v1/src/gesture_hub/system_mouse_service.dart';
import 'package:openring_v1/src/gesture_hub/system_scroll_service.dart';
import 'package:openring_v1/src/gesture_hub/system_volume_service.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/protocol/battery.dart';
import 'package:openring_v1/src/protocol/hr_log.dart';
import 'package:openring_v1/src/protocol/steps.dart';
import 'package:openring_v1/src/storage/history_models.dart';
import 'package:openring_v1/src/storage/motion_models.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('classifies calibrated open hand positions', () {
    expect(classifyGestureHubPosition(_openUp), GestureHubPosition.palmUp);
    expect(classifyGestureHubPosition(_openSide), GestureHubPosition.palmSide);
    expect(classifyGestureHubPosition(_openDown), GestureHubPosition.palmDown);
    expect(
      classifyGestureHubPosition(_openVertical),
      GestureHubPosition.palmVertical,
    );
    expect(classifyGestureHubPosition(_fistDown), GestureHubPosition.fistDown);
  });

  test('falls back to the nearest known position', () {
    expect(
      classifyGestureHubPosition(
        const AccelerometerReading(accX: -1200, accY: 6900, accZ: -300),
      ),
      GestureHubPosition.palmUp,
    );
  });

  test(
    'scroll control can be selected and selection is locked while active',
    () async {
      final fixture = _gestureHubFixture();
      addTearDown(fixture.dispose);

      final controller = fixture.container.read(
        gestureHubControllerProvider.notifier,
      );

      controller.selectControl(GestureHubControl.scroll);
      expect(
        fixture.container.read(gestureHubControllerProvider).selectedControl,
        GestureHubControl.scroll,
      );

      await controller.activate();
      controller.selectControl(GestureHubControl.volume);

      expect(
        fixture.container.read(gestureHubControllerProvider).selectedControl,
        GestureHubControl.scroll,
      );
    },
  );

  test(
    'mouse control can be selected and selection is locked while active',
    () async {
      final fixture = _gestureHubFixture();
      addTearDown(fixture.dispose);
      final controller = fixture.container.read(
        gestureHubControllerProvider.notifier,
      );

      controller.selectControl(GestureHubControl.mouse);
      expect(
        fixture.container.read(gestureHubControllerProvider).selectedControl,
        GestureHubControl.mouse,
      );

      await controller.activate();
      controller.selectControl(GestureHubControl.scroll);

      expect(
        fixture.container.read(gestureHubControllerProvider).selectedControl,
        GestureHubControl.mouse,
      );
    },
  );

  test('scroll control sends positive delta for palm up', () async {
    final fixture = _gestureHubFixture();
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.scroll);
    await controller.activate();
    await controller.onAccelerometerReading(_openUp);

    expect(fixture.scrollService.deltas, [120]);
    expect(fixture.container.read(gestureHubControllerProvider).status, 'Up');
  });

  test('scroll control sends negative delta for palm down', () async {
    final fixture = _gestureHubFixture();
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.scroll);
    await controller.activate();
    await controller.onAccelerometerReading(_openDown);

    expect(fixture.scrollService.deltas, [-120]);
    expect(fixture.container.read(gestureHubControllerProvider).status, 'Down');
  });

  test('scroll control does not scroll in neutral position', () async {
    final fixture = _gestureHubFixture();
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.scroll);
    await controller.activate();
    await controller.onAccelerometerReading(_openSide);

    expect(fixture.scrollService.deltas, isEmpty);
    expect(
      fixture.container.read(gestureHubControllerProvider).status,
      'Neutral',
    );
  });

  test('scroll control rate-limits repeated samples', () async {
    final fixture = _gestureHubFixture();
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.scroll);
    await controller.activate();
    await controller.onAccelerometerReading(_openUp);
    await controller.onAccelerometerReading(_openUp);

    expect(fixture.scrollService.deltas, [120]);
  });

  test('volume control changes relatively from side roll', () async {
    final fixture = _gestureHubFixture(adjustmentInterval: Duration.zero);
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.volume);
    fixture.volumeService.volume = 0.5;
    await controller.activate();
    await controller.onAccelerometerReading(_openUp);
    final afterUp = fixture.volumeService.volume;
    await controller.onAccelerometerReading(_openDown);

    expect(afterUp, greaterThan(0.5));
    expect(fixture.volumeService.volume, lessThan(afterUp));
  });

  test('volume neutral deadzone does not change volume', () async {
    final fixture = _gestureHubFixture(adjustmentInterval: Duration.zero);
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.volume);
    fixture.volumeService.volume = 0.5;
    await controller.activate();
    await controller.onAccelerometerReading(_openSide);

    expect(fixture.volumeService.volume, 0.5);
    expect(
      fixture.container.read(gestureHubControllerProvider).status,
      'Neutral',
    );
  });

  test('stronger volume roll creates larger steps', () {
    final lightUp = AccelerometerReading(
      accX: _openSide.accX,
      accY: 2000,
      accZ: 7200,
    );

    expect(
      volumeDeltaForGestureHubRoll(_openUp),
      greaterThan(volumeDeltaForGestureHubRoll(lightUp)),
    );
  });

  test(
    'vertical hold switches controls once until vertical is released',
    () async {
      final fixture = _gestureHubFixture(
        controlSwitchHold: Duration.zero,
        adjustmentInterval: Duration.zero,
      );
      addTearDown(fixture.dispose);
      final controller = fixture.container.read(
        gestureHubControllerProvider.notifier,
      );

      await controller.activate();
      await controller.onAccelerometerReading(_openVertical);
      await controller.onAccelerometerReading(_openVertical);

      expect(
        fixture.container.read(gestureHubControllerProvider).selectedControl,
        GestureHubControl.volume,
      );

      await controller.onAccelerometerReading(_openSide);
      await controller.onAccelerometerReading(_openVertical);

      expect(
        fixture.container.read(gestureHubControllerProvider).selectedControl,
        GestureHubControl.mouse,
      );

      await controller.onAccelerometerReading(_openSide);
      await controller.onAccelerometerReading(_openVertical);

      expect(
        fixture.container.read(gestureHubControllerProvider).selectedControl,
        GestureHubControl.scroll,
      );
    },
  );

  test('mouse palm side toggles axis once per hold', () async {
    final fixture = _gestureHubFixture(
      mouseAxisSwitchHold: Duration.zero,
      adjustmentInterval: Duration.zero,
    );
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.mouse);
    await controller.activate();
    await controller.onAccelerometerReading(_openSide);
    await controller.onAccelerometerReading(_openSide);

    expect(
      fixture.container.read(gestureHubControllerProvider).mouseAxis,
      GestureHubMouseAxis.horizontal,
    );

    await controller.onAccelerometerReading(_openUp);
    await controller.onAccelerometerReading(_openSide);

    expect(
      fixture.container.read(gestureHubControllerProvider).mouseAxis,
      GestureHubMouseAxis.vertical,
    );
  });

  test('mouse vertical axis moves up and down', () async {
    final fixture = _gestureHubFixture(adjustmentInterval: Duration.zero);
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.mouse);
    await controller.activate();
    await controller.onAccelerometerReading(_openUp);
    await controller.onAccelerometerReading(_openDown);

    expect(fixture.mouseService.moves, const [
      (dx: 0, dy: -80),
      (dx: 0, dy: 80),
    ]);
  });

  test('mouse horizontal axis maps palm up left and palm down right', () async {
    final fixture = _gestureHubFixture(
      adjustmentInterval: Duration.zero,
      mouseAxisSwitchHold: Duration.zero,
    );
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.mouse);
    await controller.activate();
    await controller.onAccelerometerReading(_openSide);
    await controller.onAccelerometerReading(_openUp);
    await controller.onAccelerometerReading(_openDown);

    expect(fixture.mouseService.moves, const [
      (dx: -80, dy: 0),
      (dx: 80, dy: 0),
    ]);
  });

  test(
    'mouse fist down clicks once per hold and ignores other controls',
    () async {
      final fixture = _gestureHubFixture(adjustmentInterval: Duration.zero);
      addTearDown(fixture.dispose);
      final controller = fixture.container.read(
        gestureHubControllerProvider.notifier,
      );

      controller.selectControl(GestureHubControl.mouse);
      await controller.activate();
      await controller.onAccelerometerReading(_fistDown);
      await controller.onAccelerometerReading(_fistDown);

      expect(fixture.mouseService.leftClicks, 1);

      await controller.deactivate();
      controller.selectControl(GestureHubControl.scroll);
      await controller.activate();
      await controller.onAccelerometerReading(_fistDown);

      expect(fixture.mouseService.leftClicks, 1);
      expect(fixture.scrollService.deltas, isEmpty);
    },
  );

  test('mouse control rate-limits repeated movement samples', () async {
    final fixture = _gestureHubFixture();
    addTearDown(fixture.dispose);
    final controller = fixture.container.read(
      gestureHubControllerProvider.notifier,
    );

    controller.selectControl(GestureHubControl.mouse);
    await controller.activate();
    await controller.onAccelerometerReading(_openUp);
    await controller.onAccelerometerReading(_openUp);

    expect(fixture.mouseService.moves, const [(dx: 0, dy: -80)]);
  });
}

const _openDown = AccelerometerReading(accX: 827, accY: -8528, accZ: -33);
const _openSide = AccelerometerReading(accX: -1155, accY: -705, accZ: 6889);
const _openUp = AccelerometerReading(accX: -1311, accY: 7430, accZ: -336);
const _openVertical = AccelerometerReading(
  accX: -8380,
  accY: -1466,
  accZ: -590,
);
const _fistDown = AccelerometerReading(accX: 7684, accY: -1073, accZ: 213);

_GestureHubFixture _gestureHubFixture({
  Duration adjustmentInterval = const Duration(seconds: 1),
  Duration controlSwitchHold = const Duration(milliseconds: 1200),
  Duration mouseAxisSwitchHold = const Duration(milliseconds: 900),
}) {
  final bleService = _FakeBleService();
  final scrollService = _FakeScrollService();
  final mouseService = _FakeMouseService();
  final volumeService = _FakeVolumeService();
  final container = ProviderContainer(
    overrides: [
      bleServiceProvider.overrideWithValue(bleService),
      openRingStorageProvider.overrideWithValue(_FakeStorage()),
      systemScrollServiceProvider.overrideWithValue(scrollService),
      systemMouseServiceProvider.overrideWithValue(mouseService),
      systemVolumeServiceProvider.overrideWithValue(volumeService),
      gestureHubControllerProvider.overrideWith(
        (ref) => GestureHubController(
          ref,
          ref.watch(systemVolumeServiceProvider),
          scrollService: ref.watch(systemScrollServiceProvider),
          mouseService: ref.watch(systemMouseServiceProvider),
          adjustmentInterval: adjustmentInterval,
          controlSwitchHold: controlSwitchHold,
          mouseAxisSwitchHold: mouseAxisSwitchHold,
        ),
      ),
    ],
  );

  return _GestureHubFixture(
    container: container,
    bleService: bleService,
    scrollService: scrollService,
    mouseService: mouseService,
    volumeService: volumeService,
  );
}

class _GestureHubFixture {
  const _GestureHubFixture({
    required this.container,
    required this.bleService,
    required this.scrollService,
    required this.mouseService,
    required this.volumeService,
  });

  final ProviderContainer container;
  final _FakeBleService bleService;
  final _FakeScrollService scrollService;
  final _FakeMouseService mouseService;
  final _FakeVolumeService volumeService;

  void dispose() {
    container.dispose();
    bleService.dispose();
  }
}

class _FakeScrollService extends SystemScrollService {
  final deltas = <int>[];

  @override
  Future<void> scrollVertical(int wheelDelta) async {
    deltas.add(wheelDelta);
  }
}

class _FakeMouseService extends SystemMouseService {
  final moves = <({int dx, int dy})>[];
  var leftClicks = 0;

  @override
  Future<void> moveRelative({required int dx, required int dy}) async {
    moves.add((dx: dx, dy: dy));
  }

  @override
  Future<void> leftClick() async {
    leftClicks++;
  }
}

class _FakeVolumeService extends SystemVolumeService {
  double volume = 0.5;

  @override
  Future<double> getVolume() async => volume;

  @override
  Future<double> setVolume(double volume) async {
    this.volume = volume.clamp(0.0, 1.0).toDouble();
    return this.volume;
  }
}

class _FakeBleService extends BleService {
  final _packetController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _scanController = StreamController<BleDevice>.broadcast();

  @override
  Stream<Uint8List> get packetStream => _packetController.stream;

  @override
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<BleDevice> get scanResults => _scanController.stream;

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> sendPacket(Uint8List packet) async {}

  @override
  void dispose() {
    _packetController.close();
    _statusController.close();
    _scanController.close();
    super.dispose();
  }
}

class _FakeStorage implements OpenRingStorage {
  @override
  Future<void> appendMotionSample({
    required int sessionId,
    required AccelerometerReading reading,
    DateTime? receivedAt,
  }) async {}

  @override
  Future<String?> getLastConnectedDeviceId() async => null;

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
  Future<HistoryDay?> loadHistoryDay({
    required DateTime day,
    String? deviceId,
  }) async => null;

  @override
  Future<MotionSessionRecording?> loadLatestMotionSession({
    required String deviceId,
  }) async => null;

  @override
  Future<List<MotionSessionRecording>> loadMotionSessions({
    required String deviceId,
  }) async => const [];

  @override
  Future<void> setLastConnectedDevice({
    required String deviceId,
    String? name,
    DateTime? connectedAt,
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

  @override
  Future<void> upsertDevice({
    required String deviceId,
    String? name,
    DateTime? seenAt,
  }) async {}
}
