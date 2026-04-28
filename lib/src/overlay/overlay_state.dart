import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OverlaySettings {
  final bool isActive;
  final bool isInteractive; // false = click-through, true = draggable
  final Offset position;
  final double opacity;
  final bool showHr;
  final bool showSpo2;
  final bool showBattery;
  final bool showSteps;
  final int hrHighThreshold;
  final int spo2LowThreshold;

  const OverlaySettings({
    this.isActive = false,
    this.isInteractive = false,
    this.position = const Offset(100, 100),
    this.opacity = 1.0,
    this.showHr = true,
    this.showSpo2 = true,
    this.showBattery = true,
    this.showSteps = true,
    this.hrHighThreshold = 120,
    this.spo2LowThreshold = 95,
  });

  OverlaySettings copyWith({
    bool? isActive,
    bool? isInteractive,
    Offset? position,
    double? opacity,
    bool? showHr,
    bool? showSpo2,
    bool? showBattery,
    bool? showSteps,
    int? hrHighThreshold,
    int? spo2LowThreshold,
  }) {
    return OverlaySettings(
      isActive: isActive ?? this.isActive,
      isInteractive: isInteractive ?? this.isInteractive,
      position: position ?? this.position,
      opacity: opacity ?? this.opacity,
      showHr: showHr ?? this.showHr,
      showSpo2: showSpo2 ?? this.showSpo2,
      showBattery: showBattery ?? this.showBattery,
      showSteps: showSteps ?? this.showSteps,
      hrHighThreshold: hrHighThreshold ?? this.hrHighThreshold,
      spo2LowThreshold: spo2LowThreshold ?? this.spo2LowThreshold,
    );
  }
}

class OverlaySettingsNotifier extends StateNotifier<OverlaySettings> {
  OverlaySettingsNotifier() : super(const OverlaySettings()) {
    _loadSettings();
  }

  static const _keyPosX = 'overlay_pos_x';
  static const _keyPosY = 'overlay_pos_y';
  static const _keyOpacity = 'overlay_opacity';
  static const _keyShowHr = 'overlay_show_hr';
  static const _keyShowSpo2 = 'overlay_show_spo2';
  static const _keyShowBattery = 'overlay_show_battery';
  static const _keyShowSteps = 'overlay_show_steps';
  static const _keyHrThreshold = 'overlay_hr_threshold';
  static const _keySpo2Threshold = 'overlay_spo2_threshold';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      position: Offset(
        prefs.getDouble(_keyPosX) ?? 100,
        prefs.getDouble(_keyPosY) ?? 100,
      ),
      opacity: 1.0,
      showHr: prefs.getBool(_keyShowHr) ?? true,
      showSpo2: prefs.getBool(_keyShowSpo2) ?? true,
      showBattery: prefs.getBool(_keyShowBattery) ?? true,
      showSteps: prefs.getBool(_keyShowSteps) ?? true,
      hrHighThreshold: prefs.getInt(_keyHrThreshold) ?? 120,
      spo2LowThreshold: prefs.getInt(_keySpo2Threshold) ?? 95,
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPosX, state.position.dx);
    await prefs.setDouble(_keyPosY, state.position.dy);
    await prefs.setDouble(_keyOpacity, state.opacity);
    await prefs.setBool(_keyShowHr, state.showHr);
    await prefs.setBool(_keyShowSpo2, state.showSpo2);
    await prefs.setBool(_keyShowBattery, state.showBattery);
    await prefs.setBool(_keyShowSteps, state.showSteps);
    await prefs.setInt(_keyHrThreshold, state.hrHighThreshold);
    await prefs.setInt(_keySpo2Threshold, state.spo2LowThreshold);
  }

  void activate() {
    state = state.copyWith(isActive: true, isInteractive: false);
  }

  void deactivate() {
    state = state.copyWith(isActive: false, isInteractive: false);
  }

  void toggleInteractive() {
    state = state.copyWith(isInteractive: !state.isInteractive);
  }

  void updatePosition(Offset position) {
    state = state.copyWith(position: position);
    _saveSettings();
  }

  void setOpacity(double opacity) {
    state = state.copyWith(opacity: opacity.clamp(0.05, 1.0));
    _saveSettings();
  }

  void setShowHr(bool value) {
    state = state.copyWith(showHr: value);
    _saveSettings();
  }

  void setShowSpo2(bool value) {
    state = state.copyWith(showSpo2: value);
    _saveSettings();
  }

  void setShowBattery(bool value) {
    state = state.copyWith(showBattery: value);
    _saveSettings();
  }

  void setShowSteps(bool value) {
    state = state.copyWith(showSteps: value);
    _saveSettings();
  }

  void setHrThreshold(int value) {
    state = state.copyWith(hrHighThreshold: value);
    _saveSettings();
  }

  void setSpo2Threshold(int value) {
    state = state.copyWith(spo2LowThreshold: value);
    _saveSettings();
  }
}

final overlaySettingsProvider =
    StateNotifierProvider<OverlaySettingsNotifier, OverlaySettings>((ref) {
      return OverlaySettingsNotifier();
    });
