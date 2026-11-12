import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/booking_user_report.dart';
import 'package:neighbor_help/models/inquiry.dart';
import 'package:neighbor_help/models/message.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/services/messaging_repository.dart';

class FakeMessagingRepository extends MessagingRepository {
  List<Inquiry> threads = [];
  List<Booking> bookingRows = [];
  final servicesById = <String, ServiceListing>{};
  final reportsById = <String, BookingUserReport>{};
  @override
  Stream<BookingUserReport?> report(String id) => Stream.value(reportsById[id]);
  @override
  Stream<List<Map<String, dynamic>>> reportEvents(String id) =>
      Stream.value([]);
  final messagesByThread = <String, List<ChatMessage>>{};
  final sent = <Map<String, String>>[];
  final actions = <Map<String, dynamic>>[];
  Stream<List<Inquiry>>? inboxSource;
  bool failNextSend = false;
  var _id = 0;
  @override
  Stream<List<Inquiry>> inbox(String uid) =>
      inboxSource ?? Stream.value(threads);
  @override
  Stream<List<Booking>> bookings(String uid, bool asCustomer) =>
      Stream.value(bookingRows);
  @override
  Stream<List<ChatMessage>> messages(String id) =>
      Stream.value(messagesByThread[id] ?? []);
  @override
  Future<void> synchronize() async {}
  @override
  Future<String> inquiryForBooking(String id) async =>
      bookingRows.firstWhere((b) => b.bookingId == id).inquiryId!;
  @override
  Future<AppUser?> user(String id) async => null;
  @override
  Future<ServiceListing?> service(String id) async => servicesById[id];
  @override
  String newId() => 'message-${++_id}';
  @override
  Future<void> command(
    String id,
    String action, {
    Map<String, dynamic> data = const {},
  }) async {
    actions.add({'inquiryId': id, 'action': action, ...data});
  }

  @override
  Future<void> send(
    String id, {
    required String messageId,
    String text = '',
    String mediaUrl = '',
  }) async {
    sent.add({
      'inquiryId': id,
      'messageId': messageId,
      'text': text,
      'mediaUrl': mediaUrl,
    });
    if (failNextSend) {
      failNextSend = false;
      throw StateError('Uncertain delivery');
    }
  }
}
