import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/admin_report.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/review.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/screens/admin/pages/admin_reports_page.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_report_generator.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_reports_widgets.dart';
import 'package:neighbor_help/services/admin_report_repository.dart';
import 'package:neighbor_help/services/auth_service.dart';
import 'package:neighbor_help/utils/report_analytics.dart';
import 'support/ui_test_support.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
}

class _Auth extends Fake implements AuthService {
  @override
  User get currentUser => _User();
  @override
  bool get isLocalAdminOnly => false;
}

class _Repository extends Fake implements AdminReportRepository {
  int reads = 0, refreshes = 0;
  Completer<AdminReportData>? pending;
  bool fail = false;
  @override
  void refresh() {
    refreshes++;
  }

  @override
  Future<AdminReportData> load(ReportPeriod period, String uid) async {
    reads++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('denied');
    return _data(period);
  }
}

AdminReportData _data(ReportPeriod period) => AdminReportData(
  period: period,
  loadedAt: period.endExclusive,
  providers: [],
  verifications: [],
  services: {
    's': ServiceListing.fromFirestore('s', {'category': 'Cleaning'}),
  },
  bookings: [
    for (var i = 0; i < 14; i++)
      Booking.fromFirestore('b$i', {
        'providerId': 'p',
        'serviceId': 's',
        'status': 'Completed',
        'totalFee': 20,
        'createdAt': Timestamp.fromDate(period.start),
      }),
  ],
  reviews: [
    for (var i = 0; i < 3; i++)
      Review.fromFirestore('r$i', {
        'providerId': 'p',
        'serviceId': 's',
        'rating': i + 3,
        'createdAt': Timestamp.fromDate(
          period.start.add(Duration(hours: 24 * i)),
        ),
        'sentiment': {'label': 'positive', 'source': 'lstm'},
      }),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'reports remain usable at $width and local controls do not refetch',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminReportsPage(auth: _Auth(), repository: repository),
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
        expect(repository.reads, 1);
        expect(find.text('Transaction statistics'), findsOneWidget);
        expect(find.text('Identity verification statistics'), findsOneWidget);
        expect(
          find.text('From 3 customer reviews in this period'),
          findsOneWidget,
        );
        expect(find.text('↑ vs last month'), findsNothing);
        expect(tester.takeException(), isNull);

        final granularity = find.byWidgetPredicate(
          (w) => w is DropdownButton<String> && w.value == 'Daily',
        );
        await tester.ensureVisible(granularity);
        await tester.tap(granularity);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
        await tester.tap(find.text('Weekly').last);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
        expect(repository.reads, 1);
        expect(
          tester
              .widget<AdminReportsTrendChart>(
                find.byType(AdminReportsTrendChart),
              )
              .granularity,
          'Weekly',
        );

        await tester.ensureVisible(find.text('Report generation'));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
        expect(find.text('1–10 of 14 records'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Next records'));
        await tester.tap(find.byTooltip('Next records'));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
        expect(find.text('11–14 of 14 records'), findsOneWidget);

        final selector = find.byWidgetPredicate(
          (w) => w is DropdownButton<AdminReportType>,
        );
        for (final type in AdminReportType.values.skip(1)) {
          await tester.ensureVisible(selector);
          await tester.tap(selector);
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 3),
          );
          await tester.tap(find.text(type.label).last);
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 3),
          );
          expect(
            tester
                .widget<AdminReportGenerator>(find.byType(AdminReportGenerator))
                .result
                .type,
            type,
          );
          expect(repository.reads, 1);
          expect(tester.takeException(), isNull);
        }

        await tester.ensureVisible(find.text('Refresh'));
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
        expect(repository.reads, 2);
        expect(repository.refreshes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'loading and failed requests do not show misleading zero statistics',
    (tester) async {
      final repository = _Repository()..pending = Completer<AdminReportData>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminReportsPage(auth: _Auth(), repository: repository),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Loading reports…'), findsOneWidget);
      expect(find.text('Total bookings'), findsNothing);
      repository.pending!.completeError(StateError('denied'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(
        find.text(
          'Could not load reports. Check your connection and administrator access.',
        ),
        findsOneWidget,
      );
      expect(find.text('Total bookings'), findsNothing);
      repository.pending = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(repository.reads, 2);
      expect(find.text('Total bookings'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'donut retains all categories and rating charts retain data points',
    (tester) async {
      final period = ReportPeriod.named(
        'This month',
        DateTime.utc(2026, 11, 13),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AdminReportsCategoryDonut(
                    categoryCounts: {
                      for (var i = 1; i <= 9; i++) 'Category $i': i,
                    },
                    periodLabel: period.label,
                  ),
                  AdminReportsRatingTrend(reviews: _data(period).reviews),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(find.text('Category 9'), findsOneWidget);
      expect(find.text('Category 1'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .length,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
