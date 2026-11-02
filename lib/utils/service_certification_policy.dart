import '../models/provider.dart';

/// Which marketplace services require an administrator-reviewed certificate
/// before the provider may submit the listing for Admin review.
///
/// Soft services (cleaning, tutoring, errands, custom, etc.) do **not** block
/// publishing when the provider has no certificates.
bool serviceRequiresCertification({
  required String category,
  required String serviceTitle,
}) {
  final cat = category.trim().toLowerCase();
  final title = serviceTitle.trim().toLowerCase();

  // Entire technical category needs credentials.
  if (cat.contains('repair and technical') || cat == 'repair & technical services') {
    return true;
  }

  // Sensitive titles even if filed under Home Repair / Moving / Custom.
  const titleNeedles = [
    'electrical',
    'electrician',
    'wiring',
    'plumbing',
    'plumber',
    'aircon',
    'air conditioning',
    'hvac',
    'refrigerant',
    'gas line',
    'welding',
    'welder',
    'appliance repair',
    'carpentry',
    'carpenter',
    'woodwork',
    'computer servicing',
  ];
  for (final needle in titleNeedles) {
    if (title.contains(needle)) return true;
  }

  return false;
}

String certificationRequirementMessage({
  required String category,
  required String serviceTitle,
}) {
  if (!serviceRequiresCertification(category: category, serviceTitle: serviceTitle)) {
    return 'This service does not require a certificate. You can submit it for Admin review after identity verification.';
  }
  return 'This service requires an authenticated certificate. '
      'Add a matching credential on your profile and wait for administrator approval before publishing.';
}

bool hasMatchingServiceCertificate(ServiceProviderProfile profile, {required String category, required String serviceTitle, DateTime? now}) {
  if (!serviceRequiresCertification(category: category, serviceTitle: serviceTitle)) return true;
  final text = '$category $serviceTitle'.toLowerCase();
  final families = <RegExp, RegExp>{
    RegExp('electric|wiring'): RegExp('electric|wiring'),
    RegExp('plumb'): RegExp('plumb'),
    RegExp('carpen|woodwork'): RegExp('carpen|woodwork'),
    RegExp('aircon|air.condition|hvac|refrigerat|refrigerant'): RegExp('aircon|air.condition|hvac|refrigerat|rac servicing'),
    RegExp('computer|laptop|desktop|network|ict'): RegExp('computer|hardware|css nc|ict|network'),
    RegExp('weld|metalwork'): RegExp('weld|metalwork'),
    RegExp('gas line|gas fitting'): RegExp('gas|pipefitting'),
    RegExp('appliance'): RegExp('appliance|electronic.*servic'),
  };
  final match = families.entries.where((e) => e.key.hasMatch(text)).firstOrNull;
  final pattern = match?.value ?? RegExp('repair|technical|servicing');
  return profile.effectiveCertificationHistory.any((c) {
    final expires = DateTime.tryParse(c.expirationDate);
    final today = now ?? DateTime.now();
    final expired = expires != null && DateTime(expires.year, expires.month, expires.day + 1).isBefore(today);
    return profile.approvedCertificationIds.contains(c.id) && c.url.isNotEmpty && !expired && pattern.hasMatch('${c.name} ${c.description}'.toLowerCase());
  });
}
