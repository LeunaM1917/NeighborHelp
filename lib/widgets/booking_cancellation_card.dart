import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../services/firestore_service.dart';
import '../theme/mobile_layout.dart';
import '../ui/app_ui_kit.dart';
import 'booking_cancellation_reason_dialog.dart';

/// Cancellation with acknowledgement checkbox and written reason (customer or provider).
class BookingCancellationCard extends StatefulWidget {
  const BookingCancellationCard({
    super.key,
    required this.appUser,
    required this.booking,
    required this.viewerRole,
    this.busy = false,
    this.onBusyChanged,
    this.onCancelled,
  });

  final AppUser appUser;
  final Booking booking;
  /// `customer` or `provider`
  final String viewerRole;
  final bool busy;
  final ValueChanged<bool>? onBusyChanged;
  final VoidCallback? onCancelled;

  bool get _isCustomer => viewerRole == 'customer';

  @override
  State<BookingCancellationCard> createState() => _BookingCancellationCardState();
}

class _BookingCancellationCardState extends State<BookingCancellationCard> {
  bool _acknowledged = false;

  bool get _canCancel =>
      widget._isCustomer ? widget.booking.canCustomerCancel : widget.booking.canProviderCancel;

  bool get _cancelledByViewer =>
      widget._isCustomer ? widget.booking.wasCancelledByCustomer : widget.booking.wasCancelledByProvider;

  bool get _cancelledByOther =>
      widget._isCustomer ? widget.booking.wasCancelledByProvider : widget.booking.wasCancelledByCustomer;

  Future<String?> _promptCancellationReason() {
    final sheet = MobileLayout.useBottomSheets(context);
    final audience = widget._isCustomer ? 'provider' : 'customer';
    final hint = widget._isCustomer
        ? 'e.g. My schedule changed and I need to cancel this booking.'
        : 'e.g. I have a scheduling conflict and cannot complete this milestone.';

    if (sheet) {
      return showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: BookingCancellationReasonDialog(
            useBottomSheet: true,
            audienceLabel: audience,
            hintExample: hint,
          ),
        ),
      );
    }
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BookingCancellationReasonDialog(
        useBottomSheet: false,
        audienceLabel: audience,
        hintExample: hint,
      ),
    );
  }

  Future<void> _openCancelDialog() async {
    final reason = await _promptCancellationReason();
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    widget.onBusyChanged?.call(true);
    try {
      final firestore = FirestoreService();
      if (widget._isCustomer) {
        await firestore.customerCancelBooking(
          bookingId: widget.booking.bookingId,
          customerId: widget.appUser.userId,
          reason: reason,
        );
      } else {
        await firestore.providerCancelBooking(
          bookingId: widget.booking.bookingId,
          providerId: widget.appUser.userId,
          reason: reason,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled')),
      );
      widget.onCancelled?.call();
    } catch (e) {
      if (mounted) {
        final message = e is StateError ? e.message : 'Could not cancel booking. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    if (b.isCancelled) {
      if (_cancelledByOther) {
        return AppSection(
          title: 'Cancellation',
          child: AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: FigmaColors.red600, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget._isCustomer
                            ? 'Your provider cancelled this booking'
                            : 'The customer cancelled this booking',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.gray900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (b.cancellationReason != null && b.cancellationReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Their explanation',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.cancellationReason!.trim(),
                    style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      if (!_cancelledByViewer) return const SizedBox.shrink();
      return AppSection(
        title: 'Cancellation',
        child: AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: FigmaColors.red600, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You cancelled this booking',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.gray900,
                      ),
                    ),
                  ),
                ],
              ),
              if (b.cancellationReason != null && b.cancellationReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Your explanation',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray500),
                ),
                const SizedBox(height: 4),
                Text(
                  b.cancellationReason!.trim(),
                  style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (!_canCancel) return const SizedBox.shrink();

    final canSubmit = _acknowledged && !widget.busy;
    final intro = widget._isCustomer
        ? 'Need to cancel this booking? Your provider will be notified right away.'
        : 'Need to back out of this job? Cancelling notifies the customer immediately.';
    final checkbox = widget._isCustomer
        ? 'I understand that cancelling may affect my account and the provider\'s schedule.'
        : 'I understand that cancelling may affect my reputation and the customer\'s schedule.';
    final buttonLabel = widget._isCustomer ? 'Cancel booking' : 'Cancel job';

    return AppSection(
      title: 'Cancellation',
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              intro,
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.45),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: widget.busy ? null : (v) => setState(() => _acknowledged = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                checkbox,
                style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800, height: 1.4),
              ),
              activeColor: FigmaColors.red600,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: canSubmit ? _openCancelDialog : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: canSubmit ? FigmaColors.red600 : FigmaColors.gray400,
                disabledForegroundColor: FigmaColors.gray400,
                side: BorderSide(
                  color: canSubmit ? FigmaColors.red600 : FigmaColors.gray300,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: widget.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      buttonLabel,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
