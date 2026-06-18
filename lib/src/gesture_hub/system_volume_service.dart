import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemVolumeService {
  const SystemVolumeService();

  static const MethodChannel _channel = MethodChannel('openring/system_volume');

  Future<double> getVolume() async {
    final value = await _channel.invokeMethod<double>('getVolume');
    return (value ?? 0).clamp(0.0, 1.0).toDouble();
  }

  Future<double> setVolume(double volume) async {
    final next = volume.clamp(0.0, 1.0).toDouble();
    final value = await _channel.invokeMethod<double>('setVolume', next);
    return (value ?? next).clamp(0.0, 1.0).toDouble();
  }
}

final systemVolumeServiceProvider = Provider<SystemVolumeService>((ref) {
  return const SystemVolumeService();
});
