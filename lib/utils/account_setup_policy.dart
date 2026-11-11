import '../data/panabo_barangays.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../models/user_role.dart';

String normalizedAccountPhone(String? value) =>
    (value ?? '').replaceAll(RegExp(r'[\s()-]'), '');

bool validAccountPhone(String? value) =>
    RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalizedAccountPhone(value));

/// Required setup is independent of the optional provider portfolio score.
List<String> missingAccountDetails(
  AppUser user, {
  required UserRole role,
  ServiceProviderProfile? profile,
}) {
  final missing = <String>[];
  if (user.fullName.trim().length < 2) missing.add('Full name');
  if (!validAccountPhone(user.contactNumber)) missing.add('Valid phone number');
  if (role == UserRole.provider) {
    final ids = panaboBarangays.map((b) => b['id']).toSet();
    if (!ids.contains(profile?.baseBarangayId)) missing.add('Home barangay');
    final areas = profile?.serviceBarangayIds ?? <String>[];
    if (areas.isEmpty || !areas.every(ids.contains)) {
      missing.add('Service barangays');
    }
  } else if ((user.address ?? '').trim().length < 5) {
    missing.add('Address or barangay and city');
  }
  return missing;
}
