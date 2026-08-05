import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../services/firestore_service.dart';
import '../theme/mobile_layout.dart';
import '../ui/app_ui_kit.dart';

class BookingUserReportCard extends StatefulWidget {
  const BookingUserReportCard({
    super.key,
    required this.appUser,
    required this.booking,
    required this.viewerRole, // 'customer' | 'provider'
    required this.reportedUserId,
    required this.reportedRole, // 'customer' | 'provider'
  });

  final AppUser appUser;
  final Booking booking;
  final String viewerRole;
  final String reportedUserId;
  final String reportedRole;

  @override
  State<BookingUserReportCard> createState() => _BookingUserReportCardState();
}

class _BookingUserReportCardState extends State<BookingUserReportCard> {
  bool _submitting = false;
  bool _submitted = false;

  static const _reasons = <String>[
    'Harassment / inappropriate behavior',
    'Scam / fraudulent activity',
    'Unsafe or dangerous behavior',
    'Dishonest communication',
    'Other',
  ];

  Future<({String reason, String details})?> _promptReport() async {
    final sheet = MobileLayout.useBottomSheets(context);
    final initialReason = _reasons.first;
    final detailsController = TextEditingController();
    var chosen = initialReason;

    Widget dialogBody() {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Report user',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: chosen,
                    isExpanded: true,
                    items: _reasons
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              r,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => _reasons
                        .map(
                          (r) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              r,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray900),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => chosen = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Additional details (optional)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (MobileLayout.useMobileChrome(context)) ...[
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, (reason: chosen, details: detailsController.text)),
                      style: FilledButton.styleFrom(
                        backgroundColor: FigmaColors.green,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Submit report'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Cancel'),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, (reason: chosen, details: detailsController.text)),
                            style: FilledButton.styleFrom(backgroundColor: FigmaColors.green),
                            child: const Text('Submit report'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    if (sheet) {
      return showModalBottomSheet<({String reason, String details})?>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AppSurfaceCard(
          child: dialogBody(),
        ),
      );
    }

    return showDialog<({String reason, String details})?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final maxW = MediaQuery.sizeOf(ctx).width - 48;
        return AlertDialog(
          title: null,
          content: SizedBox(width: maxW.clamp(280.0, 480.0), child: dialogBody()),
        );
      },
    );
  }

  Future<void> _submitReport() async {
    final r = await _promptReport();
    if (r == null || _submitted) return;

    setState(() => _submitting = true);
    try {
      await FirestoreService().createBookingUserReport(
        bookingId: widget.booking.bookingId,
        reporterId: widget.appUser.userId,
        reporterRole: widget.viewerRole,
        reportedUserId: widget.reportedUserId,
        reportedRole: widget.reportedRole,
        reason: r.reason,
        details: r.details,
      );
      if (!mounted) return;
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : 'Could not submit report. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.booking.isPending) return const SizedBox.shrink();

    if (_submitted) {
      return AppSection(
        title: 'Report user',
        child: AppSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your report has been submitted.',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.green),
            ),
          ),
        ),
      );
    }

    return AppSection(
      title: 'Report user',
      child: AppSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 22, color: FigmaColors.red600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Report the other party',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Share a reason. Admin will review it for this booking.',
                style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600, height: 1.4),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _submitting ? null : _submitReport,
                style: FilledButton.styleFrom(backgroundColor: FigmaColors.gray50),
                child: Text(
                  _submitting ? 'Submitting…' : 'Report user',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: FigmaColors.navy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

