import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openring_v1/main.dart';
import 'package:openring_v1/src/gesture_hub/gesture_hub_controller.dart';
import 'package:openring_v1/src/gesture_hub/gesture_hub_widgets.dart';
import 'package:openring_v1/src/protocol/accelerometer.dart';
import 'package:openring_v1/src/storage/app_database.dart';
import 'package:openring_v1/src/storage/motion_models.dart';
import 'package:openring_v1/src/storage/storage_repository.dart';
import 'package:openring_v1/src/ui/scan_page_widgets.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const OpenRingApp(),
      ),
    );
    expect(find.text('OpenRing'), findsOneWidget);
  });

  testWidgets('App can switch to empty History view', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const OpenRingApp(),
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No ring saved yet'), findsOneWidget);
  });

  testWidgets('History renders sample HR chart controls and unit axis', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final storage = DriftOpenRingStorage(db);
    await storage.setLastConnectedDevice(deviceId: 'ring-1');
    await storage.insertVitalSample(
      deviceId: 'ring-1',
      kind: vitalKindHeartRate,
      value: 72,
      unit: 'BPM',
      measuredAt: DateTime.now().subtract(const Duration(minutes: 5)),
      source: sampleSourceLive,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const OpenRingApp(),
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump();

    expect(find.text('BPM'), findsWidgets);
    expect(find.text('1m'), findsWidgets);
    expect(find.text('5m'), findsWidgets);
    expect(find.text('10m'), findsWidgets);
    expect(find.text('30m'), findsWidgets);
    expect(find.text('2h'), findsWidgets);
    expect(find.text('Day'), findsWidgets);
  });

  testWidgets('Motion lab renders recording controls and empty plot state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MotionLabCard(
              sessionName: 'Motion Test',
              recording: null,
              recordings: const [],
              isRecording: false,
              canRecord: true,
              onNameChanged: (_) {},
              onPresetSelected: (_) {},
              onRecord: () async {},
              onStop: () async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Motion Lab'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('No motion samples yet.'), findsOneWidget);
  });

  testWidgets('Accelerometer card renders button states and diagnostics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccelerometerCard(
            reading: null,
            isRunning: false,
            isStopping: false,
            onToggle: () {},
          ),
        ),
      ),
    );

    expect(find.text('Start sensor'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccelerometerCard(
            reading: const AccelerometerReading(
              accX: 7817,
              accY: -526,
              accZ: -1205,
            ),
            isRunning: true,
            isStopping: false,
            lastCommand: 'start',
            lastSampleAt: DateTime.now(),
            onToggle: () {},
          ),
        ),
      ),
    );

    expect(find.text('Stop sensor'), findsOneWidget);
    expect(find.textContaining('last command: start'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccelerometerCard(
            reading: const AccelerometerReading(
              accX: 7817,
              accY: -526,
              accZ: -1205,
            ),
            isRunning: true,
            isStopping: true,
            lastCommand: 'stop',
            stopCleanupSent: true,
            stopWarning: 'Stop sent, ring keeps streaming',
            onToggle: () {},
          ),
        ),
      ),
    );

    expect(find.text('Stopping...'), findsOneWidget);
    expect(find.textContaining('visual stop sequence sent'), findsOneWidget);
    expect(find.text('Stop sent, ring keeps streaming'), findsOneWidget);
  });

  testWidgets('Gesture Hub card renders volume and scroll control states', (
    WidgetTester tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureHubCard(
            state: const GestureHubState(),
            sensorRunning: false,
            sensorStopping: false,
            onControlSelected: (_) {},
            onToggle: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.text('Gesture Hub'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Scroll'), findsOneWidget);
    expect(find.text('Mouse'), findsOneWidget);
    expect(find.text('Inactive'), findsWidgets);
    expect(find.text('Activate'), findsOneWidget);

    await tester.tap(find.text('Activate'));
    expect(toggled, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureHubCard(
            state: const GestureHubState(
              selectedControl: GestureHubControl.volume,
              isActive: true,
              status: 'Waiting for gesture',
              volume: 0.42,
            ),
            sensorRunning: true,
            sensorStopping: false,
            onControlSelected: (_) {},
            onToggle: () {},
          ),
        ),
      ),
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Sensor active'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('Gesture Hub overlay renders scroll labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GestureHubOverlay(
            state: GestureHubState(
              selectedControl: GestureHubControl.scroll,
              isActive: true,
              position: GestureHubPosition.palmDown,
              status: 'Down',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gesture Hub'), findsOneWidget);
    expect(find.text('Down'), findsWidgets);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Up'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('--%'), findsNothing);
  });

  testWidgets('Gesture Hub overlay highlights selected palm position', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GestureHubOverlay(
            state: GestureHubState(
              selectedControl: GestureHubControl.volume,
              isActive: true,
              position: GestureHubPosition.palmUp,
              volume: 0.8,
              volumeIntensity: 'fast up',
              status: 'Up',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gesture Hub'), findsOneWidget);
    expect(find.text('Down'), findsOneWidget);
    expect(find.text('Neutral'), findsOneWidget);
    expect(find.text('Up'), findsWidgets);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('fast up'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('Gesture Hub overlay renders mouse axis and click hint', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GestureHubOverlay(
            state: GestureHubState(
              selectedControl: GestureHubControl.mouse,
              isActive: true,
              mouseAxis: GestureHubMouseAxis.horizontal,
              position: GestureHubPosition.palmDown,
              status: 'Mouse right',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gesture Hub'), findsOneWidget);
    expect(find.text('Horizontal'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Axis'), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Fist = click'), findsOneWidget);
  });

  testWidgets('Motion lab renders a chart for session samples', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MotionLabCard(
              sessionName: 'Ruhe',
              recording: MotionSessionRecording(
                session: MotionSessionSummary(
                  id: 7,
                  deviceId: 'ring-1',
                  name: 'Ruhe',
                  startedAt: DateTime(2026, 5, 22, 12),
                ),
                samples: [
                  MotionSamplePoint(
                    receivedAt: DateTime(2026, 5, 22, 12),
                    reading: const AccelerometerReading(
                      accX: 7817,
                      accY: -526,
                      accZ: -1205,
                    ),
                  ),
                  MotionSamplePoint(
                    receivedAt: DateTime(2026, 5, 22, 12, 0, 1),
                    reading: const AccelerometerReading(
                      accX: -360,
                      accY: -8515,
                      accZ: 322,
                    ),
                  ),
                ],
              ),
              recordings: const [],
              isRecording: false,
              canRecord: true,
              onNameChanged: (_) {},
              onPresetSelected: (_) {},
              onRecord: () async {},
              onStop: () async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Latest session | 2 Samples'), findsOneWidget);
    expect(find.text('|a|'), findsOneWidget);
    expect(find.text('Session analysis'), findsOneWidget);
    expect(find.text('No motion samples yet.'), findsNothing);
  });

  testWidgets('Motion lab renders gesture presets and applies selection', (
    WidgetTester tester,
  ) async {
    String? selectedName;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MotionLabCard(
              sessionName: 'Motion Test',
              recording: null,
              recordings: const [],
              isRecording: false,
              canRecord: true,
              onNameChanged: (value) => selectedName = value,
              onPresetSelected: (preset) => selectedName = preset.sessionPrefix,
              onRecord: () async {},
              onStop: () async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Palm up'), findsOneWidget);
    expect(find.text('Palm side'), findsOneWidget);
    expect(find.text('Palm down'), findsOneWidget);
    expect(find.text('Open down'), findsOneWidget);
    expect(find.text('Open side'), findsOneWidget);
    expect(find.text('Open up'), findsOneWidget);
    expect(find.text('Open vertical'), findsOneWidget);
    expect(find.text('Fist down'), findsOneWidget);
    expect(find.text('Fist side'), findsOneWidget);
    expect(find.text('Fist up'), findsOneWidget);
    expect(find.text('Fist vertical'), findsOneWidget);
    expect(find.text('Double tap'), findsOneWidget);

    await tester.tap(find.text('Fist vertical'));
    await tester.pump();

    expect(selectedName, 'gesture_fist_vertical');
  });

  testWidgets('Motion lab renders gesture space analysis groups', (
    WidgetTester tester,
  ) async {
    final start = DateTime(2026, 6, 9, 12);

    MotionSessionRecording recording(
      String name,
      List<AccelerometerReading> readings,
    ) {
      return MotionSessionRecording(
        session: MotionSessionSummary(
          id: name.hashCode,
          deviceId: 'ring-1',
          name: name,
          startedAt: start,
          endedAt: start.add(Duration(seconds: readings.length - 1)),
        ),
        samples: [
          for (var i = 0; i < readings.length; i++)
            MotionSamplePoint(
              receivedAt: start.add(Duration(seconds: i)),
              reading: readings[i],
            ),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MotionLabCard(
              sessionName: 'Motion Test',
              recording: null,
              recordings: [
                recording('gesture_open_side', const [
                  AccelerometerReading(accX: 0, accY: 0, accZ: 8192),
                  AccelerometerReading(accX: 20, accY: 0, accZ: 8100),
                  AccelerometerReading(accX: -20, accY: 10, accZ: 8200),
                  AccelerometerReading(accX: 10, accY: -10, accZ: 8180),
                  AccelerometerReading(accX: 0, accY: 20, accZ: 8150),
                ]),
                recording('gesture_fist_side', const [
                  AccelerometerReading(accX: 4096, accY: 0, accZ: 7000),
                  AccelerometerReading(accX: 4050, accY: 20, accZ: 7050),
                  AccelerometerReading(accX: 4100, accY: -20, accZ: 6980),
                  AccelerometerReading(accX: 4070, accY: 10, accZ: 7020),
                  AccelerometerReading(accX: 4120, accY: 0, accZ: 7010),
                ]),
              ],
              isRecording: false,
              canRecord: true,
              onNameChanged: (_) {},
              onPresetSelected: (_) {},
              onRecord: () async {},
              onStop: () async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gesture-Space'), findsOneWidget);
    expect(find.textContaining('open side'), findsWidgets);
    expect(find.textContaining('fist side'), findsWidgets);
    expect(find.textContaining('clear'), findsWidgets);
  });
}
