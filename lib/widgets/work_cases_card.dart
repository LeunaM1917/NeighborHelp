import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../services/marketplace_service.dart';
import 'work_completion_card.dart';

class WorkCasesCard extends StatefulWidget {
  const WorkCasesCard({
    super.key,
    required this.booking,
    required this.viewerId,
  });
  final Booking booking;
  final String viewerId;
  @override
  State<WorkCasesCard> createState() => _WorkCasesCardState();
}

class _WorkCasesCardState extends State<WorkCasesCard> {
  bool _busy = false;
  Future<void> _report(String type) async {
    final reason = await askRecordedReason(
      context,
      context.tr('Explain the work concern'),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await MarketplaceService.command('workCaseCommand', {
        'action': 'report',
        'bookingId': widget.booking.bookingId,
        'type': type,
        'reason': reason,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not submit the follow-up. Retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.booking.contractId == null) return const SizedBox.shrink();
    final b = widget.booking, now = DateTime.now();
    final noShow =
        b.isAccepted &&
        !now.isBefore(b.scheduledStart.add(const Duration(hours: 1)));
    final overdue =
        b.isAwaitingConfirmation &&
        b.completionResponseDueAt != null &&
        !now.isBefore(b.completionResponseDueAt!.toDate());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Work follow-ups'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(context.tr('Work follow-up notice')),
            if (noShow)
              OutlinedButton(
                onPressed: _busy ? null : () => _report('no_show'),
                child: Text(context.tr('Report a no-show')),
              ),
            if (overdue)
              OutlinedButton(
                onPressed: _busy ? null : () => _report('completion_overdue'),
                child: Text(context.tr('Request overdue completion review')),
              ),
            if (b.isInProgress &&
                b.correctionRequest != null &&
                b.correctionRequestedAt != null &&
                !now.isBefore(
                  b.correctionRequestedAt!.toDate().add(
                    const Duration(hours: 72),
                  ),
                ))
              OutlinedButton(
                onPressed: _busy ? null : () => _report('corrections_overdue'),
                child: Text(context.tr('Request overdue correction review')),
              ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('workCases')
                  .where('bookingId', isEqualTo: b.bookingId)
                  .where('participantIds', arrayContains: widget.viewerId)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text(
                    'Could not load work follow-ups. Check your connection and retry.',
                  );
                }
                final cases = snap.data?.docs ?? [];
                if (cases.isEmpty) {
                  return const Text(
                    'No work follow-ups recorded. An administrator can review overdue responses or a reported no-show. A missing start record does not by itself prove someone failed to attend.',
                  );
                }
                return Column(
                  children: [
                    for (final record in cases)
                      ExpansionTile(
                        title: Text(
                          '${record.data()['type'].toString().replaceAll('_', ' ')} · ${record.data()['status']}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              '${record.data()['reason']}\n${record.data()['decision'] ?? ''}\n${record.data()['notes'] ?? ''}',
                            ),
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: record.reference
                                .collection('events')
                                .orderBy('createdAt')
                                .snapshots(),
                            builder: (context, events) => Column(
                              children: [
                                for (final event in events.data?.docs ?? [])
                                  ListTile(
                                    title: Text('${event.data()['decision']}'),
                                    subtitle: Text('${event.data()['notes']}'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
