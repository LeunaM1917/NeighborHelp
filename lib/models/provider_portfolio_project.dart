/// One portfolio project on a provider profile.
class ProviderPortfolioProject {
  const ProviderPortfolioProject({
    required this.id,
    this.title = '',
    this.role = '',
    this.description = '',
    this.skills = const [],
    this.photos = const [],
    this.thumbnailUrl = '',
    this.thumbnailIndex = 0,
    this.isDraft = false,
    this.updatedAtMs = 0,
  });

  static const maxTitleLength = 70;
  static const maxRoleLength = 100;
  static const maxDescriptionLength = 600;
  static const maxSkills = 5;
  static const maxPhotos = 10;

  final String id;
  final String title;
  final String role;
  final String description;
  final List<String> skills;
  final List<PortfolioProjectPhoto> photos;
  final String thumbnailUrl;
  final int thumbnailIndex;
  final bool isDraft;
  final int updatedAtMs;

  bool get isEmpty => title.trim().isEmpty && photos.isEmpty;

  bool get isPublished => !isDraft && thumbnailUrl.isNotEmpty;

  factory ProviderPortfolioProject.fromMap(Map<String, dynamic> data) {
    return ProviderPortfolioProject(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      role: data['role'] as String? ?? '',
      description: data['description'] as String? ?? '',
      skills: _stringList(data['skills']),
      photos: PortfolioProjectPhoto.listFromFirestore(data['photos']),
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      thumbnailIndex: (data['thumbnailIndex'] as num?)?.toInt() ?? 0,
      isDraft: data['isDraft'] as bool? ?? false,
      updatedAtMs: (data['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title.trim(),
      if (role.isNotEmpty) 'role': role.trim(),
      if (description.isNotEmpty) 'description': description.trim(),
      if (skills.isNotEmpty) 'skills': skills,
      'photos': photos.map((p) => p.toMap()).toList(),
      if (thumbnailUrl.isNotEmpty) 'thumbnailUrl': thumbnailUrl,
      'thumbnailIndex': thumbnailIndex,
      'isDraft': isDraft,
      'updatedAtMs': updatedAtMs,
    };
  }

  static List<ProviderPortfolioProject> listFromFirestore(dynamic raw) {
    if (raw is! List) return [];
    final out = <ProviderPortfolioProject>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final project = ProviderPortfolioProject.fromMap(Map<String, dynamic>.from(item));
      if (!project.isEmpty) out.add(project);
    }
    return out;
  }

  static List<Map<String, dynamic>> listToFirestore(List<ProviderPortfolioProject> list) {
    return list.map((p) => p.toMap()).toList();
  }

  static List<ProviderPortfolioProject> fromLegacyUrls(List<String> urls) {
    final out = <ProviderPortfolioProject>[];
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i].trim();
      if (url.isEmpty) continue;
      out.add(ProviderPortfolioProject(
        id: 'legacy_$i',
        title: 'Portfolio',
        photos: [PortfolioProjectPhoto(url: url)],
        thumbnailUrl: url,
        thumbnailIndex: 0,
      ));
    }
    return out;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }
}

class PortfolioProjectPhoto {
  const PortfolioProjectPhoto({
    this.url = '',
    this.caption = '',
  });

  final String url;
  final String caption;

  factory PortfolioProjectPhoto.fromMap(Map<String, dynamic> data) {
    return PortfolioProjectPhoto(
      url: data['url'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        if (caption.isNotEmpty) 'caption': caption.trim(),
      };

  static List<PortfolioProjectPhoto> listFromFirestore(dynamic raw) {
    if (raw is! List) return [];
    final out = <PortfolioProjectPhoto>[];
    for (final item in raw) {
      if (item is Map) {
        final p = PortfolioProjectPhoto.fromMap(Map<String, dynamic>.from(item));
        if (p.url.isNotEmpty) out.add(p);
      } else {
        final url = item?.toString().trim() ?? '';
        if (url.isNotEmpty) out.add(PortfolioProjectPhoto(url: url));
      }
    }
    return out;
  }
}
