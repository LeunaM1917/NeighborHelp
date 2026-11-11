import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/booking_user_report.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_account_actions.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_navigation.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_user_report_charts.dart';
import 'package:neighbor_help/utils/user_report_stats.dart';
import 'support/ui_test_support.dart';

BookingUserReport report(String status, DateTime created) => BookingUserReport(
  reportId: '$status-$created',
  bookingId: 'synthetic-booking',
  reporterId: 'customer',
  reporterRole: 'customer',
  reportedUserId: 'provider',
  reportedRole: 'provider',
  reason: 'Synthetic report',
  status: status,
  createdAt: Timestamp.fromDate(created),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  final now = DateTime.utc(2026, 11, 11);
  final samples = [
    report('resolved', DateTime.utc(2026, 5, 31, 15, 59)),
    report('open', DateTime.utc(2026, 5, 31, 16)),
    report('waiting_response', DateTime.utc(2026, 10, 31, 16)),
    report('under_review', DateTime.utc(2026, 11, 10)),
    report('dismissed', now),
    report('open', DateTime.utc(2026, 11, 12)),
    report('legacy_pending', DateTime.utc(2026, 7, 4)),
  ];

  void resize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test(
    'report counts include active disputes and month boundaries follow Manila time',
    () {
      final stats = UserReportStats.fromReports(samples, now: now);
      expect(stats.open, 5);
      expect(stats.resolved, 1);
      expect(stats.dismissed, 1);
      expect(stats.total, samples.length);
      expect(stats.months.first, DateTime.utc(2026, 6));
      expect(stats.monthlyCounts, [1, 1, 0, 0, 0, 3]);
      final yearBoundary = UserReportStats.fromReports([
        report('open', DateTime.utc(2025, 12, 31, 16)),
      ], now: DateTime.utc(2026, 1, 2));
      expect(yearBoundary.months.first, DateTime.utc(2025, 8));
      expect(yearBoundary.monthlyCounts.last, 1);
    },
  );

  for (final width in [360.0, 1280.0]) {
    testOnPlatform(
      'report charts show honest empty states and live data at $width',
      (tester) async {
        resize(tester, Size(width, 1000));
        Future<void> show(
          List<BookingUserReport> reports, {
          bool isLimited = false,
        }) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: AdminUserReportCharts(
                      stats: UserReportStats.fromReports(
                        reports,
                        now: now,
                        isLimited: isLimited,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show([]);
        expect(find.text('No reports yet'), findsOneWidget);
        expect(
          find.text('No reports received in this period.'),
          findsOneWidget,
        );
        expect(find.byType(PieChart), findsNothing);
        final statusY = tester.getTopLeft(find.text('Report status')).dy;
        final trendY = tester.getTopLeft(find.text('Reports received')).dy;
        expect(width < 760 ? trendY > statusY : trendY == statusY, true);
        await show(samples);
        expect(find.byType(PieChart), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);
        expect(find.text('5 (71%)'), findsOneWidget);
        expect(find.text('Jun 2026 – Nov 2026 · Asia/Manila'), findsOneWidget);
        expect(find.text('No reports yet'), findsNothing);
        await show(samples, isLimited: true);
        expect(find.text('Latest 7 reports · current status'), findsOneWidget);
        expect(
          find.text('Monthly counts among the latest 7 reports only'),
          findsOneWidget,
        );
        expect(find.text('All reports · current status'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final height in [320.0, 900.0]) {
    testOnPlatform(
      'admin notifications and account stay at rail bottom at height $height',
      (tester) async {
        resize(tester, Size(1280, height));
        var notifications = 0, signouts = 0;
        final admin = AppUser.fromFirestore('admin', {
          'fullName': 'Test Administrator',
          'role': 'Administrator',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  AdminNavigation(
                    currentIndex: 3,
                    onSelect: (_) {},
                    bottomActions: AdminAccountActions(
                      appUser: admin,
                      vertical: true,
                      onNotificationsTap: () => notifications++,
                      onSignOut: () => signouts++,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bell = find.byTooltip('Notifications');
        final account = find.byTooltip('Account menu');
        expect(tester.getCenter(bell).dy, greaterThan(height - 130));
        expect(
          tester.getCenter(account).dy,
          greaterThan(tester.getCenter(bell).dy),
        );
        expect(tester.getBottomRight(account).dy, lessThanOrEqualTo(height));
        await tester.tap(bell);
        await tester.pumpAndSettle();
        expect(notifications, 1);
        await tester.tap(account);
        await tester.pumpAndSettle();
        expect(find.text('Test Administrator'), findsOneWidget);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(signouts, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
