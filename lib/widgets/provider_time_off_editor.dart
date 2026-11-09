import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/marketplace_service.dart';

class ProviderTimeOffEditor extends StatefulWidget {
  const ProviderTimeOffEditor({super.key, required this.providerId});
  final String providerId;
  @override
  State<ProviderTimeOffEditor> createState() => _ProviderTimeOffEditorState();
}

class _ProviderTimeOffEditorState extends State<ProviderTimeOffEditor> {
  bool _busy = false;
  Future<void> _command(Map<String, dynamic> data) async {
    setState(() => _busy = true);
    try {
      await MarketplaceService.command('providerTimeOff', data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Time off (whole days, Manila time)',
    );
    if (range == null || !mounted) return;
    DateTime manila(DateTime d) =>
        DateTime.utc(d.year, d.month, d.day).subtract(const Duration(hours: 8));
    await _command({
      'action': 'add',
      'blockId': FirebaseFirestore.instance
          .collection('serviceProviders')
          .doc()
          .id,
      'start': manila(range.start).millisecondsSinceEpoch,
      'end': manila(
        range.end.add(const Duration(days: 1)),
      ).millisecondsSinceEpoch,
      'label': '',
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Date-specific time off',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Block holidays, leave or emergencies. Choose up to 90 days per period, within the next year. Accepted jobs must be amended or cancelled first. Customers see unavailable dates, without a private reason.',
        ),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('serviceProviders')
              .doc(widget.providerId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text(
                'Could not load time off. Reopen availability to retry.',
              );
            }
            if (!snap.hasData) {
              return const LinearProgressIndicator(
                semanticsLabel: 'Loading time off',
              );
            }
            final blocks = (snap.data!.data()?['timeOff'] as List? ?? [])
                .map((b) => Map<String, dynamic>.from(b as Map))
                .where(
                  (b) =>
                      (b['end'] as Timestamp).toDate().isAfter(DateTime.now()),
                )
                .toList();
            String day(Timestamp t) => DateFormat.yMMMd().format(
              t.toDate().toUtc().add(const Duration(hours: 8)),
            );
            return Column(
              children: [
                for (final b in blocks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${day(b['start'] as Timestamp)} – ${day(Timestamp.fromMillisecondsSinceEpoch((b['end'] as Timestamp).millisecondsSinceEpoch - 1))}',
                    ),
                    subtitle: const Text('Unavailable, Manila time'),
                    trailing: IconButton(
                      tooltip: 'Remove this time off period',
                      onPressed: _busy
                          ? null
                          : () => _command({
                              'action': 'remove',
                              'blockId': b['id'],
                            }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            );
          },
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _add,
          icon: const Icon(Icons.event_busy),
          label: Text(_busy ? 'Saving time off…' : 'Add time off'),
        ),
      ],
    ),
  );
}
