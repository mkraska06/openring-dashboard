import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'src/overlay/overlay_controller.dart';
import 'src/overlay/overlay_state.dart';
import 'src/overlay/overlay_widget.dart';
import 'src/ui/scan_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    center: true,
    // Start with hidden title bar to avoid runtime changes that crash on
    // Windows.  The full-mode UI provides its own custom title bar via
    // DragToMoveArea.
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: OpenRingApp(),
    ),
  );
}

class OpenRingApp extends ConsumerStatefulWidget {
  const OpenRingApp({super.key});

  @override
  ConsumerState<OpenRingApp> createState() => _OpenRingAppState();
}

class _OpenRingAppState extends ConsumerState<OpenRingApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(overlayControllerProvider).registerGlobalHotkeys();
      } catch (e) {
        debugPrint('Hotkey registration failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final overlayActive = ref.watch(
      overlaySettingsProvider.select((s) => s.isActive),
    );

    return MaterialApp(
      title: 'OpenRing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: overlayActive ? const OverlayWidget() : const ScanPage(),
    );
  }
}
