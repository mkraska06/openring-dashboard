import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/ui/scan_page.dart';

void main() {
  runApp(
    // ProviderScope is required for Riverpod to work.
    const ProviderScope(
      child: OpenRingApp(),
    ),
  );
}

class OpenRingApp extends StatelessWidget {
  const OpenRingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenRing',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ScanPage(),
    );
  }
}
