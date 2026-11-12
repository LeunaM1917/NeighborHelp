import '../ui/app_notification_dialog.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
