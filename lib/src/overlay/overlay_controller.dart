import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'overlay_state.dart';

class OverlayController {
  OverlayController(this._ref);

  final Ref _ref;

  static const _fullSize = Size(1280, 720);
  static const _overlaySize = Size(200, 170);

  bool _hotkeysRegistered = false;

  Offset _savedFullPosition = const Offset(100, 100);

  SystemTray? _systemTray;

  final _hotkeyToggleOverlay = HotKey(
    key: PhysicalKeyboardKey.keyO,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  final _hotkeyToggleInteractive = HotKey(
    key: PhysicalKeyboardKey.keyL,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  OverlaySettingsNotifier get _notifier =>
      _ref.read(overlaySettingsProvider.notifier);

  OverlaySettings get _settings => _ref.read(overlaySettingsProvider);

  Future<void> activateOverlay() async {
    _savedFullPosition = await windowManager.getPosition();

    // Switch to overlay widget FIRST — it handles any size gracefully.
    // This avoids the ScanPage being squeezed during the shrink.
    _notifier.activate();

    // Loosen constraints, then shrink, then lock.
    await windowManager.setMinimumSize(const Size(0, 0));
    await windowManager.setMaximumSize(const Size(4096, 4096));
    await windowManager.setSize(_overlaySize);
    await windowManager.setMinimumSize(_overlaySize);
    await windowManager.setMaximumSize(_overlaySize);
    await windowManager.setResizable(false);

    await windowManager.setPosition(_settings.position);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await _applyOverlayOpacity();
    await windowManager.setHasShadow(false);
    await windowManager.setIgnoreMouseEvents(true);
    await _applyOverlayOpacity();

    await _initSystemTray();
    await _registerInteractiveHotkey();
  }

  Future<void> deactivateOverlay() async {
    // Save overlay position before leaving.
    final pos = await windowManager.getPosition();
    _notifier.updatePosition(pos);

    await windowManager.setIgnoreMouseEvents(false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setOpacity(1.0);
    await windowManager.setHasShadow(true);

    // Grow the window FIRST, then switch to ScanPage.
    // This avoids the ScanPage being rendered in a tiny window.
    await windowManager.setMinimumSize(const Size(0, 0));
    await windowManager.setMaximumSize(const Size(4096, 4096));
    await windowManager.setSize(_fullSize);
    await windowManager.setPosition(_savedFullPosition);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(400, 300));

    // Wait for the window resize to take effect before switching widgets.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    _notifier.deactivate();
    await _disposeSystemTray();
    await _unregisterInteractiveHotkey();
  }

  Future<void> toggleOverlay() async {
    if (_settings.isActive) {
      await deactivateOverlay();
    } else {
      await activateOverlay();
    }
  }

  Future<void> toggleInteractive() async {
    if (!_settings.isActive) return;

    _notifier.toggleInteractive();
    final nowInteractive = _settings.isInteractive;

    await windowManager.setIgnoreMouseEvents(!nowInteractive);
    await _applyOverlayOpacity();

    if (!nowInteractive) {
      // Leaving interactive mode — save position and re-enforce size.
      final pos = await windowManager.getPosition();
      _notifier.updatePosition(pos);
      await _enforceOverlaySize();
      await _applyOverlayOpacity();
    }
  }

  /// Re-enforce the overlay size constraints after a drag.
  Future<void> _enforceOverlaySize() async {
    await windowManager.setMinimumSize(_overlaySize);
    await windowManager.setMaximumSize(_overlaySize);
    await windowManager.setSize(_overlaySize);
  }

  Future<void> _applyOverlayOpacity() async {
    await windowManager.setOpacity(_settings.opacity);
  }

  Future<void> startDrag() async {
    await windowManager.startDragging();
    await _applyOverlayOpacity();
  }

  Future<void> saveCurrentPosition() async {
    final pos = await windowManager.getPosition();
    _notifier.updatePosition(pos);
    await _applyOverlayOpacity();
  }

  // -- System Tray ------------------------------------------------------------

  Future<void> _initSystemTray() async {
    try {
      _systemTray = SystemTray();

      // system_tray on Windows needs an absolute path to a valid .ico file.
      // The icon is bundled as a Flutter asset and lands under
      // <exe_dir>/data/flutter_assets/assets/app_icon.ico at runtime.
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final iconPath =
          '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets${Platform.pathSeparator}app_icon.ico';

      if (!File(iconPath).existsSync()) {
        debugPrint('System tray: icon not found at $iconPath, skipping');
        _systemTray = null;
        return;
      }

      await _systemTray!.initSystemTray(
        iconPath: iconPath,
        toolTip: 'OpenRing Overlay',
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Open main window',
          onClicked: (_) => deactivateOverlay(),
        ),
        MenuItemLabel(
          label: 'Position bearbeiten',
          onClicked: (_) => toggleInteractive(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Quit',
          onClicked: (_) async {
            await deactivateOverlay();
            await windowManager.close();
          },
        ),
      ]);
      await _systemTray!.setContextMenu(menu);

      _systemTray!.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick ||
            eventName == kSystemTrayEventRightClick) {
          _systemTray!.popUpContextMenu();
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize system tray: $e');
      _systemTray = null;
    }
  }

  Future<void> _disposeSystemTray() async {
    try {
      await _systemTray?.destroy();
    } catch (e) {
      debugPrint('Failed to dispose system tray: $e');
    }
    _systemTray = null;
  }

  // -- Hotkeys ----------------------------------------------------------------

  Future<void> registerGlobalHotkeys() async {
    if (_hotkeysRegistered) return;
    _hotkeysRegistered = true;
    try {
      await hotKeyManager.register(
        _hotkeyToggleOverlay,
        keyDownHandler: (_) => toggleOverlay(),
      );
    } catch (e) {
      debugPrint('Failed to register overlay toggle hotkey: $e');
    }
  }

  Future<void> _registerInteractiveHotkey() async {
    try {
      await hotKeyManager.register(
        _hotkeyToggleInteractive,
        keyDownHandler: (_) => toggleInteractive(),
      );
    } catch (e) {
      debugPrint('Failed to register interactive toggle hotkey: $e');
    }
  }

  Future<void> _unregisterInteractiveHotkey() async {
    try {
      await hotKeyManager.unregister(_hotkeyToggleInteractive);
    } catch (e) {
      debugPrint('Failed to unregister interactive toggle hotkey: $e');
    }
  }
}

final overlayControllerProvider = Provider<OverlayController>((ref) {
  return OverlayController(ref);
});
