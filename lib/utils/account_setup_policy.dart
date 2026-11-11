import '../data/panabo_barangays.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../models/user_role.dart';
import '../models/identity_verification.dart';

class AccountSetupStatus {
  const AccountSetupStatus({
    required this.user,
    required this.role,
    this.profile,
  });
  final AppUser user;
  final UserRole role;
  final ServiceProviderProfile? profile;
  List<String> get missing =>
      missingAccountDetails(user, role: role, profile: profile);
  IdentityVerification get verification => role == UserRole.provider
      ? IdentityVerification(
          isVerified: profile?.isVerifiedProvider ?? false,
          verificationStatus: profile?.verificationStatus ?? 'Pending',
          diditStatus: profile?.diditStatus ?? '',
          verificationProvider: profile?.verificationProvider ?? '',
          verificationRetakeRequired:
              profile?.verificationRetakeRequired ?? false,
          governmentIdTypeCode: profile?.governmentIdTypeCode ?? '',
          governmentIdTypeLabel: profile?.governmentIdTypeLabel ?? '',
        )
      : user.identityVerification;
  bool get ready =>
      user.accountStatus.firestoreValue == 'Active' &&
      missing.isEmpty &&
      verification.isVerifiedOnPlatform;
}

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
