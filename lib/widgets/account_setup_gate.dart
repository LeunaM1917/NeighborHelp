import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/identity_verification.dart';
import '../models/provider.dart';
import '../models/user_role.dart';
import '../screens/customer/customer_settings_screen.dart';
import '../screens/provider/provider_overview_settings_screen.dart';
import '../screens/provider/widgets/provider_profile_widgets.dart';
import '../services/firestore_service.dart';
import '../services/identity_verification_service.dart';
import '../ui/workflow_ui.dart';
import '../utils/account_setup_policy.dart';

/// Runs on every sign-in, including Google sign-up and verification returns.
/// No client-editable "setup complete" flag can skip these requirements.
class AccountSetupGate extends StatefulWidget {
  const AccountSetupGate({
    super.key,
    required this.appUser,
    required this.role,
    required this.onSignOut,
    required this.child,
    this.providerProfiles,
    this.onEditProfile,
    this.onRefresh,
  });
  final AppUser appUser;
  final UserRole role;
  final Future<void> Function() onSignOut;
  final Widget child;
  final Stream<ServiceProviderProfile?>? providerProfiles;
  final Future<void> Function()? onEditProfile;
  final Future<void> Function()? onRefresh;
  @override
  State<AccountSetupGate> createState() => _AccountSetupGateState();
}

class _AccountSetupGateState extends State<AccountSetupGate> {
  Stream<ServiceProviderProfile?>? _profiles;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.role == UserRole.provider) {
      _profiles =
          widget.providerProfiles ??
          FirestoreService().providerProfileForUser(widget.appUser.userId);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => WorkflowDialog(
            title: const Text('Could not update account setup'),
            content: const Text(
              'Check your connection and try again. Your account setup is still required.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ServiceProviderProfile? profile) async {
    if (widget.onEditProfile != null) return widget.onEditProfile!();
    if (widget.role == UserRole.provider) {
      await FirestoreService().ensureServiceProviderProfile(
        widget.appUser.userId,
      );
      if (!mounted) return;
      await ProviderOverviewSettingsScreen.open(
        context,
        appUser: widget.appUser,
        profile:
            profile ??
            ServiceProviderProfile.fromFirestore(widget.appUser.userId, {
              'userId': widget.appUser.userId,
            }),
        requireAccountDetails: true,
      );
    } else {
      await CustomerSettingsScreen.open(
        context,
        appUser: widget.appUser,
        requireAccountDetails: true,
      );
    }
  }

  Future<void> _refresh(IdentityVerification verification) async {
    if (widget.onRefresh != null) return widget.onRefresh!();
    if (verification.hasStarted && !verification.isVerifiedOnPlatform) {
      await IdentityVerificationService().refreshDiditStatusForAdmin(
        userId: widget.appUser.userId,
        subject: widget.role == UserRole.provider
            ? VerificationSubject.provider
            : VerificationSubject.customer,
      );
    }
    await FirestoreService().retryDataLoads();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role != UserRole.customer && widget.role != UserRole.provider) {
      return widget.child;
    }
    if (widget.role != UserRole.provider) return _content(null);
    return StreamBuilder<ServiceProviderProfile?>(
      stream: _profiles,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: WorkflowPage(
              title: 'Account setup',
              subtitle:
                  'We could not load your provider profile. Please retry.',
              children: [
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          widget.onRefresh ??
                              () => FirestoreService().retryDataLoads(),
                        ),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _run(widget.onSignOut),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _content(snap.data);
      },
    );
  }

  Widget _content(ServiceProviderProfile? profile) {
    final provider = widget.role == UserRole.provider;
    final missing = missingAccountDetails(
      widget.appUser,
      role: widget.role,
      profile: profile,
    );
    final verification = provider
        ? IdentityVerification(
            isVerified: profile?.isVerifiedProvider ?? false,
            verificationStatus: profile?.verificationStatus ?? 'Pending',
            diditStatus: profile?.diditStatus ?? '',
            verificationProvider: profile?.verificationProvider ?? '',
            governmentIdTypeCode: profile?.governmentIdTypeCode ?? '',
            governmentIdTypeLabel: profile?.governmentIdTypeLabel ?? '',
          )
        : widget.appUser.identityVerification;
    if (missing.isEmpty && verification.isVerifiedOnPlatform) {
      return widget.child;
    }
    final String status;
    if (verification.isVerifiedOnPlatform) {
      status = 'Identity verified. Finish your account details to continue.';
    } else if (verification.isAwaitingAdminApproval) {
      status =
          'ID check complete. Awaiting System Administrator approval. You cannot hire or offer services until approved.';
    } else if (verification.isDeclined) {
      status =
          'Verification was rejected. Review the result and retry with your own valid government ID.';
    } else if (verification.isInReview && !verification.isIncomplete) {
      status =
          'Your identity check is under review. Refresh the status after the review finishes.';
    } else {
      status =
          'Complete the government ID and face check on ID Analyzer. Account access opens after identity verification is approved.';
    }
    return Scaffold(
      body: SafeArea(
        child: WorkflowPage(
          title: 'Complete your account setup',
          subtitle:
              'Finish your profile and identity verification before using your ${provider ? 'provider' : 'customer'} account.',
          maxWidth: 760,
          children: [
            WorkflowSection(
              title: '1. Complete your profile',
              icon: Icons.person_outline,
              children: [
                Text(
                  missing.isEmpty
                      ? 'Required profile details are complete.'
                      : 'Still needed: ${missing.join(', ')}.',
                ),
                if (provider)
                  const Text(
                    'Your public location uses your barangay center. Your home pin is not required.',
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(() => _edit(profile)),
                  icon: const Icon(Icons.person_outline),
                  label: Text(
                    missing.isEmpty ? 'Edit profile' : 'Complete profile',
                  ),
                ),
              ],
            ),
            WorkflowSection(
              title: '2. Verify your identity (KYC)',
              icon: Icons.verified_user_outlined,
              children: [
                Text(status),
                if (missing.isNotEmpty && !verification.isVerifiedOnPlatform)
                  const Text(
                    'Save the required profile details first to unlock identity verification.',
                  ),
                if (missing.isEmpty &&
                    !verification.isVerifiedOnPlatform &&
                    !verification.isAwaitingAdminApproval &&
                    (!verification.isInReview || verification.isIncomplete))
                  ProviderVerifyIdentityButton(
                    subject: provider
                        ? VerificationSubject.provider
                        : VerificationSubject.customer,
                    governmentIdTypeCode: verification.governmentIdTypeCode,
                    governmentIdTypeLabel: verification.governmentIdTypeLabel,
                    inReview: verification.isInReview,
                    restartFromIdPicker: verification.isIncomplete,
                    declined: verification.isDeclined,
                    callbackUrl:
                        Uri.base.hasScheme && Uri.base.scheme.startsWith('http')
                        ? Uri.base.toString()
                        : null,
                  ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => _refresh(verification)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh verification status'),
                ),
              ],
            ),
            if (provider)
              const Text(
                'After account setup, each service listing requires a matching, current TESDA certificate authenticated by the System Administrator.',
              ),
            TextButton(
              onPressed: _busy ? null : () => _run(widget.onSignOut),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
