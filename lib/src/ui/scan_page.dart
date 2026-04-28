import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../overlay/overlay_controller.dart';
import '../protocol/commands.dart';
import 'scan_page_controller.dart';
import 'scan_page_widgets.dart';

class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  for (final type in ReadingType.supported)
                    RealTimeCard(
                      readingType: type,
                      reading: pageState.realTimeReadings[type],
                      isRunning: pageState.runningMeasurements.contains(type),
                      onToggle: () => notifier.toggleRealTime(type),
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
      ),
    );
  }
}
