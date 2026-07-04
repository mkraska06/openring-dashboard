import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../storage/history_models.dart';
import '../storage/storage_repository.dart' show sampleSourceLive;
import 'history_chart_models.dart';

const double _dragPanSpeed = 4;

class VitalLineChart extends StatelessWidget {
  const VitalLineChart({
    super.key,
    required this.points,
    required this.color,
    required this.day,
    required this.unit,
    required this.range,
    this.windowCenterMinute,
    this.onFocusMinute,
    this.onWindowCenterChanged,
  });

  final List<VitalHistoryPoint> points;
  final Color color;
  final DateTime day;
  final String unit;
  final HistoryChartRange range;
  final double? windowCenterMinute;
  final ValueChanged<double>? onFocusMinute;
  final ValueChanged<double>? onWindowCenterChanged;

  @override
  Widget build(BuildContext context) {
    final displayPoints = _displayPointsForRange(points, range);
    final window = calculateChartWindow(
      range: range,
      day: day,
      times: displayPoints.map((p) => p.measuredAt).toList(),
      centerMinute: windowCenterMinute,
    );
    final yBounds = calculateYBounds(
      values: displayPoints.map((p) => p.value).toList(),
      unit: unit,
    );
    final spots = [
      for (final point in displayPoints)
        if (_isInWindow(point.measuredAt, day, window))
          FlSpot(minuteOfDay(point.measuredAt, day), point.value.toDouble()),
    ];
    final spotSegments = _splitSpotSegments(spots: spots, range: range);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final nextCenter = _draggedWindowCenter(
              window: window,
              deltaDx: details.delta.dx,
              width: constraints.maxWidth,
            );
            if (nextCenter != null) {
              onWindowCenterChanged?.call(nextCenter);
            }
          },
          child: Padding(
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
                          const FlLine(
                            color: Colors.transparent,
                            strokeWidth: 0,
                          ),
                          FlDotData(show: false),
                        ),
                    ];
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return [
                        for (final spot in touchedSpots)
                          _tooltipForSpot(spot, displayPoints, day, unit),
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
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
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
                        show: !_hideDotsForRange(range),
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
          ),
        );
      },
    );
  }
}

class ActivityBarChart extends StatelessWidget {
  const ActivityBarChart({
    super.key,
    required this.points,
    required this.day,
    required this.range,
    this.windowCenterMinute,
    this.onFocusMinute,
    this.onWindowCenterChanged,
  });

  final List<ActivityHistoryPoint> points;
  final DateTime day;
  final HistoryChartRange range;
  final double? windowCenterMinute;
  final ValueChanged<double>? onFocusMinute;
  final ValueChanged<double>? onWindowCenterChanged;

  @override
  Widget build(BuildContext context) {
    final window = calculateChartWindow(
      range: range,
      day: day,
      times: points.map((p) => p.startedAt).toList(),
      centerMinute: windowCenterMinute,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final nextCenter = _draggedWindowCenter(
              window: window,
              deltaDx: details.delta.dx,
              width: constraints.maxWidth,
            );
            if (nextCenter != null) {
              onWindowCenterChanged?.call(nextCenter);
            }
          },
          child: Padding(
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
                    if (event is! FlTapUpEvent || response?.spot == null) {
                      return;
                    }
                    final groupIndex = response!.spot!.touchedBarGroupIndex;
                    if (groupIndex < 0 || groupIndex >= visiblePoints.length) {
                      return;
                    }
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
                          unit: 'Steps',
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
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

List<VitalHistoryPoint> _displayPointsForRange(
  List<VitalHistoryPoint> points,
  HistoryChartRange range,
) {
  if (!_useMedianBlocksForRange(range)) return points;

  final liveBlocks = <int, List<VitalHistoryPoint>>{};
  final displayPoints = <VitalHistoryPoint>[];

  for (final point in points) {
    if (point.source == sampleSourceLive && point.liveBlockId != null) {
      liveBlocks.putIfAbsent(point.liveBlockId!, () => []).add(point);
    } else {
      displayPoints.add(point);
    }
  }

  if (liveBlocks.isEmpty) return points;

  displayPoints.addAll(
    liveBlocks.values
        .map(
          (block) =>
              block..sort((a, b) => a.measuredAt.compareTo(b.measuredAt)),
        )
        .map(_medianDisplayPoint),
  );

  displayPoints.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  return displayPoints;
}

VitalHistoryPoint _medianDisplayPoint(List<VitalHistoryPoint> block) {
  if (block.length == 1) return block.single;

  final sortedValues = block.map((point) => point.value).toList()..sort();
  final middle = sortedValues.length ~/ 2;
  final medianValue = sortedValues.length.isOdd
      ? sortedValues[middle]
      : ((sortedValues[middle - 1] + sortedValues[middle]) / 2).round();
  final start = block.first.measuredAt;
  final end = block.last.measuredAt;
  final midpoint = start.add(
    Duration(microseconds: end.difference(start).inMicroseconds ~/ 2),
  );

  return VitalHistoryPoint(
    measuredAt: midpoint,
    value: medianValue,
    source: block.first.source,
    liveBlockId: block.first.liveBlockId,
  );
}

bool _isInWindow(DateTime time, DateTime day, ChartWindow window) {
  final x = minuteOfDay(time, day);
  return x >= window.minX && x <= window.maxX;
}

bool _useMedianBlocksForRange(HistoryChartRange range) {
  return switch (range) {
    HistoryChartRange.focus1m ||
    HistoryChartRange.focus5m ||
    HistoryChartRange.live10m => false,
    HistoryChartRange.live30m ||
    HistoryChartRange.twoHours ||
    HistoryChartRange.day => true,
  };
}

bool _hideDotsForRange(HistoryChartRange range) {
  return range == HistoryChartRange.twoHours || range == HistoryChartRange.day;
}

double? _draggedWindowCenter({
  required ChartWindow window,
  required double deltaDx,
  required double width,
}) {
  final duration = window.maxX - window.minX;
  if (duration >= 1440 || width <= 0) return null;

  final currentCenter = (window.minX + window.maxX) / 2;
  final deltaMinutes = -deltaDx / width * duration * _dragPanSpeed;
  final minCenter = duration / 2;
  final maxCenter = 1440 - duration / 2;
  return (currentCenter + deltaMinutes).clamp(minCenter, maxCenter).toDouble();
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
    fontSize: 12,
  );

  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      axisNameWidget: Text(unit, style: style),
      axisNameSize: 22,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 52,
        interval: yBounds.leftInterval,
        getTitlesWidget: (value, meta) {
          return Text(value.round().toString(), style: style);
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: window.bottomInterval,
        getTitlesWidget: (value, meta) {
          final edgePadding = window.bottomInterval * 0.5;
          if (value <= window.minX + edgePadding ||
              value >= window.maxX - edgePadding) {
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
