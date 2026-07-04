import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;
import 'package:window_manager/window_manager.dart';

import '../ble/ble_service.dart';
import '../protocol/accelerometer.dart';
import '../protocol/activity.dart';
import '../protocol/battery.dart';
import '../protocol/commands.dart';
import '../protocol/hr_log.dart';
import '../protocol/hr_settings.dart';
import '../protocol/real_time.dart';
import '../protocol/steps.dart';
import '../storage/motion_models.dart';

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
      BleConnectionStatus.disconnected => (Colors.red, 'Disconnected'),
      BleConnectionStatus.scanning => (Colors.orange, 'Scan...'),
      BleConnectionStatus.connecting => (Colors.amber, 'Connecting...'),
      BleConnectionStatus.connected => (Colors.green, 'Connected'),
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
        title: const Text('Battery'),
        trailing: Text(
          battery == null
              ? '\u2014'
              : '${battery!.level}%${battery!.isCharging ? " (charging)" : ""}',
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
        label: Text(isRunning ? 'Stop daily cycle' : 'Start daily cycle'),
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
          : 'Measuring...';
    } else {
      mainText = reading != null && reading!.hasValue
          ? '${reading!.value} $unit (stopped)'
          : '\u2014';
    }

    final debugText = kDebugMode && isRunning && reading != null
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
              child: Text(isRunning ? 'Stop' : 'Start'),
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
    required this.isStopping,
    this.lastCommand,
    this.lastSampleAt,
    this.stopCleanupSent = false,
    this.stopWarning,
    required this.onToggle,
  });

  final AccelerometerReading? reading;
  final bool isRunning;
  final bool isStopping;
  final String? lastCommand;
  final DateTime? lastSampleAt;
  final bool stopCleanupSent;
  final String? stopWarning;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final String mainText;
    final String? scaleText;
    if (isRunning && reading != null) {
      mainText = 'X=${reading!.accX}  Y=${reading!.accY}  Z=${reading!.accZ}';
      scaleText =
          'X=${reading!.xG.toStringAsFixed(3)} g  '
          'Y=${reading!.yG.toStringAsFixed(3)} g  '
          'Z=${reading!.zG.toStringAsFixed(3)} g  '
          '|a|=${reading!.magnitudeG.toStringAsFixed(3)} g';
    } else if (isRunning) {
      mainText = 'Waiting for data...';
      scaleText = null;
    } else {
      mainText = '\u2014';
      scaleText = null;
    }
    final diagnostics = <String>[
      if (lastCommand != null) 'last command: $lastCommand',
      if (lastSampleAt != null)
        'last sample ${_relativeSeconds(lastSampleAt!)}s ago',
      if (stopCleanupSent) 'visual stop sequence sent',
    ];
    final buttonLabel = isStopping
        ? 'Stopping...'
        : isRunning
        ? 'Stop sensor'
        : 'Start sensor';

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
                  if (scaleText != null)
                    Text(
                      scaleText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (isRunning)
                    Text(
                      '~1 Hz (Stock Firmware)',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  if (diagnostics.isNotEmpty)
                    Text(
                      diagnostics.join(' | '),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  if (stopWarning != null)
                    Text(
                      stopWarning!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isStopping ? null : onToggle,
              style: isRunning || isStopping
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    )
                  : null,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  int _relativeSeconds(DateTime time) {
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 0) return 0;
    return seconds;
  }
}

class MotionLabCard extends StatelessWidget {
  const MotionLabCard({
    super.key,
    required this.sessionName,
    required this.recording,
    required this.recordings,
    required this.isRecording,
    required this.canRecord,
    required this.onNameChanged,
    required this.onPresetSelected,
    required this.onRecord,
    required this.onStop,
  });

  final String sessionName;
  final MotionSessionRecording? recording;
  final List<MotionSessionRecording> recordings;
  final bool isRecording;
  final bool canRecord;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<GestureMotionPreset> onPresetSelected;
  final Future<void> Function() onRecord;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final samples = recording?.samples ?? const <MotionSamplePoint>[];
    final stats = recording == null ? null : analyzeMotionSession(recording!);
    final calibration = analyzeGestureCalibration(recordings);
    final poseAnalysis = analyzeGesturePoseSpace(recordings);
    final label = isRecording
        ? 'Recording'
        : recording == null
        ? 'No motion session'
        : 'Latest session';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.multiline_chart, color: Colors.deepOrange),
                const SizedBox(width: 8),
                const Text('Motion Lab'),
                const Spacer(),
                Text(
                  '$label | ${samples.length} Samples',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in GestureMotionPreset.values)
                  ChoiceChip(
                    label: Text(preset.label),
                    selected: sessionName.startsWith(preset.sessionPrefix),
                    onSelected: isRecording
                        ? null
                        : (_) => onPresetSelected(preset),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey(recording?.session.id ?? 'motion-name'),
                    initialValue: sessionName,
                    enabled: !isRecording,
                    onChanged: onNameChanged,
                    decoration: const InputDecoration(
                      labelText: 'Sessionname',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isRecording)
                  FilledButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  )
                else
                  FilledButton.icon(
                    onPressed: canRecord ? onRecord : null,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Record'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 230,
              child: samples.isEmpty
                  ? const Center(child: Text('No motion samples yet.'))
                  : MotionSessionChart(samples: samples),
            ),
            if (stats != null) ...[
              const SizedBox(height: 10),
              MotionSessionStatsView(stats: stats),
            ],
            if (calibration.positions.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureCalibrationView(summary: calibration),
            ],
            if (poseAnalysis.groups.isNotEmpty) ...[
              const SizedBox(height: 10),
              GesturePoseAnalysisView(summary: poseAnalysis),
            ],
          ],
        ),
      ),
    );
  }
}

class MotionSessionStatsView extends StatelessWidget {
  const MotionSessionStatsView({super.key, required this.stats});

  final MotionSessionStats stats;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session analysis', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _MetricChip(
              label: 'Duration',
              value: '${stats.duration.inSeconds}s',
            ),
            _MetricChip(label: 'Dominant', value: stats.dominantAxis),
            _MetricChip(label: 'Stable', value: stats.isStable ? 'yes' : 'no'),
            _MetricChip(
              label: 'Delta',
              value: stats.averageSampleDeltaG.toStringAsFixed(3),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'X ${_axis(stats.x)}   Y ${_axis(stats.y)}   Z ${_axis(stats.z)}   |a| ${_axis(stats.magnitude)}',
          style: style,
        ),
      ],
    );
  }

  String _axis(MotionAxisStats axis) {
    return 'min ${axis.min.toStringAsFixed(2)} / avg ${axis.average.toStringAsFixed(2)} / max ${axis.max.toStringAsFixed(2)}';
  }
}

class GestureCalibrationView extends StatelessWidget {
  const GestureCalibrationView({super.key, required this.summary});

  final GestureCalibrationSummary summary;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gesture-Kalibrierung',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _MetricChip(
              label: 'Status',
              value: summary.ready ? 'ready' : 'more data',
            ),
            _MetricChip(label: 'Best axis', value: summary.bestAxis ?? '-'),
            _MetricChip(
              label: 'Trennung',
              value: summary.axisSeparationG.toStringAsFixed(2),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final preset in const [
          GestureMotionPreset.palmUp,
          GestureMotionPreset.palmSide,
          GestureMotionPreset.palmDown,
        ])
          if (summary.positions[preset] case final position?)
            Text(
              '${preset.label}: ${position.sessionCount} Sessions, '
              '${position.sampleCount} Samples, '
              'X ${position.averageX.toStringAsFixed(2)}  '
              'Y ${position.averageY.toStringAsFixed(2)}  '
              'Z ${position.averageZ.toStringAsFixed(2)}',
              style: style,
            ),
      ],
    );
  }
}

class GesturePoseAnalysisView extends StatelessWidget {
  const GesturePoseAnalysisView({super.key, required this.summary});

  final GesturePoseAnalysisSummary summary;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final comparisons = [
      ...summary.openFistComparisons,
      ...summary.verticalComparisons,
      ...summary.rollComparisons,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gesture-Space', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _MetricChip(label: 'Status', value: summary.overallStatus.label),
            _MetricChip(label: 'Gruppen', value: '${summary.groups.length}'),
          ],
        ),
        const SizedBox(height: 6),
        for (final group in summary.groups.values)
          Text(
            '${group.key.label}: ${group.sessionCount} Sessions, '
            '${group.sampleCount} Samples, '
            'stabil ${group.isStable ? "ja" : "nein"}, '
            'Roll ${group.averageRollDegrees.toStringAsFixed(0)} deg, '
            'X ${group.x.average.toStringAsFixed(2)}  '
            'Y ${group.y.average.toStringAsFixed(2)}  '
            'Z ${group.z.average.toStringAsFixed(2)}',
            style: style,
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final comparison in comparisons)
              _MetricChip(
                label: comparison.label,
                value: comparison.status == GestureSeparationStatus.moreData
                    ? comparison.status.label
                    : '${comparison.status.label} '
                          '${comparison.distanceG.toStringAsFixed(2)}',
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class MotionSessionChart extends StatelessWidget {
  const MotionSessionChart({super.key, required this.samples});

  final List<MotionSamplePoint> samples;

  @override
  Widget build(BuildContext context) {
    final start = samples.first.receivedAt;
    final spotsX = _spots(start, (sample) => sample.reading.xG);
    final spotsY = _spots(start, (sample) => sample.reading.yG);
    final spotsZ = _spots(start, (sample) => sample.reading.zG);
    final spotsMagnitude = _spots(start, (sample) => sample.reading.magnitudeG);
    final values = [
      ...spotsX.map((spot) => spot.y),
      ...spotsY.map((spot) => spot.y),
      ...spotsZ.map((spot) => spot.y),
      ...spotsMagnitude.map((spot) => spot.y),
    ];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY).abs() < 0.1 ? 0.2 : (maxY - minY) * 0.12;
    final chartMaxX = spotsMagnitude.last.x <= 0 ? 1.0 : spotsMagnitude.last.x;
    final xInterval = _motionTimeInterval(chartMaxX);
    final yInterval = _motionGInterval(minY - padding, maxY + padding);
    final axisStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Column(
      children: [
        Expanded(
          child: LineChart(
            duration: Duration.zero,
            LineChartData(
              minX: 0,
              maxX: chartMaxX,
              minY: minY - padding,
              maxY: maxY + padding,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                drawVerticalLine: true,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.black.withValues(alpha: 0.08),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (_) => FlLine(
                  color: Colors.black.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  axisNameWidget: Text('g', style: axisStyle),
                  axisNameSize: 18,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(1),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: axisStyle,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: xInterval,
                    getTitlesWidget: (value, meta) {
                      final edgePadding = xInterval * 0.45;
                      if (value <= edgePadding ||
                          value >= chartMaxX - edgePadding) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${value.toStringAsFixed(0)} s',
                          maxLines: 1,
                          softWrap: false,
                          style: axisStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
              ),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                _line(spotsX, Colors.red, dashed: false),
                _line(spotsY, Colors.green, dashed: false),
                _line(spotsZ, Colors.blue, dashed: false),
                _line(spotsMagnitude, Colors.black87, dashed: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Wrap(
          spacing: 12,
          children: [
            _MotionLegend(color: Colors.red, label: 'X'),
            _MotionLegend(color: Colors.green, label: 'Y'),
            _MotionLegend(color: Colors.blue, label: 'Z'),
            _MotionLegend(color: Colors.black87, label: '|a|'),
          ],
        ),
      ],
    );
  }

  List<FlSpot> _spots(
    DateTime start,
    double Function(MotionSamplePoint sample) valueFor,
  ) {
    return [
      for (final sample in samples)
        FlSpot(
          sample.receivedAt.difference(start).inMilliseconds / 1000,
          valueFor(sample),
        ),
    ];
  }

  LineChartBarData _line(
    List<FlSpot> spots,
    Color color, {
    required bool dashed,
  }) {
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: dashed ? 2.8 : 2,
      dashArray: dashed ? [6, 4] : null,
      dotData: FlDotData(show: spots.length <= 20),
      isCurved: false,
    );
  }

  double _motionTimeInterval(double maxSeconds) {
    if (maxSeconds <= 15) return 5;
    if (maxSeconds <= 45) return 10;
    if (maxSeconds <= 120) return 20;
    if (maxSeconds <= 300) return 60;
    return 120;
  }

  double _motionGInterval(double minY, double maxY) {
    final span = (maxY - minY).abs();
    if (span <= 1) return 0.25;
    if (span <= 3) return 0.5;
    if (span <= 8) return 1;
    return 2;
  }
}

class _MotionLegend extends StatelessWidget {
  const _MotionLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label),
      ],
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
                const Text('Heart-rate log'),
                const Spacer(),
                ElevatedButton(
                  onPressed: isLoading ? null : () => onRequest(DateTime.now()),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load today'),
                ),
              ],
            ),
            if (hrLog != null) ...[
              const SizedBox(height: 8),
              Text(
                '${hrLog!.entries.length} entries (interval: ${hrLog!.intervalMinutes} min)',
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
                  child: Text('No data for this day.'),
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
    required this.dailyActivity,
    required this.isLoading,
    required this.onRequest,
  });

  final List<StepEntry>? steps;
  final DailyActivitySnapshot? dailyActivity;
  final bool isLoading;
  final Future<void> Function(DateTime day) onRequest;

  @override
  Widget build(BuildContext context) {
    final historySteps = steps?.fold<int>(0, (sum, e) => sum + e.steps) ?? 0;
    final historyCal = steps?.fold<int>(0, (sum, e) => sum + e.calories) ?? 0;
    final historyDist =
        steps?.fold<int>(0, (sum, e) => sum + e.distanceMeters) ?? 0;
    final totalSteps = dailyActivity?.steps ?? historySteps;
    final totalCal = dailyActivity?.calories ?? historyCal;
    final totalDist = dailyActivity?.distanceMeters ?? historyDist;

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
                const Text('Steps'),
                const Spacer(),
                ElevatedButton(
                  onPressed: isLoading ? null : () => onRequest(DateTime.now()),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load today'),
                ),
              ],
            ),
            if (dailyActivity != null || steps != null) ...[
              const SizedBox(height: 8),
              if (dailyActivity == null && steps!.isEmpty)
                const Text('No data for this day.')
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    StatColumn(label: 'Steps', value: '$totalSteps'),
                    StatColumn(label: 'Calories', value: '$totalCal kcal'),
                    StatColumn(label: 'Distance', value: '${totalDist}m'),
                  ],
                ),
                if (dailyActivity != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Current daily total',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
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
                  const Text('Heart-rate log settings'),
                  if (settings != null)
                    Text(
                      '${settings!.enabled ? "Enabled" : "Disabled"} \u2014 every ${settings!.intervalMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (settings == null)
              OutlinedButton(onPressed: onQuery, child: const Text('Query'))
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
                child: Text(settings!.enabled ? 'Disable' : 'Enable'),
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
            const Text('Device commands'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onSyncTime,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Sync time'),
                ),
                OutlinedButton.icon(
                  onPressed: onBlink,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Blink'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Restart ring?'),
                        content: const Text(
                          'The ring will restart and disconnect.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onReboot();
                            },
                            child: const Text('Restart'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
