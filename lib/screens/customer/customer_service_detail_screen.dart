import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/collections.dart';
import '../../figma_ui/figma_colors.dart';
import '../../theme/role_theme.dart';
import '../../figma_ui/figma_layout.dart';
import '../../theme/mobile_layout.dart';
import '../../figma_ui/widgets/figma_empty_state.dart';
import '../../figma_ui/marketing_service_images.dart';
import '../../figma_ui/widgets/figma_network_image.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/provider.dart';
import '../../models/review.dart';
import '../../models/service.dart';
import '../../models/service_approval_status.dart';
import '../../services/firestore_service.dart';
import '../../utils/listing_rating.dart';
import '../../utils/review_job_label.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/review_tile.dart';

class CustomerServiceDetailScreen extends StatefulWidget {
  const CustomerServiceDetailScreen({
    super.key,
    required this.appUser,
    required this.listing,
  });

  final AppUser appUser;
  final ServiceListing listing;

  @override
  State<CustomerServiceDetailScreen> createState() => _CustomerServiceDetailScreenState();
}

enum _BookingPricingMode { hourly, fixed }

const _bookingDurationOptions = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0];

class _CustomerServiceDetailScreenState extends State<CustomerServiceDetailScreen> {
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _fixedPrice = TextEditingController();
  DateTime? _preferredDate;
  TimeOfDay? _preferredTime;
  _BookingPricingMode _pricingMode = _BookingPricingMode.hourly;
  double _durationHours = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final pt = widget.listing.priceType.toLowerCase();
    _pricingMode = pt.contains('fixed') ? _BookingPricingMode.fixed : _BookingPricingMode.hourly;
    _fixedPrice.text = widget.listing.estimatedPrice.toStringAsFixed(0);
    _durationHours = _parseDefaultDuration(widget.listing.estimatedDuration);
    _preferredTime = const TimeOfDay(hour: 9, minute: 0);
  }

  double get _hourlyRate => widget.listing.estimatedPrice;

  double get _estimatedTotal {
    if (_pricingMode == _BookingPricingMode.hourly) {
      return _hourlyRate * _durationHours;
    }
    return double.tryParse(_fixedPrice.text.trim()) ?? 0;
  }

  static double _parseDefaultDuration(String raw) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
    if (match == null) return 1;
    final value = double.tryParse(match.group(1)!);
    return value != null && value > 0 ? value : 1;
  }

  @override
  void dispose() {
    _location.dispose();
    _notes.dispose();
    _fixedPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: StreamBuilder<AppUser?>(
          stream: firestore.userStream(widget.listing.providerId),
          builder: (context, providerUserSnap) {
            return StreamBuilder<ServiceProviderProfile?>(
              stream: firestore.providerProfileForUser(widget.listing.providerId),
              builder: (context, providerSnap) {
                final loading = providerUserSnap.connectionState == ConnectionState.waiting ||
                    providerSnap.connectionState == ConnectionState.waiting;

                if (loading) {
                  return const Center(
                    child: LoadingIndicator(message: 'Loading provider…', showBrand: true),
                  );
                }

                final imageUrl = widget.listing.serviceImages.isNotEmpty
                    ? widget.listing.serviceImages.first
                    : MarketingServiceImages.urlFor(
                        serviceName: widget.listing.serviceTitle,
                        categoryName: widget.listing.category,
                      );
                final compactPhoto = _ServiceHeroPhoto(url: imageUrl, compact: true);
                final headerCopy = _HeaderCopy(
                  listing: widget.listing,
                  providerUser: providerUserSnap.data,
                  providerProfile: providerSnap.data,
                );
                final left = _ServiceAndProviderSection(
                  listing: widget.listing,
                  providerId: widget.listing.providerId,
                  providerUser: providerUserSnap.data,
                  providerProfile: providerSnap.data,
                );
                final right = _BookingRequestPanel(
                  listing: widget.listing,
                  location: _location,
                  notes: _notes,
                  fixedPrice: _fixedPrice,
                  preferredDate: _preferredDate,
                  preferredTime: _preferredTime,
                  pricingMode: _pricingMode,
                  durationHours: _durationHours,
                  hourlyRate: _hourlyRate,
                  estimatedTotal: _estimatedTotal,
                  onPickDate: _pickDate,
                  onPickTime: _pickTime,
                  onPricingModeChanged: (m) => setState(() => _pricingMode = m),
                  onDurationChanged: (h) => setState(() => _durationHours = h),
                  onFixedPriceChanged: () => setState(() {}),
                  submitting: _submitting,
                  onSubmit: _submitBooking,
                );

                final nativeMobile = MobileLayout.isNativeApp(context);

                return SingleChildScrollView(
                  child: FigmaWideContainer(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        nativeMobile ? 8 : 16,
                        0,
                        nativeMobile ? MobileLayout.pageBottomPadding(context) : 80,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to services'),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, c) {
                              final wide = c.maxWidth >= 900;
                              if (!wide) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    headerCopy,
                                    const SizedBox(height: 16),
                                    _ServiceHeroPhoto(url: imageUrl, compact: false),
                                    const SizedBox(height: 24),
                                    left,
                                    const SizedBox(height: 24),
                                    right,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: headerCopy),
                                            const SizedBox(width: 20),
                                            compactPhoto,
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        left,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  SizedBox(
                                    width: 380,
                                    child: right,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null && mounted) setState(() => _preferredDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) setState(() => _preferredTime = picked);
  }

  Future<void> _submitBooking() async {
    if (_preferredDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a preferred date')),
      );
      return;
    }
    if (_preferredTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a preferred time')),
      );
      return;
    }
    if (_location.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a service location')),
      );
      return;
    }
    if (_pricingMode == _BookingPricingMode.fixed) {
      final fixed = double.tryParse(_fixedPrice.text.trim());
      if (fixed == null || fixed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid fixed price')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    final firestore = FirestoreService();
    final ref = FirebaseFirestore.instance.collection(FirestoreCollections.bookings).doc();
    final now = Timestamp.now();
    final startDt = DateTime(
      _preferredDate!.year,
      _preferredDate!.month,
      _preferredDate!.day,
      _preferredTime!.hour,
      _preferredTime!.minute,
    );
    final endDt = startDt.add(
      Duration(milliseconds: (_durationHours * 3600000).round()),
    );

    final isHourly = _pricingMode == _BookingPricingMode.hourly;
    final booking = Booking(
      bookingId: ref.id,
      customerId: widget.appUser.userId,
      providerId: widget.listing.providerId,
      serviceId: widget.listing.serviceId,
      serviceLocation: _location.text.trim(),
      location: widget.appUser.location ?? const GeoPoint(7.3081, 125.6842),
      scheduledDate: Timestamp.fromDate(startDt),
      scheduledEndDate: Timestamp.fromDate(endDt),
      status: 'Pending',
      totalFee: _estimatedTotal,
      pricingType: isHourly ? 'hourly' : 'fixed',
      hourlyRate: isHourly ? _hourlyRate : null,
      durationHours: _durationHours,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await firestore.createBooking(booking);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking request sent to the provider')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send booking request. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy({
    required this.listing,
    required this.providerUser,
    required this.providerProfile,
  });

  final ServiceListing listing;
  final AppUser? providerUser;
  final ServiceProviderProfile? providerProfile;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final providerName = providerUser?.fullName.trim().isNotEmpty == true
        ? providerUser!.fullName
        : 'Local service provider';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: FigmaColors.tintGreen,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            listing.category,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.green),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          listing.serviceTitle,
          style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: FigmaColors.gray900, height: 1.1),
        ),
        const SizedBox(height: 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              'Offered by $providerName',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: rc.primary),
            ),
            if (providerProfile?.isVerifiedProvider == true) const _VerifiedBadge(compact: true),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ServiceListing>>(
          stream: FirestoreService().servicesForProvider(listing.providerId),
          builder: (context, servicesSnap) {
            final serviceIds = serviceIdsMatchingListing(
              listing: listing,
              providerListings: servicesSnap.data ?? const <ServiceListing>[],
            );
            return StreamBuilder<List<Review>>(
              stream: FirestoreService().reviewsForProviderStream(listing.providerId),
              builder: (context, snap) {
                final rating = computeServiceListingRating(
                  reviews: snap.data ?? const <Review>[],
                  serviceIds: serviceIds,
                  profileAverage: providerProfile?.averageRating ?? 0,
                  profileReviewCount: providerProfile?.reviewCount ?? 0,
                );
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (rating.hasServiceReviews) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: FigmaColors.yellow500, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            rating.serviceRating.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.gray900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${rating.serviceReviewCount} for this service',
                            style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        'New for this service',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.gray900,
                        ),
                      ),
                    if (rating.hasOverallReviews)
                      Text(
                        'Overall ${rating.overallRating.toStringAsFixed(1)} (${rating.overallReviewCount})',
                        style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
                      ),
                    Text(
                      '${providerProfile?.completedBookings ?? 0} completed jobs',
                      style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: FigmaColors.tintGreen,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FigmaColors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: compact ? 16 : 18, color: FigmaColors.green),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: GoogleFonts.inter(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: FigmaColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Service listing hero image — [compact] fits beside the header on wide layouts.
class _ServiceHeroPhoto extends StatelessWidget {
  const _ServiceHeroPhoto({required this.url, this.compact = false});

  final String url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 240,
          height: 160,
          child: FigmaNetworkImage(url: url, fit: BoxFit.cover),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: FigmaNetworkImage(url: url, fit: BoxFit.cover),
      ),
    );
  }
}

class _ServiceAndProviderSection extends StatelessWidget {
  const _ServiceAndProviderSection({
    required this.listing,
    required this.providerId,
    required this.providerUser,
    required this.providerProfile,
  });

  final ServiceListing listing;
  final String providerId;
  final AppUser? providerUser;
  final ServiceProviderProfile? providerProfile;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoPanel(
          title: 'Service details',
          icon: Icons.description_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.description.isNotEmpty
                    ? listing.description
                    : 'This provider has not added a detailed description yet.',
                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.55),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FactChip(icon: Icons.payments_outlined, label: '₱${listing.estimatedPrice.toStringAsFixed(0)} ${listing.priceType}'),
                  _FactChip(icon: Icons.schedule_outlined, label: listing.estimatedDuration.isNotEmpty ? listing.estimatedDuration : 'Duration flexible'),
                  _FactChip(
                    icon: Icons.verified_outlined,
                    label: listing.isMarketplaceVisible
                        ? 'Live listing'
                        : listing.approvalStatus.isPending
                            ? 'Pending admin review'
                            : listing.approvalStatus == ServiceApprovalStatus.rejected
                                ? 'Not approved'
                                : 'Not visible',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _InfoPanel(
          title: 'Provider profile',
          icon: Icons.person_pin_circle_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: rc.tint,
                    backgroundImage: providerUser?.profilePhotoUrl != null ? NetworkImage(providerUser!.profilePhotoUrl!) : null,
                    child: providerUser?.profilePhotoUrl == null
                        ? Icon(Icons.person_outline, color: rc.primary)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              providerUser?.fullName ?? 'Local service provider',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
                            ),
                            if (providerProfile?.isVerifiedProvider == true) const _VerifiedBadge(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          providerProfile?.serviceArea.isNotEmpty == true
                              ? providerProfile!.serviceArea
                              : 'Serving nearby communities',
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                providerProfile?.bio.isNotEmpty == true
                    ? providerProfile!.bio
                    : 'Provider bio will appear here once they complete their profile.',
                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.5),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FactChip(icon: Icons.map_outlined, label: '${providerProfile?.serviceRadiusKm.toStringAsFixed(0) ?? '5'} km service radius'),
                  if (providerProfile?.isVerifiedProvider != true)
                    _FactChip(icon: Icons.pending_outlined, label: 'Verification pending'),
                  _FactChip(icon: Icons.handyman_outlined, label: '${providerProfile?.acceptedBookings ?? 0} accepted jobs'),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: listing.serviceImages.isNotEmpty
                    ? () => _openServicePhotos(context, listing.serviceImages)
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: rc.primary,
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: rc.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  listing.serviceImages.isNotEmpty
                      ? 'View service photos (${listing.serviceImages.length})'
                      : 'No service photos yet',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ReviewsSection(providerId: providerId),
      ],
    );
  }

  void _openServicePhotos(BuildContext context, List<String> images) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.85;
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          backgroundColor: FigmaColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Service photos',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: FigmaColors.gray600,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: FigmaColors.gray200),
                Expanded(child: _ServicePhotoGallery(images: images)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookingRequestPanel extends StatelessWidget {
  const _BookingRequestPanel({
    required this.listing,
    required this.location,
    required this.notes,
    required this.fixedPrice,
    required this.preferredDate,
    required this.preferredTime,
    required this.pricingMode,
    required this.durationHours,
    required this.hourlyRate,
    required this.estimatedTotal,
    required this.onPickDate,
    required this.onPickTime,
    required this.onPricingModeChanged,
    required this.onDurationChanged,
    required this.onFixedPriceChanged,
    required this.onSubmit,
    this.submitting = false,
  });

  final ServiceListing listing;
  final TextEditingController location;
  final TextEditingController notes;
  final TextEditingController fixedPrice;
  final DateTime? preferredDate;
  final TimeOfDay? preferredTime;
  final _BookingPricingMode pricingMode;
  final double durationHours;
  final double hourlyRate;
  final double estimatedTotal;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<_BookingPricingMode> onPricingModeChanged;
  final ValueChanged<double> onDurationChanged;
  final VoidCallback onFixedPriceChanged;
  final VoidCallback onSubmit;
  final bool submitting;

  String _durationLabel(double hours) {
    if (hours == hours.roundToDouble()) return '${hours.toInt()} hr${hours == 1 ? '' : 's'}';
    return '${hours.toStringAsFixed(1)} hrs';
  }

  static String _formatEndTime(
    BuildContext context,
    DateTime? date,
    TimeOfDay? start,
    double hours,
  ) {
    if (date == null || start == null) return '—';
    final startDt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
    final endDt = startDt.add(Duration(milliseconds: (hours * 3600000).round()));
    return TimeOfDay.fromDateTime(endDt).format(context);
  }

  static String _formatWindowSummary(
    BuildContext context,
    DateTime date,
    TimeOfDay start,
    double hours,
    String Function(double) durationLabel,
  ) {
    final startDt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
    final endDt = startDt.add(Duration(milliseconds: (hours * 3600000).round()));
    final dateFmt = DateFormat('MMM d, yyyy');
    return 'Provider sees: ${dateFmt.format(startDt)} • ${start.format(context)} – ${TimeOfDay.fromDateTime(endDt).format(context)} (${durationLabel(hours)})';
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final dateLabel = preferredDate == null
        ? 'Choose preferred date'
        : DateFormat.yMMMMd().format(preferredDate!);
    final startTimeLabel = preferredTime == null
        ? 'Choose start time'
        : preferredTime!.format(context);
    final endTimeLabel = _BookingRequestPanel._formatEndTime(
      context,
      preferredDate,
      preferredTime,
      durationHours,
    );
    final isHourly = pricingMode == _BookingPricingMode.hourly;

    return _InfoPanel(
      title: 'Booking request',
      icon: Icons.calendar_month_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Send a request to confirm availability before booking.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: location,
            decoration: const InputDecoration(
              labelText: 'Service location',
              hintText: 'Street, barangay, city',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(dateLabel),
          ),
          const SizedBox(height: 10),
          Text(
            'Service window',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<double>(
            // ignore: deprecated_member_use
            value: _bookingDurationOptions.contains(durationHours)
                ? durationHours
                : _bookingDurationOptions.first,
            decoration: InputDecoration(
              labelText: isHourly ? 'Estimated duration' : 'Expected duration',
              helperText: isHourly
                  ? null
                  : 'Fixed-rate jobs need a clear start and end so providers know the scope.',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.timelapse_outlined),
            ),
            items: [
              for (final h in _bookingDurationOptions)
                DropdownMenuItem(
                  value: h,
                  child: Text(_durationLabel(h)),
                ),
            ],
            onChanged: (v) {
              if (v != null) onDurationChanged(v);
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(startTimeLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EndTimeDisplay(label: endTimeLabel),
              ),
            ],
          ),
          if (preferredDate != null && preferredTime != null) ...[
            const SizedBox(height: 8),
            Text(
              _BookingRequestPanel._formatWindowSummary(
                context,
                preferredDate!,
                preferredTime!,
                durationHours,
                _durationLabel,
              ),
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600, height: 1.35),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'How do you want to pay?',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PricingModeChip(
                  label: 'Hourly rate',
                  subtitle: '₱${hourlyRate.toStringAsFixed(0)}/hr',
                  selected: isHourly,
                  onTap: () => onPricingModeChanged(_BookingPricingMode.hourly),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PricingModeChip(
                  label: 'Fixed rate',
                  subtitle: 'You set the price',
                  selected: !isHourly,
                  onTap: () => onPricingModeChanged(_BookingPricingMode.fixed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isHourly) ...[
            Text(
              '₱${hourlyRate.toStringAsFixed(0)} × ${_durationLabel(durationHours)} = ₱${estimatedTotal.toStringAsFixed(0)}',
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
            ),
          ] else ...[
            TextField(
              controller: fixedPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onFixedPriceChanged(),
              decoration: const InputDecoration(
                labelText: 'Your offered price (₱)',
                hintText: 'e.g. 500',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: notes,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Request notes',
              hintText: 'Describe the work needed or special instructions',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FigmaColors.gray50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FigmaColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Estimated service fee', style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
                    const Spacer(),
                    Text(
                      '₱${estimatedTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: rc.primary),
                    ),
                  ],
                ),
                if (isHourly) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Based on ₱${hourlyRate.toStringAsFixed(0)}/hr for ${_durationLabel(durationHours)}',
                    style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Fixed rate • ${_durationLabel(durationHours)} window',
                    style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(submitting ? 'Sending…' : 'Send booking request'),
          ),
        ],
      ),
    );
  }
}

class _EndTimeDisplay extends StatelessWidget {
  const _EndTimeDisplay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('End time', style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: FigmaColors.gray600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PricingModeChip extends StatelessWidget {
  const _PricingModeChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Material(
      color: selected ? rc.tint : FigmaColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? rc.primary : FigmaColors.gray200, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? rc.primary : FigmaColors.gray900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return _InfoPanel(
      title: 'Ratings and reviews',
      icon: Icons.reviews_outlined,
      child: FutureBuilder<List<Review>>(
        future: firestore.reviewsForProvider(providerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: LoadingIndicator(message: 'Loading reviews…'),
            );
          }
          final reviews = snap.data ?? [];
          if (reviews.isEmpty) {
            return const FigmaEmptyState(
              icon: Icons.star_border_rounded,
              title: 'No reviews yet',
              message: 'Completed customer reviews will appear here.',
            );
          }
          return FutureBuilder<Map<String, String>>(
            future: firestore.serviceTitlesByIds(reviews.map((r) => r.serviceId)),
            builder: (context, titlesSnap) {
              final titles = titlesSnap.data ?? const <String, String>{};
              final visible = reviews.take(6).toList();
              return Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    ReviewTile(
                      review: visible[i],
                      jobLabel: formatReviewJobLabel(
                        review: visible[i],
                        serviceTitle: titles[visible[i].serviceId],
                      ),
                    ),
                    if (i < visible.length - 1) const Divider(height: 24, color: FigmaColors.gray200),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: rc.tint, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: rc.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ServicePhotoGallery extends StatefulWidget {
  const _ServicePhotoGallery({required this.images});

  final List<String> images;

  @override
  State<_ServicePhotoGallery> createState() => _ServicePhotoGalleryState();
}

class _ServicePhotoGalleryState extends State<_ServicePhotoGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: FigmaColors.gray100,
            child: PageView.builder(
              controller: _controller,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => FigmaNetworkImage(url: images[i], fit: BoxFit.contain),
            ),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  Container(
                    width: i == _index ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index ? context.roleColors.primary : FigmaColors.gray300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          )
        else
          const SizedBox(height: 14),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: rc.primary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray700)),
        ],
      ),
    );
  }
}
