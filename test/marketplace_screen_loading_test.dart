import 'support/fake_messaging_repository.dart';
import 'support/ui_test_support.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/inquiry.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/services/booking_reference_loader.dart';
import 'package:neighbor_help/screens/shared/messages_hub.dart';
import 'package:neighbor_help/widgets/provider_search_status.dart';
import 'package:neighbor_help/widgets/booking_reference_notice.dart';

void main() {
  setUpOfflineFonts();
  Booking booking(String id) => Booking.fromFirestore(id, {
    'serviceId': 's',
    'providerId': 'p',
    'customerId': 'c',
    'status': 'Completed',
    'totalFee': 250,
  });
  final customer = AppUser.fromFirestore('c', {
    'role': 'Customer',
    'fullName': 'Test Customer',
    'accountStatus': 'Active',
  });
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));
  test(
    'unavailable provider profiles do not discard service data or the booking record',
    () async {
      final original = booking('b');
      final result = await loadBookingReferences(
        bookings: [original],
        service: (id) async => ServiceListing.fromFirestore(id, {
          'serviceTitle': 'Recorded service',
        }),
        provider: (id) async =>
            AppUser.fromFirestore(id, {'fullName': 'Provider display name'}),
        profile: (_) async => throw StateError('Public profile is unavailable'),
      );
      expect(result.services['s']!.serviceTitle, 'Recorded service');
      expect(result.providers['p']!.fullName, 'Provider display name');
      expect(result.profiles['p'], isNull);
      expect(result.unavailable, {'profile:p'});
      expect(original.status, 'Completed');
      expect(original.totalFee, 250);
    },
  );
  test(
    'shared references are fetched once and missing optional documents stay missing',
    () async {
      var services = 0, providers = 0, profiles = 0;
      final result = await loadBookingReferences(
        bookings: [booking('a'), booking('b')],
        service: (_) async {
          services++;
          return null;
        },
        provider: (_) async {
          providers++;
          return null;
        },
        profile: (_) async {
          profiles++;
          return null;
        },
      );
      expect([services, providers, profiles], [1, 1, 1]);
      expect(result.unavailable, {'service:s', 'provider:p', 'profile:p'});
    },
  );
  test(
    'a hanging metadata request times out without discarding other display data',
    () async {
      final pending = Completer<ServiceProviderProfile?>();
      final result = await loadBookingReferences(
        bookings: [booking('a')],
        timeout: const Duration(milliseconds: 10),
        service: (_) async => null,
        provider: (id) async =>
            AppUser.fromFirestore(id, {'fullName': 'Visible name'}),
        profile: (_) => pending.future,
      );
      expect(result.providers['p']!.fullName, 'Visible name');
      expect(result.unavailable, contains('profile:p'));
      pending.complete(null);
    },
  );
  test('no bookings means no reference requests or invented records', () async {
    Future<Never> unexpected(String id) async =>
        throw StateError('Unexpected reference request');
    final result = await loadBookingReferences(
      bookings: [],
      service: unexpected,
      provider: unexpected,
      profile: unexpected,
    );
    expect(result.services, isEmpty);
    expect(result.providers, isEmpty);
    expect(result.unavailable, isEmpty);
  });
  testWidgets(
    'optional booking detail failure offers a retry while records remain visible',
    (tester) async {
      var retried = false;
      await tester.pumpWidget(
        app(
          Column(
            children: [
              const Text('Existing completed booking'),
              BookingReferenceNotice(
                loading: false,
                unavailable: true,
                onRetry: () => retried = true,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Existing completed booking'), findsOneWidget);
      expect(
        find.textContaining('Your booking records are still shown'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry service and provider details'));
      expect(retried, isTrue);
    },
  );
  testWidgets(
    'failed history import is not shown as an empty inbox and can be retried',
    (tester) async {
      final first = Completer<void>();
      var calls = 0;
      final conversations = Stream<List<Inquiry>>.value([]);
      await tester.pumpWidget(
        app(
          MessagesHub(
            repository: FakeMessagingRepository(),
            appUser: customer,
            asCustomer: true,
            conversations: conversations,
            syncHistory: () {
              calls++;
              return calls == 1 ? first.future : Future<void>.value();
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Loading previous conversations…'), findsOneWidget);
      expect(find.textContaining('No conversations yet.'), findsNothing);
      first.completeError(StateError('Conversation service unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your previous conversations have not loaded.'),
        findsOneWidget,
      );
      expect(find.textContaining('No conversations yet.'), findsNothing);
      await tester.tap(find.text('Retry loading older booking conversations'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('No conversations yet.'), findsOneWidget);
    },
  );
  testWidgets(
    'existing inquiries stay readable while historical imports are unavailable',
    (tester) async {
      final history = Completer<void>();
      final conversations = Stream<List<Inquiry>>.value([
        Inquiry('thread', {
          'customerId': 'c',
          'providerId': 'p',
          'providerName': 'Existing Provider',
          'serviceTitle': 'Cleaning',
          'lastMessage': 'Existing conversation',
          'customerMessageCount': 1,
          'providerMessageCount': 1,
        }),
      ]);
      await tester.pumpWidget(
        app(
          MessagesHub(
            repository: FakeMessagingRepository(),
            appUser: customer,
            asCustomer: true,
            conversations: conversations,
            syncHistory: () => history.future,
          ),
        ),
      );
      await tester.pump();
      history.completeError(StateError('Unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Existing Provider'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Existing conversation'), findsOneWidget);
    },
  );
  testWidgets(
    'an empty provider directory never claims schedule availability',
    (tester) async {
      await tester.pumpWidget(
        app(
          const ProviderSearchStatus(
            candidates: 0,
            matches: 0,
            days: 1,
            hours: 1,
          ),
        ),
      );
      expect(
        find.textContaining('No providers are ready for search yet.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('selected base and service barangays'),
        findsOneWidget,
      );
      expect(find.textContaining('available for all'), findsNothing);
    },
  );
  testWidgets(
    'no matching schedule is distinguished from no approved providers',
    (tester) async {
      await tester.pumpWidget(
        app(
          const ProviderSearchStatus(
            candidates: 2,
            matches: 0,
            days: 1,
            hours: 1,
          ),
        ),
      );
      expect(
        find.textContaining('No providers matched this schedule and location.'),
        findsOneWidget,
      );
      expect(find.textContaining('available for all'), findsNothing);
    },
  );
  testWidgets('positive results report the match count and Manila check time', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ProviderSearchStatus(
          candidates: 2,
          matches: 1,
          days: 1,
          hours: 1,
          checkedAt: DateTime.parse('2026-11-10T01:00:00Z'),
        ),
      ),
    );
    expect(
      find.textContaining(
        '1 provider is available for all 1 workday, 1 hour each.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('9:00 AM Manila time'), findsOneWidget);
  });
}
