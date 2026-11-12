import '../ui/app_notification_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/service_proposal.dart';
import '../models/user_role.dart';
import '../services/firestore_service.dart';
import '../services/marketplace_service.dart';
import '../screens/provider/provider_certification_dialog.dart';
import '../screens/provider/provider_service_form_screen.dart';
import '../utils/service_certification_policy.dart';
import 'account_setup_gate.dart';
import 'service_proposal_dialogs.dart';

class ServiceProposalsSection extends StatefulWidget {
  const ServiceProposalsSection({super.key, this.appUser});
  final AppUser? appUser;
  @override
  State<ServiceProposalsSection> createState() =>
      _ServiceProposalsSectionState();
}

class _ServiceProposalsSectionState extends State<ServiceProposalsSection> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _query();
  bool _opening = false;
  bool get _admin => widget.appUser == null;
  Stream<QuerySnapshot<Map<String, dynamic>>> _query() {
    final collection = FirebaseFirestore.instance.collection(
      'serviceProposals',
    );
    return (_admin
            ? collection
                  .where('status', isEqualTo: 'Pending')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
            : collection
                  .where('providerId', isEqualTo: widget.appUser!.userId)
                  .orderBy('updatedAt', descending: true)
                  .limit(50))
        .snapshots();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _propose([ServiceProposal? initial]) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (!await requireAccountSetup(
        context,
        appUser: widget.appUser!,
        role: UserRole.provider,
        action: 'propose a new service',
      )) {
        return;
      }
      final profile = await FirestoreService().getProviderProfileForListing(
        widget.appUser!.userId,
      );
      if (!mounted) return;
      if (profile == null) {
        throw StateError('Complete your provider profile first.');
      }
      if (!profile.certificationHistory.any(
        (c) => isCurrentTesdaCertificate(profile, c),
      )) {
        final upload = await showDialog<bool>(
          context: context,
          builder: (ctx) => AppNotificationDialog(
            title: const Text('Approved TESDA certificate required'),
            content: const Text(
              'Upload the TESDA certificate covering your proposed work and wait for administrator authentication before submitting a proposal.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Upload certificate'),
              ),
            ],
          ),
        );
        if (upload == true && mounted) {
          await ProviderCertificationDialog.open(
            context,
            providerId: widget.appUser!.userId,
          );
        }
        return;
      }
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ServiceProposalForm(
          profile: profile,
          initial: initial,
          onSubmit: (data) async {
            await MarketplaceService.command('serviceProposalCommand', data);
          },
        ),
      );
      if (saved == true) {
        _message(
          'Proposal submitted. You will be notified after administrator review.',
        );
      }
    } catch (e) {
      _message(
        e is StateError
            ? e.message.toString()
            : 'Could not open the proposal form. Check your connection and retry.',
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _review(ServiceProposal proposal) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ServiceProposalReviewDialog(
        proposal: proposal,
        onReview: (data) async {
          await MarketplaceService.command('serviceProposalCommand', data);
        },
      ),
    );
    if (saved == true) {
      _message('Proposal review saved. The provider has been notified.');
    }
  }

  Future<void> _editDraft(ServiceProposal proposal) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      var service = await FirestoreService().getServiceForListing(
        proposal.draftServiceId,
      );
      if (service == null) {
        await MarketplaceService.command('serviceProposalCommand', {
          'action': 'restoreDraft',
          'proposalId': proposal.id,
        });
        service = await FirestoreService().getServiceForListing(proposal.draftServiceId);
      }
      if (service == null) {
        throw StateError(
          'The draft is unavailable. Ask the administrator to check this proposal.',
        );
      }
      if (!mounted) return;
      await ProviderServiceFormScreen.open(
        context,
        appUser: widget.appUser!,
        existing: service,
      );
    } catch (e) {
      _message(
        e is StateError
            ? e.message.toString()
            : 'Could not open the draft. Check your connection and retry.',
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 24),
    decoration: BoxDecoration(
      color: FigmaColors.white,
      border: Border.all(color: FigmaColors.gray200),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                _admin ? 'Service proposals' : 'Your service proposals',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!_admin)
                OutlinedButton.icon(
                  onPressed: _opening ? null : _propose,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Propose a new service'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _admin
                ? 'Review the proposed scope against the authenticated TESDA qualification. Approval creates a private draft, not a live listing.'
                : 'Missing a service in the catalog? Propose work covered by your approved TESDA certificate.',
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Row(
                  children: [
                    const Expanded(child: Text('Could not load proposals.')),
                    TextButton(
                      onPressed: () => setState(() => _stream = _query()),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final proposals = snapshot.data!.docs
                  .map((d) => ServiceProposal(d.id, d.data()))
                  .toList();
              if (proposals.isEmpty) {
                return Text(
                  _admin
                      ? 'No pending service proposals.'
                      : 'No proposals yet.',
                );
              }
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _admin,
                title: Text(
                  _admin
                      ? '${proposals.length} pending proposals'
                      : 'Recent proposals (${proposals.length})',
                ),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final p in proposals)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: FigmaColors.gray200),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    p.serviceTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text('${p.category} · ${p.status}'),
                                  if (_admin)
                                    Text('Provider: ${p.providerName}'),
                                  Text('TESDA: ${p.qualificationName}'),
                                  if (p.reviewNotes.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Review notes: ${p.reviewNotes}',
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: _admin
                                        ? OutlinedButton(
                                            onPressed: () => _review(p),
                                            child: const Text(
                                              'Review proposal',
                                            ),
                                          )
                                        : p.status == 'Approved'
                                        ? OutlinedButton(
                                            onPressed: _opening
                                                ? null
                                                : () => _editDraft(p),
                                            child: const Text('Edit listing'),
                                          )
                                        : p.status == 'Rejected'
                                        ? TextButton(
                                            onPressed: _opening
                                                ? null
                                                : () => _propose(p),
                                            child: const Text(
                                              'Revise proposal',
                                            ),
                                          )
                                        : const Text(
                                            'Awaiting administrator review',
                                          ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
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
