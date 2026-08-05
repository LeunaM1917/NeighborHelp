import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/widgets/figma_status_chip.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/service.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/role_theme.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/contract_panel.dart';
import '../../widgets/loading_indicator.dart';
import '../admin/widgets/admin_services_widgets.dart' show serviceCategoryIcon;

/// Booking request review — provider must open this before accepting or declining.
Future<void> showProviderBookingRequestReview(
  BuildContext context, {
  required AppUser appUser,
  required Booking booking,
}) async {
  if (MobileLayout.useBottomSheets(context)) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FigmaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ProviderBookingRequestReviewBody(
          appUser: appUser,
          booking: booking,
          scrollController: scrollController,
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: FigmaColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
        ),
        child: ProviderBookingRequestReviewBody(
          appUser: appUser,
          booking: booking,
        ),
      ),
    ),
  );
}

class ProviderBookingRequestReviewBody extends StatefulWidget {
  const ProviderBookingRequestReviewBody({
    super.key,
    required this.appUser,
    required this.booking,
    this.scrollController,
  });

  final AppUser appUser;
  final Booking booking;
  final ScrollController? scrollController;

  @override
  State<ProviderBookingRequestReviewBody> createState() => _ProviderBookingRequestReviewBodyState();
}

class _ProviderBookingRequestReviewBodyState extends State<ProviderBookingRequestReviewBody> {
  bool _busy = false;

  Future<void> _respond({required bool accept}) async {
    setState(() => _busy = true);
    try {
      await FirestoreService().providerRespondToBooking(
        bookingId: widget.booking.bookingId,
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
          const SnackBar(content: Text('Could not update booking. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return RoleThemeScope(
      palette: RoleTheme.provider,
      child: StreamBuilder<Booking?>(
        stream: firestore.bookingStream(widget.booking.bookingId),
        initialData: widget.booking,
        builder: (context, bookingSnap) {
          final b = bookingSnap.data ?? widget.booking;
          if (!b.isPending) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          }

          return FutureBuilder<ServiceListing?>(
            future: firestore.getService(b.serviceId),
            builder: (context, serviceSnap) {
              return StreamBuilder<AppUser?>(
                stream: firestore.userStream(b.customerId),
                builder: (context, customerSnap) {
                  if (serviceSnap.connectionState == ConnectionState.waiting &&
                      customerSnap.connectionState == ConnectionState.waiting &&
                      customerSnap.data == null) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: LoadingIndicator(message: 'Loading request…'),
                    );
                  }

                  final service = serviceSnap.data;
                  final customer = customerSnap.data;
                  final customerName = (customer?.fullName ?? '').trim().isNotEmpty
                      ? customer!.fullName
                      : 'Customer';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Booking request',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: FigmaColors.gray900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Review details before you accept or decline',
                                    style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _busy ? null : () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: FigmaColors.gray200),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _headerBlock(context, b, service, customerName),
                              const SizedBox(height: 16),
                              _summaryCard(b, service, customerName),
                              if (b.notes != null && b.notes!.trim().isNotEmpty) ...[
                                const SizedBox(height: 16),
                                AppSection(
                                  title: 'Customer notes',
                                  child: AppSurfaceCard(
                                    child: Text(
                                      b.notes!.trim(),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: FigmaColors.gray700,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              ContractPanel(
                                appUser: widget.appUser,
                                booking: b,
                                viewerRole: 'provider',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: FigmaColors.gray200),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          12 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: _busy
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _respond(accept: false),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        'Decline',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _headerBlock(
    BuildContext context,
    Booking b,
    ServiceListing? service,
    String customerName,
  ) {
    final rc = context.roleColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: rc.tint, borderRadius: BorderRadius.circular(10)),
            child: Icon(
              service != null
                  ? serviceCategoryIcon(service.category, service.serviceTitle)
                  : Icons.home_repair_service_outlined,
              color: rc.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service?.serviceTitle ?? 'Service',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (service?.category.isNotEmpty == true)
                  Text(
                    service!.category,
                    style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                  ),
                const SizedBox(height: 4),
                Text(
                  customerName,
                  style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                ),
              ],
            ),
          ),
          FigmaStatusChip(status: b.status),
        ],
      ),
    );
  }

  Widget _summaryCard(Booking b, ServiceListing? service, String customerName) {
    return AppSection(
      title: 'Booking summary',
      child: AppSurfaceCard(
        child: Column(
          children: [
            _summaryRow('Customer', customerName),
            const Divider(height: 1, color: FigmaColors.gray100),
            _summaryRow('Service', service?.serviceTitle ?? '—'),
            const Divider(height: 1, color: FigmaColors.gray100),
            _summaryRow('Date & time', b.scheduledWindowLabel),
            const Divider(height: 1, color: FigmaColors.gray100),
            _summaryRow(
              'Location',
              b.serviceLocation.isNotEmpty ? b.serviceLocation : 'Location TBD',
            ),
            if (b.totalFee != null) ...[
              const Divider(height: 1, color: FigmaColors.gray100),
              _summaryRow(
                'Estimated fee',
                b.pricingSummary != null
                    ? '₱${b.totalFee!.toStringAsFixed(0)} (${b.pricingSummary})'
                    : '₱${b.totalFee!.toStringAsFixed(0)}',
              ),
            ],
            const Divider(height: 1, color: FigmaColors.gray100),
            _summaryRow('Requested', DateFormat('MMM d, yyyy • h:mm a').format(b.createdAt.toDate())),
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
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
            ),
          ),
        ],
      ),
    );
  }
}
