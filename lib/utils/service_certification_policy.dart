/// Which marketplace services require an agency-authenticated certificate
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
      'Add a credential on your profile and wait for Verification Agency approval before publishing.';
}
