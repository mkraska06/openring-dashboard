import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/ble/ble_service.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/protocol/battery.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/hr_log.dart';
import 'package:openring_v1/src/protocol/steps.dart';
import 'package:openring_v1/src/storage/history_models.dart';
import 'package:openring_v1/src/storage/motion_models.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';
import 'package:openring_v1/src/protocol/real_time.dart';
import 'package:openring_v1/src/ui/scan_page_controller.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mergeRealTimeReadingForDisplay', () {
    test(
      'keeps the last valid heart-rate reading when a pending packet arrives',
      () {
        const validHeartRate = RealTimeReading(
          type: ReadingType.heartRate,
          value: 72,
          errorCode: 0,
        );
        const pendingHeartRate = RealTimeReading(
          type: ReadingType.heartRate,
          value: 0,
          errorCode: 0,
        );

        final readings = mergeRealTimeReadingForDisplay({
          ReadingType.heartRate: validHeartRate,
        }, pendingHeartRate);

        expect(readings[ReadingType.heartRate], same(validHeartRate));
      },
    );

    test('stores the first pending reading when no valid value exists yet', () {
      const pendingSpo2 = RealTimeReading(
        type: ReadingType.spo2,
        value: 0,
        errorCode: 0,
      );

      final readings = mergeRealTimeReadingForDisplay(const {}, pendingSpo2);

      expect(readings[ReadingType.spo2], same(pendingSpo2));
    });

    test('replaces an older valid reading with a newer valid reading', () {
      const previousHeartRate = RealTimeReading(
        type: ReadingType.heartRate,
        value: 72,
        errorCode: 0,
      );
      const nextHeartRate = RealTimeReading(
        type: ReadingType.heartRate,
        value: 75,
        errorCode: 0,
      );

      final readings = mergeRealTimeReadingForDisplay({
        ReadingType.heartRate: previousHeartRate,
      }, nextHeartRate);

      expect(readings[ReadingType.heartRate], same(nextHeartRate));
    });
  });

  group('connection lifecycle', () {
    test('autoConnectToSavedRing connects the stored device', () async {
      final service = _FakeBleService();
      final storage = _FakeStorage(lastConnectedDeviceId: 'ring-1');
      final notifier = ScanPageNotifier(
        service,
        storage,
        () {},
        autoConnectOnStartup: false,
      );
      addTearDown(notifier.dispose);
      addTearDown(service.dispose);

      await notifier.autoConnectToSavedRing();

      expect(service.connectCalls, ['ring-1']);
      expect(storage.setLastConnectedCalls, isEmpty);
      expect(service.sentPackets.any(_isBatteryRequest), isTrue);
    });

    test('unexpected disconnect reconnects to the last ring', () async {
      final service = _FakeBleService();
      final storage = _FakeStorage();
      final notifier = ScanPageNotifier(
        service,
        storage,
        () {},
        reconnectDelay: const Duration(milliseconds: 10),
        autoConnectOnStartup: false,
      );
      addTearDown(notifier.dispose);
      addTearDown(service.dispose);

      await notifier.connect('ring-1');
      service.emitStatus(BleConnectionStatus.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(service.connectCalls, ['ring-1', 'ring-1']);
      expect(notifier.state.error, isNull);
    });

    test('manual disconnect does not schedule reconnect', () async {
      final service = _FakeBleService();
      final storage = _FakeStorage();
      final notifier = ScanPageNotifier(
        service,
        storage,
        () {},
        reconnectDelay: const Duration(milliseconds: 10),
        autoConnectOnStartup: false,
      );
      addTearDown(notifier.dispose);
      addTearDown(service.dispose);

      await notifier.connect('ring-1');
      await notifier.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(service.disconnectCalls, 1);
      expect(service.connectCalls, ['ring-1']);
    });
  });
}

bool _isBatteryRequest(Uint8List packet) {
  return packet.isNotEmpty && packet[0] == Cmd.battery;
}

class _FakeBleService extends BleService {
  final _packetController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _scanController = StreamController<BleDevice>.broadcast();
  final connectCalls = <String>[];
  final sentPackets = <Uint8List>[];
  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  int disconnectCalls = 0;

  @override
  BleConnectionStatus get status => _status;

  @override
  Stream<Uint8List> get packetStream => _packetController.stream;

  @override
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<BleDevice> get scanResults => _scanController.stream;

  @override
  Future<void> connect(String deviceId) async {
    connectCalls.add(deviceId);
    _status = BleConnectionStatus.connected;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    emitStatus(BleConnectionStatus.disconnected);
  }

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> sendPacket(Uint8List packet) async {
    sentPackets.add(packet);
  }

  void emitStatus(BleConnectionStatus status) {
    _status = status;
    _statusController.add(status);
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
  _FakeStorage({this.lastConnectedDeviceId});

  final String? lastConnectedDeviceId;
  final setLastConnectedCalls = <String>[];

  @override
  Future<void> appendMotionSample({
    required int sessionId,
    required AccelerometerReading reading,
    DateTime? receivedAt,
  }) async {}

  @override
  Future<String?> getLastConnectedDeviceId() async => lastConnectedDeviceId;

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
  }) async {
    setLastConnectedCalls.add(deviceId);
  }

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
