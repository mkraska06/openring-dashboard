import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/history_models.dart';
import '../storage/storage_repository.dart';
import 'history_chart_models.dart';
import 'history_chart_widgets.dart';
import 'history_page_controller.dart';

const double _historyChartHeight = 220;

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  Timer? _refreshDebounce;
  final Map<String, HistoryChartRange> _vitalRanges = {
    vitalKindHeartRate: HistoryChartRange.live10m,
    vitalKindSpo2: HistoryChartRange.live10m,
    vitalKindHrv: HistoryChartRange.live10m,
  };
  final Map<String, double?> _vitalWindowCenterMinutes = {
    vitalKindHeartRate: null,
    vitalKindSpo2: null,
    vitalKindHrv: null,
  };
  HistoryChartRange _activityRange = HistoryChartRange.live10m;
  double? _activityWindowCenterMinute;

  @override
  void initState() {
    super.initState();
    ref.listenManual<int>(historyRefreshTickProvider, (_, _) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ref.read(historyPageProvider.notifier).load(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyPageProvider);
    final notifier = ref.read(historyPageProvider.notifier);
    final historyDay = state.historyDay;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HistoryHeader(
          selectedDay: state.selectedDay,
          isLoading: state.isLoading,
          onPrevious: notifier.previousDay,
          onToday: notifier.today,
          onNext: notifier.nextDay,
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: MaterialBanner(
              content: Text(state.error!),
              actions: [
                TextButton(
                  onPressed: notifier.load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (state.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (historyDay == null)
          const _EmptyHistory(
            title: 'No ring saved yet',
            message: 'Connect a ring first so OpenRing can show stored values.',
          )
        else ...[
          _DeviceLine(historyDay: historyDay),
          const SizedBox(height: 12),
          _VitalHistoryCard(
            title: 'Heart rate',
            accent: Colors.red,
            series: historyDay.series(vitalKindHeartRate),
            valueLabel: 'BPM',
            day: state.selectedDay,
            range: _vitalRanges[vitalKindHeartRate]!,
            windowCenterMinute: _vitalWindowCenterMinutes[vitalKindHeartRate],
            onRangeChanged: (range) {
              setState(() {
                _vitalRanges[vitalKindHeartRate] = range;
              });
            },
            onFocusMinute: (minute) {
              setState(() {
                _vitalRanges[vitalKindHeartRate] = HistoryChartRange.focus1m;
                _vitalWindowCenterMinutes[vitalKindHeartRate] = minute;
              });
            },
            onWindowCenterChanged: (minute) {
              setState(() {
                _vitalWindowCenterMinutes[vitalKindHeartRate] = minute;
              });
            },
          ),
          _VitalHistoryCard(
            title: 'SpO2',
            accent: Colors.blue,
            series: historyDay.series(vitalKindSpo2),
            valueLabel: '%',
            day: state.selectedDay,
            range: _vitalRanges[vitalKindSpo2]!,
            windowCenterMinute: _vitalWindowCenterMinutes[vitalKindSpo2],
            onRangeChanged: (range) {
              setState(() {
                _vitalRanges[vitalKindSpo2] = range;
              });
            },
            onFocusMinute: (minute) {
              setState(() {
                _vitalRanges[vitalKindSpo2] = HistoryChartRange.focus1m;
                _vitalWindowCenterMinutes[vitalKindSpo2] = minute;
              });
            },
            onWindowCenterChanged: (minute) {
              setState(() {
                _vitalWindowCenterMinutes[vitalKindSpo2] = minute;
              });
            },
          ),
          _VitalHistoryCard(
            title: 'HRV',
            accent: Colors.purple,
            series: historyDay.series(vitalKindHrv),
            valueLabel: 'ms',
            day: state.selectedDay,
            range: _vitalRanges[vitalKindHrv]!,
            windowCenterMinute: _vitalWindowCenterMinutes[vitalKindHrv],
            onRangeChanged: (range) {
              setState(() {
                _vitalRanges[vitalKindHrv] = range;
              });
            },
            onFocusMinute: (minute) {
              setState(() {
                _vitalRanges[vitalKindHrv] = HistoryChartRange.focus1m;
                _vitalWindowCenterMinutes[vitalKindHrv] = minute;
              });
            },
            onWindowCenterChanged: (minute) {
              setState(() {
                _vitalWindowCenterMinutes[vitalKindHrv] = minute;
              });
            },
          ),
          _ActivityHistoryCard(
            activity: historyDay.activity,
            day: state.selectedDay,
            range: _activityRange,
            windowCenterMinute: _activityWindowCenterMinute,
            onRangeChanged: (range) {
              setState(() {
                _activityRange = range;
              });
            },
            onFocusMinute: (minute) {
              setState(() {
                _activityRange = HistoryChartRange.focus1m;
                _activityWindowCenterMinute = minute;
              });
            },
            onWindowCenterChanged: (minute) {
              setState(() {
                _activityWindowCenterMinute = minute;
              });
            },
          ),
        ],
      ],
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.selectedDay,
    required this.isLoading,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final DateTime selectedDay;
  final bool isLoading;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('History', style: theme.textTheme.headlineSmall),
              Text(
                _formatDay(selectedDay),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Previous day',
          onPressed: isLoading ? null : onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        OutlinedButton(
          onPressed: isLoading ? null : onToday,
          child: const Text('Today'),
        ),
        IconButton(
          tooltip: 'Next day',
          onPressed: isLoading ? null : onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _DeviceLine extends StatelessWidget {
  const _DeviceLine({required this.historyDay});

  final HistoryDay historyDay;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ring: ${historyDay.deviceId}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _VitalHistoryCard extends StatelessWidget {
  const _VitalHistoryCard({
    required this.title,
    required this.accent,
    required this.series,
    required this.valueLabel,
    required this.day,
    required this.range,
    required this.windowCenterMinute,
    required this.onRangeChanged,
    required this.onFocusMinute,
    required this.onWindowCenterChanged,
  });

  final String title;
  final Color accent;
  final VitalHistorySeries? series;
  final String valueLabel;
  final DateTime day;
  final HistoryChartRange range;
  final double? windowCenterMinute;
  final ValueChanged<HistoryChartRange> onRangeChanged;
  final ValueChanged<double> onFocusMinute;
  final ValueChanged<double> onWindowCenterChanged;

  @override
  Widget build(BuildContext context) {
    final points = series?.points ?? const <VitalHistoryPoint>[];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: accent),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${points.length} Werte',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _RangeSelector(range: range, onChanged: onRangeChanged),
            const SizedBox(height: 10),
            if (points.isEmpty)
              const _EmptyInline(message: 'No data for this day.')
            else ...[
              SizedBox(
                height: _historyChartHeight,
                child: VitalLineChart(
                  points: points,
                  color: accent,
                  day: day,
                  unit: valueLabel,
                  range: range,
                  windowCenterMinute: windowCenterMinute,
                  onFocusMinute: onFocusMinute,
                  onWindowCenterChanged: onWindowCenterChanged,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _MetricPill(
                    label: 'Min',
                    value: '${series!.min} $valueLabel',
                  ),
                  _MetricPill(
                    label: 'Ø',
                    value: '${series!.average!.toStringAsFixed(1)} $valueLabel',
                  ),
                  _MetricPill(
                    label: 'Max',
                    value: '${series!.max} $valueLabel',
                  ),
                  _MetricPill(
                    label: 'Latest',
                    value:
                        '${series!.latest} $valueLabel um ${_formatTime(series!.latestPoint!.measuredAt)}',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityHistoryCard extends StatelessWidget {
  const _ActivityHistoryCard({
    required this.activity,
    required this.day,
    required this.range,
    required this.windowCenterMinute,
    required this.onRangeChanged,
    required this.onFocusMinute,
    required this.onWindowCenterChanged,
  });

  final ActivityDaySummary activity;
  final DateTime day;
  final HistoryChartRange range;
  final double? windowCenterMinute;
  final ValueChanged<HistoryChartRange> onRangeChanged;
  final ValueChanged<double> onFocusMinute;
  final ValueChanged<double> onWindowCenterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk, color: Colors.green),
                const SizedBox(width: 8),
                Text('Activity', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${activity.points.length} Intervalle',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _RangeSelector(range: range, onChanged: onRangeChanged),
            const SizedBox(height: 10),
            if (activity.isEmpty)
              const _EmptyInline(message: 'No steps for this day.')
            else ...[
              SizedBox(
                height: _historyChartHeight,
                child: ActivityBarChart(
                  points: activity.points,
                  day: day,
                  range: range,
                  windowCenterMinute: windowCenterMinute,
                  onFocusMinute: onFocusMinute,
                  onWindowCenterChanged: onWindowCenterChanged,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _MetricPill(label: 'Steps', value: '${activity.totalSteps}'),
                  _MetricPill(
                    label: 'Calories',
                    value: '${activity.totalCalories} kcal',
                  ),
                  _MetricPill(
                    label: 'Distance',
                    value: '${activity.totalDistanceMeters} m',
                  ),
                  _MetricPill(
                    label: 'Latest interval',
                    value: _formatTime(activity.latestPoint!.startedAt),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});

  final HistoryChartRange range;
  final ValueChanged<HistoryChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<HistoryChartRange>(
      segments: [
        for (final value in HistoryChartRange.values)
          ButtonSegment(value: value, label: Text(value.label)),
      ],
      selected: {range},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.single),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 42,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

String _formatDay(DateTime day) {
  return '${day.day.toString().padLeft(2, '0')}.'
      '${day.month.toString().padLeft(2, '0')}.'
      '${day.year}';
}

String _formatTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
