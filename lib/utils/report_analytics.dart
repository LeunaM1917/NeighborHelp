import '../models/booking.dart';
import '../models/review.dart';

/// Manila has no daylight saving time. Calendar markers use UTC fields so the
/// browser/device timezone cannot change a reporting day.
DateTime reportLocal(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));
DateTime reportDay(DateTime instant) {
  final local = reportLocal(instant);
  return DateTime.utc(local.year, local.month, local.day);
}

DateTime reportRangeStart(String range, DateTime now) {
  final local = reportLocal(now);
  final day = switch (range) {
    'This week' => DateTime.utc(
      local.year,
      local.month,
      local.day - local.weekday + 1,
    ),
    'Last 3 months' => DateTime.utc(local.year, local.month - 2),
    'This year' => DateTime.utc(local.year),
    _ => DateTime.utc(local.year, local.month),
  };
  return day.subtract(const Duration(hours: 8));
}

class ReportPeriod {
  ReportPeriod(this.start, this.endExclusive) {
    if (!start.isBefore(endExclusive)) {
      throw ArgumentError('Invalid report period');
    }
  }
  factory ReportPeriod.named(String range, DateTime now) => ReportPeriod(
    reportRangeStart(range, now),
    now.toUtc().add(const Duration(microseconds: 1)),
  );
  factory ReportPeriod.dates(DateTime first, DateTime last, DateTime now) {
    final start = DateTime.utc(
      first.year,
      first.month,
      first.day,
    ).subtract(const Duration(hours: 8));
    final end = DateTime.utc(
      last.year,
      last.month,
      last.day + 1,
    ).subtract(const Duration(hours: 8));
    final cutoff = now.toUtc().add(const Duration(microseconds: 1));
    return ReportPeriod(start, end.isBefore(cutoff) ? end : cutoff);
  }
  final DateTime start;
  final DateTime endExclusive;
  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);
  String get label =>
      '${reportDateText(start)} – ${reportDateText(endExclusive.subtract(const Duration(microseconds: 1)))} · Asia/Manila';
}

String reportDateText(DateTime value) =>
    reportLocal(value).toIso8601String().substring(0, 10);
String reportTimestampText(DateTime value) =>
    '${reportLocal(value).toIso8601String().replaceFirst(RegExp(r'Z$'), '')}+08:00';

bool inReportRange(DateTime value, String range, {DateTime? now}) {
  return ReportPeriod.named(range, now ?? DateTime.now()).contains(value);
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
  for (final r in {
    for (final r in reviews) r.reviewId: r,
  }.values.where((r) => r.isCustomerReview && r.rating >= 1 && r.rating <= 5)) {
    final at = reportLocal(r.createdAt.toDate());
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
