import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'export_formatter.dart';
import 'export_models.dart';
import 'export_repository.dart';

typedef DirectoryPicker = Future<String?> Function();
typedef NowProvider = DateTime Function();

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
  DataExportNotifier(
    this._repository, {
    DirectoryPicker? chooseDirectory,
    NowProvider? now,
  }) : _chooseDirectory = chooseDirectory ?? _defaultChooseDirectory,
       _now = now ?? DateTime.now,
       super(const DataExportState());

  final ExportRepository _repository;
  final DirectoryPicker _chooseDirectory;
  final NowProvider _now;

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
      final directoryPath = await _chooseDirectory();
      if (directoryPath == null) {
        state = state.copyWith(isExporting: false);
        return;
      }

      final bundle = await _repository.load(request);
      final contents = formatExportBundle(bundle, request.format);
      final file = await _createExportFile(request, directoryPath);
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

  Future<File> _createExportFile(
    ExportRequest request,
    String directoryPath,
  ) async {
    final dir = Directory(directoryPath);
    await dir.create(recursive: true);
    final timestamp = _fileTimestamp(_now());
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

  static Future<String?> _defaultChooseDirectory() {
    return getDirectoryPath(confirmButtonText: 'Export');
  }
}

final dataExportProvider =
    StateNotifierProvider<DataExportNotifier, DataExportState>((ref) {
      return DataExportNotifier(ref.watch(exportRepositoryProvider));
    });
