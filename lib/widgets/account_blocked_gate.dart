import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/account_status.dart';
import '../models/app_user.dart';
import 'account_appeal_dialog.dart';
import 'loading_indicator.dart';

/// Shown when a signed-in customer or provider has a blocked [AccountStatus].
class AccountBlockedGate extends StatefulWidget {
  const AccountBlockedGate({
    super.key,
    required this.appUser,
    required this.onSignOut,
  });

  final AppUser appUser;
  final Future<void> Function() onSignOut;

  @override
  State<AccountBlockedGate> createState() => _AccountBlockedGateState();
}

class _AccountBlockedGateState extends State<AccountBlockedGate> {
  bool _signingOut = false;
  bool _appealShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showAppealOnce());
  }

  void _showAppealOnce() {
    if (!mounted || _appealShown) return;
    _appealShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAccountAppealDialog(
        context,
        status: widget.appUser.accountStatus,
        userEmail: widget.appUser.email,
        userName: widget.appUser.fullName,
      );
    });
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = widget.appUser.accountStatus;

    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.no_accounts_outlined, size: 56, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  status.blockedTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You are signed in as ${widget.appUser.email}, but this account is not allowed to use NeighborHelp right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                if (_signingOut)
                  const LoadingIndicator(message: 'Signing out…')
                else ...[
                  FilledButton.icon(
                    onPressed: _showAppealOnce,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('How to appeal'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
