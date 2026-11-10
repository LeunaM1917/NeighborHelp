import '../../ui/workflow_ui.dart';
import '../../l10n/app_strings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/marketplace_service.dart';
import '../../widgets/service_agreement_card.dart';

class AgreementAmendmentScreen extends StatefulWidget {
  const AgreementAmendmentScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });
  final String bookingId;
  final Map<String, dynamic> bookingData;
  @override
  State<AgreementAmendmentScreen> createState() =>
      _AgreementAmendmentScreenState();
}

class _AgreementAmendmentScreenState extends State<AgreementAmendmentScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late final Map<String, TextEditingController> _fields;
  late final TextEditingController _rate, _days;
  late String _type;
  late double _hours;
  late DateTime _start;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final b = widget.bookingData;
    _fields = {
      for (final key in [
        'scope',
        'deliverables',
        'exclusions',
        'materials',
        'paymentTerms',
        'completionCriteria',
        'responsibilities',
      ])
        key: TextEditingController(text: b[key] as String? ?? ''),
    };
    _rate = TextEditingController(text: (b['proposedRate'] as num).toString());
    _days = TextEditingController(text: (b['numberOfDays'] as num).toString());
    _type = b['pricingType'] as String;
    _hours = (b['hoursPerDay'] as num).toDouble();
    _start = (b['scheduledDate'] as Timestamp).toDate().toUtc().add(
      const Duration(hours: 8),
    );
  }

  @override
  void dispose() {
    for (final c in [_reason, _rate, _days, ..._fields.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final template = await MarketplaceService.command('inquiryCommand', {
        'action': 'template',
      });
      final revisionId = FirebaseFirestore.instance
          .collection('bookings')
          .doc()
          .id;
      final payload = {
        'bookingId': widget.bookingId,
        'revisionId': revisionId,
        'reason': _reason.text.trim(),
        'expectedHash': (widget.bookingData['agreement'] as Map)['hash'],
        'templateVersion': template['version'],
        'acceptAgreement': true,
        'scheduledDate': DateTime.utc(
          _start.year,
          _start.month,
          _start.day,
          _start.hour - 8,
          _start.minute,
        ).millisecondsSinceEpoch,
        'pricingType': _type,
        'proposedRate': double.parse(_rate.text),
        'numberOfDays': int.parse(_days.text),
        'hoursPerDay': _hours,
        for (final f in _fields.entries) f.key: f.value.text.trim(),
      };
      final preview = await MarketplaceService.command('agreementCommand', {
        'action': 'preview',
        ...payload,
      });
      if (!mounted) return;
      final agreement = Map<String, dynamic>.from(preview['agreement'] as Map);
      final ok = await confirmServiceAgreement(
        context,
        agreement: agreement,
        title: 'Review proposed amendment',
        confirmation:
            'I voluntarily propose these exact revised terms. They take effect only after the other participant accepts.',
      );
      if (ok != true) return;
      await MarketplaceService.command('agreementCommand', {
        'action': 'propose',
        ...payload,
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
                  : 'Could not propose amendment. Retry.',
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
    appBar: AppBar(title: Text(context.tr('Propose contract amendment'))),
    body: Form(
      key: _form,
      child: WorkflowPage(
        title: context.tr('Propose contract amendment'),
        subtitle:
            'Keep the agreed changes together for both parties to review.',
        children: [
          WorkflowNotice(
            child: WorkflowFields(
              children: [
                const Text(
                  'Review all revised terms, including scope, materials, total price and schedule. The current agreement stays in effect until both parties accept. Previous versions remain available.',
                ),
              ],
            ),
          ),
          WorkflowSection(
            title: 'Price and schedule changes',
            icon: Icons.edit_calendar_outlined,
            children: [
              TextFormField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                maxLength: 3000,
                decoration: InputDecoration(
                  labelText: context.tr('Reason for amendment'),
                ),
                validator: (v) => (v?.trim().length ?? 0) < 10
                    ? 'Explain in at least 10 characters'
                    : null,
              ),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'fixed',
                    label: Text(context.tr('Fixed amount')),
                  ),
                  ButtonSegment(
                    value: 'daily',
                    label: Text(context.tr('Daily rate')),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: _busy
                    ? null
                    : (v) => setState(() => _type = v.first),
              ),
              TextFormField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _type == 'fixed'
                      ? 'Revised total labour fee (PHP)'
                      : 'Revised daily rate (PHP)',
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || !n.isFinite || n <= 0 || n > 1000000
                      ? 'Enter a positive amount up to 1,000,000'
                      : null;
                },
              ),
              TextFormField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Revised total consecutive working days (1–30)',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 30
                      ? 'Choose 1–30 days'
                      : null;
                },
              ),
              DropdownButtonFormField<double>(
                initialValue: _hours,
                decoration: InputDecoration(labelText: 'Hours per day'),
                items: [
                  for (var h = .5; h <= 8; h += .5)
                    DropdownMenuItem(value: h, child: Text('$h hours')),
                ],
                onChanged: _busy || widget.bookingData['startedAt'] != null
                    ? null
                    : (v) => setState(() => _hours = v!),
              ),
              Text(
                'Start: ${DateFormat('MMM d, yyyy h:mm a').format(_start)} (Asia/Manila)',
              ),
              OutlinedButton(
                onPressed: _busy || widget.bookingData['startedAt'] != null
                    ? null
                    : () async {
                        final now = DateTime.now().toUtc().add(
                          const Duration(hours: 8),
                        );
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime(now.year, now.month, now.day),
                          lastDate: now.add(const Duration(days: 180)),
                          initialDate: _start.isBefore(now) ? now : _start,
                        );
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: _start.hour,
                            minute: _start.minute,
                          ),
                        );
                        if (time != null && mounted) {
                          setState(
                            () => _start = DateTime.utc(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            ),
                          );
                        }
                      },
                child: const Text('Change start date and time'),
              ),
              if (widget.bookingData['startedAt'] != null)
                const Text(
                  'Ongoing work keeps the original start and hours per day. You may add days and agree on revised scope or price.',
                ),
            ],
          ),
          WorkflowSection(
            title: 'Revised work and responsibilities',
            icon: Icons.description_outlined,
            children: [
              for (final f in _fields.entries)
                TextFormField(
                  controller: f.value,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 3000,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      {
                        'scope': 'Scope of work',
                        'deliverables': 'Deliverables',
                        'exclusions': 'Exclusions',
                        'materials': 'Materials and costs',
                        'paymentTerms': 'Payment arrangement',
                        'completionCriteria': 'Completion criteria',
                        'responsibilities': 'Responsibilities',
                      }[f.key]!,
                    ),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 5
                      ? 'Describe in at least 5 characters'
                      : null,
                ),
            ],
          ),
          WorkflowActions(
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Preparing…' : 'Preview amendment'),
            ),
          ),
        ],
      ),
    ),
  );
}
