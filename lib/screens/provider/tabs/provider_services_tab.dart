import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../figma_ui/service_categories.dart';
import '../../../figma_ui/widgets/figma_empty_state.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/review.dart';
import '../../../models/service.dart';
import '../../../models/service_approval_status.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/mobile_layout.dart';
import '../../../theme/role_theme.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/stream_snapshot.dart';
import '../provider_availability_screen.dart';
import '../provider_service_form_screen.dart';
import '../widgets/provider_services_widgets.dart';

class ProviderServicesTab extends StatefulWidget {
  const ProviderServicesTab({
    super.key,
    required this.appUser,
    this.scrollController,
    this.onNavigateToTab,
  });

  final AppUser appUser;
  final ScrollController? scrollController;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<ProviderServicesTab> createState() => _ProviderServicesTabState();
}

class _ProviderServicesTabState extends State<ProviderServicesTab> {
  final _firestore = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All categories';
  String _status = 'All statuses';
  String _sort = 'Newest first';
  List<Review> _reviews = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
    unawaited(_loadReviews());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final profile = await _firestore.getProviderProfile(widget.appUser.userId);
    final providerId = profile?.providerId ?? widget.appUser.userId;
    final reviews = await _firestore.reviewsForProvider(providerId);
    if (!mounted) return;
    setState(() => _reviews = reviews);
  }

  Future<void> _openForm(BuildContext context, {ServiceListing? existing}) async {
    final saved = await ProviderServiceFormScreen.open(
      context,
      appUser: widget.appUser,
      existing: existing,
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Service published' : 'Service updated')),
      );
    }
  }

  /// Fits more cards per row in the main column (sidebar layout narrows this area).
  static int _serviceGridColumnCount(double width) {
    const gap = 16.0;
    const minCardWidth = 220.0;
    if (width < minCardWidth) return 1;
    return ((width + gap) / (minCardWidth + gap)).floor().clamp(1, 4);
  }

  Future<void> _toggleActive(BuildContext context, ServiceListing service) async {
    if (!service.approvalStatus.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing must be approved before you can pause or resume visibility.'),
        ),
      );
      return;
    }
    try {
      await _firestore.setServiceActive(service.serviceId, !service.isActive);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(service.isActive ? 'Service paused' : 'Service activated')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update service.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final categories = ServiceCategories.categoryNames;

    return ColoredBox(
      color: FigmaColors.gray50,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProviderServicesHero(),
            FigmaWideContainer(
              child: Padding(
                padding: const EdgeInsets.only(top: 28, bottom: 48),
                child: StreamBuilder<List<ServiceListing>>(
                  initialData: const [],
                  stream: _firestore.servicesForProviderUser(widget.appUser.userId),
                  builder: (context, serviceSnap) {
                    if (isStreamWaiting(serviceSnap)) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: LoadingIndicator(message: 'Loading services…'),
                      );
                    }

                    return StreamBuilder<List<Booking>>(
                      initialData: const [],
                      stream: _firestore.bookingsForProviderUser(widget.appUser.userId),
                      builder: (context, bookingSnap) {
                        final allServices = serviceSnap.data ?? [];
                        final bookings = bookingSnap.data ?? [];
                        final bookingCounts = bookingCountByService(bookings);
                        final ratings = ratingsByService(_reviews);

                        final active = allServices.where((s) => s.isMarketplaceVisible).length;
                        final paused = allServices
                            .where((s) => s.approvalStatus == ServiceApprovalStatus.pending)
                            .length;
                        final filtered = filterAndSortServices(
                          services: allServices,
                          query: _query,
                          category: _category,
                          status: _status,
                          sort: _sort,
                        );

                        final now = DateTime.now();
                        final thisMonth = bookings.where((b) {
                          final d = b.createdAt.toDate();
                          return d.year == now.year && d.month == now.month;
                        }).length;
                        final inquiries = bookings
                            .where((b) {
                              final s = b.status.toLowerCase();
                              return s == 'pending' || s == 'accepted' || s == 'in progress';
                            })
                            .length;
                        final completed = bookings.where((b) => b.status.toLowerCase() == 'completed').length;
                        final views = (thisMonth * 8 + allServices.length * 12).clamp(0, 9999);
                        final conversion = inquiries > 0 ? (completed / inquiries) * 100 : 0.0;
                        final trend = performanceTrendLabel();

                        final serviceCategories = [
                          ...{for (final s in allServices) if (s.category.isNotEmpty) s.category},
                        ]..sort();

                        final main = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProviderServicesStatsRow(
                              total: allServices.length,
                              active: active,
                              paused: paused,
                              totalBookings: bookings.length,
                            ),
                            const SizedBox(height: 24),
                            ProviderServicesFilterBar(
                              searchController: _searchController,
                              category: _category,
                              status: _status,
                              sort: _sort,
                              categories: serviceCategories.isNotEmpty ? serviceCategories : categories,
                              onCategoryChanged: (v) => setState(() => _category = v),
                              onStatusChanged: (v) => setState(() => _status = v),
                              onSortChanged: (v) => setState(() => _sort = v),
                              onAddService: () => _openForm(context),
                            ),
                            const SizedBox(height: 24),
                            if (filtered.isEmpty)
                              FigmaEmptyState(
                                icon: Icons.home_repair_service_outlined,
                                title: allServices.isEmpty ? 'No services listed' : 'No matching services',
                                message: allServices.isEmpty
                                    ? 'Add your first service so customers can find and book you.'
                                    : 'Try changing your search or filters.',
                                action: FilledButton.icon(
                                  onPressed: () => _openForm(context),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: rc.primary,
                                    foregroundColor: rc.onPrimary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add service'),
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, c) {
                                  final cols = _serviceGridColumnCount(c.maxWidth);
                                  final gap = 16.0;
                                  final w = cols == 1
                                      ? c.maxWidth
                                      : (c.maxWidth - gap * (cols - 1)) / cols;
                                  return Wrap(
                                    spacing: gap,
                                    runSpacing: gap,
                                    children: [
                                      for (final s in filtered)
                                        SizedBox(
                                          width: w,
                                          child: ProviderServiceGridCard(
                                            listing: s,
                                            bookingCount: bookingCounts[s.serviceId] ?? 0,
                                            rating: ratings[s.serviceId]?.avg ?? 0,
                                            reviewCount: ratings[s.serviceId]?.count ?? 0,
                                            onEdit: () => _openForm(context, existing: s),
                                            onMenu: (action) {
                                              if (action == 'edit') _openForm(context, existing: s);
                                              if (action == 'toggle') _toggleActive(context, s);
                                            },
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            const SizedBox(height: 20),
                            Center(
                              child: Text(
                                'Showing ${filtered.length} of ${allServices.length} services',
                                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
                              ),
                            ),
                          ],
                        );

                        final side = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!MobileLayout.isNativeApp(context)) ...[
                              ProviderServicesQuickActionsPanel(
                                onAddService: () => _openForm(context),
                                onManageServices: () {},
                                onUpdateAvailability: () {
                                  ProviderAvailabilityScreen.open(context, appUser: widget.appUser);
                                },
                                onViewBookings: () => widget.onNavigateToTab?.call(2),
                                onServiceSettings: () => widget.onNavigateToTab?.call(4),
                              ),
                              const SizedBox(height: 20),
                            ],
                            ProviderServicesPerformancePanel(
                              views: views,
                              inquiries: inquiries,
                              bookings: thisMonth,
                              conversionPct: conversion,
                              trendLabel: trend,
                            ),
                            const SizedBox(height: 20),
                            ProviderServicesProfileTipCard(
                              onAddPhotos: () {
                                if (filtered.isNotEmpty) {
                                  _openForm(context, existing: filtered.first);
                                } else if (allServices.isNotEmpty) {
                                  _openForm(context, existing: allServices.first);
                                } else {
                                  _openForm(context);
                                }
                              },
                            ),
                          ],
                        );

                        return LayoutBuilder(
                          builder: (context, c) {
                            if (c.maxWidth >= 1000) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: main),
                                  const SizedBox(width: 24),
                                  SizedBox(width: 300, child: side),
                                ],
                              );
                            }
                            return Column(
                              children: [main, const SizedBox(height: 28), side],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
