import 'dart:typed_data';

import '../ble/ble_service.dart';
import '../protocol/accelerometer.dart';
import '../protocol/battery.dart';
import '../protocol/hr_log.dart';
import '../protocol/hr_settings.dart';
import '../protocol/real_time.dart';
import '../protocol/set_time.dart';
import '../protocol/steps.dart';
import '../protocol/utility.dart';

class ScanPageUseCases {
  const ScanPageUseCases(this._service);

  final BleService _service;

  Future<void> connect(String deviceId) => _service.connect(deviceId);

  Future<void> disconnect() => _service.disconnect();

  Future<void> startScan() => _service.startScan();

  Future<void> stopScan() => _service.stopScan();

  Stream<Uint8List> get packetStream => _service.packetStream;

  void Function(String line)? get onDebugLog => _service.onDebugLog;

  set onDebugLog(void Function(String line)? value) {
    _service.onDebugLog = value;
  }

  Future<void> requestBattery() {
    return _service.sendPacket(makeBatteryRequest());
  }

  Future<void> startRealTime(int readingType) {
    return _service.sendPacket(makeStartRealTimeRequest(readingType));
  }

  Future<void> stopRealTime(int readingType) {
    return _service.sendPacket(makeStopRealTimeRequest(readingType));
  }

  Future<void> requestHrLog(DateTime day) {
    return _service.sendPacket(makeHrLogRequest(day));
  }

  Future<void> queryHrLogSettings() {
    return _service.sendPacket(makeHrLogSettingsQuery());
  }

  Future<void> setHrLogSettings(HrLogSettings settings) {
    return _service.sendPacket(makeHrLogSettingsSet(settings));
  }

  Future<void> requestSteps(DateTime day) {
    return _service.sendPacket(makeStepsRequest(day));
  }

  Future<void> startAccelerometer() {
    return _service.sendPacket(makeAccelerometerStartRequest());
  }

  Future<void> stopAccelerometer() {
    return _service.sendPacket(makeAccelerometerStopRequest());
  }

  Future<void> syncTime() {
    return _service.sendPacket(makeSetTimePacket());
  }

  Future<void> blinkTwice() {
    return _service.sendPacket(makeBlinkTwicePacket());
  }

  Future<void> reboot() {
    return _service.sendPacket(makeRebootPacket());
  }
}
