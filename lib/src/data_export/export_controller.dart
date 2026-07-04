import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'export_formatter.dart';
import 'export_models.dart';
import 'export_repository.dart';

class DataExportState {
  const DataExportState({
    this.isExporting = false,
    this.lastFilePath,
    this.lastRowCount,
    this.error,
  });

  final bool isExporting;
  final String? lastFilePath;
  final int? lastRowCount;
  final String? error;

  DataExportState copyWith({
    bool? isExporting,
    String? lastFilePath,
    bool clearLastFilePath = false,
    int? lastRowCount,
    bool clearLastRowCount = false,
    String? error,
    bool clearError = false,
  }) {
    return DataExportState(
      isExporting: isExporting ?? this.isExporting,
      lastFilePath: clearLastFilePath
          ? null
          : (lastFilePath ?? this.lastFilePath),
      lastRowCount: clearLastRowCount
          ? null
          : (lastRowCount ?? this.lastRowCount),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DataExportNotifier extends StateNotifier<DataExportState> {
  DataExportNotifier(this._repository) : super(const DataExportState());

  final ExportRepository _repository;

  Future<void> export(ExportRequest request) async {
    if (request.types.isEmpty) {
      state = state.copyWith(error: 'Select at least one data type.');
      return;
    }
    if (!request.endExclusive.isAfter(request.start)) {
      state = state.copyWith(error: 'End date must be after start date.');
      return;
    }

    state = state.copyWith(
      isExporting: true,
      clearError: true,
      clearLastFilePath: true,
      clearLastRowCount: true,
    );

    try {
      final bundle = await _repository.load(request);
      final contents = formatExportBundle(bundle, request.format);
      final file = await _createExportFile(request);
      await file.writeAsString(contents);
      state = state.copyWith(
        isExporting: false,
        lastFilePath: file.path,
        lastRowCount: bundle.rowCount,
      );
    } catch (e) {
      state = state.copyWith(isExporting: false, error: 'Export failed: $e');
    }
  }

  Future<File> _createExportFile(ExportRequest request) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'OpenRing', 'exports'));
    await dir.create(recursive: true);
    final timestamp = _fileTimestamp(DateTime.now());
    return File(
      p.join(
        dir.path,
        'openring_export_$timestamp.${request.format.extension}',
      ),
    );
  }

  String _fileTimestamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}

final dataExportProvider =
    StateNotifierProvider<DataExportNotifier, DataExportState>((ref) {
      return DataExportNotifier(ref.watch(exportRepositoryProvider));
    });
