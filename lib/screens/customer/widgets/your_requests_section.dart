import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/widgets/figma_empty_state.dart';
import '../../../figma_ui/widgets/figma_status_chip.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/mobile_layout.dart';
import '../../../theme/role_theme.dart';
import '../../../ui/app_ui_kit.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/stream_snapshot.dart';
import '../customer_booking_detail_screen.dart';

enum _RequestFilter { all, inProgress, completed, cancelled }

/// Customer home — booking list with status tabs (reference: Your Requests).
class YourRequestsSection extends StatefulWidget {
  const YourRequestsSection({
    super.key,
    required this.appUser,
    this.onViewAll,
    this.maxItems = 8,
  });

  final AppUser appUser;
  final VoidCallback? onViewAll;
  final int maxItems;

  @override
  State<YourRequestsSection> createState() => _YourRequestsSectionState();
}

class _YourRequestsSectionState extends State<YourRequestsSection> {
  final FirestoreService _firestore = FirestoreService();
  _RequestFilter _filter = _RequestFilter.all;

  Map<String, ServiceListing?> _services = {};
  Map<String, AppUser?> _providers = {};
  Map<String, ServiceProviderProfile?> _providerProfiles = {};
  String? _hydratedForKey;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your Requests',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
              ),
            ),
            TextButton(
              onPressed: widget.onViewAll,
              child: Text(
                'View all',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: rc.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Booking>>(
          stream: _firestore.bookingsForUser(widget.appUser.userId, asCustomer: true),
          builder: (context, snap) {
            if (isStreamWaiting(snap)) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: LoadingIndicator(message: 'Loading your requests…'),
              );
            }
            final bookings = snap.data ?? [];
            return FutureBuilder<void>(
              future: _hydrate(bookings),
              builder: (context, hydrateSnap) {
                if (hydrateSnap.connectionState != ConnectionState.done && bookings.isNotEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: LoadingIndicator(message: 'Loading request details…'),
                  );
                }

                final counts = _tabCounts(bookings);
                final filtered = _filterBookings(bookings, _filter);
                final visible = filtered.take(widget.maxItems).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RequestTabs(
                      selected: _filter,
                      counts: counts,
                      onSelected: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      AppSurfaceCard(
                        padding: const EdgeInsets.all(24),
                        child: FigmaEmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No requests here',
                          message: _filter == _RequestFilter.all
                              ? 'Book a service to see your requests on this list.'
                              : 'Try another tab to see other bookings.',
                        ),
                      )
                    else
                      AppSurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < visible.length; i++) ...[
                              if (i > 0) const Divider(height: 1, color: FigmaColors.gray200),
                              _RequestRow(
                                booking: visible[i],
                                service: _services[visible[i].serviceId],
                                provider: _providers[visible[i].providerId],
                                providerRating: _providerProfiles[visible[i].providerId]?.averageRating,
                                dateFmt: DateFormat('MMM d, yyyy • h:mm a'),
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerBookingDetailScreen(
                                        appUser: widget.appUser,
                                        booking: visible[i],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
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

  Future<void> _hydrate(List<Booking> bookings) async {
    final key = bookings.map((b) => b.bookingId).join(',');
    if (_hydratedForKey == key) return;
    if (bookings.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hydratedForKey = '';
        _services = {};
        _providers = {};
        _providerProfiles = {};
      });
      return;
    }
    final services = <String, ServiceListing?>{};
    final providers = <String, AppUser?>{};
    final profiles = <String, ServiceProviderProfile?>{};
    for (final b in bookings) {
      services[b.serviceId] ??= await _firestore.getService(b.serviceId);
      providers[b.providerId] ??= await _firestore.getUser(b.providerId);
      profiles[b.providerId] ??= await _firestore.getProviderProfile(b.providerId);
    }
    if (!mounted) return;
    setState(() {
      _hydratedForKey = key;
      _services = services;
      _providers = providers;
      _providerProfiles = profiles;
    });
  }
}

Map<_RequestFilter, int> _tabCounts(List<Booking> bookings) {
  return {
    _RequestFilter.all: bookings.length,
    _RequestFilter.inProgress: bookings.where((b) => _matchesFilter(b, _RequestFilter.inProgress)).length,
    _RequestFilter.completed: bookings.where((b) => _matchesFilter(b, _RequestFilter.completed)).length,
    _RequestFilter.cancelled: bookings.where((b) => _matchesFilter(b, _RequestFilter.cancelled)).length,
  };
}

List<Booking> _filterBookings(List<Booking> bookings, _RequestFilter filter) {
  if (filter == _RequestFilter.all) return bookings;
  return bookings.where((b) => _matchesFilter(b, filter)).toList();
}

bool _matchesFilter(Booking booking, _RequestFilter filter) {
  final s = booking.status.toLowerCase();
  switch (filter) {
    case _RequestFilter.all:
      return true;
    case _RequestFilter.inProgress:
      return s == 'pending' || s == 'accepted' || s == 'in progress';
    case _RequestFilter.completed:
      return s == 'completed' || s == 'milestone complete';
    case _RequestFilter.cancelled:
      return s == 'cancelled' || s == 'canceled';
  }
}

String _displayStatus(String status) {
  final s = status.toLowerCase();
  if (s == 'completed') return 'Completed';
  if (s == 'cancelled' || s == 'canceled') return 'Cancelled';
  if (s == 'in progress' || s == 'accepted' || s == 'pending') return 'In Progress';
  return status;
}

class _RequestIconStyle {
  const _RequestIconStyle(this.icon, this.bg, this.fg);
  final IconData icon;
  final Color bg;
  final Color fg;
}

_RequestIconStyle _iconStyleFor(String category) {
  final c = category.toLowerCase();
  if (c.contains('clean')) {
    return const _RequestIconStyle(Icons.cleaning_services, FigmaColors.yellow50, FigmaColors.yellow500);
  }
  if (c.contains('errand') || c.contains('moving') || c.contains('grocery') || c.contains('shop')) {
    return const _RequestIconStyle(Icons.shopping_cart_outlined, FigmaColors.tintGreen, FigmaColors.green);
  }
  if (c.contains('document') || c.contains('delivery')) {
    return const _RequestIconStyle(Icons.description_outlined, FigmaColors.gray100, FigmaColors.gray600);
  }
  return const _RequestIconStyle(Icons.home_repair_service_outlined, FigmaColors.tintBlue, FigmaColors.navy);
}

class _RequestTabs extends StatelessWidget {
  const _RequestTabs({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _RequestFilter selected;
  final Map<_RequestFilter, int> counts;
  final ValueChanged<_RequestFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    Widget tab(_RequestFilter f, String label) {
      final active = selected == f;
      return InkWell(
        onTap: () => onSelected(f),
        child: Padding(
          padding: const EdgeInsets.only(right: 20, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label (${counts[f] ?? 0})',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? rc.primary : FigmaColors.gray600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 2,
                width: active ? 48 : 0,
                decoration: BoxDecoration(
                  color: active ? rc.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tabs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tab(_RequestFilter.all, 'All'),
        tab(_RequestFilter.inProgress, 'In Progress'),
        tab(_RequestFilter.completed, 'Completed'),
        tab(_RequestFilter.cancelled, 'Cancelled'),
      ],
    );

    if (MobileLayout.isNativeApp(context)) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: tabs,
      );
    }
    return tabs;
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.booking,
    required this.service,
    required this.provider,
    this.providerRating,
    required this.dateFmt,
    required this.onTap,
  });

  final Booking booking;
  final ServiceListing? service;
  final AppUser? provider;
  final double? providerRating;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = service?.serviceTitle ?? 'Service request';
    final iconStyle = _iconStyleFor(service?.category ?? title);
    final providerName = provider?.fullName.isNotEmpty == true ? provider!.fullName : 'Provider';
    final ratingLabel = providerRating != null && providerRating! > 0 ? providerRating!.toStringAsFixed(1) : 'New';
    final location = booking.serviceLocation.isNotEmpty ? booking.serviceLocation : 'Location not set';

    if (MobileLayout.isNativeApp(context)) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconStyle.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(iconStyle.icon, color: iconStyle.fg, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking.scheduledWindowLabel,
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FigmaStatusChip(status: _displayStatus(booking.status)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: FigmaColors.gray500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: FigmaColors.gray200,
                    backgroundImage: provider?.profilePhotoUrl != null ? NetworkImage(provider!.profilePhotoUrl!) : null,
                    child: provider?.profilePhotoUrl == null
                        ? Text(
                            providerName[0].toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: FigmaColors.gray700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: FigmaColors.yellow500),
                            const SizedBox(width: 2),
                            Text(
                              ratingLabel,
                              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconStyle.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconStyle.icon, color: iconStyle.fg, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.scheduledWindowLabel,
                    style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: FigmaColors.gray500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FigmaStatusChip(status: _displayStatus(booking.status)),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: FigmaColors.gray200,
                    backgroundImage: provider?.profilePhotoUrl != null ? NetworkImage(provider!.profilePhotoUrl!) : null,
                    child: provider?.profilePhotoUrl == null
                        ? Text(
                            providerName[0].toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: FigmaColors.yellow500),
                            const SizedBox(width: 2),
                            Text(
                              ratingLabel,
                              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
