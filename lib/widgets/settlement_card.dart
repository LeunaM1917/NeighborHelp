import '../ui/workflow_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../services/marketplace_service.dart';
import 'service_agreement_card.dart';

class SettlementCard extends StatefulWidget {
  const SettlementCard({
    super.key,
    required this.bookingId,
    required this.bookingData,
    required this.viewerId,
  });
  final String bookingId, viewerId;
  final Map<String, dynamic> bookingData;
  @override
  State<SettlementCard> createState() => _SettlementCardState();
}

class _SettlementCardState extends State<SettlementCard> {
  bool _busy = false;
  Future<void> _respond(
    String action,
    String id,
    Map<String, dynamic> record,
  ) async {
    if (action == 'accept') {
      final ok = await confirmServiceAgreement(
        context,
        agreement: Map<String, dynamic>.from(record['agreement'] as Map),
        title: context.tr('Final work settlement'),
        confirmation: context.tr(
          'I voluntarily accept this exact settlement record.',
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await MarketplaceService.command('settlementCommand', {
        'action': action,
        'bookingId': widget.bookingId,
        'settlementId': id,
        'acceptAgreement': true,
        'agreementHash': (record['agreement'] as Map)['hash'],
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not record the response. Retry.',
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
    final b = widget.bookingData;
    if (![
      'Cancelled',
      'Completed',
      'Milestone Complete',
    ].contains(b['status'])) {
      return const SizedBox.shrink();
    }
    return WorkflowSurface(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: WorkflowFields(
          children: [
            Text(
              context.tr('Final work settlement'),
              style: WorkflowStyles.sectionTitle,
            ),
            Text(context.tr('Contract language notice')),
            OutlinedButton(
              onPressed: _busy || b['pendingSettlementId'] != null
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettlementProposalScreen(
                          bookingId: widget.bookingId,
                          bookingData: b,
                        ),
                      ),
                    ),
              child: Text(context.tr('Propose settlement')),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(widget.bookingId)
                  .collection('settlements')
                  .orderBy('proposedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text(
                    'Could not load settlement records. Check your connection and retry.',
                  );
                }
                return Column(
                  children: [
                    for (final doc in snap.data?.docs ?? [])
                      Builder(
                        builder: (context) {
                          final record = doc.data();
                          return ExpansionTile(
                            title: Text(
                              '${context.tr('Final work settlement')} · ${context.tr(record['status'] as String)}',
                            ),
                            subtitle: Text(
                              '${context.tr('Balance due')}: PHP ${((record['balanceDueCents'] as num) / 100).toStringAsFixed(2)}\n${context.tr('Refund due')}: PHP ${((record['refundDueCents'] as num) / 100).toStringAsFixed(2)}',
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: SelectableText(
                                  '${(record['agreement'] as Map)['text']}\nSHA-256: ${(record['agreement'] as Map)['hash']}\nProposer: ${record['proposedBy']}\nProposed: ${record['proposedAt']}\nAccepted by: ${record['acceptedBy'] ?? '-'}\nAccepted: ${record['acceptedAt'] ?? '-'}',
                                ),
                              ),
                              if (record['status'] == 'Proposed')
                                Wrap(
                                  spacing: 8,
                                  children:
                                      record['proposedBy'] == widget.viewerId
                                      ? [
                                          TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _respond(
                                                    'withdraw',
                                                    doc.id,
                                                    record,
                                                  ),
                                            child: Text(
                                              context.tr('Withdraw settlement'),
                                            ),
                                          ),
                                        ]
                                      : [
                                          FilledButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _respond(
                                                    'accept',
                                                    doc.id,
                                                    record,
                                                  ),
                                            child: Text(
                                              context.tr('Review and accept'),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _respond(
                                                    'decline',
                                                    doc.id,
                                                    record,
                                                  ),
                                            child: Text(context.tr('Declined')),
                                          ),
                                        ],
                                ),
                            ],
                          );
                        },
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

class SettlementProposalScreen extends StatefulWidget {
  const SettlementProposalScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });
  final String bookingId;
  final Map<String, dynamic> bookingData;
  @override
  State<SettlementProposalScreen> createState() =>
      _SettlementProposalScreenState();
}

class _SettlementProposalScreenState extends State<SettlementProposalScreen> {
  final _form = GlobalKey<FormState>();
  final _work = TextEditingController(),
      _materials = TextEditingController(),
      _reason = TextEditingController();
  late final TextEditingController _fee;
  final _id = FirebaseFirestore.instance.collection('bookings').doc().id;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _fee = TextEditingController(
      text: (widget.bookingData['totalFee'] as num? ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    for (final controller in [_work, _materials, _reason, _fee]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _propose() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final payload = {
        'bookingId': widget.bookingId,
        'settlementId': _id,
        'agreedWorkAmount': double.parse(_fee.text),
        'workCompleted': _work.text.trim(),
        'materialsReturned': _materials.text.trim(),
        'reason': _reason.text.trim(),
      };
      final preview = await MarketplaceService.command('settlementCommand', {
        'action': 'preview',
        ...payload,
      });
      if (!mounted) return;
      if (preview['duplicate'] == true) {
        Navigator.pop(context);
        return;
      }
      final agreement = Map<String, dynamic>.from(preview['agreement'] as Map);
      final ok = await confirmServiceAgreement(
        context,
        agreement: agreement,
        title: context.tr('Final work settlement'),
        confirmation: context.tr(
          'I voluntarily propose this exact settlement for the other party to review.',
        ),
      );
      if (ok != true) return;
      await MarketplaceService.command('settlementCommand', {
        'action': 'propose',
        ...payload,
        'acceptAgreement': true,
        'agreementHash': agreement['hash'],
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not propose the settlement. Retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Final work settlement')),
      actions: const [LanguageMenuButton()],
    ),
    body: Form(
      key: _form,
      child: WorkflowPage(
        title: context.tr('Final work settlement'),
        subtitle:
            'Review the final fee and record the work and materials with the other party.',
        children: [
          WorkflowNotice(
            child: WorkflowFields(
              spacing: 8,
              children: [
                Text(context.tr('Contract language notice')),
                Text(context.tr('Payment record notice')),
              ],
            ),
          ),
          WorkflowSection(
            title: context.tr('Agreed final labour fee (PHP)'),
            icon: Icons.receipt_long_outlined,
            children: [
              TextFormField(
                controller: _fee,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('Agreed final labour fee (PHP)'),
                ),
                validator: (value) {
                  final n = double.tryParse(value ?? '');
                  return n == null ||
                          !n.isFinite ||
                          n < 0 ||
                          n > (widget.bookingData['totalFee'] as num? ?? 0)
                      ? 'Enter an amount from zero to the original labour fee.'
                      : null;
                },
              ),
            ],
          ),
          WorkflowSection(
            title: 'Work and materials',
            icon: Icons.task_alt_outlined,
            subtitle: 'Describe the completed work and any remaining concerns.',
            children: [
              for (final field in [
                (_work, 'Work completed'),
                (_materials, 'Materials supplied and returned'),
                (_reason, 'Reason and outstanding concerns'),
              ])
                TextFormField(
                  controller: field.$1,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 3000,
                  decoration: InputDecoration(labelText: context.tr(field.$2)),
                  validator: (value) => (value?.trim().length ?? 0) < 10
                      ? context.tr('Explain in at least 10 characters')
                      : null,
                ),
            ],
          ),
          WorkflowActions(
            child: FilledButton(
              onPressed: _busy ? null : _propose,
              child: Text(context.tr('Preview settlement')),
            ),
          ),
        ],
      ),
    ),
  );
}
