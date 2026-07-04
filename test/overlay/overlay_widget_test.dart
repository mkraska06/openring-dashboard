import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/ble/ble_service.dart';
import 'package:openring_v1/src/overlay/overlay_state.dart';
import 'package:openring_v1/src/overlay/overlay_widget.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/protocol/activity.dart';
import 'package:openring_v1/src/protocol/battery.dart';
import 'package:openring_v1/src/protocol/commands.dart';
import 'package:openring_v1/src/protocol/hr_log.dart';
import 'package:openring_v1/src/protocol/real_time.dart';
import 'package:openring_v1/src/protocol/steps.dart';
import 'package:openring_v1/src/storage/history_models.dart';
import 'package:openring_v1/src/storage/motion_models.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';
import 'package:openring_v1/src/ui/scan_page_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OverlayWidget renders values and threshold colors', (
    tester,
  ) async {
    final notifier = _StaticScanPageNotifier(
      const ScanPageState(
        battery: BatteryResponse(level: 85, isCharging: true),
        realTimeReadings: {
          ReadingType.heartRate: RealTimeReading(
            type: ReadingType.heartRate,
            value: 130,
            errorCode: 0,
          ),
          ReadingType.spo2: RealTimeReading(
            type: ReadingType.spo2,
            value: 94,
            errorCode: 0,
          ),
        },
        dailyActivity: DailyActivitySnapshot(
          steps: 1234,
          calories: 0,
          distanceMeters: 100,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanPageProvider.overrideWith((ref) => notifier),
          bleStatusProvider.overrideWith(
            (ref) => Stream.value(BleConnectionStatus.connected),
          ),
        ],
        child: const MaterialApp(home: OverlayWidget()),
      ),
    );
    await tester.pump();

    expect(find.text('OpenRing'), findsOneWidget);
    expect(find.text('130'), findsOneWidget);
    expect(find.text('94'), findsOneWidget);
    expect(find.text('85'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(tester.widget<Text>(find.text('130')).style?.color, Colors.red);
    expect(tester.widget<Text>(find.text('94')).style?.color, Colors.red);
  });

  testWidgets('OverlayWidget respects visibility preferences', (tester) async {
    SharedPreferences.setMockInitialValues({
      'overlay_show_hr': false,
      'overlay_show_spo2': true,
      'overlay_show_battery': false,
      'overlay_show_steps': false,
    });
    final notifier = _StaticScanPageNotifier(
      const ScanPageState(
        battery: BatteryResponse(level: 85, isCharging: false),
        realTimeReadings: {
          ReadingType.heartRate: RealTimeReading(
            type: ReadingType.heartRate,
            value: 72,
            errorCode: 0,
          ),
          ReadingType.spo2: RealTimeReading(
            type: ReadingType.spo2,
            value: 98,
            errorCode: 0,
          ),
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanPageProvider.overrideWith((ref) => notifier),
          bleStatusProvider.overrideWith(
            (ref) => Stream.value(BleConnectionStatus.connected),
          ),
        ],
        child: const MaterialApp(home: OverlayWidget()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('72'), findsNothing);
    expect(find.text('98'), findsOneWidget);
    expect(find.text('85'), findsNothing);
  });

  test('OverlaySettingsNotifier persists settings', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = OverlaySettingsNotifier();
    await Future<void>.delayed(Duration.zero);

    notifier.updatePosition(const Offset(12, 34));
    notifier.setOpacity(0.4);
    notifier.setShowHr(false);
    notifier.setShowSpo2(false);
    notifier.setShowBattery(false);
    notifier.setShowSteps(false);
    notifier.setHrThreshold(111);
    notifier.setSpo2Threshold(93);
    await Future<void>.delayed(Duration.zero);

    final reloaded = OverlaySettingsNotifier();
    await Future<void>.delayed(Duration.zero);

    expect(reloaded.state.position, const Offset(12, 34));
    expect(reloaded.state.showHr, isFalse);
    expect(reloaded.state.showSpo2, isFalse);
    expect(reloaded.state.showBattery, isFalse);
    expect(reloaded.state.showSteps, isFalse);
    expect(reloaded.state.hrHighThreshold, 111);
    expect(reloaded.state.spo2LowThreshold, 93);
  });
}

class _StaticScanPageNotifier extends ScanPageNotifier {
  factory _StaticScanPageNotifier(ScanPageState initialState) {
    return _StaticScanPageNotifier._(_FakeBleService(), initialState);
  }

  _StaticScanPageNotifier._(this._service, ScanPageState initialState)
    : super(_service, _FakeStorage(), () {}, autoConnectOnStartup: false) {
    state = initialState;
  }

  final _FakeBleService _service;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

class _FakeBleService extends BleService {
  final _packetController = StreamController<Uint8List>.broadcast();
  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _scanController = StreamController<BleDevice>.broadcast();
  BleConnectionStatus _status = BleConnectionStatus.disconnected;

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
    _status = BleConnectionStatus.connected;
  }

  @override
  Future<void> disconnect() async {
    _status = BleConnectionStatus.disconnected;
    _statusController.add(BleConnectionStatus.disconnected);
  }

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
