import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemScrollService {
  const SystemScrollService();

  static const MethodChannel _channel = MethodChannel('openring/system_scroll');

  Future<void> scrollVertical(int wheelDelta) async {
    await _channel.invokeMethod<void>('scrollVertical', wheelDelta);
  }
}

final systemScrollServiceProvider = Provider<SystemScrollService>((ref) {
  return const SystemScrollService();
});
