/// One employment entry on a provider profile.
class ProviderEmploymentEntry {
  const ProviderEmploymentEntry({
    this.company = '',
    this.city = '',
    this.country = '',
    this.title = '',
    this.startMonth = '',
    this.startYear = '',
    this.endMonth = '',
    this.endYear = '',
    this.currentlyWorking = false,
    this.description = '',
  });

  final String company;
  final String city;
  final String country;
  final String title;
  final String startMonth;
  final String startYear;
  final String endMonth;
  final String endYear;
  final bool currentlyWorking;
  final String description;

  bool get isEmpty => company.trim().isEmpty && title.trim().isEmpty;

  factory ProviderEmploymentEntry.fromMap(Map<String, dynamic> data) {
    return ProviderEmploymentEntry(
      company: data['company'] as String? ?? '',
      city: data['city'] as String? ?? '',
      country: data['country'] as String? ?? '',
      title: data['title'] as String? ?? '',
      startMonth: data['startMonth'] as String? ?? '',
      startYear: data['startYear'] as String? ?? '',
      endMonth: data['endMonth'] as String? ?? '',
      endYear: data['endYear'] as String? ?? '',
      currentlyWorking: data['currentlyWorking'] as bool? ?? false,
      description: data['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company': company.trim(),
      if (city.isNotEmpty) 'city': city.trim(),
      if (country.isNotEmpty) 'country': country.trim(),
      if (title.isNotEmpty) 'title': title.trim(),
      if (startMonth.isNotEmpty) 'startMonth': startMonth,
      if (startYear.isNotEmpty) 'startYear': startYear,
      if (!currentlyWorking && endMonth.isNotEmpty) 'endMonth': endMonth,
      if (!currentlyWorking && endYear.isNotEmpty) 'endYear': endYear,
      'currentlyWorking': currentlyWorking,
      if (description.isNotEmpty) 'description': description.trim(),
    };
  }

  String get displayLine {
    final parts = <String>[];
    final role = title.trim();
    final org = company.trim();
    if (role.isNotEmpty && org.isNotEmpty) {
      parts.add('$role at $org');
    } else if (role.isNotEmpty) {
      parts.add(role);
    } else if (org.isNotEmpty) {
      parts.add(org);
    }
    final loc = _locationLine;
    if (loc.isNotEmpty) parts.add(loc);
    final dates = _dateRange;
    if (dates.isNotEmpty) parts.add(dates);
    return parts.join(' • ');
  }

  String get _locationLine {
    final c = city.trim();
    final co = country.trim();
    if (c.isEmpty && co.isEmpty) return '';
    if (c.isNotEmpty && co.isNotEmpty) return '$c, $co';
    return c.isNotEmpty ? c : co;
  }

  String get _dateRange {
    final start = _formatMonthYear(startMonth, startYear);
    if (start.isEmpty) return '';
    if (currentlyWorking) return '$start – Present';
    final end = _formatMonthYear(endMonth, endYear);
    if (end.isEmpty) return start;
    return '$start – $end';
  }

  static String _formatMonthYear(String month, String year) {
    if (month.isEmpty && year.isEmpty) return '';
    if (month.isEmpty) return year;
    if (year.isEmpty) return month;
    return '$month $year';
  }

  static const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static List<ProviderEmploymentEntry> listFromFirestore(dynamic raw) {
    if (raw is! List) return [];
    final out = <ProviderEmploymentEntry>[];
    for (final item in raw) {
      if (item is Map) {
        final entry = ProviderEmploymentEntry.fromMap(Map<String, dynamic>.from(item));
        if (!entry.isEmpty) out.add(entry);
      } else {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) out.add(ProviderEmploymentEntry(company: text));
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> listToFirestore(List<ProviderEmploymentEntry> list) {
    return list.map((e) => e.toMap()).toList();
  }
}
