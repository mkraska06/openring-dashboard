import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'export_controller.dart';
import 'export_models.dart';

class DataExportCard extends ConsumerStatefulWidget {
  const DataExportCard({super.key});

  @override
  ConsumerState<DataExportCard> createState() => _DataExportCardState();
}

class _DataExportCardState extends ConsumerState<DataExportCard> {
  late DateTime _startDay;
  late DateTime _endDay;
  ExportFormat _format = ExportFormat.csv;
  Set<ExportDataType> _types = Set.of(ExportDataType.values);

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _startDay = today.subtract(const Duration(days: 6));
    _endDay = today;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataExportProvider);
    final notifier = ref.read(dataExportProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.file_download_outlined),
                const SizedBox(width: 8),
                Text('Data export', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: state.isExporting
                      ? null
                      : () => _pickStartDay(context),
                  icon: const Icon(Icons.event),
                  label: Text('From ${_formatDay(_startDay)}'),
                ),
                OutlinedButton.icon(
                  onPressed: state.isExporting
                      ? null
                      : () => _pickEndDay(context),
                  icon: const Icon(Icons.event_available),
                  label: Text('To ${_formatDay(_endDay)}'),
                ),
                SegmentedButton<ExportFormat>(
                  segments: [
                    for (final format in ExportFormat.values)
                      ButtonSegment(value: format, label: Text(format.label)),
                  ],
                  selected: {_format},
                  showSelectedIcon: false,
                  onSelectionChanged: state.isExporting
                      ? null
                      : (selection) {
                          setState(() => _format = selection.single);
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in ExportDataType.values)
                  FilterChip(
                    label: Text(type.label),
                    selected: _types.contains(type),
                    onSelected: state.isExporting
                        ? null
                        : (selected) {
                            setState(() {
                              final next = Set<ExportDataType>.from(_types);
                              if (selected) {
                                next.add(type);
                              } else {
                                next.remove(type);
                              }
                              _types = next;
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: state.isExporting
                    ? null
                    : () => notifier.export(
                        ExportRequest(
                          start: _startDay,
                          endExclusive: _endDay.add(const Duration(days: 1)),
                          types: _types,
                          format: _format,
                        ),
                      ),
                icon: state.isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(state.isExporting ? 'Exporting...' : 'Export'),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (state.lastFilePath != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                'Saved ${state.lastRowCount ?? 0} rows to ${state.lastFilePath}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDay(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDay,
      firstDate: DateTime(2020),
      lastDate: _endDay,
    );
    if (selected == null) return;
    setState(() => _startDay = _dateOnly(selected));
  }

  Future<void> _pickEndDay(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDay,
      firstDate: _startDay,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() => _endDay = _dateOnly(selected));
  }

  DateTime _dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

  String _formatDay(DateTime day) {
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }
}
