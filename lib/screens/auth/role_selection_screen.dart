import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_role.dart';
import '../../theme/provider_tokens.dart';
import '../../widgets/marketplace_ui.dart';
import 'register_details_screen.dart';

/// Welcome step — which role describes you best?
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF2FAF3),
              Colors.white,
              Color(0xFFFFFBF5),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final pad = c.maxWidth > 600 ? 48.0 : 24.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                    child: Row(
                      children: [
                        if (Navigator.of(context).canPop())
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                            color: ProviderTokens.ink,
                          ),
                        const Expanded(child: Align(alignment: Alignment.centerLeft, child: BrandLockup(compact: true))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Welcome to NeighborHelp',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: ProviderTokens.ink,
                                letterSpacing: -0.8,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Which describes you best?',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                color: ProviderTokens.inkSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 400),
                                child: LayoutBuilder(
                                  builder: (context, inner) {
                                    final row = inner.maxWidth >= 360;
                                    final clientCard = _RoleCard(
                                      gradientIcon: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFFDFF6E3), Color(0xFFFFF8DC)],
                                      ),
                                      icon: Icons.work_outline_rounded,
                                      title: 'Customer',
                                      subtitle: 'Browse services and book',
                                      onTap: () => _go(context, UserRole.customer),
                                    );
                                    final providerCard = _RoleCard(
                                      gradientIcon: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFFDFF6E3), Color(0xFFFFF8DC)],
                                      ),
                                      icon: Icons.home_repair_service_rounded,
                                      title: 'Service Provider',
                                      subtitle: 'List services and get booked',
                                      onTap: () => _go(context, UserRole.provider),
                                    );
                                    if (row) {
                                      return IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(child: clientCard),
                                            const SizedBox(width: 12),
                                            Expanded(child: providerCard),
                                          ],
                                        ),
                                      );
                                    }
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        clientCard,
                                        const SizedBox(height: 12),
                                        providerCard,
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 20),
                    child: Center(
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(fontSize: 15, color: ProviderTokens.inkSecondary),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Log in',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: ProviderTokens.green,
                                    decoration: TextDecoration.underline,
                                    decorationColor: ProviderTokens.green,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterDetailsScreen(selectedRole: role),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.gradientIcon,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Gradient gradientIcon;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ProviderTokens.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: gradientIcon,
                  ),
                  child: Icon(icon, size: 28, color: ProviderTokens.ink),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ProviderTokens.ink,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: ProviderTokens.ink),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: ProviderTokens.inkSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
