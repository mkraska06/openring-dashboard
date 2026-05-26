import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../protocol/commands.dart';
import '../ui/scan_page_controller.dart';
import 'overlay_controller.dart';
import 'overlay_state.dart';

class OverlayWidget extends ConsumerWidget {
  const OverlayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(overlaySettingsProvider);
    final pageState = ref.watch(scanPageProvider);
    final bleStatus =
        ref.watch(bleStatusProvider).valueOrNull ??
        BleConnectionStatus.disconnected;
    final controller = ref.read(overlayControllerProvider);

    final hrReading = pageState.realTimeReadings[ReadingType.heartRate];
    final spo2Reading = pageState.realTimeReadings[ReadingType.spo2];
    final battery = pageState.battery;
    final steps = pageState.steps;
    final dailyActivity = pageState.dailyActivity;
    final totalSteps =
        dailyActivity?.steps ?? steps?.fold<int>(0, (sum, e) => sum + e.steps);

    final isConnected = bleStatus == BleConnectionStatus.connected;

    return Scaffold(
      backgroundColor: const Color(0x661E1E1E),
      body: GestureDetector(
        onPanStart: settings.isInteractive
            ? (_) => controller.startDrag()
            : null,
        child: Container(
          decoration: BoxDecoration(
            border: settings.isInteractive
                ? Border.all(color: Colors.amber, width: 2)
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status bar
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'OpenRing',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (settings.isInteractive) ...[
                    const Spacer(),
                    Text(
                      'Drag',
                      style: TextStyle(
                        color: Colors.amber.withValues(alpha: 0.8),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // Heart Rate
              if (settings.showHr)
                _VitalRow(
                  icon: Icons.favorite,
                  iconColor: Colors.red,
                  value: hrReading != null && hrReading.hasValue
                      ? '${hrReading.value}'
                      : '--',
                  unit: 'BPM',
                  valueColor:
                      hrReading != null &&
                          hrReading.hasValue &&
                          hrReading.value > settings.hrHighThreshold
                      ? Colors.red
                      : Colors.white,
                ),

              // SpO2
              if (settings.showSpo2)
                _VitalRow(
                  icon: Icons.air,
                  iconColor: Colors.lightBlue,
                  value: spo2Reading != null && spo2Reading.hasValue
                      ? '${spo2Reading.value}'
                      : '--',
                  unit: '%',
                  valueColor:
                      spo2Reading != null &&
                          spo2Reading.hasValue &&
                          spo2Reading.value < settings.spo2LowThreshold
                      ? Colors.red
                      : Colors.white,
                ),

              // Battery
              if (settings.showBattery)
                _VitalRow(
                  icon: battery != null && battery.isCharging
                      ? Icons.battery_charging_full
                      : Icons.battery_full,
                  iconColor: Colors.greenAccent,
                  value: battery != null ? '${battery.level}' : '--',
                  unit: '%',
                  valueColor: Colors.white,
                ),

              // Steps
              if (settings.showSteps)
                _VitalRow(
                  icon: Icons.directions_walk,
                  iconColor: Colors.orangeAccent,
                  value: totalSteps != null ? '$totalSteps' : '--',
                  unit: '',
                  valueColor: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  const _VitalRow({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            unit,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
