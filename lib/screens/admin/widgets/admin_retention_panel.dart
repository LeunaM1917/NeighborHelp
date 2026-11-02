import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../../constants/functions_config.dart';

class AdminRetentionPanel extends StatefulWidget {
  const AdminRetentionPanel({super.key});
  @override
  State<AdminRetentionPanel> createState() => _AdminRetentionPanelState();
}

class _AdminRetentionPanelState extends State<AdminRetentionPanel> {
  String _collection = 'bookings';
  bool _archived = false, _busy = false;
  final _selected = <String>{};
  Future<void> _apply() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _archived ? 'Restore selected records' : 'Archive selected records',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_selected.length} records. Archiving keeps the records and their links intact. It does not delete personal data.',
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason (at least 10 characters)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_archived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: kNeighborHelpFunctionsRegion,
      ).httpsCallable('adminDataOperation').call({
        'action': _archived ? 'restore' : 'archive',
        'collection': _collection,
        'ids': _selected.toList(),
        'reason': reason,
      });
      if (mounted) setState(_selected.clear);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Could not update retention status.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Record retention',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const Text(
        'Archive closed/read records last updated at least 180 days ago. Archives remain available for reporting and investigation. Restore them here when needed.',
      ),
      Wrap(
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: _collection,
            items: [
              for (final name in [
                'bookings',
                'notifications',
                'bookingUserReports',
              ])
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _collection = v!;
                    _selected.clear();
                  }),
          ),
          FilterChip(
            label: const Text('Show archived'),
            selected: _archived,
            onSelected: _busy
                ? null
                : (v) => setState(() {
                    _archived = v;
                    _selected.clear();
                  }),
          ),
          FilledButton(
            onPressed: _busy || _selected.isEmpty ? null : _apply,
            child: Text(_archived ? 'Restore selected' : 'Archive selected'),
          ),
        ],
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(_collection).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Text(
              'Could not load retention records. Check administrator access.',
            );
          }
          if (!snap.hasData) return const LinearProgressIndicator();
          final records = snap.data!.docs
              .where((d) {
                final row = d.data();
                if ((row['archived'] == true) != _archived) return false;
                if (_archived) return true;
                final date =
                    (row['updatedAt'] ?? row['createdAt']) as Timestamp?;
                final status = '${row['status']}'.toLowerCase();
                final closed = _collection == 'bookings'
                    ? [
                        'completed',
                        'milestone complete',
                        'cancelled',
                        'declined',
                      ].contains(status)
                    : _collection == 'bookingUserReports'
                    ? ['resolved', 'dismissed', 'closed'].contains(status)
                    : row['isRead'] == true;
                return closed &&
                    date != null &&
                    date.toDate().isBefore(
                      DateTime.now().subtract(const Duration(days: 180)),
                    );
              })
              .take(50)
              .toList();
          if (records.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _archived
                    ? 'No archived records.'
                    : 'No closed/read records are eligible for archiving.',
              ),
            );
          }
          return Column(
            children: [
              for (final d in records)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(d.id),
                  title: Text(
                    d.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${d.data()['status'] ?? d.data()['title'] ?? ''}',
                  ),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          if (v == true) {
                            _selected.add(d.id);
                          } else {
                            _selected.remove(d.id);
                          }
                        }),
                ),
            ],
          );
        },
      ),
    ],
  );
}
