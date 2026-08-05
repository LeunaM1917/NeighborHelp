import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/guest_marketing_root.dart';
import '../../theme/mobile_layout.dart';
import '../auth/mobile_auth_gate.dart';
import '../../models/account_status.dart';
import '../../models/app_user.dart';
import '../../models/provider.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/account_blocked_gate.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/stream_snapshot.dart';
import '../admin/admin_shell.dart';
import '../customer/customer_shell.dart';
import '../provider/provider_shell.dart';
import '../verification_agency/verification_agency_shell.dart';

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingIndicator(message: 'Checking session…', showBrand: true),
          );
        }

        final firebaseUser = authSnap.data;
        if (firebaseUser != null) {
          return _SignedInUserGate(
            key: ValueKey(firebaseUser.uid),
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            auth: auth,
          );
        }

        return StreamBuilder<bool>(
          stream: auth.localAdminStateChanges(),
          builder: (context, localAdminSnap) {
            if (localAdminSnap.data == true) {
              return AdminShell(appUser: _localAdminUser(), auth: auth);
            }
            if (MobileLayout.isNativePlatform) {
              return const MobileAuthGate();
            }
            return const GuestMarketingRoot();
          },
        );
      },
    );
  }
}

AppUser _localAdminUser() {
  final now = Timestamp.now();
  return AppUser(
    userId: 'local-admin',
    fullName: 'System Administrator',
    email: 'admin@neighborhelp.local',
    role: UserRole.administrator,
    accountStatus: AccountStatus.active,
    createdAt: now,
    updatedAt: now,
    lastActive: now,
  );
}

/// Tries to create a missing `users/{uid}` doc (common when only `serviceProviders` exists).
class _ProfileRecoveryGate extends StatefulWidget {
  const _ProfileRecoveryGate({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.auth,
    required this.onSignOut,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final AuthService auth;
  final VoidCallback onSignOut;

  @override
  State<_ProfileRecoveryGate> createState() => _ProfileRecoveryGateState();
}

class _ProfileRecoveryGateState extends State<_ProfileRecoveryGate> {
  bool _busy = true;
  bool _emailConflict = false;

  @override
  void initState() {
    super.initState();
    _recover();
  }

  Future<void> _recover() async {
    final ok = await widget.auth.repairUserProfileIfMissing(
      uid: widget.uid,
      email: widget.email,
      displayName: widget.displayName,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _emailConflict = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Setting up your profile…', showBrand: true),
      );
    }
    if (!_emailConflict) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading profile…', showBrand: true),
      );
    }
    return _MissingProfileScreen(
      uid: widget.uid,
      email: widget.email,
      onSignOut: widget.onSignOut,
      onRetry: () {
        setState(() {
          _busy = true;
          _emailConflict = false;
        });
        _recover();
      },
    );
  }
}

class _MissingProfileScreen extends StatelessWidget {
  const _MissingProfileScreen({
    required this.uid,
    required this.email,
    required this.onSignOut,
    this.onRetry,
  });

  final String uid;
  final String? email;
  final VoidCallback onSignOut;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We could not load your account profile.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'NeighborHelp needs a document at users/$uid (same id as Firebase Authentication). '
                  'A serviceProviders profile alone is not enough.\n\n'
                  'In Firestore, open users → add a document whose Document ID is exactly:\n$uid\n\n'
                  'Set role to "Provider" (or "Customer") and include at least fullName, email, and accountStatus: "Active".',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (email != null && email!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Signed in as: $email',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 20),
                if (onRetry != null) ...[
                  FilledButton(onPressed: onRetry, child: const Text('Try again')),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loads [AppUser] once, then keeps the shell mounted across Firestore profile updates.
class _SignedInUserGate extends StatefulWidget {
  const _SignedInUserGate({
    super.key,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.auth,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final AuthService auth;

  @override
  State<_SignedInUserGate> createState() => _SignedInUserGateState();
}

class _SignedInUserGateState extends State<_SignedInUserGate> {
  bool _userHydrated = false;
  late final Future<bool> _repairFuture;

  @override
  void initState() {
    super.initState();
    _repairFuture = FirestoreService().removeMistakenProviderProfileIfCustomer(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return FutureBuilder<bool>(
      future: _repairFuture,
      builder: (context, repairSnap) {
        if (repairSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: LoadingIndicator(message: 'Loading profile…', showBrand: true),
          );
        }
        return StreamBuilder<AppUser?>(
          stream: firestore.userStream(widget.uid),
          builder: (context, userSnap) {
        if (!_userHydrated) {
          if (isStreamWaiting(userSnap)) {
            return const Scaffold(
              body: LoadingIndicator(message: 'Loading profile…', showBrand: true),
            );
          }
          _userHydrated = true;
        }

        final appUser = userSnap.data;
        if (appUser == null) {
          return _ProfileRecoveryGate(
            uid: widget.uid,
            email: widget.email,
            displayName: widget.displayName,
            auth: widget.auth,
            onSignOut: () => widget.auth.signOut(),
          );
        }
        if (appUser.role != UserRole.administrator &&
            appUser.role != UserRole.verificationAgency &&
            appUser.accountStatus.isBlocked) {
          return AccountBlockedGate(
            appUser: appUser,
            onSignOut: widget.auth.signOut,
          );
        }
        if (appUser.role == UserRole.administrator) {
          return AdminShell(appUser: appUser, auth: widget.auth);
        }
        if (appUser.role == UserRole.verificationAgency) {
          return VerificationAgencyShell(appUser: appUser, auth: widget.auth);
        }
        if (appUser.role == UserRole.provider) {
          return _SignedInApp(appUser: appUser, role: UserRole.provider, auth: widget.auth);
        }
        if (appUser.role == UserRole.customer) {
          return _SignedInCustomerShell(
            appUser: appUser,
            auth: widget.auth,
          );
        }
        return _CustomerSignedInGate(
          appUser: appUser,
          auth: widget.auth,
        );
          },
        );
      },
    );
  }
}

/// Customer accounts use the customer shell; cleans up mistaken provider docs from Didit.
class _SignedInCustomerShell extends StatefulWidget {
  const _SignedInCustomerShell({
    required this.appUser,
    required this.auth,
  });

  final AppUser appUser;
  final AuthService auth;

  @override
  State<_SignedInCustomerShell> createState() => _SignedInCustomerShellState();
}

class _SignedInCustomerShellState extends State<_SignedInCustomerShell> {
  @override
  Widget build(BuildContext context) {
    return _SignedInApp(
      appUser: widget.appUser,
      role: UserRole.customer,
      auth: widget.auth,
    );
  }
}

/// Legacy accounts without an explicit role: infer from provider profile presence.
class _CustomerSignedInGate extends StatefulWidget {
  const _CustomerSignedInGate({
    required this.appUser,
    required this.auth,
  });

  final AppUser appUser;
  final AuthService auth;

  @override
  State<_CustomerSignedInGate> createState() => _CustomerSignedInGateState();
}

class _CustomerSignedInGateState extends State<_CustomerSignedInGate> {
  bool _roleResolved = false;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return StreamBuilder<ServiceProviderProfile?>(
      stream: firestore.providerProfileForUser(widget.appUser.userId),
      builder: (context, providerSnap) {
        if (!_roleResolved) {
          if (isStreamWaiting(providerSnap)) {
            return const Scaffold(
              body: LoadingIndicator(message: 'Loading profile…', showBrand: true),
            );
          }
          _roleResolved = true;
        }

        final role = UserRole.resolve(
          storedRole: widget.appUser.role,
          hasProviderProfile: providerSnap.data != null,
        );
        return _SignedInApp(appUser: widget.appUser, role: role, auth: widget.auth);
      },
    );
  }
}

class _SignedInApp extends StatelessWidget {
  const _SignedInApp({required this.appUser, required this.role, required this.auth});

  final AppUser appUser;
  final UserRole role;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case UserRole.provider:
        return ProviderShell(appUser: appUser, auth: auth);
      case UserRole.customer:
        return CustomerShell(appUser: appUser, auth: auth);
      case UserRole.administrator:
        return AdminShell(appUser: appUser, auth: auth);
      case UserRole.verificationAgency:
        return VerificationAgencyShell(appUser: appUser, auth: auth);
    }
  }
}
