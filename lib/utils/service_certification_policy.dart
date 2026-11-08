import '../models/provider.dart';
import 'approved_service_catalog.dart';
export 'approved_service_catalog.dart';

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
    return 'Choose a supported service from the catalog. Custom services and services requiring unsupported professional licences cannot be published.';
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
  if (family == null) return false;
  final accepted = approvedQualifications[family]!
      .map(normalizeCredential)
      .toSet();
  return profile.effectiveCertificationHistory.any((c) {
    final expires = DateTime.tryParse('${c.expirationDate}T23:59:59.999+08:00');
    return profile.approvedCertificationIds.contains(c.id) &&
        c.isApproved &&
        c.url.isNotEmpty &&
        c.certificationId.isNotEmpty &&
        normalizeCredential(c.provider) == 'tesda' &&
        accepted.contains(normalizeCredential(c.name)) &&
        c.verificationSource == 'TESDA Registry of Certified Workers' &&
        c.reviewedBy.isNotEmpty &&
        c.reviewedAt != null &&
        expires != null &&
        !expires.isBefore(now ?? DateTime.now());
  });
}
