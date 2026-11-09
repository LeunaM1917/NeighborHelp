import '../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/marketplace_service.dart';

Future<String?> askRecordedReason(BuildContext context, String title) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLines: 4,
        maxLength: 3000,
        decoration:  InputDecoration(
          labelText: context.tr('Explain in at least 10 characters'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.tr('Back')),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().length >= 10) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: Text(context.tr('Continue')),
        ),
      ],
    ),
  );
  // Dialog route animations may still reference its controller.
  Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}

class WorkCompletionCard extends StatefulWidget {
  const WorkCompletionCard({
    super.key,
    required this.booking,
    required this.asCustomer,
  });
  final Booking booking;
  final bool asCustomer;
  @override
  State<WorkCompletionCard> createState() => _WorkCompletionCardState();
}

class _WorkCompletionCardState extends State<WorkCompletionCard> {
  bool _busy = false;
  Future<void> _respond(bool confirm) async {
    String? reason;
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('Confirm the work is complete?')),
          content: Text(context.tr('Inspect the deliverables and completion criteria in your agreement. Confirmation unlocks reviews. Payment receipt is recorded separately and your legal remedies remain available.')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Back')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('Confirm deliverables complete')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      reason = await askRecordedReason(context, 'What needs correction?');
      if (reason == null) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await MarketplaceService.command('bookingCommand', {
        'action': confirm ? 'confirmCompletion' : 'requestCorrections',
        'bookingId': widget.booking.bookingId,
        'confirmDeliverables': confirm,
        if (reason != null) 'reason': reason,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not record your response. Retry.',
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
    final b = widget.booking;
    if (!b.isAwaitingConfirmation && (b.correctionRequest?.isEmpty ?? true)) {
      return const SizedBox.shrink();
    }
    final due = b.completionResponseDueAt?.toDate().toUtc().add(
      const Duration(hours: 8),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              b.isAwaitingConfirmation
                  ? 'Work reported finished'
                  : 'Corrections requested',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (b.correctionRequest != null) Text(b.correctionRequest!),
            if (b.isAwaitingConfirmation) ...[
              Text(
                widget.asCustomer
                    ? 'Inspect the agreed work, then confirm completion or explain what needs correction.'
                    : 'Waiting for the customer to inspect and confirm the work.',
              ),
              if (due != null)
                Text(
                  '${context.tr('Please respond by')} ${DateFormat('MMM d, yyyy h:mm a').format(due)} (Asia/Manila). ${context.tr('Overdue review notice')}',
                ),
              if (widget.asCustomer) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : () => _respond(true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(context.tr('Confirm work complete')),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _respond(false),
                  child: Text(context.tr('Request corrections')),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
