import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../figma_ui/figma_colors.dart';
import '../../../services/marketplace_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_widgets.dart';

class AdminWorkCasesPage extends StatefulWidget {
  const AdminWorkCasesPage({super.key});
  @override
  State<AdminWorkCasesPage> createState() => _AdminWorkCasesPageState();
}

class _AdminWorkCasesPageState extends State<AdminWorkCasesPage> {
  bool _busy = false, _closed = false;
  Future<void> _review(
    QueryDocumentSnapshot<Map<String, dynamic>> record,
  ) async {
    final booking = await FirebaseFirestore.instance
        .doc('bookings/${record.data()['bookingId']}')
        .get();
    if (!mounted) return;
    final notes = TextEditingController(), form = GlobalKey<FormState>();
    String decision = 'Discussed with parties';
    final answer = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Review unresolved work'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(
                      'Booking: ${record.data()['bookingId']}\nCurrent status: ${booking.data()?['status']}\nConcern: ${record.data()['type']}\n${record.data()['reason']}\n\nCustomer: ${record.data()['customerId']}\nProvider: ${record.data()['providerId']}',
                    ),
                    const Text(
                      'Review evidence with both parties. Missing start or response records are signals to investigate, not proof of fault. Administrative review cannot confirm job completion, acknowledge money or decide legal liability for a party.',
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: decision,
                      isExpanded: true,
                      items: [
                        for (final label in [
                          'Discussed with parties',
                          'No-show confirmed',
                          'Insufficient evidence',
                          'Cancelled after review',
                          'Other',
                        ])
                          DropdownMenuItem(value: label, child: Text(label)),
                      ],
                      onChanged: (value) => setLocal(() => decision = value!),
                      decoration: const InputDecoration(
                        labelText: 'Recorded outcome',
                      ),
                    ),
                    if (decision == 'Cancelled after review')
                      const Text(
                        'Resolving with this outcome cancels an accepted or ongoing booking. Contract and payment evidence remain. The parties must agree any final fee and refund separately.',
                      ),
                    TextFormField(
                      controller: notes,
                      maxLines: 5,
                      maxLength: 3000,
                      decoration: const InputDecoration(
                        labelText: 'Evidence reviewed, decision and reasons',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 10
                          ? 'Record at least 10 characters'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            OutlinedButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'action': 'review',
                    'notes': notes.text.trim(),
                  });
                }
              },
              child: const Text('Mark reviewing'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'action': 'resolve',
                    'decision': decision,
                    'notes': notes.text.trim(),
                  });
                }
              },
              child: const Text('Resolve with recorded outcome'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), notes.dispose);
    if (answer == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await MarketplaceService.command('workCaseCommand', {
        'caseId': record.id,
        ...answer,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not record the review. Retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPageFrame(
    useDashboardChrome: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminDashboardHeader(
          title: 'Unresolved work',
          subtitle:
              'Overdue completion/corrections and unconfirmed starts appear here. No-shows reported by participants also appear. Reminders never auto-complete work or impose financial penalties.',
        ),
        const SizedBox(height: 24),
        AdminPanelCard(
          title: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Show resolved cases',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: FigmaColors.gray700,
                    ),
                  ),
                  value: _closed,
                  onChanged: (value) => setState(() => _closed = value),
                ),
              ),
              const Divider(height: 1, color: FigmaColors.gray200),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('workCases')
                    .where(
                      'status',
                      whereIn: _closed ? ['resolved'] : ['open', 'reviewing'],
                    )
                    .orderBy('createdAt', descending: true)
                    .limit(200)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const AdminErrorBox(
                      message:
                          'Could not load follow-ups. Check your access, connection and deployed indexes.',
                    );
                  }
                  if (!snap.hasData) {
                    return const AdminLoadingBox();
                  }
                  if (snap.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No matching work follow-ups.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: FigmaColors.gray500,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final record in snap.data!.docs)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: FigmaColors.gray200),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    record.data()['type'].toString().replaceAll(
                                      '_',
                                      ' ',
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: FigmaColors.gray900,
                                    ),
                                  ),
                                  AdminStatusChip(
                                    status: record.data()['status'].toString(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Booking ${record.data()['bookingId']}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: FigmaColors.gray700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${record.data()['reason']}\n${record.data()['decision'] ?? ''}\n${record.data()['notes'] ?? ''}'
                                    .trim(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: FigmaColors.gray600,
                                  height: 1.5,
                                ),
                              ),
                              if (!_closed) ...[
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _review(record),
                                    child: const Text('Review'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
