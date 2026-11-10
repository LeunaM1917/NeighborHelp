import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/booking_user_report.dart';
import 'package:neighbor_help/models/inquiry.dart';
import 'package:neighbor_help/models/message.dart';
import 'package:neighbor_help/screens/shared/messages_hub.dart';
import 'package:neighbor_help/theme/role_theme.dart';
import 'package:neighbor_help/widgets/dispute_case_panel.dart';
import 'package:neighbor_help/widgets/report_photo_picker.dart';
import 'support/fake_messaging_repository.dart';
import 'support/ui_test_support.dart';

void main() {
  setUpOfflineFonts();
  final customer = AppUser.fromFirestore('c', {
    'fullName': 'Customer Name',
    'role': 'Customer',
  });
  final admin = AppUser.fromFirestore('a', {
    'fullName': 'Admin Name',
    'role': 'Administrator',
  });
  BookingUserReport report({
    String status = 'under_review',
    Map<String, dynamic>? proposal,
  }) => BookingUserReport.fromFirestore('report', {
    'bookingId': 'b',
    'reporterId': 'c',
    'reportedUserId': 'p',
    'reporterRole': 'customer',
    'reportedRole': 'provider',
    'reason': 'Incomplete work',
    'details': 'The agreed kitchen cleaning is unfinished.',
    'assignedAdminId': 'a',
    'disputeInquiryId': 'dispute',
    'status': status,
    'resolutionProposal': proposal,
  });
  Widget panel(
    AppUser user,
    BookingUserReport record,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) command,
  ) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DisputeCasePanel(
            appUser: user,
            reportId: record.reportId,
            reports: Stream.value(record),
            showHistory: false,
            command: command,
          ),
        ),
      ),
    ),
  );

  testOnPlatform(
    'party confirms only after reviewing the exact agreement in a dialog',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        panel(
          customer,
          report(
            proposal: {
              'id': 'version-1',
              'type': 'refund',
              'summary': 'Return PHP 200 directly after both parties agree.',
              'confirmedBy': [],
            },
          ),
          (data) async {
            calls.add(data);
            return {};
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review and confirm proposal'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('Confirm proposed resolution?'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('Review and confirm proposal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I agree to this proposal'));
      await tester.pumpAndSettle();
      expect(calls.single['action'], 'confirmResolution');
      expect(calls.single['proposalId'], 'version-1');
    },
  );

  testOnPlatform(
    'admin cannot resolve an agreement while either confirmation is missing',
    (tester) async {
      await tester.pumpWidget(
        panel(
          admin,
          report(
            proposal: {
              'id': 'v',
              'type': 'correction',
              'summary': 'Clean the kitchen at the mutually agreed time.',
              'confirmedBy': ['c'],
            },
          ),
          (_) async => {},
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Reviewed both responses and the original agreed scope.',
      );
      await tester.pump();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Resolve with recorded outcome'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('1 of 2 parties confirmed'), findsOneWidget);
    },
  );

  testOnPlatform(
    'proposal retries retain the proposal reference after uncertain delivery',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        panel(admin, report(), (data) async {
          calls.add(data);
          throw StateError('Uncertain delivery');
        }),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Correct the unfinished kitchen work at the agreed time.',
      );
      await tester.pump();
      final button = find.text('Propose agreement for both parties');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls[0]['proposalId'], calls[1]['proposalId']);
    },
  );

  testOnPlatform(
    'another admin can review case evidence without assigned-admin controls',
    (tester) async {
      final staff = AppUser.fromFirestore('staff', {'role': 'Administrator'});
      await tester.pumpWidget(panel(staff, report(), (_) async => {}));
      await tester.pumpAndSettle();
      expect(
        find.text('Another administrator is assigned to this case.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Incomplete work'), findsOneWidget);
    },
  );

  testOnPlatform(
    'optional photos can be selected and removed without changing report requirements',
    (tester) async {
      var photos = <Uint8List>[];
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setLocal) => ReportPhotoPicker(
                photos: photos,
                onChanged: (next) => setLocal(() => photos = next),
                pickPhotos: () async => [png],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add photos (optional)'));
      await tester.pumpAndSettle();
      expect(photos.length, 1);
      expect(find.text('Photo 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(photos, isEmpty);
    },
  );

  testOnPlatform('oversized selections reject all photos with a clear limit', (
    tester,
  ) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportPhotoPicker(
            photos: const [],
            onChanged: (_) => changed = true,
            pickPhotos: () async => List.generate(6, (_) => Uint8List(2)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add photos (optional)'));
    await tester.pumpAndSettle();
    expect(changed, isFalse);
    expect(find.text('Attach at most 5 photos.'), findsOneWidget);
  });

  for (final width in [390.0, 900.0, 1500.0]) {
    testOnPlatform(
      'dispute keeps the Messages layout and identifies all three senders at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeMessagingRepository();
        repo.threads = [
          Inquiry('dispute', {
            'kind': 'dispute',
            'reportId': 'report',
            'customerId': 'c',
            'providerId': 'p',
            'serviceId': '',
            'customerName': 'Customer Name',
            'providerName': 'Provider Name',
            'adminName': 'Admin Name',
            'caseStatus': 'under_review',
            'unreadCounts': {'c': 0},
          }),
        ];
        repo.reportsById['report'] = report();
        repo.messagesByThread['dispute'] = [
          for (final (id, name, role) in [
            ('c', 'Customer Name', 'Customer'),
            ('p', 'Provider Name', 'Provider'),
            ('a', 'Admin Name', 'Administrator'),
          ])
            ChatMessage(
              messageId: id,
              bookingId: '',
              senderId: id,
              receiverId: '',
              senderName: name,
              senderRole: role,
              messageText: '$role evidence',
              messageType: 'Text',
              isRead: false,
              sentAt: Timestamp.now(),
            ),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoleThemeScope(
                palette: RoleTheme.customer,
                child: MessagesHub(
                  appUser: customer,
                  asCustomer: true,
                  repository: repo,
                  initialInquiryId: 'dispute',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Admin Name · Administrator'), findsOneWidget);
        expect(find.text('Provider evidence'), findsOneWidget);
        expect(find.text('Prepare fixed or daily offer'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testOnPlatform('a closed dispute retains messages with a disabled composer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeMessagingRepository();
    repo.threads = [
      Inquiry('closed', {
        'kind': 'dispute',
        'reportId': 'report',
        'customerId': 'c',
        'providerId': 'p',
        'serviceId': '',
        'caseStatus': 'resolved',
      }),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoleThemeScope(
            palette: RoleTheme.customer,
            child: MessagesHub(
              appUser: customer,
              asCustomer: true,
              repository: repo,
              initialInquiryId: 'closed',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final composer = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.startsWith('Send a message') ?? false),
    );
    expect(tester.widget<TextField>(composer).enabled, isFalse);
    expect(
      find.text(
        'This dispute is closed. Its messages, evidence and recorded outcome remain available.',
      ),
      findsOneWidget,
    );
  });
}
