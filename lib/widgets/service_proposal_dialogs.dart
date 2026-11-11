import 'package:flutter/material.dart';
import '../figma_ui/figma_colors.dart';
import '../models/provider.dart';
import '../models/service_proposal.dart';
import '../utils/service_certification_policy.dart';

typedef ProposalAction = Future<void> Function(Map<String, dynamic> data);

class ServiceProposalForm extends StatefulWidget {
  const ServiceProposalForm({
    super.key,
    required this.profile,
    required this.onSubmit,
    this.initial,
  });
  final ServiceProviderProfile profile;
  final ProposalAction onSubmit;
  final ServiceProposal? initial;
  @override
  State<ServiceProposalForm> createState() => _ServiceProposalFormState();
}

class _ServiceProposalFormState extends State<ServiceProposalForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.serviceTitle,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initial?.description,
  );
  late String _category =
      widget.initial?.category ?? approvedServiceCatalog.keys.first;
  String? _certificate;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'action': 'submit',
        'serviceTitle': _title.text.trim(),
        'category': _category,
        'description': _description.text.trim(),
        'certificationEntryId': _certificate,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Could not submit the proposal. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificates = widget.profile.certificationHistory
        .where((c) => isCurrentTesdaCertificate(widget.profile, c))
        .toList();
    return AlertDialog(
      title: const Text('Propose a new service'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Describe work covered by your authenticated TESDA certificate. Admin approval creates a private draft; the listing still needs its own review.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  maxLength: 100,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Proposed service name',
                  ),
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'Enter at least 3 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Suggested category',
                  ),
                  items:
                      [...approvedServiceCatalog.keys, 'Other TESDA Services']
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Approved TESDA certificate',
                  ),
                  items: certificates
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _certificate = v),
                  validator: (v) => v == null
                      ? 'Choose a current approved certificate'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 6,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Work covered and limitations',
                  ),
                  validator: (v) => (v ?? '').trim().length < 20
                      ? 'Describe the work in at least 20 characters'
                      : null,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: FigmaColors.red600),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Submitting…' : 'Submit proposal'),
        ),
      ],
    );
  }
}

class ServiceProposalReviewDialog extends StatefulWidget {
  const ServiceProposalReviewDialog({
    super.key,
    required this.proposal,
    required this.onReview,
  });
  final ServiceProposal proposal;
  final ProposalAction onReview;
  @override
  State<ServiceProposalReviewDialog> createState() =>
      _ServiceProposalReviewDialogState();
}

class _ServiceProposalReviewDialogState
    extends State<ServiceProposalReviewDialog> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  bool _scope = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _review(String action) async {
    if (_busy || !_form.currentState!.validate()) return;
    if (action == 'approve' && !_scope) {
      setState(
        () => _error =
            'Confirm the certificate matches this work and no unsupported professional licence is required.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onReview({
        'action': action,
        'proposalId': widget.proposal.id,
        'notes': _notes.text.trim(),
        'scopeConfirmed': _scope,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Could not save the review. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    return AlertDialog(
      title: const Text('Review service proposal'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p.serviceTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('Provider: ${p.providerName}'),
                Text('Category: ${p.category}'),
                const SizedBox(height: 12),
                Text('Authenticated qualification: ${p.qualificationName}'),
                const SizedBox(height: 12),
                Text(p.description),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _scope,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I checked that this work matches the TESDA qualification and does not require an unsupported professional licence.',
                  ),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _scope = v ?? false),
                ),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Review notes / rejection reason',
                  ),
                  validator: (v) => (v ?? '').trim().length < 10
                      ? 'Explain the decision in at least 10 characters'
                      : null,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: FigmaColors.red600),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _review('reject'),
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _review('approve'),
          child: Text(_busy ? 'Saving…' : 'Approve proposal'),
        ),
      ],
    );
  }
}
