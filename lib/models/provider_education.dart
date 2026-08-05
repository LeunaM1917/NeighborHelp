/// One education entry on a provider profile (Upwork-style).
class ProviderEducationEntry {
  const ProviderEducationEntry({
    this.school = '',
    this.fromYear = '',
    this.toYear = '',
    this.degree = '',
    this.areaOfStudy = '',
    this.description = '',
  });

  final String school;
  final String fromYear;
  final String toYear;
  final String degree;
  final String areaOfStudy;
  final String description;

  bool get isEmpty => school.trim().isEmpty;

  factory ProviderEducationEntry.fromMap(Map<String, dynamic> data) {
    return ProviderEducationEntry(
      school: data['school'] as String? ?? '',
      fromYear: data['fromYear'] as String? ?? '',
      toYear: data['toYear'] as String? ?? '',
      degree: data['degree'] as String? ?? '',
      areaOfStudy: data['areaOfStudy'] as String? ?? '',
      description: data['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'school': school.trim(),
      if (fromYear.isNotEmpty) 'fromYear': fromYear,
      if (toYear.isNotEmpty) 'toYear': toYear,
      if (degree.isNotEmpty) 'degree': degree,
      if (areaOfStudy.isNotEmpty) 'areaOfStudy': areaOfStudy,
      if (description.isNotEmpty) 'description': description,
    };
  }

  /// Single-line summary for profile timeline lists.
  String get displayLine {
    final parts = <String>[school.trim()];
    if (degree.isNotEmpty) parts.add(degree);
    if (areaOfStudy.isNotEmpty) parts.add(areaOfStudy);
    final dates = _dateRange;
    if (dates.isNotEmpty) parts.add(dates);
    return parts.join(' • ');
  }

  String get _dateRange {
    if (fromYear.isEmpty && toYear.isEmpty) return '';
    if (fromYear.isNotEmpty && toYear.isNotEmpty) return '$fromYear – $toYear';
    return fromYear.isNotEmpty ? fromYear : toYear;
  }

  static List<ProviderEducationEntry> listFromFirestore(dynamic raw) {
    if (raw is! List) return [];
    final out = <ProviderEducationEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final entry = ProviderEducationEntry.fromMap(Map<String, dynamic>.from(item));
      if (!entry.isEmpty) out.add(entry);
    }
    return out;
  }

  static List<Map<String, dynamic>> listToFirestore(List<ProviderEducationEntry> list) {
    return list.map((e) => e.toMap()).toList();
  }
}
