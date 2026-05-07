import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift_db_viewer/drift_db_viewer.dart';
import '../ble/ble_service.dart';
import '../history/history_page.dart';
import '../history/history_page_controller.dart';
import '../overlay/overlay_controller.dart';
import '../protocol/commands.dart';
import 'scan_page_controller.dart';
import 'scan_page_widgets.dart';
import '../storage/app_database.dart';

enum _MainSection { dashboard, history }

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
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: Text('History'),
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
                    _MainSection.history => const HistoryPage(),
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
                AccelerometerCard(
                  reading: pageState.lastAccel,
                  isRunning: pageState.accelRunning,
                  onToggle: notifier.toggleAccelerometer,
                ),
                const Divider(indent: 12, endIndent: 12),
                HrLogCard(
                  hrLog: pageState.hrLog,
                  isLoading: pageState.hrLogLoading,
                  onRequest: notifier.requestHrLog,
                ),
                StepsCard(
                  steps: pageState.steps,
                  isLoading: pageState.stepsLoading,
                  onRequest: notifier.requestSteps,
                ),
                HrLogSettingsCard(
                  settings: pageState.hrLogSettings,
                  onQuery: notifier.queryHrLogSettings,
                  onSet: notifier.setHrLogSettings,
                ),
                // DER NEUE BUTTON:
                ListTile(
                  leading: const Icon(Icons.storage, color: Colors.indigo),
                  title: const Text('SQLite Datenbank einsehen'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Hier greifen wir auf den eben erstellten Provider zu
                    final db = ref.read(databaseProvider);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DriftDbViewer(db),
                      ),
                    );
                  },
                ),
                const Divider(indent: 12, endIndent: 12),
                UtilityCard(
                  onSyncTime: notifier.syncTime,
                  onBlink: notifier.blinkTwice,
                  onReboot: notifier.reboot,
                ),
                SizedBox(
                  height: 250,
                  child: DebugLogPanel(lines: pageState.debugLog),
                ),
              ],
            ),
          ),
        if (bleStatus == BleConnectionStatus.connecting)
          const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}
