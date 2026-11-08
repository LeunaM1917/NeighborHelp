/// Supported household tasks only. Professional design, regulated electrical
/// work and master plumbing remain excluded until licence checks are supported.
const approvedServiceCatalog = <String, Map<String, String>>{
  'Home Repair': {
    'Basic Carpentry': 'carpentry',
    'Carpentry': 'carpentry',
    'Door Repair': 'carpentry',
    'Furniture Repair': 'carpentry',
  },
  'Cleaning': {
    'House Cleaning': 'domestic',
    'Apartment Cleaning': 'domestic',
    'Kitchen Cleaning': 'domestic',
    'Bathroom Cleaning': 'domestic',
    'Laundry Assistance': 'domestic',
    'Ironing Service': 'domestic',
  },
  'Repair and Technical Services': {
    'Computer Repair': 'computer',
    'Laptop Repair': 'computer',
    'Internet/Wi-Fi Setup': 'computer',
    'Aircon Cleaning': 'rac',
    'Aircon Repair': 'rac',
    'Refrigerator Repair': 'rac',
  },
  'Handyman': {
    'Furniture Assembly': 'carpentry',
    'Shelf Installation': 'carpentry',
  },
};
const approvedQualifications = <String, List<String>>{
  'carpentry': ['Carpentry NC II', 'Carpentry NC III'],
  'domestic': ['Domestic Work NC II'],
  'computer': ['Computer Systems Servicing NC II'],
  'rac': ['RAC Servicing (DomRAC) NC II', 'RAC Servicing (Domestic) NC II'],
};
String normalizeCredential(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
String? approvedServiceFamily(String category, String title) {
  for (final entry in approvedServiceCatalog.entries) {
    if (normalizeCredential(entry.key) != normalizeCredential(category)) {
      continue;
    }
    for (final service in entry.value.entries) {
      if (normalizeCredential(service.key) == normalizeCredential(title)) {
        return service.value;
      }
    }
  }
  return null;
}

bool isSupportedService(String category, String title) =>
    approvedServiceFamily(category, title) != null;
