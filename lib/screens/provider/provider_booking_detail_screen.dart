import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../figma_ui/figma_colors.dart';
import '../../theme/role_theme.dart';
import '../../figma_ui/figma_layout.dart';
import '../../figma_ui/widgets/figma_status_chip.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/service.dart';
import '../../services/firestore_service.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/app_scroll_chrome.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/stream_snapshot.dart';
import '../admin/widgets/admin_services_widgets.dart' show serviceCategoryIcon;
import '../../widgets/customer_reputation_dialog.dart';
import '../shared/messages_hub.dart';
import '../../widgets/contract_panel.dart';
import '../../widgets/booking_cancellation_card.dart';
import '../../widgets/booking_user_report_card.dart';
import '../../widgets/milestone_feedback_details.dart';
import '../../widgets/milestone_review_section.dart';

class ProviderBookingDetailScreen extends StatefulWidget {
  const ProviderBookingDetailScreen({
    super.key,
    required this.appUser,
    required this.booking,
  });

  final AppUser appUser;
  final Booking booking;

  @override
  State<ProviderBookingDetailScreen> createState() => _ProviderBookingDetailScreenState();
}

class _ProviderBookingDetailScreenState extends State<ProviderBookingDetailScreen> {
  bool _busy = false;
  Timer? _workWindowTicker;

  @override
  void dispose() {
    _workWindowTicker?.cancel();
    super.dispose();
  }

  void _syncWorkWindowTicker(Booking b) {
    if (b.isInProgress && !b.canMarkCompleted) {
      _workWindowTicker ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _workWindowTicker?.cancel();
      _workWindowTicker = null;
    }
  }

  Booking get booking => widget.booking;

  Future<void> _respond({required bool accept}) async {
    setState(() => _busy = true);
    try {
      await FirestoreService().providerRespondToBooking(
        bookingId: booking.bookingId,
        providerId: widget.appUser.userId,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Booking accepted' : 'Booking declined')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update booking.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startJob(Booking b) async {
    setState(() => _busy = true);
    try {
      await FirestoreService().providerStartBooking(
        bookingId: b.bookingId,
        providerId: widget.appUser.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job started — timer is running')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start job. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(Booking b) async {
    setState(() => _busy = true);
    try {
      await FirestoreService().providerCompleteBooking(
        bookingId: b.bookingId,
        providerId: widget.appUser.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as completed')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete is only available after the work window ends.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final dateFmt = DateFormat('EEEE, MMM d, yyyy • h:mm a');

    return RoleThemeScope(
      palette: RoleTheme.provider,
      child: StreamBuilder<Booking?>(
        stream: firestore.bookingStream(widget.booking.bookingId),
        initialData: widget.booking,
        builder: (context, bookingSnap) {
          final b = bookingSnap.data ?? widget.booking;
          _syncWorkWindowTicker(b);
          final isPending = b.isPending;

          return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: AppScrollChrome(
          child: SingleChildScrollView(
            child: FigmaWideContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: 'Booking request',
                      subtitle: 'Review details and respond',
                      onBack: () => Navigator.pop(context),
                    ),
                    FutureBuilder<ServiceListing?>(
                      future: firestore.getService(b.serviceId),
                      builder: (context, serviceSnap) {
                        return StreamBuilder<AppUser?>(
                          stream: firestore.userStream(b.customerId),
                          builder: (context, customerSnap) {
                            if (serviceSnap.connectionState == ConnectionState.waiting ||
                                isStreamWaiting(customerSnap)) {
                              return const LoadingIndicator(message: 'Loading…');
                            }
                            final service = serviceSnap.data;
                            final customer = customerSnap.data;

                            final mainChildren = <Widget>[
                              _headerCard(context, b, service, dateFmt),
                              const SizedBox(height: 20),
                              BookingStatusTracker(
                                status: b.status,
                                pendingAt: b.createdAt.toDate(),
                                acceptedAt: b.acceptedAt?.toDate() ??
                                    ((b.isAccepted || b.isInProgress || b.isCompleted)
                                        ? b.updatedAt.toDate()
                                        : null),
                                inProgressAt: b.startedAt?.toDate(),
                                completedAt: b.completedAt?.toDate(),
                              ),
                              const SizedBox(height: 20),
                              ContractPanel(
                                appUser: widget.appUser,
                                booking: b,
                                viewerRole: 'provider',
                              ),
                              const SizedBox(height: 20),
                              AppSection(
                                title: 'Service details',
                                child: AppSurfaceCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (b.serviceLocation.isNotEmpty)
                                        _detail(Icons.place_outlined, 'Location', b.serviceLocation),
                                      if (b.notes != null && b.notes!.isNotEmpty)
                                        _detail(Icons.notes_outlined, 'Notes', b.notes!),
                                      if (b.totalFee != null)
                                        _detail(
                                          Icons.payments_outlined,
                                          'Estimated fee',
                                          b.pricingSummary != null
                                              ? '₱${b.totalFee!.toStringAsFixed(0)} (${b.pricingSummary})'
                                              : '₱${b.totalFee!.toStringAsFixed(0)}',
                                        ),
                                      if (b.isCompleted) ...[
                                        const Padding(
                                          padding: EdgeInsets.only(top: 6, bottom: 16),
                                          child: Divider(height: 1, color: FigmaColors.gray200),
                                        ),
                                        Text(
                                          'Milestone feedback',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: FigmaColors.gray800,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        MilestoneFeedbackDetails(
                                          booking: b,
                                          viewerRole: 'provider',
                                          customerName: customer?.fullName ?? 'Customer',
                                          providerName: widget.appUser.fullName.isNotEmpty
                                              ? widget.appUser.fullName
                                              : 'Provider',
                                          compact: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              MilestoneReviewSection(
                                appUser: widget.appUser,
                                booking: b,
                                reviewerRole: 'provider',
                                title: 'Rate your customer',
                              ),
                              const SizedBox(height: 20),
                              _actionButtons(context, b, isPending: isPending),
                            ];

                            final sideChildren = <Widget>[
                              _bookingSummaryCard(context, b, service, dateFmt),
                              const SizedBox(height: 20),
                              _customerCard(context, b, customer),
                              if (b.canProviderCancel ||
                                  (b.isCancelled &&
                                      (b.wasCancelledByProvider || b.wasCancelledByCustomer))) ...[
                                const SizedBox(height: 20),
                                BookingCancellationCard(
                                  appUser: widget.appUser,
                                  booking: b,
                                  viewerRole: 'provider',
                                  busy: _busy,
                                  onBusyChanged: (v) => setState(() => _busy = v),
                                  onCancelled: () => Navigator.pop(context),
                                ),
                              ],
                            if (!b.isPending) ...[
                              const SizedBox(height: 20),
                              BookingUserReportCard(
                                appUser: widget.appUser,
                                booking: b,
                                viewerRole: 'provider',
                                reportedUserId: b.customerId,
                                reportedRole: 'customer',
                              ),
                            ],
                            ];

                            return LayoutBuilder(
                              builder: (context, c) {
                                final wide = c.maxWidth >= 900;
                                if (wide) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: mainChildren,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      SizedBox(
                                        width: 340,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: sideChildren,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ...mainChildren,
                                    const SizedBox(height: 20),
                                    ...sideChildren,
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
          );
        },
      ),
    );
  }

  Widget _headerCard(BuildContext context, Booking b, ServiceListing? service, DateFormat dateFmt) {
    final rc = context.roleColors;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: rc.tint, shape: BoxShape.circle),
                child: Icon(
                  service != null
                      ? serviceCategoryIcon(service.category, service.serviceTitle)
                      : Icons.home_repair_service_outlined,
                  color: rc.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service?.serviceTitle ?? 'Service',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.scheduledWindowLabel,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FigmaStatusChip(status: b.status),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (b.serviceLocation.isNotEmpty)
                _chip(Icons.place_outlined, b.serviceLocation),
              if (b.totalFee != null)
                _chip(Icons.payments_outlined, 'Estimated fee ₱${b.totalFee!.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FigmaColors.gray500),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray700)),
        ],
      ),
    );
  }

  Widget _bookingSummaryCard(BuildContext context, Booking b, ServiceListing? service, DateFormat dateFmt) {
    return AppSection(
      title: 'Booking summary',
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow('Service', service?.serviceTitle ?? 'Service'),
            const Divider(height: 1, color: FigmaColors.gray100),
            _summaryRow('Date & time', b.scheduledWindowLabel),
            const Divider(height: 1, color: FigmaColors.gray100),
            _summaryRow('Location', b.serviceLocation.isNotEmpty ? b.serviceLocation : '—'),
            if (b.totalFee != null) ...[
              const Divider(height: 1, color: FigmaColors.gray100),
              _summaryRow('Estimated fee', '₱${b.totalFee!.toStringAsFixed(0)}'),
            ],
            const Divider(height: 1, color: FigmaColors.gray100),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text('Status', style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
                  const Spacer(),
                  FigmaStatusChip(status: b.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(BuildContext context, Booking b, AppUser? customer) {
    final rc = context.roleColors;
    final initials = (customer?.fullName.isNotEmpty == true ? customer!.fullName[0] : 'C').toUpperCase();

    return AppSection(
      title: 'Customer',
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: rc.tint,
                  backgroundImage: customer?.profilePhotoUrl != null
                      ? NetworkImage(customer!.profilePhotoUrl!)
                      : null,
                  child: customer?.profilePhotoUrl == null
                      ? Text(
                          initials,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: rc.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?.fullName ?? 'Customer',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (customer?.email.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          customer!.email,
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (customer != null)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => showCustomerReputationDialog(
                          context,
                          appUser: widget.appUser,
                          customer: customer,
                          booking: b,
                        ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: rc.primary,
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: rc.primary.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(
                  'View customer profile',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            if (customer != null) const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      MessagesHub.openConversation(
                        context,
                        appUser: widget.appUser,
                        booking: b,
                        asCustomer: false,
                      );
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: FigmaColors.gray800,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: FigmaColors.gray200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: Text('Message customer', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButtons(BuildContext context, Booking b, {required bool isPending}) {
    if (_busy) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }

    if (isPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _respond(accept: false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Decline', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppPrimaryButton(
              label: 'Accept',
              icon: Icons.check_rounded,
              onPressed: () => _respond(accept: true),
            ),
          ),
        ],
      );
    }

    if (b.canStartJob) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start when you arrive — the ${b.effectiveDurationHours == b.effectiveDurationHours.roundToDouble() ? '${b.effectiveDurationHours.toInt()}' : b.effectiveDurationHours.toStringAsFixed(1)}-hour window runs from your start time.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: 'Start the job',
            icon: Icons.play_arrow_rounded,
            onPressed: () => _startJob(b),
          ),
        ],
      );
    }

    if (b.isInProgress && !b.canMarkCompleted) {
      final end = b.workEndsAt;
      final endLabel = end != null ? DateFormat('h:mm a').format(end) : 'later';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FigmaColors.tintBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FigmaColors.gray200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.timelapse_outlined, size: 20, color: FigmaColors.navy),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Job in progress. You can mark complete after $endLabel once the full work period has elapsed.',
                    style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (b.canMarkCompleted) {
      return AppPrimaryButton(
        label: 'Complete milestone',
        icon: Icons.task_alt_outlined,
        onPressed: () => _complete(b),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _detail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: FigmaColors.gray500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray900, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
