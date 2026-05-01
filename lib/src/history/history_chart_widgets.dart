import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../storage/history_models.dart';
import 'history_chart_models.dart';

class VitalLineChart extends StatelessWidget {
  const VitalLineChart({
    super.key,
    required this.points,
    required this.color,
    required this.day,
    required this.unit,
    required this.range,
    this.focusMinute,
    this.onFocusMinute,
  });

  final List<VitalHistoryPoint> points;
  final Color color;
  final DateTime day;
  final String unit;
  final HistoryChartRange range;
  final double? focusMinute;
  final ValueChanged<double>? onFocusMinute;

  @override
  Widget build(BuildContext context) {
    final window = calculateChartWindow(
      range: range,
      day: day,
      times: points.map((p) => p.measuredAt).toList(),
      focusMinute: _isFocusedRange(range) ? focusMinute : null,
    );
    final yBounds = calculateYBounds(
      values: points.map((p) => p.value).toList(),
      unit: unit,
    );
    final spots = [
      for (final point in points)
        if (_isInWindow(point.measuredAt, day, window))
          FlSpot(minuteOfDay(point.measuredAt, day), point.value.toDouble()),
    ];
    final spotSegments = _splitSpotSegments(spots: spots, range: range);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          minX: window.minX,
          maxX: window.maxX,
          minY: yBounds.minY,
          maxY: yBounds.maxY,
          clipData: const FlClipData.all(),
          lineTouchData: LineTouchData(
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent || response == null) return;
              final touchedSpot = response.lineBarSpots?.firstOrNull;
              if (touchedSpot == null) return;
              onFocusMinute?.call(touchedSpot.x);
            },
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return [
                for (final _ in spotIndexes)
                  TouchedSpotIndicatorData(
                    const FlLine(color: Colors.transparent, strokeWidth: 0),
                    FlDotData(show: false),
                  ),
              ];
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return [
                  for (final spot in touchedSpots)
                    _tooltipForSpot(spot, points, day, unit),
                ];
              },
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: true,
            horizontalInterval: yBounds.leftInterval,
            verticalInterval: window.bottomInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.black.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (_) => FlLine(
              color: Colors.black.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: _titlesData(
            context: context,
            window: window,
            yBounds: yBounds,
            unit: unit,
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
          ),
          lineBarsData: [
            for (final segment in spotSegments)
              LineChartBarData(
                spots: segment,
                isCurved: segment.length >= 3,
                curveSmoothness: 0.35,
                preventCurveOverShooting: true,
                color: color,
                barWidth: 2.6,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: switch (range) {
                        HistoryChartRange.focus1m => 2.8,
                        HistoryChartRange.focus5m => 2.6,
                        HistoryChartRange.live10m => 2.4,
                        HistoryChartRange.live30m => 2.2,
                        HistoryChartRange.twoHours => 2.0,
                        HistoryChartRange.day => 1.7,
                      },
                      color: Colors.white,
                      strokeWidth: 1.4,
                      strokeColor: color,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: segment.length >= 2,
                  color: color.withValues(alpha: 0.10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ActivityBarChart extends StatelessWidget {
  const ActivityBarChart({
    super.key,
    required this.points,
    required this.day,
    required this.range,
    this.focusMinute,
    this.onFocusMinute,
  });

  final List<ActivityHistoryPoint> points;
  final DateTime day;
  final HistoryChartRange range;
  final double? focusMinute;
  final ValueChanged<double>? onFocusMinute;

  @override
  Widget build(BuildContext context) {
    final window = calculateChartWindow(
      range: range,
      day: day,
      times: points.map((p) => p.startedAt).toList(),
      focusMinute: _isFocusedRange(range) ? focusMinute : null,
    );
    final yBounds = calculateYBounds(
      values: points.map((p) => p.steps).toList(),
      unit: '',
    );
    final visiblePoints = points.where((point) {
      final x = minuteOfDay(point.startedAt, day);
      return x >= window.minX && x <= window.maxX;
    }).toList();
    final groups = [
      for (var i = 0; i < visiblePoints.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: visiblePoints[i].steps.toDouble(),
              width: range == HistoryChartRange.day ? 3 : 8,
              borderRadius: BorderRadius.circular(2),
              color: Colors.green.withValues(alpha: 0.78),
            ),
          ],
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      child: BarChart(
        duration: Duration.zero,
        BarChartData(
          minY: yBounds.minY,
          maxY: yBounds.maxY,
          groupsSpace: 0,
          barGroups: groups,
          alignment: BarChartAlignment.start,
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent || response?.spot == null) return;
              final groupIndex = response!.spot!.touchedBarGroupIndex;
              if (groupIndex < 0 || groupIndex >= visiblePoints.length) return;
              final point = visiblePoints[groupIndex];
              onFocusMinute?.call(minuteOfDay(point.startedAt, day));
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = visiblePoints[group.x];
                return BarTooltipItem(
                  formatChartTooltip(
                    time: point.startedAt,
                    value: point.steps,
                    unit: 'Schritte',
                  ),
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: true,
            horizontalInterval: yBounds.leftInterval,
            verticalInterval: window.bottomInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.black.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (_) => FlLine(
              color: Colors.black.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: _titlesData(
            context: context,
            window: window,
            yBounds: yBounds,
            unit: 'Steps',
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
          ),
        ),
      ),
    );
  }
}

LineTooltipItem _tooltipForSpot(
  LineBarSpot spot,
  List<VitalHistoryPoint> points,
  DateTime day,
  String unit,
) {
  final point = points.reduce((closest, next) {
    final currentDistance = (minuteOfDay(closest.measuredAt, day) - spot.x)
        .abs();
    final nextDistance = (minuteOfDay(next.measuredAt, day) - spot.x).abs();
    return nextDistance < currentDistance ? next : closest;
  });
  return LineTooltipItem(
    formatChartTooltip(time: point.measuredAt, value: point.value, unit: unit),
    const TextStyle(color: Colors.white),
  );
}

bool _isInWindow(DateTime time, DateTime day, ChartWindow window) {
  final x = minuteOfDay(time, day);
  return x >= window.minX && x <= window.maxX;
}

bool _isFocusedRange(HistoryChartRange range) {
  return range == HistoryChartRange.focus1m ||
      range == HistoryChartRange.focus5m;
}

List<List<FlSpot>> _splitSpotSegments({
  required List<FlSpot> spots,
  required HistoryChartRange range,
}) {
  if (spots.isEmpty) return const [];

  final gapThreshold = switch (range) {
    HistoryChartRange.focus1m => 0.5,
    HistoryChartRange.focus5m => 1.0,
    HistoryChartRange.live10m => 1.25,
    HistoryChartRange.live30m => 2.0,
    HistoryChartRange.twoHours => 5.0,
    HistoryChartRange.day => 20.0,
  };

  final segments = <List<FlSpot>>[];
  var current = <FlSpot>[spots.first];

  for (final spot in spots.skip(1)) {
    final previous = current.last;
    if ((spot.x - previous.x).abs() > gapThreshold) {
      segments.add(current);
      current = <FlSpot>[spot];
    } else {
      current.add(spot);
    }
  }

  segments.add(current);
  return segments;
}

FlTitlesData _titlesData({
  required BuildContext context,
  required ChartWindow window,
  required ChartYBounds yBounds,
  required String unit,
}) {
  final theme = Theme.of(context);
  final style = theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
    fontSize: 10,
  );

  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      axisNameWidget: Text(unit, style: style),
      axisNameSize: 18,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 42,
        interval: yBounds.leftInterval,
        getTitlesWidget: (value, meta) {
          return Text(value.round().toString(), style: style);
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        interval: window.bottomInterval,
        getTitlesWidget: (value, meta) {
          if (value < window.minX || value > window.maxX) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(formatMinuteLabel(value), style: style),
          );
        },
      ),
    ),
  );
}
