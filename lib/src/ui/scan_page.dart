import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift_db_viewer/drift_db_viewer.dart';
import '../ble/ble_service.dart';
import '../gesture_hub/gesture_hub_controller.dart';
import '../gesture_hub/gesture_hub_widgets.dart';
import '../history/history_page.dart';
import '../history/history_page_controller.dart';
import '../overlay/overlay_controller.dart';
import '../protocol/commands.dart';
import 'scan_page_controller.dart';
import 'scan_page_widgets.dart';
import '../storage/app_database.dart';

enum _MainSection { dashboard, gestures, history, advanced }

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  _MainSection _section = _MainSection.dashboard;

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(scanPageProvider);
    final bleStatus =
        ref.watch(bleStatusProvider).valueOrNull ??
        BleConnectionStatus.disconnected;
    final notifier = ref.read(scanPageProvider.notifier);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScanPageTitleBar(
            bleStatus: bleStatus,
            onOverlay: () =>
                ref.read(overlayControllerProvider).activateOverlay(),
          ),
          if (pageState.error != null)
            MaterialBanner(
              content: Text(pageState.error!),
              actions: [
                TextButton(
                  onPressed: notifier.clearError,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NavigationRail(
                  selectedIndex: _section.index,
                  onDestinationSelected: (index) {
                    final nextSection = _MainSection.values[index];
                    setState(() => _section = nextSection);
                    if (nextSection == _MainSection.history) {
                      ref.read(historyPageProvider.notifier).load();
                    }
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.monitor_heart_outlined),
                      selectedIcon: Icon(Icons.monitor_heart),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.gesture_outlined),
                      selectedIcon: Icon(Icons.gesture),
                      label: Text('Gestures'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune_outlined),
                      selectedIcon: Icon(Icons.tune),
                      label: Text('Advanced'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: switch (_section) {
                    _MainSection.dashboard => _DashboardView(
                      pageState: pageState,
                      bleStatus: bleStatus,
                      notifier: notifier,
                    ),
                    _MainSection.gestures =>
                      bleStatus == BleConnectionStatus.connected
                          ? _GestureHubView(pageState: pageState)
                          : const _ConnectRingHint(),
                    _MainSection.history => const HistoryPage(),
                    _MainSection.advanced =>
                      bleStatus == BleConnectionStatus.connected
                          ? _AdvancedView(
                              pageState: pageState,
                              notifier: notifier,
                            )
                          : const _ConnectRingHint(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectRingHint extends StatelessWidget {
  const _ConnectRingHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 42,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Connect a ring first', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Dashboard scanning is available while no ring is connected.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView({
    required this.pageState,
    required this.bleStatus,
    required this.notifier,
  });

  final ScanPageState pageState;
  final BleConnectionStatus bleStatus;
  final ScanPageNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ScanControlRow(
            status: bleStatus,
            onScan: notifier.startScan,
            onDisconnect: notifier.disconnect,
          ),
        ),
        if (bleStatus != BleConnectionStatus.connected &&
            bleStatus != BleConnectionStatus.connecting) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Found rings:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: pageState.foundDevices.isEmpty
                ? const Center(child: Text('No rings found yet.'))
                : ListView(
                    children: pageState.foundDevices.values
                        .map(
                          (device) => DeviceTile(
                            device: device,
                            onTap: () => notifier.connect(device.deviceId),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
        if (bleStatus == BleConnectionStatus.connected)
          Expanded(
            child: _ConnectedSectionShell(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  BatteryCard(battery: pageState.battery),
                  DailyMeasurementButton(
                    isRunning: pageState.dailyMeasurementRunning,
                    onToggle: notifier.toggleDailyMeasurement,
                  ),
                  for (final type in ReadingType.supported)
                    RealTimeCard(
                      readingType: type,
                      reading: pageState.realTimeReadings[type],
                      isRunning: pageState.runningMeasurements.contains(type),
                      onToggle: pageState.dailyMeasurementRunning
                          ? null
                          : () => notifier.toggleRealTime(type),
                    ),
                  StepsCard(
                    steps: pageState.steps,
                    dailyActivity: pageState.dailyActivity,
                    isLoading: pageState.stepsLoading,
                    onRequest: notifier.requestSteps,
                  ),
                  HrLogCard(
                    hrLog: pageState.hrLog,
                    isLoading: pageState.hrLogLoading,
                    onRequest: notifier.requestHrLog,
                  ),
                ],
              ),
            ),
          ),
        if (bleStatus == BleConnectionStatus.connecting)
          const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

class _GestureHubView extends ConsumerWidget {
  const _GestureHubView({required this.pageState});

  final ScanPageState pageState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestureHubState = ref.watch(gestureHubControllerProvider);
    final gestureHubController = ref.read(
      gestureHubControllerProvider.notifier,
    );

    return _ConnectedSectionShell(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          GestureHubCard(
            state: gestureHubState,
            sensorRunning: pageState.accelRunning,
            sensorStopping: pageState.accelStopping,
            onControlSelected: gestureHubController.selectControl,
            onToggle: gestureHubController.toggle,
          ),
        ],
      ),
    );
  }
}

class _AdvancedView extends ConsumerWidget {
  const _AdvancedView({required this.pageState, required this.notifier});

  final ScanPageState pageState;
  final ScanPageNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ConnectedSectionShell(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          AccelerometerCard(
            reading: pageState.lastAccel,
            isRunning: pageState.accelRunning,
            isStopping: pageState.accelStopping,
            lastCommand: pageState.lastAccelCommand,
            lastSampleAt: pageState.lastAccelReceivedAt,
            stopCleanupSent: pageState.accelStopCleanupSent,
            stopWarning: pageState.accelStopWarning,
            onToggle: notifier.toggleAccelerometer,
          ),
          MotionLabCard(
            sessionName: pageState.motionSessionName,
            recording: pageState.motionRecording,
            recordings: pageState.motionRecordings,
            isRecording: pageState.motionRecordingActive,
            canRecord: pageState.accelRunning,
            onNameChanged: notifier.setMotionSessionName,
            onPresetSelected: notifier.setMotionGesturePreset,
            onRecord: notifier.startMotionRecording,
            onStop: notifier.stopMotionRecording,
          ),
          HrLogSettingsCard(
            settings: pageState.hrLogSettings,
            onQuery: notifier.queryHrLogSettings,
            onSet: notifier.setHrLogSettings,
          ),
          if (kDebugMode) ...[
            ListTile(
              leading: const Icon(Icons.storage, color: Colors.indigo),
              title: const Text('Inspect SQLite database'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final db = ref.read(databaseProvider);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => DriftDbViewer(db)),
                );
              },
            ),
            const Divider(indent: 12, endIndent: 12),
          ],
          UtilityCard(
            onSyncTime: notifier.syncTime,
            onBlink: notifier.blinkTwice,
            onReboot: notifier.reboot,
          ),
        ],
      ),
    );
  }
}

class _ConnectedSectionShell extends ConsumerWidget {
  const _ConnectedSectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(scanPageProvider.select((state) => state.lastAccel), (_, next) {
      if (next != null) {
        ref
            .read(gestureHubControllerProvider.notifier)
            .onAccelerometerReading(next);
      }
    });

    final gestureHubState = ref.watch(gestureHubControllerProvider);
    return Stack(
      children: [
        child,
        if (gestureHubState.isActive) GestureHubOverlay(state: gestureHubState),
      ],
    );
  }
}
