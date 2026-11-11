import '../models/booking_user_report.dart';

class UserReportStats {
  UserReportStats._(
    this.open,
    this.resolved,
    this.dismissed,
    this.months,
    this.monthlyCounts,
    this.isLimited,
  );

  final int open;
  final int resolved;
  final int dismissed;
  final List<DateTime> months;
  final List<int> monthlyCounts;
  final bool isLimited;
  int get total => open + resolved + dismissed;

  factory UserReportStats.fromReports(
    Iterable<BookingUserReport> reports, {
    DateTime? now,
    bool isLimited = false,
  }) {
    final instant = (now ?? DateTime.now()).toUtc();
    final manila = instant.add(const Duration(hours: 8));
    final months = List.generate(
      6,
      (i) => DateTime.utc(manila.year, manila.month - 5 + i),
    );
    final counts = List<int>.filled(6, 0);
    var open = 0, resolved = 0, dismissed = 0;
    for (final report in reports) {
      if (report.status == BookingUserReport.statusResolved) {
        resolved++;
      } else if (report.status == BookingUserReport.statusDismissed) {
        dismissed++;
      } else {
        open++;
      }
      final created = report.createdAt.toDate().toUtc();
      if (created.isAfter(instant)) continue;
      final local = created.add(const Duration(hours: 8));
      final index = months.indexOf(DateTime.utc(local.year, local.month));
      if (index >= 0) counts[index]++;
    }
    return UserReportStats._(
      open,
      resolved,
      dismissed,
      List.unmodifiable(months),
      List.unmodifiable(counts),
      isLimited,
    );
  }
}
