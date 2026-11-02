import '../models/provider.dart';

bool matchesServiceFilters({
  required double price,
  required double rating,
  required String area,
  required ServiceProviderProfile? profile,
  String? location,
  String? priceFilter,
  String? ratingFilter,
  String? availability,
  DateTime? now,
}) {
  if (location != null &&
      location != 'All locations' &&
      !area.toLowerCase().contains(location.toLowerCase())) {
    return false;
  }
  if (priceFilter != null) {
    final numbers = RegExp(
      r'\d+',
    ).allMatches(priceFilter).map((m) => double.parse(m[0]!)).toList();
    if (priceFilter.startsWith('Under') &&
        numbers.isNotEmpty &&
        price >= numbers.first) {
      return false;
    }
    if (numbers.length == 2 && (price < numbers.first || price >= numbers.last)) {
      return false;
    }
    if (priceFilter.endsWith('+') &&
        numbers.isNotEmpty &&
        price < numbers.first) {
      return false;
    }
  }
  if (ratingFilter != null) {
    final minimum =
        double.tryParse(
          RegExp(r'\d+(?:\.\d+)?').firstMatch(ratingFilter)?[0] ?? '',
        ) ??
        0;
    if (rating < minimum) return false;
  }
  if (availability != null) {
    if (profile == null) return false;
    final at = now ?? DateTime.now();
    final schedule = profile.effectiveWeeklyAvailability;
    final offset = availability == 'This week'
        ? DateTime.sunday - at.weekday + 1
        : availability == 'Weekends'
        ? 7
        : 1;
    var available = false;
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    for (var i = 0; i < offset; i++) {
      final day = at.add(Duration(days: i));
      if (availability == 'Weekends' && day.weekday < 6) continue;
      final item = schedule.scheduleFor(dayNames[day.weekday - 1]);
      if (item.enabled) available = true;
    }
    if (!available) return false;
  }
  return true;
}
