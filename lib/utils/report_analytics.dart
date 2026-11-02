import '../models/booking.dart';
import '../models/review.dart';

DateTime reportRangeStart(String range, DateTime now) => switch (range) {
  'This week' => DateTime(now.year, now.month, now.day - now.weekday + 1),
  'Last 3 months' => DateTime(now.year, now.month - 2),
  'This year' => DateTime(now.year),
  _ => DateTime(now.year, now.month),
};

bool inReportRange(DateTime value, String range, {DateTime? now}) {
  final end = now ?? DateTime.now();
  return !value.isBefore(reportRangeStart(range, end)) && !value.isAfter(end);
}

List<Booking> bookingsInRange(
  List<Booking> bookings,
  String range, {
  DateTime? now,
}) => bookings
    .where((b) => inReportRange(b.createdAt.toDate(), range, now: now))
    .toList();

/// Observed daily means only: gaps are not filled with invented historical ratings.
Map<DateTime, double> dailyReviewRatings(List<Review> reviews) {
  final sums = <DateTime, double>{}, counts = <DateTime, int>{};
  for (final r in reviews.where((r) => r.isCustomerReview)) {
    final at = r.createdAt.toDate();
    final day = DateTime(at.year, at.month, at.day);
    sums[day] = (sums[day] ?? 0) + r.rating;
    counts[day] = (counts[day] ?? 0) + 1;
  }
  final days = sums.keys.toList()..sort();
  return {for (final day in days) day: sums[day]! / counts[day]!};
}

String safeCsvCell(Object? value) {
  var text = value?.toString() ?? '';
  if (RegExp(r'^\s*[=+@\-]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

String encodeCsv(List<Map<String, Object?>> rows) {
  final keys = <String>{for (final row in rows) ...row.keys}.toList();
  if (keys.isEmpty) return '';
  return [
    keys.map(safeCsvCell).join(','),
    ...rows.map((row) => keys.map((key) => safeCsvCell(row[key])).join(',')),
  ].join('\r\n');
}
