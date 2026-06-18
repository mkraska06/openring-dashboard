import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemMouseService {
  const SystemMouseService();

  static const MethodChannel _channel = MethodChannel('openring/system_mouse');

  Future<void> moveRelative({required int dx, required int dy}) async {
    await _channel.invokeMethod<void>('moveRelative', {'dx': dx, 'dy': dy});
  }

  Future<void> leftClick() async {
    await _channel.invokeMethod<void>('leftClick');
  }
}

final systemMouseServiceProvider = Provider<SystemMouseService>((ref) {
  return const SystemMouseService();
});
