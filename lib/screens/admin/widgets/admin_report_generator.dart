import 'package:flutter/material.dart';
import '../../../models/admin_report.dart';
import '../../../services/export_service.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_widgets.dart';

class AdminReportGenerator extends StatefulWidget {
  const AdminReportGenerator({super.key, required this.result});
  final AdminReportResult result;
  @override
  State<AdminReportGenerator> createState() => _AdminReportGeneratorState();
}

class _AdminReportGeneratorState extends State<AdminReportGenerator> {
  bool _exporting = false;
  int _page = 0;
  @override
  void didUpdateWidget(covariant AdminReportGenerator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.result, oldWidget.result)) _page = 0;
  }

  Future<void> _export(String format) async {
    final snapshot = widget.result;
    setState(() => _exporting = true);
    await ExportService.exportReport(context, snapshot, format: format);
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.result;
    final columns = report.rows.isEmpty
        ? <String>[]
        : report.rows.first.keys.toList();
    const pageSize = 10;
    final start = _page * pageSize;
    return AdminPanelCard(
      title: 'Report generation',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              report.type.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(report.period.label),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                for (final entry in report.summary.entries)
                  Text(
                    '${entry.key}: ${entry.value is double ? (entry.value as double).toStringAsFixed(2) : entry.value ?? '—'}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final format in ['pdf', 'csv', 'json'])
                  OutlinedButton.icon(
                    onPressed: _exporting || report.rows.isEmpty
                        ? null
                        : () => _export(format),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text('Export ${format.toUpperCase()}'),
                  ),
              ],
            ),
            if (_exporting) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            if (report.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No records match the selected filters.'),
              )
            else ...[
              AdminHorizontalScrollTable(
                minTableWidth: 900,
                child: DataTable(
                  columns: [
                    for (final key in columns) DataColumn(label: Text(key)),
                  ],
                  rows: [
                    for (final row in report.rows.skip(start).take(pageSize))
                      DataRow(
                        cells: [
                          for (final key in columns)
                            DataCell(
                              SelectableText(
                                row[key] is double
                                    ? (row[key] as double).toStringAsFixed(2)
                                    : '${row[key] ?? '—'}',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    '${start + 1}–${(start + pageSize).clamp(0, report.rows.length)} of ${report.rows.length} records',
                  ),
                  IconButton(
                    tooltip: 'Previous records',
                    onPressed: _page > 0 ? () => setState(() => _page--) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next records',
                    onPressed: start + pageSize < report.rows.length
                        ? () => setState(() => _page++)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Exports include every matching record. Verification reports show current status by verification update date, with registration date as a legacy fallback. Feedback excludes free-text comments and private identity details.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
