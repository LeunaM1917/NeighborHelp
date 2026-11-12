import '../../../models/admin_report.dart';
import '../../../services/admin_report_repository.dart';
import '../widgets/admin_report_generator.dart';
import '../widgets/admin_report_count_chart.dart';
import '../../../utils/report_analytics.dart';
import '../../../services/export_service.dart';
import '../widgets/admin_feedback_location_reports.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../services/auth_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_reports_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
    this.repository,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;
  final AdminReportRepository? repository;

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String _dateRange = 'This month';
  String _trendGranularity = 'Daily';

  late final AdminReportRepository _repository;
  late ReportPeriod _period;
  late Future<AdminReportData> _data;
  DateTimeRange? _customDates;
  AdminReportType _reportType = AdminReportType.transactions;
  String? _category, _provider, _status;
  AdminReportData? _lastData;
  AdminReportAnalytics? _analytics;
  AdminReportResult? _result;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminReportRepository();
    _reload();
  }

  void _reload({bool refresh = false}) {
    if (refresh) _repository.refresh();
    final now = DateTime.now().toUtc();
    _period = _customDates == null
        ? ReportPeriod.named(_dateRange, now)
        : ReportPeriod.dates(_customDates!.start, _customDates!.end, now);
    final uid = widget.auth.currentUser?.uid;
    _data = uid == null
        ? Future.error(StateError('Sign in required.'))
        : _repository.load(_period, uid);
    _lastData = null;
  }

  void _invalidate() {
    _analytics = null;
    _result = null;
  }

  Future<void> _pickDates() async {
    final today = reportLocal(DateTime.now());
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: _customDates,
    );
    if (dates != null && mounted) {
      setState(() {
        _customDates = dates;
        _reload();
      });
    }
  }

  Widget _filters(AdminReportData data) {
    final categories = {
      ...data.services.values.map((s) => s.category.trim()),
      'Other',
    }..remove('');
    final providers = {
      ...data.providers.map((p) => p.userId),
      ...data.bookings.map((b) => b.providerId),
      ...data.reviews.map((r) => r.providerId),
    }..remove('');
    final statuses = switch (_reportType) {
      AdminReportType.transactions =>
        data.bookings.map((b) => b.status).toSet().toList()..sort(),
      AdminReportType.verification => [
        'Approved',
        'Rejected',
        'Pending',
        'Not started',
      ],
      AdminReportType.feedback => [
        'positive',
        'neutral',
        'negative',
        'Unanalyzed',
      ],
      AdminReportType.providers => <String>[],
    };
    Widget filter(
      String label,
      String? value,
      Iterable<String> values,
      ValueChanged<String?> changed,
    ) => SizedBox(
      width: 230,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$value:$_reportType'),
        initialValue: value ?? '',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('All')),
          for (final option in {...values, if (value != null) value})
            DropdownMenuItem(
              value: option,
              child: Tooltip(
                message: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
        onChanged: (v) => setState(() {
          changed(v == '' ? null : v);
          _invalidate();
        }),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 290,
              child: DropdownButtonFormField<AdminReportType>(
                initialValue: _reportType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Report type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final type in AdminReportType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _reportType = v;
                      _status = null;
                      if (v == AdminReportType.verification) _category = null;
                      _invalidate();
                    });
                  }
                },
              ),
            ),
            if (_reportType != AdminReportType.verification)
              filter(
                'Category',
                _category,
                categories.toList()..sort(),
                (v) => _category = v,
              ),
            filter(
              'Provider ID',
              _provider,
              providers.toList()..sort(),
              (v) => _provider = v,
            ),
            if (statuses.isNotEmpty)
              filter('Status', _status, statuses, (v) => _status = v),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range),
              label: const Text('Custom dates'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _reload(refresh: true)),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(data.period.label, style: const TextStyle(fontSize: 12)),
        Text(
          'Snapshot: ${reportTimestampText(data.loadedAt)}. Refresh to load recent changes.',
          style: const TextStyle(fontSize: 12),
        ),
        const Text(
          'Bookings use request dates; ratings and sentiment use review submission dates. Records without those dates are excluded.',
          style: TextStyle(fontSize: 12),
        ),
        if (_status != null)
          const Text(
            'Status applies to the selected report; dashboard charts share the date, category and provider filters.',
            style: TextStyle(fontSize: 12),
          ),
        if (data.missingDates > 0)
          Text(
            '${data.missingDates} verification records have no usable date and are excluded.',
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }

  Widget _additionalStatistics(
    AdminReportData data,
    AdminReportAnalytics analytics,
  ) {
    final verification = AdminReportAnalytics(
      data,
      AdminReportFilter(provider: _provider),
    ).verifications;
    final statuses = <String, int>{};
    for (final booking in analytics.bookings) {
      statuses[booking.status] = (statuses[booking.status] ?? 0) + 1;
    }
    final transactions = AdminPanelCard(
      title: 'Transaction statistics',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Completed booking value: PHP ${analytics.completedValue.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text(
              'Agreed fees for completed bookings requested in this period. This is not a payment or revenue total.',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '${analytics.bookings.where((b) => b.isCompleted && !AdminReportAnalytics.validFee(b.totalFee)).length} completed bookings have no usable fee.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            AdminReportCountChart(
              labels: statuses.keys.toList(),
              series: const ['Bookings'],
              values: [
                for (final count in statuses.values) [count],
              ],
              periodLabel: data.period.label,
            ),
          ],
        ),
      ),
    );
    const labels = ['Approved', 'Rejected', 'Pending', 'Not started'];
    final identity = AdminPanelCard(
      title: 'Identity verification statistics',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Current status by verification update date; registration date is used for legacy records. Category does not apply to identity verification.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            AdminReportCountChart(
              labels: labels,
              series: const ['Users'],
              values: [
                for (final status in labels)
                  [verification.where((v) => v.status == status).length],
              ],
              periodLabel: data.period.label,
            ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 960
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: transactions),
                const SizedBox(width: 16),
                Expanded(child: identity),
              ],
            )
          : Column(
              children: [transactions, const SizedBox(height: 16), identity],
            ),
    );
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

    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: FutureBuilder<AdminReportData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AdminLoadingBox(message: 'Loading reports…');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Column(
              children: [
                const AdminErrorBox(
                  message:
                      'Could not load reports. Check your connection and administrator access.',
                ),
                TextButton(
                  onPressed: () => setState(() => _reload(refresh: true)),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          final data = snapshot.data!;
          if (!identical(_lastData, data)) {
            _lastData = data;
            _invalidate();
          }
          final filter = AdminReportFilter(
            category: _category,
            provider: _provider,
          );
          final analytics = _analytics ??= AdminReportAnalytics(data, filter);
          final report = _result ??= AdminReportAnalytics(
            data,
            AdminReportFilter(
              category: _category,
              provider: _provider,
              status: _status,
            ),
          ).generate(_reportType);
          final bookings = analytics.bookings;
          final reviews = analytics.reviews;
          final total = bookings.length, completed = analytics.completed;
          final categoryCounts = analytics.categories;
          final categoryRows = buildCategoryRows(
            bookings: bookings,
            servicesById: data.services,
            providers: data.providers,
            reviews: reviews,
          );
          final sorted = categoryCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topCategory = sorted.isEmpty ? '' : sorted.first.key;
          final topCategoryCount = sorted.isEmpty ? 0 : sorted.first.value;
          final topCategoryPct = total > 0
              ? (topCategoryCount * 100 / total).toStringAsFixed(1)
              : '0';
          final avgRating = analytics.averageRating;
          final rated = analytics.ratedReviews.length;
          final completionRate = total > 0 ? completed / total : 0.0;
          final ratingDist = analytics.ratingDistribution;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardHeader(
                title: 'Reports and Analytics',
                subtitle:
                    'Summary metrics computed from Firestore collections.',
                dateRange: _customDates == null ? _dateRange : 'Custom dates',
                dateRangeOptions: [
                  ...AdminDashboardHeader.dateRanges,
                  if (_customDates != null) 'Custom dates',
                ],
                onDateRangeChanged: (v) => setState(() {
                  if (v == 'Custom dates') {
                    _pickDates();
                    return;
                  }
                  _dateRange = v;
                  _customDates = null;
                  _reload();
                }),
                onExport: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => Dialog(
                      child: SizedBox(
                        width: 1100,
                        child: SingleChildScrollView(
                          child: AdminReportGenerator(result: report),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _filters(data),
              const SizedBox(height: 24),
              AdminFeedbackLocationReports(
                bookings: bookings,
                reviews: reviews,
                range: _dateRange,
                periodLabel: data.period.label,
              ),
              const SizedBox(height: 24),
              AdminMetricGrid(
                children: [
                  AdminMetricCard(
                    label: 'Total bookings',
                    value: '$total',
                    hint: 'Requested in the selected period',
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
                    trendLabel: total > 0
                        ? '${((completed / total) * 100).round()}% of total'
                        : '0% of total',
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
                    label: 'Provider rating',
                    value: avgRating > 0
                        ? '${avgRating.toStringAsFixed(2)} / 5'
                        : '—',
                    hint: rated > 0
                        ? 'From $rated customer reviews in this period'
                        : 'No ratings yet',
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
                            DropdownMenuItem(
                              value: 'Daily',
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: 'Weekly',
                              child: Text('Weekly'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _trendGranularity = v);
                            }
                          },
                        ),
                      ),
                    ),
                    child: AdminReportsTrendChart(
                      bookings: bookings,
                      granularity: _trendGranularity,
                      range: _dateRange,
                      period: data.period,
                    ),
                  );
                  final categoryCard = AdminPanelCard(
                    title: 'Bookings by category',
                    child: AdminReportsCategoryDonut(
                      categoryCounts: categoryCounts,
                      periodLabel: data.period.label,
                    ),
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
                    child: AdminReportsRatingDistribution(
                      distribution: ratingDist,
                      periodLabel: data.period.label,
                    ),
                  );
                  final ratingTime = AdminPanelCard(
                    title: 'Average rating over time',
                    child: AdminReportsRatingTrend(reviews: reviews),
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
                    onOpenRow: (r) =>
                        showAdminCategoryReportDetail(context, row: r),
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
                      ExportService.exportReport(
                        context,
                        report,
                        format: 'csv',
                      );
                    },
                    onViewBookings: () => widget.onNavigateToTab?.call(7),
                    onReviewProviders: () => widget.onNavigateToTab?.call(2),
                    onGenerateSummary: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: SizedBox(
                            width: 1100,
                            child: SingleChildScrollView(
                              child: AdminReportGenerator(result: report),
                            ),
                          ),
                        ),
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
                    children: [table, const SizedBox(height: 16), actions],
                  );
                },
              ),
              const SizedBox(height: 24),
              _additionalStatistics(data, analytics),
              const SizedBox(height: 24),
              AdminReportGenerator(result: report),
            ],
          );
        },
      ),
    );
  }
}
