import '../ui/workflow_ui.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/booking_user_report.dart';
import '../models/user_role.dart';
import '../services/firestore_service.dart';
import '../services/marketplace_service.dart';
import 'chat_image.dart';

class DisputeCasePanel extends StatefulWidget {
  const DisputeCasePanel({
    super.key,
    required this.appUser,
    required this.reportId,
    this.onOpenConversation,
    this.reports,
    this.command,
    this.showHistory = true,
    this.events,
  });
  final AppUser appUser;
  final String reportId;
  final ValueChanged<String>? onOpenConversation;
  final Stream<BookingUserReport?>? reports;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? command;
  final bool showHistory;
  final Stream<List<Map<String, dynamic>>>? events;
  @override
  State<DisputeCasePanel> createState() => _DisputeCasePanelState();
}

class _DisputeCasePanelState extends State<DisputeCasePanel> {
  late final Stream<BookingUserReport?> _reports;
  late final Stream<List<Map<String, dynamic>>> _events;
  String? _proposalId, _proposalSignature;
  final _notes = TextEditingController();
  String _resolutionType = 'correction';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _reports =
        widget.reports ?? FirestoreService().bookingUserReport(widget.reportId);
    _events = !widget.showHistory
        ? Stream.value([])
        : widget.events ??
              FirebaseFirestore.instance
                  .collection('bookingUserReports')
                  .doc(widget.reportId)
                  .collection('events')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots()
                  .map((s) => s.docs.map((d) => d.data()).toList());
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _act(
    String action, {
    Map<String, dynamic> data = const {},
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final payload = {
        'action': action,
        'reportId': widget.reportId,
        'adminNotes': _notes.text.trim(),
        ...data,
      };
      final result =
          await (widget.command?.call(payload) ??
              MarketplaceService.command('reportCommand', payload));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Case updated.')));
      if (action == 'startReview' && result['inquiryId'] is String) {
        widget.onOpenConversation?.call(result['inquiryId'] as String);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not update the case. Retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _proposalReference() {
    final signature = '$_resolutionType:${_notes.text.trim()}';
    if (_proposalSignature != signature) {
      _proposalSignature = signature;
      _proposalId =
          'proposal_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';
    }
    return _proposalId!;
  }

  Future<void> _confirm(BookingUserReport report) async {
    final proposal = report.resolutionProposal!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => WorkflowDialog(
        title: const Text('Confirm proposed resolution?'),
        content: SingleChildScrollView(
          child: Text(
            '${proposal['summary']}\n\nConfirm only if you agree to these terms. This records your agreement; it does not transfer money, change the booking schedule or mark work completed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I agree to this proposal'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _act('confirmResolution', data: {'proposalId': proposal['id']});
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<BookingUserReport?>(
    stream: _reports,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'Could not load the case. Check your access and connection.',
        );
      }
      if (!snapshot.hasData) {
        return snapshot.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : const Text('Case not found.');
      }
      final report = snapshot.data!;
      final isAdmin = widget.appUser.role == UserRole.administrator;
      final canManage =
          isAdmin &&
          (report.assignedAdminId.isEmpty ||
              report.assignedAdminId == widget.appUser.userId);
      final isParty = [
        report.reporterId,
        report.reportedUserId,
      ].contains(widget.appUser.userId);
      final proposal = report.resolutionProposal;
      final confirmed = List<String>.from(
        proposal?['confirmedBy'] as List? ?? const [],
      );
      final hasNotes = _notes.text.trim().length >= 10;
      final enabled = !_busy && !report.isClosed;
      return WorkflowTheme(
        child: WorkflowFields(
          spacing: 12,
          children: [
            const WorkflowHeading(
              title: 'Dispute case',
              icon: Icons.gavel_outlined,
            ),
            const SizedBox(height: 8),
            WorkflowStatus(label: report.statusLabel, status: report.status),
            if (report.bookingId.isNotEmpty)
              Text('Booking: ${report.bookingId}'),
            const SizedBox(height: 12),
            Text(
              report.reason,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            if (report.details.isNotEmpty) Text(report.details),
            if (report.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Submitted photos',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final url in report.photoUrls)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ChatImage(url: url),
                ),
            ],
            if (report.adminNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Recorded outcome: ${report.adminNotes}'),
            ],
            if (report.disputeInquiryId.isNotEmpty &&
                widget.onOpenConversation != null)
              TextButton.icon(
                onPressed: () =>
                    widget.onOpenConversation!(report.disputeInquiryId),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Open dispute conversation'),
              ),
            if (proposal != null) ...[
              const Divider(height: 24),
              Text(
                'Proposed ${proposal['type']} resolution',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('${proposal['summary']}'),
              Text('${confirmed.length} of 2 parties confirmed'),
              if (isParty && !report.isClosed)
                FilledButton(
                  onPressed:
                      !enabled || confirmed.contains(widget.appUser.userId)
                      ? null
                      : () => _confirm(report),
                  child: Text(
                    confirmed.contains(widget.appUser.userId)
                        ? 'You confirmed this proposal'
                        : 'Review and confirm proposal',
                  ),
                ),
            ],
            if (canManage && !report.isClosed) ...[
              const Divider(height: 24),
              if (report.assignedAdminId.isEmpty)
                FilledButton.icon(
                  onPressed: enabled ? () => _act('startReview') : null,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Start review and contact both parties'),
                )
              else ...[
                TextField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 3000,
                  decoration: const InputDecoration(
                    labelText: 'Evidence, response request or decision notes',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: enabled && hasNotes
                          ? () => _act(
                              'setStatus',
                              data: {'status': 'under_review'},
                            )
                          : null,
                      child: const Text('Under review'),
                    ),
                    OutlinedButton(
                      onPressed: enabled && hasNotes
                          ? () => _act(
                              'setStatus',
                              data: {'status': 'waiting_response'},
                            )
                          : null,
                      child: const Text('Request response'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _resolutionType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Proposed agreement type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'correction',
                      child: Text('Correction / rework'),
                    ),
                    DropdownMenuItem(
                      value: 'refund',
                      child: Text('Refund agreement'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Other agreement'),
                    ),
                  ],
                  onChanged: enabled
                      ? (v) => setState(() => _resolutionType = v!)
                      : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: enabled && hasNotes
                      ? () => _act(
                          'proposeResolution',
                          data: {
                            'resolutionType': _resolutionType,
                            'proposalId': _proposalReference(),
                          },
                        )
                      : null,
                  child: const Text('Propose agreement for both parties'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: enabled && hasNotes
                          ? () => _act('resolve', data: {'status': 'dismissed'})
                          : null,
                      child: const Text('Dismiss'),
                    ),
                    FilledButton(
                      onPressed:
                          enabled &&
                              hasNotes &&
                              (proposal == null ||
                                  [
                                    report.reporterId,
                                    report.reportedUserId,
                                  ].every(confirmed.contains))
                          ? () => _act('resolve', data: {'status': 'resolved'})
                          : null,
                      child: const Text('Resolve with recorded outcome'),
                    ),
                  ],
                ),
              ],
            ] else if (isAdmin && !report.isClosed)
              const Text('Another administrator is assigned to this case.'),
            const SizedBox(height: 12),
            Text(
              'Agreements here do not automatically transfer money, change schedules or mark work completed.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: FigmaColors.gray600,
              ),
            ),
            if (widget.showHistory) ...[
              const Divider(height: 24),
              const Text(
                'Case history',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _events,
                builder: (context, events) {
                  if (events.hasError) {
                    return const Text('Could not load case history.');
                  }
                  if (!events.hasData) return const LinearProgressIndicator();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final event in events.data!)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${event['action']} · ${event['createdAt'] is Timestamp ? DateFormat('MMM d, yyyy h:mm a').format((event['createdAt'] as Timestamp).toDate().toUtc().add(const Duration(hours: 8))) : ''}\n${event['notes'] ?? ''}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: FigmaColors.gray600,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      );
    },
  );
}
