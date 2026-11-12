import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/inquiry.dart';
import 'package:neighbor_help/models/message.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/screens/shared/messages_hub.dart';
import 'package:neighbor_help/theme/role_theme.dart';
import 'support/fake_messaging_repository.dart';
import 'support/ui_test_support.dart';

void main() {
  setUpOfflineFonts();
  final customer = AppUser.fromFirestore('c', {
    'role': 'Customer',
    'fullName': 'Test Customer',
  });
  Inquiry thread(
    String id,
    String name, {
    List<String> blocked = const [],
    bool discussed = true,
  }) => Inquiry(id, {
    'customerId': 'c',
    'providerId': 'p-$id',
    'serviceId': 's-$id',
    'providerName': name,
    'customerName': 'Test Customer',
    'serviceTitle': 'House Cleaning',
    'lastMessage': 'Latest preview for $name',
    'customerMessageCount': 1,
    'providerMessageCount': discussed ? 1 : 0,
    'blockedBy': blocked,
    'updatedAt': Timestamp.now(),
  });
  ChatMessage message(String text) => ChatMessage.fromFirestore('m', {
    'senderId': 'p-first',
    'receiverId': 'c',
    'messageText': text,
    'sentAt': Timestamp.now(),
  });
  FakeMessagingRepository repository() => FakeMessagingRepository()
    ..threads = [
      thread('first', 'First Provider'),
      thread('second', 'Second Provider'),
    ]
    ..messagesByThread['first'] = [message('First protected message')]
    ..messagesByThread['second'] = [message('Second protected message')];
  void size(WidgetTester tester, double width, {double height = 900}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(
    FakeMessagingRepository repo, {
    String? initial,
    bool asCustomer = true,
  }) => MaterialApp(
    home: Scaffold(
      body: RoleThemeScope(
        palette: asCustomer ? RoleTheme.customer : RoleTheme.provider,
        child: MessagesHub(
          appUser: asCustomer
              ? customer
              : AppUser.fromFirestore('p-first', {
                  'role': 'Provider',
                  'fullName': 'First Provider',
                }),
          asCustomer: asCustomer,
          repository: repo,
          initialInquiryId: initial,
        ),
      ),
    ),
  );
  Finder composer() => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Send a message…',
  );
  Finder search() => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Search',
  );

  testOnPlatform(
    'desktop restores the conversation list, central chat and context sidebar',
    (tester) async {
      size(tester, 1440);
      final repo = repository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNWidgets(2));
      expect(find.text('First protected message'), findsOneWidget);
      expect(find.text('Activity timeline'), findsOneWidget);
      expect(find.text('First Provider'), findsAtLeastNWidgets(3));
      final left = tester.getTopLeft(search()).dx,
          center = tester.getTopLeft(find.text('First protected message')).dx,
          right = tester.getTopLeft(find.text('Activity timeline')).dx;
      expect(left, lessThan(center));
      expect(center, lessThan(right));
      expect(tester.takeException(), isNull);
    },
  );
  testOnPlatform(
    'search and selection keep the same conversation backend and separate drafts',
    (tester) async {
      size(tester, 1440);
      final repo = repository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.enterText(composer(), 'Draft for the first provider');
      await tester.enterText(search(), 'Second Provider');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Second Provider'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second protected message'), findsOneWidget);
      expect(tester.widget<TextField>(composer()).controller!.text, isEmpty);
      await tester.enterText(composer(), 'Discuss materials first');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(repo.sent.single['inquiryId'], 'second');
      expect(repo.sent.single['text'], 'Discuss materials first');
    },
  );
  testOnPlatform('retrying uncertain delivery reuses the message ID', (
    tester,
  ) async {
    size(tester, 1440);
    final repo = repository()..failNextSend = true;
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.enterText(composer(), 'A message to retry');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry message with uncertain delivery'));
    await tester.pumpAndSettle();
    expect(repo.sent, hasLength(2));
    expect(repo.sent[0]['messageId'], repo.sent[1]['messageId']);
    expect(repo.sent[0]['inquiryId'], repo.sent[1]['inquiryId']);
    expect(tester.widget<TextField>(composer()).controller!.text, isEmpty);
  });
  testOnPlatform('Ctrl+Enter sends once through the canonical conversation', (
    tester,
  ) async {
    size(tester, 1440);
    final repo = repository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.enterText(composer(), 'Keyboard message');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(repo.sent, hasLength(1));
    expect(repo.sent.single['inquiryId'], 'first');
  });
  testOnPlatform('blocked conversations disable text, photos and new offers', (
    tester,
  ) async {
    size(tester, 1440);
    final repo = repository()
      ..threads = [
        thread('first', 'First Provider', blocked: ['p-first']),
      ];
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(composer()).enabled, isFalse);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Attach an image'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    final offer = find.ancestor(
      of: find.text('Request booking'),
      matching: find.byWidgetPredicate((w) => w is TextButton),
    );
    expect(tester.widget<TextButton>(offer).onPressed, isNull);
    expect(repo.sent, isEmpty);
  });
  testOnPlatform(
    'block uses the existing safety command and keeps history readable',
    (tester) async {
      size(tester, 1440);
      final updates = StreamController<List<Inquiry>>.broadcast();
      final repo = repository()..inboxSource = updates.stream;
      await tester.pumpWidget(app(repo));
      updates.add(repo.threads);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conversation safety'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block conversation'));
      await tester.pumpAndSettle();
      expect(
        repo.actions,
        contains(equals({'inquiryId': 'first', 'action': 'block'})),
      );
      updates.add([
        thread('first', 'First Provider', blocked: ['c']),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('First protected message'), findsOneWidget);
      expect(tester.widget<TextField>(composer()).enabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await updates.close();
    },
  );
  testOnPlatform('real bookings stay linked in the restored sidebar', (
    tester,
  ) async {
    size(tester, 1440);
    final repo = repository()
      ..bookingRows = [
        Booking.fromFirestore('b', {
          'customerId': 'c',
          'providerId': 'p-first',
          'inquiryId': 'first',
          'serviceId': 's-first',
          'status': 'Accepted',
          'totalFee': 200,
          'scheduledDate': Timestamp.now(),
        }),
      ];
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(find.text('View booking'), findsAtLeastNWidgets(1));
    expect(find.text('Activity timeline'), findsOneWidget);
    expect(
      repo.actions,
      contains(equals({'inquiryId': 'first', 'action': 'read'})),
    );
    expect(tester.takeException(), isNull);
  });
  testOnPlatform(
    'inquiries support messaging without a discussion prerequisite for booking',
    (tester) async {
      size(tester, 1440);
      final repo = repository()
        ..threads = [thread('first', 'First Provider', discussed: false)];
      repo.servicesById['s-first'] = ServiceListing.fromFirestore('s-first', {
        'providerId': 'p-first',
        'serviceTitle': 'House Cleaning',
        'category': 'Cleaning',
        'isActive': true,
        'approvalStatus': 'Approved',
      });
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Both parties must send a message before an offer can be sent.',
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text('Request booking'),
                matching: find.byWidgetPredicate((w) => w is TextButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.widget<TextField>(composer()).enabled, isTrue);
    },
  );
  testOnPlatform(
    'provider role uses the same layout without a customer offer action',
    (tester) async {
      size(tester, 1440);
      final repo = repository()..threads = [thread('first', 'First Provider')];
      await tester.pumpWidget(app(repo, asCustomer: false));
      await tester.pumpAndSettle();
      expect(find.byType(VerticalDivider), findsNWidgets(2));
      expect(find.text('Request booking'), findsNothing);
      expect(find.text('Test Customer'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
  testOnPlatform(
    'narrow screens retain list, back navigation and access to conversation info',
    (tester) async {
      size(tester, 390);
      final repo = repository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(composer(), findsNothing);
      await tester.tap(find.text('First Provider'));
      await tester.pumpAndSettle();
      expect(composer(), findsOneWidget);
      expect(find.text('First protected message'), findsOneWidget);
      await tester.tap(find.byTooltip('Conversation safety'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conversation info'));
      await tester.pumpAndSettle();
      expect(find.text('Activity timeline'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide conversation info'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(search(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testOnPlatform(
    'an inquiry deep link selects its thread instead of the first row',
    (tester) async {
      size(tester, 1440);
      final repo = repository();
      await tester.pumpWidget(app(repo, initial: 'second'));
      await tester.pumpAndSettle();
      expect(find.text('Second protected message'), findsOneWidget);
      expect(find.text('First protected message'), findsNothing);
    },
  );
  testOnPlatform('the right sidebar can be hidden and restored', (
    tester,
  ) async {
    size(tester, 1440);
    final repo = repository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide conversation info').first);
    await tester.pumpAndSettle();
    expect(find.text('Activity timeline'), findsNothing);
    await tester.tap(find.byTooltip('Show conversation info'));
    await tester.pumpAndSettle();
    expect(find.text('Activity timeline'), findsOneWidget);
  });
  testOnPlatform(
    'booking deep links select the matching canonical conversation in place',
    (tester) async {
      size(tester, 1440);
      final repo = repository()
        ..bookingRows = [
          Booking.fromFirestore('target', {
            'customerId': 'c',
            'providerId': 'p-second',
            'serviceId': 's-second',
            'inquiryId': 'second',
            'status': 'Accepted',
            'scheduledDate': Timestamp.now(),
          }),
        ];
      MessagesHub.pendingBookingId.value = 'target';
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Second protected message'), findsOneWidget);
      expect(MessagesHub.pendingBookingId.value, isNull);
      expect(find.byType(MessagesHub), findsOneWidget);
    },
  );
}
