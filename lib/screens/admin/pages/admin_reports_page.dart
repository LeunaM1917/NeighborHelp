import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_reports_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String _dateRange = 'This month';
  String _trendGranularity = 'Daily';

  String _trendHint(int count) {
    if (count <= 0) return '— 0% vs last month';
    return '↑ vs last month';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Reports and Analytics',
        subtitle: 'Summary metrics computed from Firestore collections.',
        child: const AdminErrorBox(message: 'Firebase admin required.'),
      );
    }

    final firestore = FirestoreService();

    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: StreamBuilder<List<Booking>>(
        stream: firestore.allBookingsStream(),
        builder: (context, bookingSnap) {
          if (bookingSnap.connectionState == ConnectionState.waiting) {
            return const AdminLoadingBox(message: 'Loading reports…');
          }

          return StreamBuilder<List<ServiceListing>>(
            stream: firestore.allServicesStream(),
            builder: (context, serviceSnap) {
              return StreamBuilder<List<ServiceProviderProfile>>(
                stream: firestore.serviceProvidersStream(),
                builder: (context, providerSnap) {
                  final bookings = bookingSnap.data ?? [];
                  final servicesById = <String, ServiceListing>{
                    for (final s in serviceSnap.data ?? []) s.serviceId: s,
                  };
                  final providers = providerSnap.data ?? [];

                  final total = bookings.length;
                  var completed = 0;
                  for (final b in bookings) {
                    if (b.status.toLowerCase() == 'completed') completed++;
                  }

                  final categoryCounts = bookingCountsByCategory(bookings, servicesById);
                  final categoryRows = buildCategoryRows(
                    bookings: bookings,
                    servicesById: servicesById,
                    providers: providers,
                  );

                  var topCategory = '';
                  var topCategoryCount = 0;
                  categoryCounts.forEach((cat, n) {
                    if (n > topCategoryCount) {
                      topCategory = cat;
                      topCategoryCount = n;
                    }
                  });
                  final topCategoryPct = total > 0 ? ((topCategoryCount / total) * 100).toStringAsFixed(1) : '0';

                  var ratingSum = 0.0;
                  var rated = 0;
                  for (final p in providers) {
                    if (p.averageRating > 0) {
                      ratingSum += p.averageRating;
                      rated++;
                    }
                  }
                  final avgRating = rated > 0 ? ratingSum / rated : 0.0;
                  final completionRate = total > 0 ? completed / total : 0.0;
                  final ratingDist = providerRatingDistribution(providers);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminDashboardHeader(
                        title: 'Reports and Analytics',
                        subtitle: 'Summary metrics computed from Firestore collections.',
                        dateRange: _dateRange,
                        onDateRangeChanged: (v) => setState(() => _dateRange = v),
                        onExport: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export report — coming soon.')),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      AdminMetricGrid(
                        children: [
                          AdminMetricCard(
                            label: 'Total bookings',
                            value: '$total',
                            hint: _trendHint(total),
                            icon: Icons.event_note_outlined,
                            iconBg: FigmaColors.tintGreen,
                            iconColor: FigmaColors.green,
                          ),
                          AdminMetricCard(
                            label: 'Completed bookings',
                            value: '$completed',
                            hint: 'Successfully finished',
                            icon: Icons.check_circle_outline,
                            iconBg: FigmaColors.tintGreen2,
                            iconColor: FigmaColors.green,
                            trendLabel: total > 0 ? '${((completed / total) * 100).round()}% of total' : '0% of total',
                          ),
                          AdminMetricCard(
                            label: 'Top category',
                            value: topCategory.isEmpty ? '—' : topCategory,
                            hint: topCategory.isEmpty
                                ? 'No bookings yet'
                                : '$topCategoryCount bookings ($topCategoryPct%)',
                            icon: Icons.sell_outlined,
                            iconBg: FigmaColors.tintBlue,
                            iconColor: FigmaColors.green,
                          ),
                          AdminMetricCard(
                            label: 'Average provider rating',
                            value: avgRating > 0 ? '${avgRating.toStringAsFixed(2)} / 5' : '—',
                            hint: rated > 0 ? '↑ from $rated rated providers' : 'No ratings yet',
                            icon: Icons.star_outline,
                            iconBg: FigmaColors.yellow50,
                            iconColor: FigmaColors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 900;
                          final trendCard = AdminPanelCard(
                            title: 'Bookings trend',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: FigmaColors.gray300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _trendGranularity,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  items: const [
                                    DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                                    DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _trendGranularity = v);
                                  },
                                ),
                              ),
                            ),
                            child: AdminReportsTrendChart(
                              bookings: bookings,
                              granularity: _trendGranularity,
                            ),
                          );
                          final categoryCard = AdminPanelCard(
                            title: 'Bookings by category',
                            child: AdminReportsCategoryDonut(categoryCounts: categoryCounts),
                          );

                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: trendCard),
                                const SizedBox(width: 16),
                                Expanded(child: categoryCard),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              trendCard,
                              const SizedBox(height: 16),
                              categoryCard,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth;
                          final quality = AdminPanelCard(
                            title: 'Provider quality distribution',
                            child: AdminReportsRatingDistribution(distribution: ratingDist),
                          );
                          final ratingTime = AdminPanelCard(
                            title: 'Average rating over time',
                            child: AdminReportsRatingTrend(providers: providers),
                          );
                          final insights = AdminReportsInsightsPanel(
                            completionRate: completionRate,
                            completed: completed,
                            total: total,
                            topCategory: topCategory,
                            avgRating: avgRating,
                          );

                          if (w >= 960) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: quality),
                                const SizedBox(width: 16),
                                Expanded(child: ratingTime),
                                const SizedBox(width: 16),
                                Expanded(child: insights),
                              ],
                            );
                          }
                          if (w >= 640) {
                            return Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: quality),
                                    const SizedBox(width: 16),
                                    Expanded(child: ratingTime),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                insights,
                              ],
                            );
                          }
                          return Column(
                            children: [
                              quality,
                              const SizedBox(height: 16),
                              ratingTime,
                              const SizedBox(height: 16),
                              insights,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 720;
                          final table = AdminReportsCategoryTable(
                            rows: categoryRows,
                            onOpenRow: (r) => showAdminCategoryReportDetail(context, row: r),
                            onViewAll: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    categoryRows.isEmpty
                                        ? 'No categories to show'
                                        : '${categoryRows.length} categories in report',
                                  ),
                                ),
                              );
                            },
                          );
                          final actions = AdminReportsQuickActions(
                            onExportCsv: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Export CSV — coming soon.')),
                              );
                            },
                            onViewBookings: () => widget.onNavigateToTab?.call(7),
                            onReviewProviders: () => widget.onNavigateToTab?.call(2),
                            onGenerateSummary: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Generate summary — coming soon.')),
                              );
                            },
                          );

                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: table),
                                const SizedBox(width: 16),
                                Expanded(child: actions),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              table,
                              const SizedBox(height: 16),
                              actions,
                            ],
                          );
                        },
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
}
