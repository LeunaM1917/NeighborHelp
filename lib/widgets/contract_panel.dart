import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../figma_ui/figma_colors.dart';
import '../figma_ui/widgets/figma_status_chip.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/service_contract.dart';
import '../services/firestore_service.dart';
import '../theme/role_theme.dart';
import '../ui/app_ui_kit.dart';
import 'milestone_feedback_details.dart';

/// Contract summary, milestone history, and optional end-contract action.
class ContractPanel extends StatefulWidget {
  const ContractPanel({
    super.key,
    required this.appUser,
    required this.booking,
    required this.viewerRole,
    this.onContractEnded,
  });

  final AppUser appUser;
  final Booking booking;
  /// `customer` or `provider`
  final String viewerRole;
  final VoidCallback? onContractEnded;

  @override
  State<ContractPanel> createState() => _ContractPanelState();
}

class _ContractPanelState extends State<ContractPanel> {
  bool _ending = false;

  Future<void> _confirmEnd(ServiceContract contract) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End contract?'),
        content: const Text(
          'You can still message each other, but future bookings will start a new contract unless you work together again under a new agreement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End contract')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _ending = true);
    try {
      await FirestoreService().endContract(
        contractId: contract.contractId,
        endedByUserId: widget.appUser.userId,
        endedByRole: widget.viewerRole,
      );
      widget.onContractEnded?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract ended.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not end contract. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contractId = widget.booking.contractId;
    if (contractId == null || contractId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<ServiceContract?>(
      stream: FirestoreService().contractStream(contractId),
      builder: (context, contractSnap) {
        final contract = contractSnap.data;
        if (contract == null) return const SizedBox.shrink();

        return StreamBuilder<List<Booking>>(
          stream: FirestoreService().bookingsForContract(contractId),
          builder: (context, bookingsSnap) {
            final milestones = bookingsSnap.data ?? [];
            final rc = context.roleColors;
            final dateFmt = DateFormat('MMM d, yyyy');

            final past = milestones.where((m) => m.isMilestoneComplete).toList()
              ..sort((a, b) => (b.milestoneNumber ?? 0).compareTo(a.milestoneNumber ?? 0));
            final active = milestones.where((m) => !m.isMilestoneComplete).toList()
              ..sort((a, b) => (a.milestoneNumber ?? 0).compareTo(b.milestoneNumber ?? 0));

            return FutureBuilder<(String, String)>(
              future: _partyNames(contract),
              builder: (context, namesSnap) {
                final customerName = namesSnap.data?.$1 ?? 'Customer';
                final providerName = namesSnap.data?.$2 ?? 'Provider';

                return AppSection(
                  title: 'Contract',
                  subtitle: contract.isActive
                      ? 'Ongoing work with repeat milestones on one contract'
                      : 'This contract has ended',
                  child: AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: rc.tint,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${contract.milestoneCount} milestone${contract.milestoneCount == 1 ? '' : 's'}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: rc.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FigmaStatusChip(status: contract.isActive ? 'Active' : 'Ended'),
                            if (widget.booking.milestoneNumber != null) ...[
                              const Spacer(),
                              Text(
                                widget.booking.milestoneLabel,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                        if (active.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Current milestones',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...active.map(
                            (m) => _ActiveMilestoneRow(
                              booking: m,
                              dateFmt: dateFmt,
                              highlight: m.bookingId == widget.booking.bookingId,
                            ),
                          ),
                        ],
                        if (past.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Past milestones',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...past.map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PastMilestoneCard(
                                booking: m,
                                dateFmt: dateFmt,
                                viewerRole: widget.viewerRole,
                                customerName: customerName,
                                providerName: providerName,
                                highlight: m.bookingId == widget.booking.bookingId,
                              ),
                            ),
                          ),
                        ],
                        if (contract.isEnded && contract.endedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Ended ${dateFmt.format(contract.endedAt!.toDate())}',
                            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                          ),
                        ],
                        if (contract.isActive) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _ending ? null : () => _confirmEnd(contract),
                            icon: _ending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.handshake_outlined, size: 18),
                            label: Text(
                              'End contract',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              foregroundColor: FigmaColors.gray800,
                              side: const BorderSide(color: FigmaColors.gray200),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<(String, String)> _partyNames(ServiceContract contract) async {
    final firestore = FirestoreService();
    final results = await Future.wait([
      firestore.getUser(contract.customerId),
      firestore.getUser(contract.providerId),
    ]);
    final customer = results[0];
    final provider = results[1];
    return (
      customer?.fullName.trim().isNotEmpty == true ? customer!.fullName : 'Customer',
      provider?.fullName.trim().isNotEmpty == true ? provider!.fullName : 'Provider',
    );
  }
}

class _ActiveMilestoneRow extends StatelessWidget {
  const _ActiveMilestoneRow({
    required this.booking,
    required this.dateFmt,
    required this.highlight,
  });

  final Booking booking;
  final DateFormat dateFmt;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final when = booking.scheduledDate.toDate();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: highlight ? const EdgeInsets.all(10) : EdgeInsets.zero,
        decoration: highlight
            ? BoxDecoration(
                color: FigmaColors.tintBlue.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FigmaColors.navy.withValues(alpha: 0.15)),
              )
            : null,
        child: Row(
          children: [
            Icon(
              Icons.radio_button_unchecked,
              size: 18,
              color: highlight ? FigmaColors.navy : FigmaColors.gray400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.milestoneLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FigmaColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dateFmt.format(when)} • ${booking.scheduledWindowLabel}',
                    style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                  ),
                ],
              ),
            ),
            FigmaStatusChip(status: booking.status),
          ],
        ),
      ),
    );
  }
}

class _PastMilestoneCard extends StatelessWidget {
  const _PastMilestoneCard({
    required this.booking,
    required this.dateFmt,
    required this.viewerRole,
    required this.customerName,
    required this.providerName,
    required this.highlight,
  });

  final Booking booking;
  final DateFormat dateFmt;
  final String viewerRole;
  final String customerName;
  final String providerName;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final completedAt = booking.completedAt?.toDate() ?? booking.scheduledDate.toDate();
    final fee = booking.totalFee != null ? '₱${booking.totalFee!.toStringAsFixed(0)}' : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? FigmaColors.tintGreen.withValues(alpha: 0.25) : FigmaColors.gray50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? FigmaColors.green.withValues(alpha: 0.35) : FigmaColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, size: 20, color: FigmaColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            booking.milestoneLabel,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.gray900,
                            ),
                          ),
                        ),
                        if (highlight)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: FigmaColors.tintBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'This booking',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: FigmaColors.navy,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completed ${dateFmt.format(completedAt)}',
                      style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.scheduledWindowLabel,
                      style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                    ),
                    if (fee != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        fee,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FigmaColors.gray800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: FigmaColors.gray200),
          ),
          MilestoneFeedbackDetails(
            booking: booking,
            viewerRole: viewerRole,
            customerName: customerName,
            providerName: providerName,
          ),
        ],
      ),
    );
  }
}
