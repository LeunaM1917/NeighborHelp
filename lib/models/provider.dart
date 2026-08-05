import 'package:cloud_firestore/cloud_firestore.dart';

import 'provider_education.dart';
import 'provider_employment.dart';
import 'provider_certification.dart';
import 'provider_portfolio_project.dart';
import 'provider_weekly_availability.dart';

/// Service provider profile stored in `serviceProviders` (matches Firestore schema).
class ServiceProviderProfile {
  ServiceProviderProfile({
    required this.providerId,
    required this.userId,
    required this.bio,
    required this.serviceArea,
    required this.location,
    required this.serviceRadiusKm,
    required this.averageRating,
    required this.completedBookings,
    required this.acceptedBookings,
    this.reviewCount = 0,
    required this.isVerified,
    required this.verificationStatus,
    required this.createdAt,
    required this.updatedAt,
    this.diditStatus = '',
    this.verificationProvider = '',
    this.governmentIdTypeCode = '',
    this.governmentIdTypeLabel = '',
    this.education = '',
    this.educationHistory = const [],
    this.employmentHistory = const <ProviderEmploymentEntry>[],
    this.portfolioUrls = const [],
    this.portfolioProjects = const [],
    this.videoIntroUrl = '',
    this.certifications = const [],
    this.certificationHistory = const [],
    this.approvedCertificationIds = const [],
    this.otherExperiences = const [],
    this.linkedAccounts = const {},
    this.profileTraits = const [],
    this.weeklyAvailability,
  });

  final String providerId;
  final String userId;
  final String bio;
  final String serviceArea;
  final GeoPoint location;
  final double serviceRadiusKm;
  final double averageRating;
  final int completedBookings;
  final int acceptedBookings;
  /// Customer reviews received (denormalized from cloud function).
  final int reviewCount;
  final bool isVerified;
  final String verificationStatus;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  /// Weekly schedule used for availability scoring (A). Null → defaults.
  final ProviderWeeklyAvailability? weeklyAvailability;

  /// Raw Didit session status, e.g. "Approved", "In Review", "Declined".
  final String diditStatus;

  /// Which KYC vendor drives verification, e.g. "didit". Empty if none yet.
  final String verificationProvider;

  /// Didit document type code (P, ID, DL, RP, HIC, TC) for the selected PH government ID.
  final String governmentIdTypeCode;

  /// Human-readable label, e.g. "Philippine National ID (PhilID / PhilSys)".
  final String governmentIdTypeLabel;

  final String education;
  final List<ProviderEducationEntry> educationHistory;
  final List<ProviderEmploymentEntry> employmentHistory;
  final List<String> portfolioUrls;
  final List<ProviderPortfolioProject> portfolioProjects;
  final String videoIntroUrl;
  final List<String> certifications;
  final List<ProviderCertificationEntry> certificationHistory;
  /// Certificate entry ids authenticated by Verification Agency (cannot be forged by provider).
  final List<String> approvedCertificationIds;
  final List<String> otherExperiences;

  /// Platform id → profile URL, e.g. `facebook`, `instagram`.
  final Map<String, String> linkedAccounts;

  /// Work-style traits shown on overview (e.g. Reliable, Friendly).
  final List<String> profileTraits;

  /// Verified badge — only after platform admin approval ([isVerified] or status Approved).
  bool get isVerifiedProvider =>
      isVerified || verificationStatus.toLowerCase() == 'approved';

  /// Effective schedule for ranking / display (defaults when unset).
  ProviderWeeklyAvailability get effectiveWeeklyAvailability =>
      weeklyAvailability ?? ProviderWeeklyAvailability.defaults;

  /// Whether the provider is within working hours right now (availability score A).
  bool isAvailableNow([DateTime? now]) =>
      effectiveWeeklyAvailability.isAvailableNow(now);

  String get _diditNormalized => diditStatus.trim().toLowerCase();
  String get _verificationNormalized => verificationStatus.trim().toLowerCase();

  /// Didit finished successfully; waiting for NeighborHelp admin to approve.
  bool get isAwaitingAdminApproval =>
      !isVerifiedProvider &&
      (_diditNormalized == 'approved' || _diditNormalized == 'active') &&
      _verificationNormalized != 'rejected';

  /// Admin Approve/Reject actions are allowed only after Didit reports Approved.
  bool get canAdminReviewVerification => isAwaitingAdminApproval;

  /// User is in the hosted Didit flow or Didit is reviewing.
  bool get isVerificationInReview =>
      !isVerifiedProvider &&
      !isAwaitingAdminApproval &&
      (_diditNormalized == 'in review' ||
          _diditNormalized == 'in progress' ||
          _diditNormalized == 'awaiting user' ||
          _diditNormalized == 'resubmitted' ||
          _diditNormalized == 'not started');

  bool get isVerificationDeclined =>
      _verificationNormalized == 'rejected' || _diditNormalized == 'declined';

  bool get hasEducation =>
      educationHistory.isNotEmpty || education.trim().isNotEmpty;

  List<ProviderEducationEntry> get effectiveEducationHistory {
    if (educationHistory.isNotEmpty) return educationHistory;
    if (education.trim().isEmpty) return const [];
    return [ProviderEducationEntry(school: education.trim())];
  }

  List<String> get educationDisplayLines =>
      effectiveEducationHistory.map((e) => e.displayLine).toList();

  bool get hasEmployment => employmentHistory.isNotEmpty;

  List<String> get employmentDisplayLines =>
      employmentHistory.map((e) => e.displayLine).toList();

  List<ProviderPortfolioProject> get effectivePortfolioProjects {
    if (portfolioProjects.isNotEmpty) return portfolioProjects;
    return ProviderPortfolioProject.fromLegacyUrls(portfolioUrls);
  }

  bool get hasPortfolio =>
      effectivePortfolioProjects.any((p) => !p.isDraft && p.thumbnailUrl.isNotEmpty) ||
      portfolioUrls.isNotEmpty;

  List<ProviderCertificationEntry> get effectiveCertificationHistory {
    if (certificationHistory.isNotEmpty) {
      final approved = approvedCertificationIds.toSet();
      // Treat agency allow-list as source of truth for Approved display.
      return certificationHistory
          .map(
            (e) => approved.contains(e.id) && e.id.isNotEmpty
                ? e.copyWith(status: CertificationVerificationStatus.approved)
                : e,
          )
          .toList();
    }
    return certifications.map((c) => ProviderCertificationEntry(name: c)).toList();
  }

  bool get hasCertifications => effectiveCertificationHistory.isNotEmpty;

  /// At least one certificate authenticated by the Verification Agency.
  bool get hasApprovedCertifications {
    final approved = approvedCertificationIds.toSet();
    return effectiveCertificationHistory.any((e) => e.id.isNotEmpty && approved.contains(e.id));
  }

  List<ProviderCertificationEntry> get approvedCertifications =>
      effectiveCertificationHistory.where((e) => e.isApproved).toList();

  /// Thumbnail-first URLs for profile grid (published projects only).
  List<String> get portfolioThumbnailUrls {
    final published = effectivePortfolioProjects.where((p) => !p.isDraft && p.thumbnailUrl.isNotEmpty);
    if (published.isNotEmpty) return published.map((p) => p.thumbnailUrl).toList();
    return portfolioUrls;
  }

  factory ServiceProviderProfile.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ServiceProviderProfile(
      providerId: id,
      userId: data['userId'] as String? ?? id,
      bio: data['bio'] as String? ?? '',
      serviceArea: data['serviceArea'] as String? ?? '',
      location: data['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      serviceRadiusKm: (data['serviceRadiusKm'] as num?)?.toDouble() ?? 5,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
      completedBookings: (data['completedBookings'] as num?)?.toInt() ?? 0,
      acceptedBookings: (data['acceptedBookings'] as num?)?.toInt() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      isVerified: data['isVerified'] as bool? ?? false,
      verificationStatus: data['verificationStatus'] as String? ?? 'Pending',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      diditStatus: data['diditStatus'] as String? ?? '',
      verificationProvider: data['verificationProvider'] as String? ?? '',
      governmentIdTypeCode: data['governmentIdTypeCode'] as String? ?? '',
      governmentIdTypeLabel: data['governmentIdTypeLabel'] as String? ?? '',
      education: data['education'] as String? ?? '',
      educationHistory: ProviderEducationEntry.listFromFirestore(data['educationHistory']),
      employmentHistory: ProviderEmploymentEntry.listFromFirestore(data['employmentHistory']),
      portfolioUrls: _stringList(data['portfolioUrls']),
      portfolioProjects: ProviderPortfolioProject.listFromFirestore(data['portfolioProjects']),
      videoIntroUrl: data['videoIntroUrl'] as String? ?? '',
      certifications: _stringList(data['certifications']),
      certificationHistory: ProviderCertificationEntry.listFromFirestore(data['certificationHistory']),
      approvedCertificationIds: _stringList(data['approvedCertificationIds']),
      otherExperiences: _stringList(data['otherExperiences']),
      linkedAccounts: _linkedAccountsMap(data['linkedAccounts']),
      profileTraits: _stringList(data['profileTraits']),
      weeklyAvailability: _weeklyAvailability(data['weeklyAvailability']),
    );
  }

  static ProviderWeeklyAvailability? _weeklyAvailability(dynamic raw) {
    if (raw is! Map) return null;
    return ProviderWeeklyAvailability.fromFirestore(Map<String, dynamic>.from(raw));
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static Map<String, String> _linkedAccountsMap(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      final url = value?.toString().trim() ?? '';
      if (url.isNotEmpty) out[key.toString()] = url;
    });
    return out;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bio': bio,
      'serviceArea': serviceArea,
      'location': location,
      'serviceRadiusKm': serviceRadiusKm,
      'averageRating': averageRating,
      'completedBookings': completedBookings,
      'acceptedBookings': acceptedBookings,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'diditStatus': diditStatus,
      'verificationProvider': verificationProvider,
      'governmentIdTypeCode': governmentIdTypeCode,
      'governmentIdTypeLabel': governmentIdTypeLabel,
      'education': education,
      'educationHistory': ProviderEducationEntry.listToFirestore(educationHistory),
      'employmentHistory': ProviderEmploymentEntry.listToFirestore(employmentHistory),
      'portfolioUrls': portfolioUrls,
      'portfolioProjects': ProviderPortfolioProject.listToFirestore(portfolioProjects),
      'videoIntroUrl': videoIntroUrl,
      'certifications': certifications,
      'certificationHistory': ProviderCertificationEntry.listToFirestore(certificationHistory),
      'approvedCertificationIds': approvedCertificationIds,
      'otherExperiences': otherExperiences,
      'linkedAccounts': linkedAccounts,
      'profileTraits': profileTraits,
      if (weeklyAvailability != null) 'weeklyAvailability': weeklyAvailability!.toFirestore(),
    };
  }
}
