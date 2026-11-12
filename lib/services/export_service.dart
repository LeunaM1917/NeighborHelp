import '../ui/app_notification_dialog.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/admin_report.dart';
import '../constants/functions_config.dart';
import '../utils/report_analytics.dart';

Object? exportValue(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is GeoPoint) {
    return {'latitude': value.latitude, 'longitude': value.longitude};
  }
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), exportValue(v)));
  }
  if (value is Iterable) return value.map(exportValue).toList();
  return value;
}

class ExportService {
  static Future<Uint8List> reportBytes(
    AdminReportResult report,
    String format,
  ) async {
    if (format == 'json') {
      return Uint8List.fromList(
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert(report.toJson()),
        ),
      );
    }
    if (format == 'csv') {
      // Keep a conventional rectangular CSV, repeating the reporting context on
      // each record so the file retains filters and summary without special rows.
      final context = <String, Object?>{
        'Report': report.type.label,
        'Timezone': 'Asia/Manila',
        'Period start (inclusive)': reportTimestampText(report.period.start),
        'Period end (exclusive)': reportTimestampText(
          report.period.endExclusive,
        ),
        'Snapshot at': reportTimestampText(report.loadedAt),
        for (final entry in report.filters.entries)
          'Filter: ${entry.key}': entry.value,
        for (final entry in report.summary.entries)
          'Summary: ${entry.key}': entry.value,
      };
      return Uint8List.fromList(
        utf8.encode(
          encodeCsv([
            for (final row in report.rows) {...context, ...row},
          ]),
        ),
      );
    }
    if (format != 'pdf') throw ArgumentError.value(format, 'format');
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final pdf = pw.Document(
      title: 'NeighborHelp - ${report.type.label}',
      author: 'NeighborHelp',
    );
    final columns = report.rows.isEmpty
        ? <String>[]
        : report.rows.first.keys.toList();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        maxPages: (report.rows.length ~/ 10 + 30),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            'NeighborHelp | ${report.type.label}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          pw.Text(report.period.label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'Snapshot: ${reportTimestampText(report.loadedAt)}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            report.filters.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(' | '),
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 10),
          ...report.summary.entries.map(
            (e) => pw.Text(
              '${e.key}: ${e.value is double ? (e.value as double).toStringAsFixed(2) : e.value ?? '—'}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(height: 12),
          if (columns.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headers: columns,
              data: [
                for (final row in report.rows)
                  [for (final key in columns) row[key]?.toString() ?? '—'],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.all(4),
            ),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<void> exportReport(
    BuildContext context,
    AdminReportResult report, {
    required String format,
  }) async {
    try {
      // The existing callable rechecks role, account status, App Check and MFA.
      // Fail closed before generating or writing any report bytes.
      await FirebaseFunctions.instanceFor(
        region: kNeighborHelpFunctionsRegion,
      ).httpsCallable('adminDataOperation').call({
        'action': 'recordExport',
        'collection': report.type.collection,
        'count': report.rows.length,
      });
      final bytes = await reportBytes(report, format);
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Save report',
        fileName:
            'neighborhelp-${report.type.name}-${reportDateText(report.loadedAt)}.$format',
        type: FileType.custom,
        allowedExtensions: [format],
        bytes: bytes,
      );
      if (context.mounted && (saved != null || kIsWeb)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${report.rows.length} records as ${format.toUpperCase()}.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export failed. Check your connection and administrator access, then retry.',
            ),
          ),
        );
      }
    }
  }

  static Future<void> exportCollection(
    BuildContext context,
    String collection, {
    List<Map<String, Object?>>? rows,
    String? label,
  }) async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AppNotificationDialog(
        title: Text(label ?? 'Export $collection'),
        content: Text(
          rows == null
              ? 'Export all records in this collection. CSV and JSON include dates in UTC.'
              : 'Export the displayed ${rows.length} records. Dates are in UTC.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('CSV'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'json'),
            child: const Text('JSON'),
          ),
        ],
      ),
    );
    if (format == null) return;
    try {
      if (rows == null) {
        rows = [];
        QueryDocumentSnapshot<Map<String, dynamic>>? last;
        while (true) {
          Query<Map<String, dynamic>> query = FirebaseFirestore.instance
              .collection(collection)
              .orderBy(FieldPath.documentId)
              .limit(500);
          if (last != null) query = query.startAfterDocument(last);
          final snap = await query.get();
          rows.addAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
          if (snap.docs.length < 500) break;
          last = snap.docs.last;
        }
      }
      final normalized = rows
          .map((r) => r.map((k, v) => MapEntry(k, exportValue(v))))
          .toList();
      final text = format == 'json'
          ? const JsonEncoder.withIndent('  ').convert(normalized)
          : encodeCsv(
              normalized
                  .map(
                    (r) => r.map(
                      (k, v) => MapEntry(
                        k,
                        v is Map || v is List ? jsonEncode(v) : v,
                      ),
                    ),
                  )
                  .toList(),
            );
      await FirebaseFunctions.instanceFor(
        region: kNeighborHelpFunctionsRegion,
      ).httpsCallable('adminDataOperation').call({
        'action': 'recordExport',
        'collection': collection,
        'count': rows.length,
      });
      final fileName =
          'neighborhelp-$collection-${DateTime.now().millisecondsSinceEpoch}.$format';
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Save export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [format],
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
      if (context.mounted && saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${rows.length} records.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export failed. Check your connection and administrator access, then retry.',
            ),
          ),
        );
      }
    }
  }
}
