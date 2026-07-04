import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/ble/ble_service.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/protocol/battery.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/hr_log.dart';
import 'package:openring_v1/src/protocol/packet.dart';
import 'package:openring_v1/src/protocol/steps.dart';
import 'package:openring_v1/src/storage/history_models.dart';
import 'package:openring_v1/src/storage/motion_models.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';
import 'package:openring_v1/src/ui/scan_page_controller.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stop without further samples marks accelerometer as stopped', () async {
    final service = _FakeBleService();
    final notifier = ScanPageNotifier(
      service,
      _FakeStorage(),
      () {},
      accelStopVerificationDelay: const Duration(milliseconds: 20),
    );
    addTearDown(notifier.dispose);
    addTearDown(service.dispose);

    await notifier.toggleAccelerometer();
    await notifier.toggleAccelerometer();

    expect(notifier.state.accelStopping, isTrue);
    expect(notifier.state.lastAccelCommand, 'stop');
    expect(notifier.state.accelStopCleanupSent, isTrue);
    expect(service.sentPackets.where(_isAccelerometerStopPacket), hasLength(1));
    expect(service.sentPackets.where(_isRealTimeStopPacket), hasLength(3));
    expect(
      service.sentPackets.map(_packetKey).toList(),
      containsAllInOrder(['a1:02', '6a:01', '6a:03', '6a:0a']),
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(notifier.state.accelRunning, isFalse);
    expect(notifier.state.accelStopping, isFalse);
    expect(notifier.state.accelStopWarning, isNull);
    expect(service.sentPackets.any(_isAccelerometerStopPacket), isTrue);
  });

  test(
    'stop skips optical cleanup while a real-time measurement is active',
    () async {
      final service = _FakeBleService();
      final notifier = ScanPageNotifier(
        service,
        _FakeStorage(),
        () {},
        accelStopVerificationDelay: const Duration(milliseconds: 20),
      );
      addTearDown(notifier.dispose);
      addTearDown(service.dispose);

      await notifier.toggleRealTime(ReadingType.heartRate);
      await notifier.toggleAccelerometer();
      service.sentPackets.clear();
      await notifier.toggleAccelerometer();

      expect(notifier.state.accelStopCleanupSent, isFalse);
      expect(
        service.sentPackets.where(_isAccelerometerStopPacket),
        hasLength(1),
      );
      expect(service.sentPackets.where(_isRealTimeStopPacket), isEmpty);
    },
  );

  test(
    'samples after stop keep accelerometer running and show warning',
    () async {
      final service = _FakeBleService();
      final notifier = ScanPageNotifier(
        service,
        _FakeStorage(),
        () {},
        accelStopVerificationDelay: const Duration(milliseconds: 30),
      );
      addTearDown(notifier.dispose);
      addTearDown(service.dispose);

      await notifier.connect('ring-1');
      await notifier.toggleAccelerometer();
      await notifier.toggleAccelerometer();

      service.addPacket(
        makePacket(cmdRawSensor, [0x03, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00]),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.accelRunning, isTrue);
      expect(notifier.state.accelStopping, isFalse);
      expect(
        notifier.state.accelStopWarning,
        'Stop sent, ring keeps streaming',
      );
    },
  );

  test('stop send failure is surfaced as an error', () async {
    final service = _FakeBleService()..failAccelerometerStop = true;
    final notifier = ScanPageNotifier(
      service,
      _FakeStorage(),
      () {},
      accelStopVerificationDelay: const Duration(milliseconds: 20),
    );
    addTearDown(notifier.dispose);
    addTearDown(service.dispose);

    await notifier.toggleAccelerometer();
    await notifier.toggleAccelerometer();

    expect(notifier.state.accelStopping, isFalse);
    expect(notifier.state.accelRunning, isTrue);
    expect(notifier.state.error, startsWith('Accelerometer stop failed:'));
    expect(service.sentPackets.where(_isRealTimeStopPacket), isEmpty);
  });

  test(
    'optical cleanup failure is surfaced but stop verification continues',
    () async {
      final service = _FakeBleService()..failRealTimeStop = true;
      final notifier = ScanPageNotifier(
        service,
        _FakeStorage(),
        () {},
        accelStopVerificationDelay: const Duration(milliseconds: 20),
      );
      addTearDown(notifier.dispose);
      addTearDown(service.dispose);

      await notifier.toggleAccelerometer();
      await notifier.toggleAccelerometer();

      expect(notifier.state.accelStopping, isTrue);
      expect(notifier.state.accelStopCleanupSent, isFalse);
      expect(notifier.state.error, startsWith('Visual stop sequence failed:'));

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(notifier.state.accelRunning, isFalse);
      expect(notifier.state.accelStopping, isFalse);
    },
  );
}

bool _isAccelerometerStopPacket(Uint8List packet) {
  return packet.length == packetLength &&
      packet[0] == cmdRawSensor &&
      packet[1] == 0x02;
}

bool _isRealTimeStopPacket(Uint8List packet) {
  return packet.length == packetLength && packet[0] == Cmd.stopRealTime;
}

String _packetKey(Uint8List packet) {
  return '${packet[0].toRadixString(16).padLeft(2, '0')}:'
      '${packet[1].toRadixString(16).padLeft(2, '0')}';
}

class _FakeBleService extends BleService {
  final _packetController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _scanController = StreamController<BleDevice>.broadcast();
  final sentPackets = <Uint8List>[];
  bool failAccelerometerStop = false;
  bool failRealTimeStop = false;

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
  Future<void> sendPacket(Uint8List packet) async {
    sentPackets.add(packet);
    if (failAccelerometerStop && _isAccelerometerStopPacket(packet)) {
      throw StateError('stop failed');
    }
    if (failRealTimeStop && _isRealTimeStopPacket(packet)) {
      throw StateError('optical stop failed');
    }
  }

  void addPacket(Uint8List packet) {
    _packetController.add(packet);
  }

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
