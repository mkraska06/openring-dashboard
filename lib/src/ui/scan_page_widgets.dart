import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;
import 'package:window_manager/window_manager.dart';

import '../ble/ble_service.dart';
import '../protocol/accelerometer.dart';
import '../protocol/battery.dart';
import '../protocol/commands.dart';
import '../protocol/hr_log.dart';
import '../protocol/hr_settings.dart';
import '../protocol/real_time.dart';
import '../protocol/steps.dart';

class ScanPageTitleBar extends StatelessWidget {
  const ScanPageTitleBar({
    super.key,
    required this.bleStatus,
    required this.onOverlay,
  });

  final BleConnectionStatus bleStatus;
  final VoidCallback onOverlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      color: theme.colorScheme.primary,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'OpenRing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ScanStatusIndicator(status: bleStatus),
          ),
          if (bleStatus == BleConnectionStatus.connected)
            IconButton(
              icon: Icon(
                Icons.picture_in_picture_alt,
                color: theme.colorScheme.onPrimary,
                size: 18,
              ),
              tooltip: 'Overlay aktivieren (Strg+Shift+O)',
              onPressed: onOverlay,
              splashRadius: 16,
            ),

          WindowButton(
            icon: Icons.minimize,
            onPressed: () => windowManager.minimize(),
            color: theme.colorScheme.onPrimary,
          ),
          WindowButton(
            icon: Icons.crop_square,
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            color: theme.colorScheme.onPrimary,
          ),
          WindowButton(
            icon: Icons.close,
            onPressed: () => windowManager.close(),
            color: theme.colorScheme.onPrimary,
            hoverColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

class WindowButton extends StatelessWidget {
  const WindowButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.color,
    this.hoverColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 40,
      child: IconButton(
        icon: Icon(icon, color: color, size: 16),
        onPressed: onPressed,
        hoverColor: hoverColor?.withValues(alpha: 0.8),
        splashRadius: 0.01,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class ScanStatusIndicator extends StatelessWidget {
  const ScanStatusIndicator({super.key, required this.status});

  final BleConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      BleConnectionStatus.disconnected => (Colors.red, 'Getrennt'),
      BleConnectionStatus.scanning => (Colors.orange, 'Scan...'),
      BleConnectionStatus.connecting => (Colors.amber, 'Verbinde...'),
      BleConnectionStatus.connected => (Colors.green, 'Verbunden'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class ScanControlRow extends StatelessWidget {
  const ScanControlRow({
    super.key,
    required this.status,
    required this.onScan,
    required this.onDisconnect,
  });

  final BleConnectionStatus status;
  final VoidCallback onScan;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: status == BleConnectionStatus.disconnected ? onScan : null,
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Scan starten'),
        ),
        const SizedBox(width: 12),
        if (status == BleConnectionStatus.connected)
          OutlinedButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Trennen'),
          ),
      ],
    );
  }
}

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, required this.onTap});

  final BleDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.watch),
      title: Text(device.name ?? '(unbekannt)'),
      subtitle: Text(device.deviceId),
      trailing: device.rssi != null
          ? Text(
              '${device.rssi} dBm',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      onTap: onTap,
    );
  }
}

class BatteryCard extends StatelessWidget {
  const BatteryCard({super.key, required this.battery});

  final BatteryResponse? battery;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          battery == null
              ? Icons.battery_unknown
              : battery!.isCharging
              ? Icons.battery_charging_full
              : Icons.battery_full,
        ),
        title: const Text('Batterie'),
        trailing: Text(
          battery == null
              ? '\u2014'
              : '${battery!.level}%${battery!.isCharging ? " (laedt)" : ""}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class DailyMeasurementButton extends StatelessWidget {
  const DailyMeasurementButton({
    super.key,
    required this.isRunning,
    required this.onToggle,
  });

  final bool isRunning;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: FilledButton.icon(
        onPressed: onToggle,
        icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
        label: Text(
          isRunning ? 'Tagesmessung stoppen' : 'Tagesmessung starten',
        ),
      ),
    );
  }
}

class RealTimeCard extends StatelessWidget {
  const RealTimeCard({
    super.key,
    required this.readingType,
    required this.reading,
    required this.isRunning,
    this.onToggle,
  });

  final int readingType;
  final RealTimeReading? reading;
  final bool isRunning;
  final VoidCallback? onToggle;

  IconData get _icon {
    return switch (readingType) {
      ReadingType.heartRate => Icons.favorite,
      ReadingType.spo2 => Icons.air,
      ReadingType.hrv => Icons.show_chart,
      _ => Icons.sensors,
    };
  }

  Color get _iconColor {
    return switch (readingType) {
      ReadingType.heartRate => Colors.red,
      ReadingType.spo2 => Colors.blue,
      ReadingType.hrv => Colors.purple,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final info = readingTypeInfo[readingType];
    final label = info?.label ?? 'Messung';
    final unit = info?.unit ?? '';

    final String mainText;
    if (isRunning) {
      mainText = reading != null && reading!.hasValue
          ? '${reading!.value} $unit'
          : 'Messe...';
    } else {
      mainText = reading != null && reading!.hasValue
          ? '${reading!.value} $unit (gestoppt)'
          : '\u2014';
    }

    final debugText = isRunning && reading != null
        ? 'raw: err=${reading!.errorCode} val=${reading!.value}'
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(_icon, color: _iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(mainText, style: Theme.of(context).textTheme.titleLarge),
                  if (debugText != null)
                    Text(
                      debugText,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onToggle,
              style: isRunning
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    )
                  : null,
              child: Text(isRunning ? 'Stoppen' : 'Starten'),
            ),
          ],
        ),
      ),
    );
  }
}

class AccelerometerCard extends StatelessWidget {
  const AccelerometerCard({
    super.key,
    required this.reading,
    required this.isRunning,
    required this.onToggle,
  });

  final AccelerometerReading? reading;
  final bool isRunning;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final String mainText;
    if (isRunning && reading != null) {
      mainText = 'X=${reading!.accX}  Y=${reading!.accY}  Z=${reading!.accZ}';
    } else if (isRunning) {
      mainText = 'Warte auf Daten...';
    } else {
      mainText = '\u2014';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.screen_rotation, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Accelerometer'),
                  Text(
                    mainText,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (isRunning)
                    Text(
                      '~1 Hz (Stock Firmware)',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onToggle,
              style: isRunning
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    )
                  : null,
              child: Text(isRunning ? 'Stoppen' : 'Starten'),
            ),
          ],
        ),
      ),
    );
  }
}

class HrLogCard extends StatelessWidget {
  const HrLogCard({
    super.key,
    required this.hrLog,
    required this.isLoading,
    required this.onRequest,
  });

  final HrLogResult? hrLog;
  final bool isLoading;
  final Future<void> Function(DateTime day) onRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.red),
                const SizedBox(width: 8),
                const Text('HR-Verlauf'),
                const Spacer(),
                ElevatedButton(
                  onPressed: isLoading ? null : () => onRequest(DateTime.now()),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Heute laden'),
                ),
              ],
            ),
            if (hrLog != null) ...[
              const SizedBox(height: 8),
              Text(
                '${hrLog!.entries.length} Eintr\u00e4ge (Intervall: ${hrLog!.intervalMinutes} min)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (hrLog!.entries.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: hrLog!.entries.length,
                    itemBuilder: (_, i) {
                      final e = hrLog!.entries[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${e.bpm}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            Container(
                              width: 6,
                              height: (e.bpm.clamp(40, 180) - 40) * 0.5,
                              color: Colors.red.shade400,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (hrLog!.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Keine Daten f\u00fcr diesen Tag.'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class StepsCard extends StatelessWidget {
  const StepsCard({
    super.key,
    required this.steps,
    required this.isLoading,
    required this.onRequest,
  });

  final List<StepEntry>? steps;
  final bool isLoading;
  final Future<void> Function(DateTime day) onRequest;

  @override
  Widget build(BuildContext context) {
    final totalSteps = steps?.fold<int>(0, (sum, e) => sum + e.steps) ?? 0;
    final totalCal = steps?.fold<int>(0, (sum, e) => sum + e.calories) ?? 0;
    final totalDist =
        steps?.fold<int>(0, (sum, e) => sum + e.distanceMeters) ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Schritte'),
                const Spacer(),
                ElevatedButton(
                  onPressed: isLoading ? null : () => onRequest(DateTime.now()),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Heute laden'),
                ),
              ],
            ),
            if (steps != null) ...[
              const SizedBox(height: 8),
              if (steps!.isEmpty)
                const Text('Keine Daten f\u00fcr diesen Tag.')
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    StatColumn(label: 'Schritte', value: '$totalSteps'),
                    StatColumn(label: 'Kalorien', value: '$totalCal kcal'),
                    StatColumn(label: 'Distanz', value: '${totalDist}m'),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatColumn extends StatelessWidget {
  const StatColumn({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class HrLogSettingsCard extends StatelessWidget {
  const HrLogSettingsCard({
    super.key,
    required this.settings,
    required this.onQuery,
    required this.onSet,
  });

  final HrLogSettings? settings;
  final Future<void> Function() onQuery;
  final Future<void> Function(HrLogSettings settings) onSet;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.settings, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HR-Log Einstellungen'),
                  if (settings != null)
                    Text(
                      '${settings!.enabled ? "Aktiv" : "Inaktiv"} \u2014 alle ${settings!.intervalMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (settings == null)
              OutlinedButton(onPressed: onQuery, child: const Text('Abfragen'))
            else
              OutlinedButton(
                onPressed: () {
                  onSet(
                    HrLogSettings(
                      enabled: !settings!.enabled,
                      intervalMinutes: settings!.intervalMinutes,
                    ),
                  );
                },
                child: Text(settings!.enabled ? 'Deaktivieren' : 'Aktivieren'),
              ),
          ],
        ),
      ),
    );
  }
}

class UtilityCard extends StatelessWidget {
  const UtilityCard({
    super.key,
    required this.onSyncTime,
    required this.onBlink,
    required this.onReboot,
  });

  final VoidCallback onSyncTime;
  final VoidCallback onBlink;
  final VoidCallback onReboot;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Befehle'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onSyncTime,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Zeit sync'),
                ),
                OutlinedButton.icon(
                  onPressed: onBlink,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Blinken'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Ring neustarten?'),
                        content: const Text(
                          'Der Ring wird neu gestartet und die Verbindung getrennt.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abbrechen'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onReboot();
                            },
                            child: const Text('Neustarten'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Neustart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DebugLogPanel extends StatefulWidget {
  const DebugLogPanel({super.key, required this.lines});

  final List<String> lines;

  @override
  State<DebugLogPanel> createState() => _DebugLogPanelState();
}

class _DebugLogPanelState extends State<DebugLogPanel> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant DebugLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines.length > oldWidget.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'Debug Log (${widget.lines.length})',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Expanded(
            child: widget.lines.isEmpty
                ? const Center(
                    child: Text(
                      'Keine Pakete.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: widget.lines.length,
                    itemBuilder: (_, i) {
                      final line = widget.lines[i];
                      final isTx = line.startsWith('[TX]');
                      return Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontFamilyFallback: const [
                            'monospace',
                            'Courier New',
                          ],
                          fontSize: 11,
                          color: isTx
                              ? Colors.lightGreenAccent
                              : Colors.cyanAccent,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
