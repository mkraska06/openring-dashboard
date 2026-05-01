import 'dart:math' as math;

enum HistoryChartRange {
  focus1m('1m', Duration(minutes: 1)),
  focus5m('5m', Duration(minutes: 5)),
  live10m('10m', Duration(minutes: 10)),
  live30m('30m', Duration(minutes: 30)),
  twoHours('2h', Duration(hours: 2)),
  day('Tag', Duration(days: 1));

  const HistoryChartRange(this.label, this.duration);

  final String label;
  final Duration duration;
}

class ChartWindow {
  const ChartWindow({
    required this.minX,
    required this.maxX,
    required this.bottomInterval,
  });

  final double minX;
  final double maxX;
  final double bottomInterval;
}

class ChartYBounds {
  const ChartYBounds({
    required this.minY,
    required this.maxY,
    required this.leftInterval,
  });

  final double minY;
  final double maxY;
  final double leftInterval;
}

ChartWindow calculateChartWindow({
  required HistoryChartRange range,
  required DateTime day,
  required List<DateTime> times,
  double? focusMinute,
}) {
  if (range == HistoryChartRange.day) {
    return const ChartWindow(minX: -6, maxX: 1446, bottomInterval: 360);
  }

  final durationMinutes = range.duration.inMinutes.toDouble();
  final (minX, maxX) = focusMinute == null
      ? _latestAnchoredWindow(
          day: day,
          times: times,
          durationMinutes: durationMinutes,
        )
      : _focusedWindow(
          focusMinute: focusMinute,
          durationMinutes: durationMinutes,
        );

  return ChartWindow(
    minX: minX,
    maxX: maxX,
    bottomInterval: switch (range) {
      HistoryChartRange.focus1m => 1 / 6,
      HistoryChartRange.focus5m => 1,
      HistoryChartRange.live10m => 2,
      HistoryChartRange.live30m => 10,
      HistoryChartRange.twoHours => 30,
      HistoryChartRange.day => 360,
    },
  );
}

ChartYBounds calculateYBounds({
  required List<int> values,
  required String unit,
}) {
  if (values.isEmpty) {
    return ChartYBounds(
      minY: 0,
      maxY: unit == '%' ? 100 : 1,
      leftInterval: unit == '%' ? 10 : 1,
    );
  }

  final minValue = values.reduce(math.min).toDouble();
  final maxValue = values.reduce(math.max).toDouble();
  final spread = math.max(1, maxValue - minValue);
  final padding = math.max(_defaultPaddingForUnit(unit), spread * 0.15);
  var minY = minValue - padding;
  var maxY = maxValue + padding;

  if (unit == '%') {
    minY = math.max(0, minY);
    maxY = math.min(100, math.max(maxY, minY + 1));
  } else {
    minY = math.max(0, minY);
  }

  final interval = _niceInterval((maxY - minY) / 3);
  minY = (minY / interval).floor() * interval;
  maxY = (maxY / interval).ceil() * interval;

  return ChartYBounds(minY: minY, maxY: maxY, leftInterval: interval);
}

double minuteOfDay(DateTime time, DateTime day) {
  return _minutesSinceStartOfDay(time, day).toDouble();
}

String formatMinuteLabel(double minute) {
  final clampedSeconds = (minute * 60).round().clamp(0, 24 * 60 * 60);
  final hour = clampedSeconds ~/ 3600;
  final mins = (clampedSeconds % 3600) ~/ 60;
  final seconds = clampedSeconds % 60;
  final base =
      '${hour.toString().padLeft(2, '0')}:'
      '${mins.toString().padLeft(2, '0')}';
  if (seconds == 0) return base;
  return '$base:${seconds.toString().padLeft(2, '0')}';
}

String formatChartTooltip({
  required DateTime time,
  required int value,
  required String unit,
}) {
  return '${formatMinuteLabel((time.hour * 60 + time.minute).toDouble())} - $value $unit';
}

double _minutesSinceStartOfDay(DateTime time, DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final diff = time.difference(start);
  final minutes = diff.inMilliseconds / Duration.millisecondsPerMinute;
  return minutes.clamp(0, 1440).toDouble();
}

double _defaultPaddingForUnit(String unit) {
  return switch (unit) {
    '%' => 2,
    'BPM' => 5,
    'ms' => 5,
    _ => 3,
  };
}

const _edgePaddingMinutes = 0.75;

(double, double) _latestAnchoredWindow({
  required DateTime day,
  required List<DateTime> times,
  required double durationMinutes,
}) {
  final latestMinute = times.isEmpty
      ? _minutesSinceStartOfDay(DateTime.now(), day)
      : times
            .map((time) => _minutesSinceStartOfDay(time, day))
            .reduce(math.max);
  final maxX = (latestMinute + _edgePaddingMinutes)
      .clamp(durationMinutes, 1440)
      .toDouble();
  final minX = math.max(0, maxX - durationMinutes).toDouble();
  return (minX, maxX);
}

(double, double) _focusedWindow({
  required double focusMinute,
  required double durationMinutes,
}) {
  var minX = focusMinute - durationMinutes / 2;
  var maxX = focusMinute + durationMinutes / 2;

  if (minX < 0) {
    maxX += -minX;
    minX = 0;
  }
  if (maxX > 1440) {
    minX -= maxX - 1440;
    maxX = 1440;
  }

  return (math.max(0, minX), math.min(1440, maxX));
}

double _niceInterval(double raw) {
  if (raw <= 1) return 1;
  if (raw <= 2) return 2;
  if (raw <= 5) return 5;
  if (raw <= 10) return 10;
  if (raw <= 20) return 20;
  if (raw <= 50) return 50;
  return 100;
}
