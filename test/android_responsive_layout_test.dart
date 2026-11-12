// Firebase's official test mocks keep these layout checks offline.
// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/admin_report.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/review.dart';
import 'package:neighbor_help/models/inquiry.dart';
import 'package:neighbor_help/figma_ui/app_shell_layout.dart';
import 'package:neighbor_help/figma_ui/app_shell_tab.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/models/user_role.dart';
import 'package:neighbor_help/screens/admin/pages/admin_reports_page.dart';
import 'package:neighbor_help/screens/auth/login_screen.dart';
import 'package:neighbor_help/screens/customer/customer_service_detail_screen.dart';
import 'package:neighbor_help/screens/provider/provider_service_form_screen.dart';
import 'package:neighbor_help/screens/shared/agreement_amendment_screen.dart';
import 'package:neighbor_help/screens/shared/notifications_popover.dart';
import 'package:neighbor_help/screens/shared/messages_hub.dart';
import 'package:neighbor_help/services/admin_report_repository.dart';
import 'package:neighbor_help/services/auth_service.dart';
import 'package:neighbor_help/theme/app_theme.dart';
import 'package:neighbor_help/utils/report_analytics.dart';
import 'notifications_test.dart' as notification_fixture;
import 'service_management_workflow_test.dart' as service_fixture;
import 'support/ui_test_support.dart';
import 'support/fake_messaging_repository.dart';

class _AdminUser extends Fake implements User {
  @override
  String get uid => 'admin';
}

class _AdminAuth extends Fake implements AuthService {
  @override
  User get currentUser => _AdminUser();
  @override
  bool get isLocalAdminOnly => false;
}

class _Reports extends Fake implements AdminReportRepository {
  @override
  Future<AdminReportData> load(ReportPeriod period, String uid) async =>
      AdminReportData(
        period: period,
        loadedAt: period.endExclusive,
        bookings: [
          for (var i = 0; i < 3; i++)
            Booking.fromFirestore('b$i', {
              'providerId': 'p',
              'serviceId': 's',
              'status': 'Completed',
              'totalFee': 125.5,
              'createdAt': Timestamp.fromDate(period.start),
            }),
        ],
        reviews: [
          for (var i = 0; i < 3; i++)
            Review.fromFirestore('r$i', {
              'providerId': 'p',
              'serviceId': 's',
              'rating': i + 3,
              'createdAt': Timestamp.fromDate(period.start),
              'sentiment': {'label': 'positive', 'source': 'lstm'},
            }),
        ],
        services: {
          's': ServiceListing.fromFirestore('s', {'category': 'Cleaning'}),
        },
        providers: [],
        verifications: [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  tearDown(NotificationsPopover.hide);
  const cases = [
    (Size(320, 640), 1.0, 0.0),
    (Size(360, 740), 1.3, 0.0),
    (Size(412, 915), 1.3, 300.0),
    (Size(740, 360), 1.0, 0.0),
  ];
  for (final spec in cases) {
    final label = '${spec.$1}, text ${spec.$2}, keyboard ${spec.$3}';
    Future<void> show(WidgetTester tester, Widget child) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = spec.$1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: neighborHelpTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(spec.$2),
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
              viewInsets: EdgeInsets.only(bottom: spec.$3),
            ),
            child: child!,
          ),
          home: child,
        ),
      );
      await tester.pumpAndSettle();
    }

    testOnPlatform(
      'Android service form keeps actions separate at $label',
      (tester) async {
        await show(
          tester,
          ProviderServiceFormScreen(
            appUser: AppUser.fromFirestore('provider', {'role': 'Provider'}),
            firestore: service_fixture.ServiceFormStore(),
          ),
        );
        final submit = find.widgetWithText(FilledButton, 'Submit for approval');
        final draft = find.widgetWithText(OutlinedButton, 'Save as draft');
        expect(submit, findsOneWidget);
        expect(draft, findsOneWidget);
        expect(tester.getRect(submit).overlaps(tester.getRect(draft)), false);
        expect(
          tester.getRect(submit).bottom,
          lessThanOrEqualTo(spec.$1.height - spec.$3),
        );
        expect(tester.takeException(), isNull);
      },
      platform: TargetPlatform.android,
    );
    testOnPlatform(
      'Android booking form scrolls to its send action at $label',
      (tester) async {
        final location = TextEditingController(
              text: 'New Visayas, Panabo City',
            ),
            notes = TextEditingController();
        addTearDown(location.dispose);
        addTearDown(notes.dispose);
        var sent = 0;
        await show(
          tester,
          Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: BookingRequestPanel(
                  listing: ServiceListing.fromFirestore('s', {
                    'serviceTitle': 'House Cleaning',
                    'priceType': 'hourly',
                    'estimatedPrice': 125.5,
                  }),
                  location: location,
                  locationPicker: const Text('Service location confirmed'),
                  notes: notes,
                  preferredDate: DateTime(2026, 12, 1),
                  preferredTime: const TimeOfDay(hour: 9, minute: 0),
                  pricingMode: BookingPricingMode.hourly,
                  durationHours: 1.5,
                  hourlyRate: 125.5,
                  estimatedTotal: 188.25,
                  onPickDate: () {},
                  onPickTime: () {},
                  onSubmit: () => sent++,
                ),
              ),
            ),
          ),
        );
        final send = find.text('Send booking request');
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(sent, 1);
        expect(tester.takeException(), isNull);
      },
      platform: TargetPlatform.android,
    );
    testOnPlatform(
      'Android provider estimate remains scrollable at $label',
      (tester) async {
        await show(
          tester,
          AgreementAmendmentScreen(
            bookingId: 'layout-only',
            bookingData: {
              'requestVersion': 2,
              'serviceTitle': 'House Cleaning',
              'pricingType': 'hourly',
              'hourlyRate': 125.5,
              'durationHours': 1.5,
              'totalFee': 188.25,
              'scheduledDate': Timestamp.fromDate(DateTime.utc(2026, 12, 1, 1)),
            },
          ),
        );
        final action = find.text('Preview provider estimate');
        await tester.ensureVisible(action);
        expect(action, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      platform: TargetPlatform.android,
    );
    testOnPlatform(
      'Android login remains scrollable with safe areas at $label',
      (tester) async {
        await show(tester, const LoginScreen());
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
      platform: TargetPlatform.android,
    );
    testOnPlatform(
      'Android reports remain readable at $label',
      (tester) async {
        await show(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: AdminReportsPage(
                auth: _AdminAuth(),
                repository: _Reports(),
              ),
            ),
          ),
        );
        expect(find.text('Reports and Analytics'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      platform: TargetPlatform.android,
    );
    for (final provider in [false, true]) {
      testOnPlatform(
        'Android ${provider ? 'provider' : 'customer'} shell keeps navigation separate at $label',
        (tester) async {
          await show(
            tester,
            Scaffold(
              body: AppShellLayout(
                tabs: const [
                  AppShellTab(
                    label: 'Home',
                    icon: Icons.home,
                    selectedIcon: Icons.home,
                  ),
                  AppShellTab(
                    label: 'Services',
                    icon: Icons.work,
                    selectedIcon: Icons.work,
                  ),
                  AppShellTab(
                    label: 'Bookings',
                    icon: Icons.event,
                    selectedIcon: Icons.event,
                  ),
                  AppShellTab(
                    label: 'Messages',
                    shortLabel: 'Chat',
                    icon: Icons.chat,
                    selectedIcon: Icons.chat,
                  ),
                  AppShellTab(
                    label: 'Profile',
                    icon: Icons.person,
                    selectedIcon: Icons.person,
                  ),
                ],
                currentIndex: 0,
                onTabChanged: (_) {},
                appUser: AppUser.fromFirestore('phone', {
                  'role': provider ? 'Provider' : 'Customer',
                  'fullName': 'NeighborHelp Phone User',
                }),
                roleBadge: provider ? 'Provider' : 'Customer',
                onSignOut: () {},
                showUtilityActions: false,
                child: const Center(child: Text('Phone workspace')),
              ),
            ),
          );
          expect(find.text('Phone workspace'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        platform: TargetPlatform.android,
      );
      testOnPlatform(
        'Android ${provider ? 'provider' : 'customer'} messages fit at $label',
        (tester) async {
          final repo = FakeMessagingRepository()
            ..threads = [
              Inquiry('phone', {
                'customerId': 'c',
                'providerId': 'p',
                'serviceId': 's',
                'providerName': 'Service Provider With A Longer Name',
                'customerName': 'Phone Customer',
                'serviceTitle': 'House Cleaning',
                'lastMessage':
                    'The agreed schedule and booking details are ready.',
                'updatedAt': Timestamp.now(),
              }),
            ];
          await show(
            tester,
            Scaffold(
              body: SafeArea(
                child: MessagesHub(
                  appUser: AppUser.fromFirestore(provider ? 'p' : 'c', {
                    'role': provider ? 'Provider' : 'Customer',
                  }),
                  asCustomer: !provider,
                  repository: repo,
                ),
              ),
            ),
          );
          expect(find.text('Messages'), findsWidgets);
          await tester.tap(
            find
                .text(
                  provider
                      ? 'Phone Customer'
                      : 'Service Provider With A Longer Name',
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is TextField && w.decoration?.hintText == 'Send a message…',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
        platform: TargetPlatform.android,
      );
    }
    for (final role in [
      UserRole.customer,
      UserRole.provider,
      UserRole.administrator,
    ]) {
      testOnPlatform(
        'Android ${role.name} notification menu fits at $label',
        (tester) async {
          await show(
            tester,
            Scaffold(
              body: SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: NotificationBell(
                    appUser: notification_fixture.user(role),
                    stream: Stream.value([
                      notification_fixture.note(role, 'phone'),
                    ]),
                    onRead: (_) async {},
                    onReadAll: () async {},
                    onOpen: (_) async {},
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byTooltip('Notifications'));
          await tester.pumpAndSettle();
          final bounds = tester.getRect(
            find.byKey(const ValueKey('notifications-dropdown')),
          );
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(spec.$1.width));
          expect(bounds.bottom, lessThanOrEqualTo(spec.$1.height - spec.$3));
          expect(tester.takeException(), isNull);
        },
        platform: TargetPlatform.android,
      );
    }
  }
}
