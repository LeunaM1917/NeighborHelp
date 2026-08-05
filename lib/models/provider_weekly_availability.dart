/// Provider weekly schedule stored in `serviceProviders.weeklyAvailability`.
class ProviderDaySchedule {
  const ProviderDaySchedule({
    required this.enabled,
    required this.start,
    required this.end,
  });

  final bool enabled;
  final String start;
  final String end;

  ProviderDaySchedule copyWith({bool? enabled, String? start, String? end}) {
    return ProviderDaySchedule(
      enabled: enabled ?? this.enabled,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  factory ProviderDaySchedule.fromDynamic(dynamic raw, {required ProviderDaySchedule fallback}) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return ProviderDaySchedule(
        enabled: map['enabled'] as bool? ?? fallback.enabled,
        start: map['start'] as String? ?? fallback.start,
        end: map['end'] as String? ?? fallback.end,
      );
    }
    if (raw is bool) {
      return fallback.copyWith(enabled: raw);
    }
    return fallback;
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'start': start,
        'end': end,
      };
}

class ProviderWeeklyAvailability {
  const ProviderWeeklyAvailability({required this.days});

  static const dayOrder = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  final Map<String, ProviderDaySchedule> days;

  ProviderDaySchedule scheduleFor(String day) =>
      days[day] ?? ProviderWeeklyAvailability.defaults.days[day]!;

  ProviderWeeklyAvailability updateDay(String day, ProviderDaySchedule schedule) {
    return ProviderWeeklyAvailability(days: {...days, day: schedule});
  }

  static final defaults = ProviderWeeklyAvailability(
    days: {
      'Monday': const ProviderDaySchedule(enabled: true, start: '8:00 AM', end: '5:00 PM'),
      'Tuesday': const ProviderDaySchedule(enabled: true, start: '8:00 AM', end: '5:00 PM'),
      'Wednesday': const ProviderDaySchedule(enabled: true, start: '8:30 AM', end: '5:30 PM'),
      'Thursday': const ProviderDaySchedule(enabled: true, start: '8:00 AM', end: '5:00 PM'),
      'Friday': const ProviderDaySchedule(enabled: true, start: '8:00 AM', end: '5:00 PM'),
      'Saturday': const ProviderDaySchedule(enabled: true, start: '9:00 AM', end: '1:00 PM'),
      'Sunday': const ProviderDaySchedule(enabled: false, start: '8:00 AM', end: '5:00 PM'),
    },
  );

  factory ProviderWeeklyAvailability.fromFirestore(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    final out = <String, ProviderDaySchedule>{};
    for (final day in dayOrder) {
      out[day] = ProviderDaySchedule.fromDynamic(
        raw[day],
        fallback: defaults.scheduleFor(day),
      );
    }
    return ProviderWeeklyAvailability(days: out);
  }

  Map<String, dynamic> toFirestore() {
    return {for (final e in days.entries) e.key: e.value.toMap()};
  }

  String get workingDaysLabel {
    const short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final on = <String>[];
    for (var i = 0; i < dayOrder.length; i++) {
      if (scheduleFor(dayOrder[i]).enabled) on.add(short[i]);
    }
    if (on.isEmpty) return 'No days set';
    if (on.length == 7) return 'Every day';
    if (on.length >= 2 && on.first == 'Mon' && on.last == 'Sat' && on.length == 6) {
      return 'Mon – Sat';
    }
    return on.join(', ');
  }

  String get workingHoursLabel {
    final enabled = dayOrder.where((d) => scheduleFor(d).enabled).toList();
    if (enabled.isEmpty) return '—';
    final first = scheduleFor(enabled.first);
    final same = enabled.every((d) {
      final s = scheduleFor(d);
      return s.start == first.start && s.end == first.end;
    });
    if (same) return '${first.start} – ${first.end}';
    return 'Varies by day';
  }

  /// Half-hour slots from 6:00 AM through 11:30 PM.
  static List<String> get timeSlotOptions {
    const periods = ['AM', 'PM'];
    final out = <String>[];
    for (var h = 6; h <= 23; h++) {
      for (final m in [0, 30]) {
        if (h == 23 && m == 30) continue;
        final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        final period = h < 12 ? periods[0] : periods[1];
        final min = m == 0 ? '00' : '30';
        out.add('$hour12:$min $period');
      }
    }
    return out;
  }

  /// Whether [now] falls on an enabled day within that day's start–end window.
  bool isAvailableNow([DateTime? now]) {
    final at = now ?? DateTime.now();
    final dayName = dayOrder[at.weekday - 1];
    final day = scheduleFor(dayName);
    if (!day.enabled) return false;
    final start = minutesFromTimeLabel(day.start);
    final end = minutesFromTimeLabel(day.end);
    if (start == null || end == null) return false;
    final current = at.hour * 60 + at.minute;
    if (end >= start) {
      return current >= start && current <= end;
    }
    // Overnight window (e.g. 10:00 PM – 2:00 AM).
    return current >= start || current <= end;
  }

  /// Parses labels like `8:00 AM` / `5:30 PM` into minutes from midnight.
  static int? minutesFromTimeLabel(String label) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(label.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (period == 'AM') {
      if (hour == 12) hour = 0;
    } else if (hour != 12) {
      hour += 12;
    }
    return hour * 60 + minute;
  }
}

String formatWorkingDays(Map<String, dynamic>? raw) =>
    ProviderWeeklyAvailability.fromFirestore(raw).workingDaysLabel;

String formatWorkingHours(Map<String, dynamic>? raw) =>
    ProviderWeeklyAvailability.fromFirestore(raw).workingHoursLabel;
