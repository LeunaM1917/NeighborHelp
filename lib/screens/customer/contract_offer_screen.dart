import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/inquiry.dart';
import '../../models/service.dart';
import '../../services/firestore_service.dart';
import '../../services/marketplace_service.dart';
import '../../widgets/service_location_picker.dart';
import '../../widgets/service_agreement_card.dart';

class ContractOfferScreen extends StatefulWidget {
  const ContractOfferScreen({
    super.key,
    required this.appUser,
    required this.inquiry,
  });
  final AppUser appUser;
  final Inquiry inquiry;
  @override
  State<ContractOfferScreen> createState() => _ContractOfferScreenState();
}

class _ContractOfferScreenState extends State<ContractOfferScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _rate = TextEditingController();
  final _days = TextEditingController(text: '1');
  final _fields = <String, TextEditingController>{
    'scope': TextEditingController(),
    'deliverables': TextEditingController(),
    'exclusions': TextEditingController(text: 'None agreed'),
    'materials': TextEditingController(),
    'paymentTerms': TextEditingController(),
    'completionCriteria': TextEditingController(),
    'responsibilities': TextEditingController(),
  };
  String _type = 'fixed';
  String? _serviceId;
  GeoPoint? _location;
  String? _locatedAddress;
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  double _hours = 8;
  bool _busy = false;
  @override
  void dispose() {
    for (final c in [_address, _rate, _days, ..._fields.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _preview() async {
    if (!_form.currentState!.validate()) return;
    if (_date == null ||
        _location == null ||
        _locatedAddress != _address.text.trim() ||
        _serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a service, start date and confirmed map location.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final template = await MarketplaceService.command('inquiryCommand', {
        'action': 'template',
      });
      final id = FirebaseFirestore.instance.collection('bookings').doc().id;
      final start = DateTime.utc(
        _date!.year,
        _date!.month,
        _date!.day,
        _time.hour - 8,
        _time.minute,
      );
      final payload = <String, dynamic>{
        'bookingId': id,
        'serviceId': _serviceId,
        'inquiryId': widget.inquiry.id,
        'serviceLocation': _address.text.trim(),
        'location': {
          'latitude': _location!.latitude,
          'longitude': _location!.longitude,
        },
        'scheduledDate': start.millisecondsSinceEpoch,
        'pricingType': _type,
        'proposedRate': double.parse(_rate.text),
        'numberOfDays': int.parse(_days.text),
        'hoursPerDay': _hours,
        for (final f in _fields.entries) f.key: f.value.text.trim(),
        'templateVersion': template['version'],
        'acceptAgreement': true,
      };
      final preview = await MarketplaceService.command('bookingCommand', {
        'action': 'preview',
        ...payload,
      });
      if (!mounted) return;
      final agreement = Map<String, dynamic>.from(preview['agreement'] as Map);
      final accepted = await confirmServiceAgreement(
        context,
        agreement: agreement,
        title: 'Review and send contract offer',
        confirmation:
            'I am at least 18, legally able to contract, and voluntarily offer these exact terms.',
      );
      if (accepted != true) return;
      await MarketplaceService.command('bookingCommand', {
        'action': 'create',
        ...payload,
        'agreementHash': agreement['hash'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Offer sent. Work can begin only after the provider accepts.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not send the offer. Please retry.',
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
    appBar: AppBar(title: const Text('Prepare contract offer')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Offer work to ${widget.inquiry.providerName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Agree on the job in messages first. State all costs and responsibilities clearly. Additional days or work require a new accepted agreement; no automatic charges apply.',
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<ServiceListing>>(
                stream: FirestoreService().servicesForProvider(
                  widget.inquiry.providerId,
                ),
                builder: (context, snap) {
                  final services = (snap.data ?? [])
                      .where((s) => s.isMarketplaceVisible)
                      .toList();
                  _serviceId ??=
                      services.any(
                        (s) => s.serviceId == widget.inquiry.serviceId,
                      )
                      ? widget.inquiry.serviceId
                      : services.firstOrNull?.serviceId;
                  return DropdownButtonFormField<String>(
                    initialValue: services.any((s) => s.serviceId == _serviceId)
                        ? _serviceId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Service'),
                    items: [
                      for (final s in services)
                        DropdownMenuItem(
                          value: s.serviceId,
                          child: Text(s.serviceTitle),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _serviceId = v),
                    validator: (v) =>
                        v == null ? 'Choose an available service' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fixed', label: Text('Fixed amount')),
                  ButtonSegment(value: 'daily', label: Text('Daily rate')),
                ],
                selected: {_type},
                onSelectionChanged: _busy
                    ? null
                    : (v) => setState(() => _type = v.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _type == 'fixed'
                      ? 'Total labour amount (₱)'
                      : 'Labour amount per day (₱)',
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || !n.isFinite || n <= 0 || n > 1000000
                      ? 'Enter a positive amount up to ₱1,000,000'
                      : null;
                },
              ),
              TextFormField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of consecutive working days (1–30)',
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
                decoration: const InputDecoration(
                  labelText: 'Working hours per day (schedule only)',
                ),
                items: [
                  for (var h = .5; h <= 8; h += .5)
                    DropdownMenuItem(value: h, child: Text('$h hours')),
                ],
                onChanged: (v) => setState(() => _hours = v!),
              ),
              const SizedBox(height: 12),
              const Text(
                'Schedule times are in Asia/Manila. The same hours apply on each consecutive working day.',
              ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _date == null
                          ? 'Choose start date'
                          : DateFormat.yMMMd().format(_date!),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 180)),
                        initialDate: _date ?? now.add(const Duration(days: 1)),
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(_time.format(context)),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (t != null && mounted) setState(() => _time = t);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ServiceLocationPicker(
                address: _address,
                origin: widget.appUser.location,
                onSelected: (p) => setState(() {
                  _location = p;
                  _locatedAddress = _address.text.trim();
                }),
              ),
              const SizedBox(height: 16),
              for (final f in _fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: f.value,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 3000,
                    decoration: InputDecoration(
                      labelText: const {
                        'scope': 'Work scope',
                        'deliverables': 'Deliverables',
                        'exclusions': 'Work excluded',
                        'materials': 'Materials and who pays for them',
                        'paymentTerms':
                            'Direct payment method, timing and any deposit',
                        'completionCriteria': 'How completion will be checked',
                        'responsibilities':
                            'Tools, access, hazards and each party’s responsibilities',
                      }[f.key],
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 5
                        ? 'Provide at least 5 characters'
                        : null,
                  ),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : _preview,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Icon(Icons.preview_outlined),
                label: const Text('Review complete agreement'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
