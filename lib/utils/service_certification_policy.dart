import '../models/provider.dart';
import '../models/provider_certification.dart';
import 'approved_service_catalog.dart';
export 'approved_service_catalog.dart';

bool isCurrentTesdaCertificate(
  ServiceProviderProfile profile,
  ProviderCertificationEntry c, {
  DateTime? now,
}) {
  final expires = DateTime.tryParse('${c.expirationDate}T23:59:59.999+08:00');
  return profile.approvedCertificationIds.contains(c.id) &&
      c.isApproved &&
      c.url.isNotEmpty &&
      c.certificationId.isNotEmpty &&
      normalizeCredential(c.provider) == 'tesda' &&
      c.verificationSource == 'TESDA Registry of Certified Workers' &&
      c.reviewedBy.isNotEmpty &&
      c.reviewedAt != null &&
      expires != null &&
      !expires.isBefore(now ?? DateTime.now());
}

bool isCurrentReviewedCredential(
  ServiceProviderProfile profile,
  ProviderCertificationEntry c, {
  DateTime? now,
}) {
  if (c.credentialType != 'equivalent') {
    return isCurrentTesdaCertificate(profile, c, now: now);
  }
  final expires = DateTime.tryParse('${c.expirationDate}T23:59:59.999+08:00');
  return profile.approvedCertificationIds.contains(c.id) &&
      c.isApproved &&
      c.verificationSource == 'Issuing authority verification' &&
      c.issuerVerified &&
      c.reviewedBy.isNotEmpty &&
      c.reviewedAt != null &&
      c.url.isNotEmpty &&
      c.certificationId.isNotEmpty &&
      c.name.isNotEmpty &&
      c.provider.isNotEmpty &&
      expires != null &&
      !expires.isBefore(now ?? DateTime.now());
}

enum ServiceCertificateStatus {
  approved,
  missing,
  pending,
  rejected,
  expired,
  needsReview,
}

/// Explains a failed eligibility check without treating an unreviewed upload as approval.
ServiceCertificateStatus serviceCertificateStatus(
  ServiceProviderProfile profile, {
  required String category,
  required String serviceTitle,
  DateTime? now,
}) {
  if (hasMatchingServiceCertificate(
    profile,
    category: category,
    serviceTitle: serviceTitle,
    now: now,
  )) {
    return ServiceCertificateStatus.approved;
  }
  final family = approvedServiceFamily(category, serviceTitle);
  final customNames =
      [
            ...profile.approvedServiceProposals.values,
            ...profile.approvedServiceListings.values,
          ]
          .whereType<Map>()
          .where(
            (g) =>
                g['status'] == 'Approved' &&
                normalizeCredential('${g['category']}') ==
                    normalizeCredential(category) &&
                normalizeCredential('${g['serviceTitle']}') ==
                    normalizeCredential(serviceTitle),
          )
          .map((g) => '${g['qualificationName']}');
  final accepted = [
    ...(approvedQualifications[family] ?? <String>[]),
    ...customNames,
  ].map(normalizeCredential).toSet();
  final matching = profile.certificationHistory
      .where(
        (c) =>
            normalizeCredential(c.provider) == 'tesda' &&
            accepted.contains(normalizeCredential(c.name)),
      )
      .toList();
  if (matching.isEmpty) return ServiceCertificateStatus.missing;
  if (matching.any((c) => c.isPending)) return ServiceCertificateStatus.pending;
  if (matching.any((c) => c.isRejected)) {
    return ServiceCertificateStatus.rejected;
  }
  if (matching.every((c) {
    final expires = DateTime.tryParse('${c.expirationDate}T23:59:59.999+08:00');
    return expires != null && expires.isBefore(now ?? DateTime.now());
  })) {
    return ServiceCertificateStatus.expired;
  }
  return ServiceCertificateStatus.needsReview;
}

/// All listings require a matching TESDA credential. Unsupported tasks fail closed.
bool serviceRequiresCertification({
  required String category,
  required String serviceTitle,
}) => true;

String certificationRequirementMessage({
  required String category,
  required String serviceTitle,
}) {
  final family = approvedServiceFamily(category, serviceTitle);
  if (family == null) {
    return 'Select a relevant TESDA NC or accepted equivalent credential. The administrator must confirm its alignment with this service and category.';
  }
  return 'Requires ${approvedQualifications[family]!.join(' or ')}, checked by the System Administrator through the TESDA registry.';
}

bool hasMatchingServiceCertificate(
  ServiceProviderProfile profile, {
  required String category,
  required String serviceTitle,
  DateTime? now,
}) {
  final family = approvedServiceFamily(category, serviceTitle);
  final grants =
      [
            ...profile.approvedServiceProposals.values,
            ...profile.approvedServiceListings.values,
          ]
          .whereType<Map>()
          .where(
            (g) =>
                g['status'] == 'Approved' &&
                g['reviewedBy'] is String &&
                (g['reviewedBy'] as String).isNotEmpty &&
                g['reviewedAt'] != null &&
                normalizeCredential('${g['category']}') ==
                    normalizeCredential(category) &&
                normalizeCredential('${g['serviceTitle']}') ==
                    normalizeCredential(serviceTitle),
          )
          .toList();
  if (family == null && grants.isEmpty) return false;
  final accepted = (approvedQualifications[family] ?? <String>[])
      .map(normalizeCredential)
      .toSet();
  // Match the backend: both the approved ID and the stored review decision
  // must agree. Presentation fallbacks must not grant publishing permission.
  return profile.certificationHistory.any((c) {
    return (isCurrentTesdaCertificate(profile, c, now: now) &&
            accepted.contains(normalizeCredential(c.name))) ||
        (isCurrentReviewedCredential(profile, c, now: now) &&
            grants.any(
              (g) =>
                  (g['reviewType'] != 'directListing' ||
                      g['certificationEntryId'] == c.id) &&
                  normalizeCredential('${g['qualificationName']}') ==
                      normalizeCredential(c.name),
            ));
  });
}
