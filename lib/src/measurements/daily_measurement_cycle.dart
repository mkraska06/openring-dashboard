import '../protocol/commands.dart';

/// Edit this list to change the continuous daily measurement ratio/order.
const dailyMeasurementCycle = [
  ReadingType.heartRate,
  ReadingType.heartRate,
  ReadingType.hrv,
  ReadingType.heartRate,
  ReadingType.heartRate,
  ReadingType.spo2,
  ReadingType.heartRate,
  ReadingType.heartRate,
  ReadingType.hrv,
];

class DailyMeasurementCycleCursor {
  DailyMeasurementCycleCursor([this._index = 0]);

  int _index;

  int get index => _index;

  int get current => dailyMeasurementCycle[_index];

  void reset() {
    _index = 0;
  }

  void advance() {
    _index = (_index + 1) % dailyMeasurementCycle.length;
  }
}
