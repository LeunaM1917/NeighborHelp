/// Instants are UTC; the marketplace displays and evaluates Asia/Manila time.
class RequestedWorkSchedule {
  const RequestedWorkSchedule({
    required this.start,
    required this.days,
    required this.hoursPerDay,
  });
  final DateTime start;
  final int days;
  final double hoursPerDay;
  Iterable<(DateTime, DateTime)> get periods sync* {
    for (var i = 0; i < days; i++) {
      final from = start.toUtc().add(Duration(days: i));
      yield (from, from.add(Duration(minutes: (hoursPerDay * 60).round())));
    }
  }

  Map<String, dynamic> toMap() => {
    'scheduledDate': start.millisecondsSinceEpoch,
    'numberOfDays': days,
    'hoursPerDay': hoursPerDay,
  };
}
