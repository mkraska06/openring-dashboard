import 'package:flutter_test/flutter_test.dart';
import 'package:openring_v1/src/history/history_chart_models.dart';

void main() {
  test('10m chart window follows the latest point with edge padding', () {
    final window = calculateChartWindow(
      range: HistoryChartRange.live10m,
      day: DateTime(2026, 4, 1),
      times: [DateTime(2026, 4, 1, 12, 45)],
    );

    expect(window.minX, 755.75);
    expect(window.maxX, 765.75);
    expect(window.bottomInterval, 2);
  });

  test('5m focused chart window centers around selected minute', () {
    final window = calculateChartWindow(
      range: HistoryChartRange.focus5m,
      day: DateTime(2026, 4, 1),
      times: [DateTime(2026, 4, 1, 12, 45)],
      focusMinute: 765,
    );

    expect(window.minX, 762.5);
    expect(window.maxX, 767.5);
    expect(window.bottomInterval, 1);
  });

  test('1m focused chart window centers around selected second', () {
    final window = calculateChartWindow(
      range: HistoryChartRange.focus1m,
      day: DateTime(2026, 4, 1),
      times: [DateTime(2026, 4, 1, 12, 45, 30)],
      focusMinute: 765.5,
    );

    expect(window.minX, 765);
    expect(window.maxX, 766);
    expect(window.bottomInterval, closeTo(1 / 6, 0.0001));
  });

  test('30m chart window follows the latest point', () {
    final window = calculateChartWindow(
      range: HistoryChartRange.live30m,
      day: DateTime(2026, 4, 1),
      times: [DateTime(2026, 4, 1, 12, 45)],
    );

    expect(window.minX, 735.75);
    expect(window.maxX, 765.75);
    expect(window.bottomInterval, 10);
  });

  test('2h chart window follows the latest point', () {
    final window = calculateChartWindow(
      range: HistoryChartRange.twoHours,
      day: DateTime(2026, 4, 1),
      times: [DateTime(2026, 4, 1, 12, 45)],
    );

    expect(window.minX, 645.75);
    expect(window.maxX, 765.75);
    expect(window.bottomInterval, 30);
  });

  test('day chart window covers the full day', () {
    final window = calculateChartWindow(
      range: HistoryChartRange.day,
      day: DateTime(2026, 4, 1),
      times: [DateTime(2026, 4, 1, 12, 45)],
    );

    expect(window.minX, -6);
    expect(window.maxX, 1446);
    expect(window.bottomInterval, 360);
  });

  test('y bounds contain min and max with padding', () {
    final bounds = calculateYBounds(values: [70, 80], unit: 'BPM');

    expect(bounds.minY, lessThanOrEqualTo(70));
    expect(bounds.maxY, greaterThanOrEqualTo(80));
    expect(bounds.leftInterval, greaterThan(0));
  });

  test('percent y bounds stay within percent range', () {
    final bounds = calculateYBounds(values: [95, 98], unit: '%');

    expect(bounds.minY, greaterThanOrEqualTo(0));
    expect(bounds.maxY, lessThanOrEqualTo(100));
  });

  test('minute and tooltip formatting is human readable', () {
    expect(formatMinuteLabel(765), '12:45');
    expect(formatMinuteLabel(765.5), '12:45:30');
    expect(
      minuteOfDay(DateTime(2026, 4, 1, 12, 45, 30), DateTime(2026, 4, 1)),
      765.5,
    );
    expect(
      formatChartTooltip(
        time: DateTime(2026, 4, 1, 12, 45),
        value: 72,
        unit: 'BPM',
      ),
      '12:45 - 72 BPM',
    );
  });
}
