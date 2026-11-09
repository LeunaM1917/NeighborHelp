import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/marketplace_service.dart';
import '../screens/shared/agreement_amendment_screen.dart';
import 'service_agreement_card.dart';
import 'work_completion_card.dart';

/// Read-only history plus server-authorized agreement and payment actions.
class ContractRecordsCard extends StatefulWidget {
  const ContractRecordsCard({
    super.key,
    required this.booking,
    required this.viewerId,
  });
  final Booking booking;
  final String viewerId;
  @override
  State<ContractRecordsCard> createState() => _ContractRecordsCardState();
}

class _ContractRecordsCardState extends State<ContractRecordsCard> {
  bool _busy = false;
  String? _paymentAttemptId;
  String? _paymentAttemptPayload;
  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance
      .collection('bookings')
      .doc(widget.booking.bookingId);
  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not save this action. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(dynamic stamp) => stamp is Timestamp
      ? '${DateFormat('MMM d, yyyy h:mm a').format(stamp.toDate().toUtc().add(const Duration(hours: 8)))} (Asia/Manila)'
      : 'Pending';
  Future<void> _amend(
    String action,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (action == 'accept') {
      final ok = await confirmServiceAgreement(
        context,
        agreement: Map<String, dynamic>.from(data['agreement'] as Map),
        title: 'Review amendment',
        confirmation: 'I voluntarily accept this exact amended agreement.',
      );
      if (ok != true) return;
    }
    await MarketplaceService.command('agreementCommand', {
      'action': action,
      'bookingId': widget.booking.bookingId,
      'revisionId': id,
      'acceptAgreement': true,
      'agreementHash': (data['agreement'] as Map)['hash'],
    });
  }

  Future<void> _reportPayment() async {
    final form = GlobalKey<FormState>(),
        amount = TextEditingController(),
        reference = TextEditingController();
    String method = 'Cash';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record a payment you made'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This records a direct payment; the app does not transfer or hold money. The provider must acknowledge receipt. Do not enter PINs, passwords or full account numbers.',
                    ),
                    TextFormField(
                      controller: amount,
                      decoration: const InputDecoration(
                        labelText: 'Amount paid (PHP)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || !n.isFinite || n <= 0
                            ? 'Enter a positive amount'
                            : null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      items: [
                        for (final m in [
                          'Cash',
                          'GCash',
                          'Bank transfer',
                          'Other',
                        ])
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: (v) => setLocal(() => method = v!),
                      decoration: const InputDecoration(labelText: 'Method'),
                    ),
                    TextFormField(
                      controller: reference,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Transaction reference (optional)',
                      ),
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
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'amount': double.parse(amount.text),
                    'method': method,
                    'reference': reference.text.trim(),
                  });
                }
              },
              child: const Text('Report payment'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), () {
      amount.dispose();
      reference.dispose();
    });
    if (payload == null) return;
    final payloadKey=jsonEncode(payload);
    if(_paymentAttemptId==null || _paymentAttemptPayload!=payloadKey){
      _paymentAttemptId=_ref.collection('payments').doc().id;_paymentAttemptPayload=payloadKey;
    }
    await MarketplaceService.command('paymentCommand', {
      'action': 'report',
      'bookingId': widget.booking.bookingId,
      'paymentId': _paymentAttemptId,
      ...payload,
    });
    _paymentAttemptId=null;_paymentAttemptPayload=null;
  }

  Future<void> _payment(
    String action,
    String id,
    Map<String, dynamic> data,
  ) async {
    String? reason;
    if (action == 'confirm') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Acknowledge actual receipt?'),
          content: Text(
            'Confirm only if you received PHP ${((data['amountCents'] as num) / 100).toStringAsFixed(2)} by ${data['method']}. Check your own cash or account records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('I received this amount'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      reason = await askRecordedReason(
        context,
        action == 'dispute'
            ? 'Explain the payment concern'
            : 'Explain the withdrawal',
      );
      if (reason == null) return;
    }
    await MarketplaceService.command('paymentCommand', {
      'action': action,
      'bookingId': widget.booking.bookingId,
      'paymentId': id,
      'confirmReceived': true,
      if (reason != null) 'reason': reason,
    });
  }

  Widget _history(
    String collection,
    String title,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _ref.collection(collection).snapshots(),
    builder: (context, snap) {
      if (snap.hasError) {
        return Text(
          '$title could not load. Check your connection and reopen this booking.',
        );
      }
      final docs = (snap.data?.docs ?? []).toList();
      if (collection == 'agreementVersions') {
        docs.sort(
          (a, b) => ((a.data()['revision'] as num?) ?? 0).compareTo(
            (b.data()['revision'] as num?) ?? 0,
          ),
        );
      } else {
        docs.sort(
          (a, b) =>
              ((b.data()['proposedAt'] ?? b.data()['reportedAt'])
                          as Timestamp? ??
                      Timestamp(0, 0))
                  .compareTo(
                    (a.data()['proposedAt'] ?? a.data()['reportedAt'])
                            as Timestamp? ??
                        Timestamp(0, 0),
                  ),
        );
      }
      return ExpansionTile(
        title: Text('$title (${docs.length})'),
        children: [
          for (final doc in docs)
            Builder(
              builder: (context) {
                final data = doc.data();
                if (collection == 'payments') {
                  return ListTile(
                    isThreeLine: true,
                    title: Text(
                      'PHP ${((data['amountCents'] as num) / 100).toStringAsFixed(2)} · ${data['status']}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['method']} · ${_time(data['reportedAt'])}\nReference: ${data['reference'] ?? ''}${data['reason'] != null ? '\n${data['reason']}' : ''}',
                        ),
                        if (data['status'] == 'Received')
                          Text(
                            'Provider acknowledged ${_time(data['confirmedAt'])}',
                          ),
                        if (data['status'] == 'Reported')
                          Wrap(
                            spacing: 8,
                            children:
                                widget.viewerId == widget.booking.providerId
                                ? [
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => _payment(
                                                'confirm',
                                                doc.id,
                                                data,
                                              ),
                                            ),
                                      child: const Text('Confirm receipt'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => _payment(
                                                'dispute',
                                                doc.id,
                                                data,
                                              ),
                                            ),
                                      child: const Text('Dispute'),
                                    ),
                                  ]
                                : [
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => _payment(
                                                'withdraw',
                                                doc.id,
                                                data,
                                              ),
                                            ),
                                      child: const Text('Withdraw report'),
                                    ),
                                  ],
                          ),
                      ],
                    ),
                  );
                }
                final agreement = Map<String, dynamic>.from(
                  data['agreement'] as Map,
                );
                return ExpansionTile(
                  title: Text(
                    collection == 'agreementVersions'
                        ? 'Accepted version ${data['revision']}'
                        : 'Amendment · ${data['status']}',
                  ),
                  subtitle: Text(
                    collection == 'agreementVersions'
                        ? 'Customer: ${_time(data['customerAcceptedAt'])}\nProvider: ${_time(data['providerAcceptedAt'])}'
                        : '${data['reason']}\nProposed ${_time(data['proposedAt'])}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(agreement['text'] as String),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download agreement record'),
                      onPressed: () async {
                        final record =
                            '${agreement['text']}\nSHA-256: ${agreement['hash']}\nCustomer accepted: ${_time(data['customerAcceptedAt'])}\nProvider accepted: ${_time(data['providerAcceptedAt'])}\nProposed: ${_time(data['proposedAt'])}\nAccepted: ${_time(data['acceptedAt'])}\nStatus: ${data['status'] ?? 'Accepted'}';
                        try {
                          await FilePicker.platform.saveFile(
                            dialogTitle: 'Save agreement record',
                            fileName:
                                'NeighborHelp-${widget.booking.bookingId}-${doc.id}.txt',
                            bytes: Uint8List.fromList(utf8.encode(record)),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save the record. Retry.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    if (data['status'] == 'Proposed')
                      Wrap(
                        spacing: 8,
                        children: data['proposedBy'] == widget.viewerId
                            ? [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () =>
                                              _amend('withdraw', doc.id, data),
                                        ),
                                  child: const Text('Withdraw amendment'),
                                ),
                              ]
                            : [
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => _amend('accept', doc.id, data),
                                        ),
                                  child: const Text('Review and accept'),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => _amend('decline', doc.id, data),
                                        ),
                                  child: const Text('Decline'),
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
  );
  @override
  Widget build(BuildContext context) {
    if (widget.booking.contractId == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) return const SizedBox.shrink();
        final received = ((data['confirmedPaymentCents'] as num?) ?? 0) / 100,
            pending = ((data['pendingPaymentCents'] as num?) ?? 0) / 100,
            total = (data['totalFee'] as num?)?.toDouble() ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Agreement changes and payments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.booking.agreement != null &&
                    (widget.booking.isAccepted || widget.booking.isInProgress))
                  OutlinedButton.icon(
                    onPressed: _busy || data['pendingAmendmentId'] != null
                        ? null
                        : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AgreementAmendmentScreen(
                                bookingId: widget.booking.bookingId,
                                bookingData: data,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Propose amendment'),
                  ),
                _history('amendments', 'Amendment history'),
                _history('agreementVersions', 'Accepted agreement versions'),
                Text(
                  'Received: PHP ${received.toStringAsFixed(2)}\nReported, awaiting receipt: PHP ${pending.toStringAsFixed(2)}\nBalance after acknowledged receipts: PHP ${(total - received).toStringAsFixed(2)}',
                ),
                const Text(
                  'Payment records are separate from completion. They record statements by the parties and do not verify a bank transfer or move money.',
                ),
                if (widget.viewerId == widget.booking.customerId)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(_reportPayment),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Record payment made'),
                  ),
                _history('payments', 'Payment records'),
              ],
            ),
          ),
        );
      },
    );
  }
}
