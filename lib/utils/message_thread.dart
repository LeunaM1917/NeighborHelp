import '../models/booking.dart';

/// Stable id for one chat between a customer and provider (all bookings share this).
String messageThreadId(String customerId, String providerId) {
  final pair = [customerId, providerId]..sort();
  return '${pair[0]}_${pair[1]}';
}

/// One row in the messages list — grouped by the other party, not per booking.
class MessageConversationThread {
  MessageConversationThread({
    required this.otherUserId,
    required this.bookings,
  });

  final String otherUserId;
  final List<Booking> bookings;

  Booking get primaryBooking => bookings.first;

  String get customerId => primaryBooking.customerId;
  String get providerId => primaryBooking.providerId;

  String get threadId => messageThreadId(customerId, providerId);

  List<String> get bookingIds => bookings.map((b) => b.bookingId).toList();

  /// Same customer + provider = one conversation (reuse existing thread).
  static List<MessageConversationThread> groupBookings({
    required List<Booking> bookings,
    required bool asCustomer,
  }) {
    final map = <String, List<Booking>>{};
    for (final b in bookings) {
      final other = asCustomer ? b.providerId : b.customerId;
      map.putIfAbsent(other, () => []).add(b);
    }

    final threads = <MessageConversationThread>[];
    for (final entry in map.entries) {
      final list = entry.value
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      threads.add(MessageConversationThread(otherUserId: entry.key, bookings: list));
    }
    threads.sort(
      (a, b) => b.primaryBooking.updatedAt.compareTo(a.primaryBooking.updatedAt),
    );
    return threads;
  }

  /// When opening chat from a booking, use the thread that already exists for this pair.
  static MessageConversationThread? threadForBooking(
    List<MessageConversationThread> threads,
    Booking booking,
    bool asCustomer,
  ) {
    final other = asCustomer ? booking.providerId : booking.customerId;
    for (final t in threads) {
      if (t.otherUserId == other) return t;
    }
    return null;
  }
}
