import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/notification.dart';
import 'package:neighbor_help/models/user_role.dart';
import 'package:neighbor_help/screens/shared/notifications_popover.dart';
import 'package:neighbor_help/services/notification_navigation.dart';
import 'package:neighbor_help/theme/role_theme.dart';
import 'package:neighbor_help/utils/notification_destination.dart';
import 'support/ui_test_support.dart';

AppUser user(UserRole role) => AppUser.fromFirestore(role.name, {
  'role': role.firestoreValue,
  'accountStatus': 'Active',
});
AppNotification note(
  UserRole role,
  String id, {
  String type = 'Booking',
  bool read = false,
  Map<String, Object?> extra = const {},
}) => AppNotification.fromFirestore(id, {
  'userId': role.name,
  'title': 'Update $id',
  'message':
      'A booking or account record was updated. Open it to review the details.',
  'notificationType': type,
  'isRead': read,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 13, 2)),
  ...extra,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  tearDown(NotificationsPopover.hide);

  test(
    'notification IDs round-trip without dropping service, certificate, report or admin targets',
    () {
      final original = note(
        UserRole.administrator,
        'n',
        extra: {
          'relatedServiceId': 's',
          'relatedCertificationId': 'c',
          'relatedProviderId': 'p',
          'relatedUserId': 'u',
          'relatedReportId': 'r',
          'relatedReviewId': 'v',
          'relatedProposalId': 'proposal',
          'sourceCollection': 'serviceProviders',
          'adminTab': 5,
        },
      );
      final saved = AppNotification.fromFirestore('n', original.toMap());
      expect(saved.toMap(), original.toMap());
      expect(saved.relatedReportId, 'r');
      expect(saved.relatedCertificationId, 'c');
    },
  );
  test(
    'each role resolves exact entities and safe legacy section fallbacks',
    () {
      for (final role in [
        UserRole.customer,
        UserRole.provider,
        UserRole.administrator,
      ]) {
        final entities = {
          'relatedBookingId': NotificationDestinationKind.booking,
          'relatedInquiryId': NotificationDestinationKind.conversation,
          'relatedServiceId': NotificationDestinationKind.service,
          'relatedCertificationId': NotificationDestinationKind.certificate,
          'relatedReportId': NotificationDestinationKind.report,
          'relatedReviewId': NotificationDestinationKind.review,
        };
        for (final entry in entities.entries) {
          final target = notificationDestination(
            note(role, 'n', extra: {entry.key: 'target'}),
            role,
          );
          expect(target.kind, entry.value);
          expect(target.id, 'target');
        }
        final message = notificationDestination(
          note(role, 'n', type: 'Message', extra: {'relatedBookingId': 'b'}),
          role,
        );
        expect(message.kind, NotificationDestinationKind.conversation);
        expect(message.ownerId, 'booking');
        expect(
          notificationDestination(
            note(role, 'n', type: 'Verification'),
            role,
          ).tab,
          4,
        );
        expect(
          notificationDestination(
            note(role, 'n', type: 'Announcement'),
            role,
          ).kind,
          NotificationDestinationKind.details,
        );
      }
      expect(
        notificationDestination(
          note(
            UserRole.administrator,
            'n',
            type: 'Admin Activity',
            extra: {'adminTab': 5},
          ),
          UserRole.administrator,
        ).tab,
        5,
      );
      expect(
        notificationDestination(
          note(
            UserRole.customer,
            'n',
            type: 'Admin Activity',
            extra: {'adminTab': 12},
          ),
          UserRole.customer,
        ).kind,
        NotificationDestinationKind.details,
      );
      expect(
        notificationDestination(
          note(
            UserRole.administrator,
            'n',
            type: 'Admin Activity',
            extra: {'adminTab': 999},
          ),
          UserRole.administrator,
        ).kind,
        NotificationDestinationKind.details,
      );
    },
  );
  test(
    'fresh target reads reject deleted records, strangers and private conversations even for unassigned admins',
    () async {
      final records = NotificationRecordLoader(
        read: (collection, id) async => switch (collection) {
          'bookings' =>
            id == 'deleted'
                ? null
                : {
                    'customerId': 'customer',
                    'providerId': 'provider',
                    'status': 'Completed',
                  },
          'inquiries' => {
            'participantIds': ['customer', 'provider'],
          },
          'bookingUserReports' => {
            'reporterId': 'customer',
            'reportedUserId': 'provider',
          },
          'serviceProviders' => {'userId': 'provider'},
          _ => null,
        },
      );
      expect(
        (await records.booking('b', user(UserRole.customer))).bookingId,
        'b',
      );
      expect(
        (await records.booking('b', user(UserRole.provider))).bookingId,
        'b',
      );
      expect(
        (await records.booking('b', user(UserRole.administrator))).bookingId,
        'b',
      );
      final stranger = AppUser.fromFirestore('stranger', {'role': 'Customer'});
      await expectLater(records.booking('b', stranger), throwsStateError);
      await expectLater(
        records.booking('deleted', user(UserRole.customer)),
        throwsStateError,
      );
      await expectLater(
        records.read('bookings', 'invalid/path'),
        throwsStateError,
      );
      await records.conversation('i', user(UserRole.provider));
      await expectLater(
        records.conversation('i', user(UserRole.administrator)),
        throwsStateError,
      );
      await expectLater(records.report('r', stranger), throwsStateError);
      await expectLater(
        records.certificateOwner('provider', user(UserRole.customer)),
        throwsStateError,
      );
    },
  );

  for (final role in [
    UserRole.customer,
    UserRole.provider,
    UserRole.administrator,
  ]) {
    for (final size in [
      const Size(360, 780),
      const Size(1280, 900),
      const Size(320, 320),
    ]) {
      testOnPlatform(
        '${role.name} bell anchors, scrolls, dismisses, reads and opens at $size',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final updates = StreamController<List<AppNotification>>.broadcast();
          addTearDown(updates.close);
          var notes = [for (var i = 0; i < 15; i++) note(role, '$i')];
          final opened = <String>[];
          final read = <String>[];
          var all = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topRight,
                  child: NotificationBell(
                    appUser: user(role),
                    stream: updates.stream,
                    onRead: (n) async {
                      read.add(n.notificationId);
                      notes = [
                        for (final old in notes)
                          AppNotification.fromFirestore(old.notificationId, {
                            ...old.toMap(),
                            'isRead':
                                old.notificationId == n.notificationId ||
                                old.isRead,
                          }),
                      ];
                      updates.add(notes);
                    },
                    onReadAll: () async {
                      all++;
                      notes = [
                        for (final old in notes)
                          AppNotification.fromFirestore(old.notificationId, {
                            ...old.toMap(),
                            'isRead': true,
                          }),
                      ];
                      updates.add(notes);
                    },
                    onOpen: (n) async {
                      opened.add(n.notificationId);
                    },
                  ),
                ),
              ),
            ),
          );
          updates.add(notes);
          await tester.pumpAndSettle();
          expect(find.text('15'), findsOneWidget);
          await tester.tap(find.byTooltip('Notifications'));
          await tester.pumpAndSettle();
          final panel = find.byKey(const ValueKey('notifications-dropdown'));
          expect(panel, findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(BottomSheet), findsNothing);
          final bounds = tester.getRect(panel),
              bell = tester.getRect(find.byTooltip('Notifications'));
          expect(bounds.left, greaterThanOrEqualTo(12));
          expect(bounds.right, lessThanOrEqualTo(size.width - 12));
          expect(bounds.top, greaterThanOrEqualTo(bell.bottom));
          expect(bounds.bottom, lessThanOrEqualTo(size.height - 12));
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(
            tester
                .state<ScrollableState>(
                  find.descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  ),
                )
                .position
                .pixels,
            greaterThan(0),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(panel, findsNothing);
          await tester.tap(find.byTooltip('Notifications'));
          await tester.pumpAndSettle();
          await tester.tapAt(Offset(2, size.height - 2));
          await tester.pumpAndSettle();
          expect(panel, findsNothing);
          await tester.tap(find.byTooltip('Notifications'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('notification-0')));
          await tester.pumpAndSettle();
          expect(opened, ['0']);
          expect(read, ['0']);
          expect(panel, findsNothing);
          expect(find.text('14'), findsOneWidget);
          await tester.tap(find.byTooltip('Notifications'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Mark all as read'));
          await tester.pumpAndSettle();
          expect(all, 1);
          expect(find.text('0 unread'), findsOneWidget);
          expect(
            tester.widget<Badge>(find.byType(Badge)).isLabelVisible,
            false,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testOnPlatform(
    'read receipt failure still opens the notification and navigation closes the menu',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: NotificationBell(
                appUser: user(UserRole.customer),
                stream: Stream.value([note(UserRole.customer, 'failed')]),
                onRead: (_) async => throw StateError('offline'),
                onReadAll: () async {},
                onOpen: (_) async {
                  opened = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notification-failed')));
      await tester.pumpAndSettle();
      expect(opened, true);
      expect(
        find.textContaining('Could not mark this notification'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notifications-dropdown')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform(
    'empty, loading and stream errors keep the notification header usable',
    (tester) async {
      final updates = StreamController<List<AppNotification>>.broadcast();
      addTearDown(updates.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleThemeScope(
              palette: RoleTheme.customer,
              child: SizedBox(
                width: 360,
                height: 400,
                child: NotificationsPanel(
                  stream: updates.stream,
                  onClose: () {},
                  onRead: (_) async {},
                  onReadAll: () async {},
                  onOpen: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      updates.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsOneWidget);
      updates.addError(StateError('denied'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not load notifications'),
        findsOneWidget,
      );
      expect(find.byTooltip('Close notifications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform(
    'badge and mark-all include unread records outside the recent menu window',
    (tester) async {
      final counts = StreamController<int>.broadcast();
      addTearDown(counts.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: NotificationBell(
                appUser: user(UserRole.customer),
                stream: Stream.value([
                  note(UserRole.customer, 'recent', read: true),
                ]),
                unreadCount: counts.stream,
                onRead: (_) async {},
                onReadAll: () async {
                  counts.add(0);
                },
                onOpen: (_) async {},
              ),
            ),
          ),
        ),
      );
      counts.add(55);
      await tester.pumpAndSettle();
      expect(find.text('55'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('55 unread'), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, true);
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(find.text('0 unread'), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, false);
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform(
    'record navigation shows the specific listing and gracefully handles a deleted booking',
    (tester) async {
      final provider = user(UserRole.provider);
      final selected = <int>[];
      final navigator = NotificationNavigator(
        records: NotificationRecordLoader(
          read: (collection, id) async => collection == 'services'
              ? {
                  'providerId': provider.userId,
                  'serviceTitle': 'The notified listing',
                  'category': 'Cleaning',
                  'approvalStatus': 'Rejected',
                  'rejectionReason': 'Update the qualification',
                }
              : null,
        ),
      );
      late BuildContext shell;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                shell = context;
                return TextButton(
                  onPressed: () => navigator.open(
                    context,
                    user: provider,
                    note: note(
                      UserRole.provider,
                      'service',
                      extra: {'relatedServiceId': 'specific-service'},
                    ),
                    onSelectTab: selected.add,
                  ),
                  child: const Text('Open listing'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open listing'));
      await tester.pumpAndSettle();
      expect(find.text('The notified listing'), findsOneWidget);
      expect(
        find.textContaining('specific-service', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Update the qualification', findRichText: true),
        findsOneWidget,
      );
      expect(selected, [1]);
      await tester.tap(find.text('Open services'));
      await tester.pumpAndSettle();
      expect(selected, [1, 1]);
      await navigator.open(
        shell,
        user: provider,
        note: note(
          UserRole.provider,
          'booking',
          extra: {'relatedBookingId': 'deleted'},
        ),
        onSelectTab: selected.add,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This record is unavailable or you no longer have access.'),
        findsOneWidget,
      );
      expect(selected.last, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform(
    'native mobile notifications stay anchored when the viewport changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: NotificationBell(
                appUser: user(UserRole.customer),
                stream: Stream.value([note(UserRole.customer, 'mobile')]),
                onRead: (_) async {},
                onReadAll: () async {},
                onOpen: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(780, 320);
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('notifications-dropdown')),
      );
      expect(rect.right, lessThanOrEqualTo(768));
      expect(rect.bottom, lessThanOrEqualTo(308));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    platform: TargetPlatform.android,
  );
}
