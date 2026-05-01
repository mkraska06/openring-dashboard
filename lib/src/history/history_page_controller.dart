import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/history_models.dart';
import '../storage/storage_repository.dart';

final historyRefreshTickProvider = StateProvider<int>((ref) => 0);

class HistoryPageState {
  const HistoryPageState({
    required this.selectedDay,
    this.isLoading = false,
    this.historyDay,
    this.error,
  });

  final DateTime selectedDay;
  final bool isLoading;
  final HistoryDay? historyDay;
  final String? error;

  HistoryPageState copyWith({
    DateTime? selectedDay,
    bool? isLoading,
    HistoryDay? historyDay,
    bool clearHistoryDay = false,
    String? error,
    bool clearError = false,
  }) {
    return HistoryPageState(
      selectedDay: selectedDay ?? this.selectedDay,
      isLoading: isLoading ?? this.isLoading,
      historyDay: clearHistoryDay ? null : (historyDay ?? this.historyDay),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HistoryPageNotifier extends StateNotifier<HistoryPageState> {
  HistoryPageNotifier(this._storage, {DateTime? initialDay})
    : super(
        HistoryPageState(
          selectedDay: _dateOnly(initialDay ?? DateTime.now()),
          isLoading: true,
        ),
      ) {
    unawaited(load());
  }

  final OpenRingStorage _storage;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(clearError: true);
    }
    try {
      final historyDay = await _storage.loadHistoryDay(day: state.selectedDay);
      state = state.copyWith(
        isLoading: false,
        historyDay: historyDay,
        clearHistoryDay: historyDay == null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'History konnte nicht geladen werden: $e',
      );
    }
  }

  Future<void> previousDay() {
    return _setDay(state.selectedDay.subtract(const Duration(days: 1)));
  }

  Future<void> nextDay() {
    return _setDay(state.selectedDay.add(const Duration(days: 1)));
  }

  Future<void> today() {
    return _setDay(DateTime.now());
  }

  Future<void> _setDay(DateTime day) async {
    state = state.copyWith(selectedDay: _dateOnly(day), clearHistoryDay: true);
    await load(silent: false);
  }

  static DateTime _dateOnly(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }
}

final historyPageProvider =
    StateNotifierProvider<HistoryPageNotifier, HistoryPageState>((ref) {
      return HistoryPageNotifier(ref.watch(openRingStorageProvider));
    });
