import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../models/user_role.dart';
import '../screens/customer/customer_settings_screen.dart';
import '../screens/provider/provider_overview_settings_screen.dart';
import '../screens/provider/widgets/provider_profile_widgets.dart';
import '../services/firestore_service.dart';
import '../services/identity_verification_service.dart';
import '../ui/workflow_ui.dart';
import '../utils/account_setup_policy.dart';

typedef AccountSetupLoader = Future<AccountSetupStatus> Function();
final _activeSetupChecks = <String>{};

/// Browsing never calls this guard. Only booking and listing entry points do.
Future<bool> requireAccountSetup(
  BuildContext context, {
  required AppUser appUser,
  required String action,
  UserRole? role,
  FirestoreService? firestore,
  AccountSetupLoader? loadStatus,
  Future<void> Function()? editProfile,
  Future<void> Function()? refreshVerification,
}) async {
  final subject = role ?? appUser.role;
  if (subject != UserRole.customer && subject != UserRole.provider) return true;
  final key = '${appUser.userId}:${subject.name}';
  if (!_activeSetupChecks.add(key)) return false;
  Future<AccountSetupStatus> load() async {
    if (loadStatus != null) return loadStatus();
    final store = firestore ?? FirestoreService();
    final user = await store.getUserForAccountSetup(appUser.userId);
    if (user == null || user.role != subject) {
      throw StateError('Account unavailable');
    }
    final profile = subject == UserRole.provider
        ? await store.getProviderProfileForListing(appUser.userId)
        : null;
    return AccountSetupStatus(user: user, role: subject, profile: profile);
  }

  try {
    final status = await load();
    if (!context.mounted) return false;
    if (status.ready) return true;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AccountSetupDialog(
            initial: status,
            action: action,
            loadStatus: load,
            editProfile: editProfile,
            refreshVerification: refreshVerification,
          ),
        ) ??
        false;
  } catch (_) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => WorkflowDialog(
          title: const Text('Could not check account setup'),
          content: const Text(
            'Check your connection and try again. You can keep browsing, but booking and listing require a completed profile and approved identity verification.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep browsing'),
            ),
          ],
        ),
      );
    }
    return false;
  } finally {
    _activeSetupChecks.remove(key);
  }
}

class AccountSetupDialog extends StatefulWidget {
  const AccountSetupDialog({
    super.key,
    required this.initial,
    required this.action,
    required this.loadStatus,
    this.editProfile,
    this.refreshVerification,
  });
  final AccountSetupStatus initial;
  final String action;
  final AccountSetupLoader loadStatus;
  final Future<void> Function()? editProfile, refreshVerification;
  @override
  State<AccountSetupDialog> createState() => _AccountSetupDialogState();
}

class _AccountSetupDialogState extends State<AccountSetupDialog> {
  late AccountSetupStatus _status = widget.initial;
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      final latest = await widget.loadStatus();
      if (mounted) setState(() => _status = latest);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not refresh your account. Check your connection and retry. You can still keep browsing.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    if (widget.editProfile != null) return widget.editProfile!();
    if (_status.role == UserRole.provider) {
      await FirestoreService().ensureServiceProviderProfile(
        _status.user.userId,
      );
      if (!mounted) return;
      await ProviderOverviewSettingsScreen.open(
        context,
        appUser: _status.user,
        profile:
            _status.profile ??
            ServiceProviderProfile.fromFirestore(_status.user.userId, {
              'userId': _status.user.userId,
            }),
        requireAccountDetails: true,
      );
    } else {
      await CustomerSettingsScreen.open(
        context,
        appUser: _status.user,
        requireAccountDetails: true,
      );
    }
  }

  Future<void> _refresh() async {
    if (widget.refreshVerification != null) {
      return widget.refreshVerification!();
    }
    if (_status.verification.hasStarted &&
        !_status.verification.isVerifiedOnPlatform) {
      await IdentityVerificationService().refreshDiditStatusForAdmin(
        userId: _status.user.userId,
        subject: _status.role == UserRole.provider
            ? VerificationSubject.provider
            : VerificationSubject.customer,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _status.verification;
    final missing = _status.missing;
    final String verificationMessage;
    if (v.isVerifiedOnPlatform) {
      verificationMessage = 'Identity verification approved.';
    } else if (v.isAwaitingAdminApproval) {
      verificationMessage =
          'ID check complete. Awaiting System Administrator approval.';
    } else if (v.isDeclined) {
      verificationMessage =
          'Verification was rejected. Retry with your own valid government ID.';
    } else if (v.isInReview && !v.isIncomplete) {
      verificationMessage =
          'Your identity check is under review. Refresh its status after the review finishes.';
    } else {
      verificationMessage =
          'Complete the government ID and face check on ID Analyzer before you can ${widget.action}.';
    }
    return WorkflowDialog(
      scrollable: true,
      title: const Text('Complete your profile and verification'),
      content: SizedBox(
        width: 520,
        child: WorkflowFields(
          children: [
            Text(
              'Complete these requirements to ${widget.action}. You can keep browsing the system.',
            ),
            Text('Profile details', style: WorkflowStyles.sectionTitle),
            Text(
              missing.isEmpty
                  ? 'Required profile details are complete.'
                  : 'Still needed: ${missing.join(', ')}.',
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_edit),
              icon: const Icon(Icons.person_outline),
              label: Text(
                missing.isEmpty ? 'Edit profile' : 'Complete profile',
              ),
            ),
            Text(
              'Identity verification (KYC)',
              style: WorkflowStyles.sectionTitle,
            ),
            Text(verificationMessage),
            if (missing.isEmpty &&
                !v.isVerifiedOnPlatform &&
                !v.isAwaitingAdminApproval &&
                (!v.isInReview || v.isIncomplete))
              ProviderVerifyIdentityButton(
                subject: _status.role == UserRole.provider
                    ? VerificationSubject.provider
                    : VerificationSubject.customer,
                governmentIdTypeCode: v.governmentIdTypeCode,
                governmentIdTypeLabel: v.governmentIdTypeLabel,
                inReview: v.isInReview,
                restartFromIdPicker: v.isIncomplete,
                declined: v.isDeclined,
                callbackUrl:
                    Uri.base.hasScheme && Uri.base.scheme.startsWith('http')
                    ? Uri.base.toString()
                    : null,
              ),
            if (missing.isNotEmpty && !v.isVerifiedOnPlatform)
              const Text(
                'Save your required profile details first to start verification.',
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_refresh),
              icon: const Icon(Icons.refresh),
              label: Text(_busy ? 'Checking account…' : 'Refresh status'),
            ),
            if (_error != null) Text(_error!),
            if (_status.ready)
              const Text(
                'Your account is ready. You can continue with this action.',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep browsing'),
        ),
        if (_status.ready)
          FilledButton(
            onPressed: _busy ? null : () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
      ],
    );
  }
}
