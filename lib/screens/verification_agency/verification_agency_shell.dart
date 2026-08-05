import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_marketing_assets.dart';
import '../../figma_ui/widgets/figma_brand_row.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/role_theme.dart';
import '../../widgets/app_scroll_chrome.dart';
import '../admin/pages/admin_verification_page.dart';
import '../admin/widgets/admin_widgets.dart';
import 'agency_certificates_page.dart';

/// Own shell for the Verification Agency role (identity + certificate authentication).
class VerificationAgencyShell extends StatefulWidget {
  const VerificationAgencyShell({
    super.key,
    required this.appUser,
    required this.auth,
  });

  final AppUser appUser;
  final AuthService auth;

  @override
  State<VerificationAgencyShell> createState() => _VerificationAgencyShellState();
}

class _VerificationAgencyShellState extends State<VerificationAgencyShell> {
  int _tab = 0;

  static const _tabs = [
    (label: 'Identity', icon: Icons.badge_outlined),
    (label: 'Certificates', icon: Icons.workspace_premium_outlined),
    (label: 'About role', icon: Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return RoleThemeScope(
      palette: RoleTheme.verificationAgency,
      child: Scaffold(
        backgroundColor: FigmaColors.gray50,
        body: Column(
          children: [
            _AgencyTopBar(
              appUser: widget.appUser,
              onSignOut: () => widget.auth.signOut(),
            ),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    _AgencySideNav(
                      tabs: _tabs,
                      selectedIndex: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                  Expanded(
                    child: AppScrollChrome(
                      showBackToTop: true,
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          AdminVerificationPage(
                            auth: widget.auth,
                            forAgency: true,
                            reviewerUserId: widget.appUser.userId,
                          ),
                          AgencyCertificatesPage(reviewerUserId: widget.appUser.userId),
                          const _AgencyAboutPage(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!wide)
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(icon: Icon(t.icon), label: t.label),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AgencyTopBar extends StatelessWidget {
  const _AgencyTopBar({required this.appUser, required this.onSignOut});

  final AppUser appUser;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final displayName = appUser.fullName.isNotEmpty ? appUser.fullName : appUser.email;

    return Material(
      color: FigmaColors.white,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: FigmaColors.gray200)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: LayoutBuilder(
          builder: (context, c) {
            final showName = c.maxWidth >= 720;
            return Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        fit: FlexFit.loose,
                        child: FigmaBrandRow(
                          logoHeight: 36,
                          titleFontSize: 16,
                          logoAssetPath: FigmaMarketingAssets.navLogo,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: FigmaColors.tintBlue,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: FigmaColors.gray200),
                        ),
                        child: Text(
                          'Verification Agency',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: FigmaColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showName)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: FigmaColors.gray900,
                            ),
                          ),
                        ),
                      ),
                    PopupMenuButton<String>(
                      offset: const Offset(0, 8),
                      tooltip: 'Account menu',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: (value) {
                        if (value != 'signout') return;
                        WidgetsBinding.instance.addPostFrameCallback((_) => onSignOut());
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'signout',
                          child: Row(
                            children: [
                              const Icon(Icons.logout_rounded, size: 20, color: FigmaColors.gray800),
                              const SizedBox(width: 10),
                              Text(
                                'Sign out',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                              ),
                            ],
                          ),
                        ),
                      ],
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: FigmaColors.navy,
                        backgroundImage: appUser.profilePhotoUrl != null
                            ? NetworkImage(appUser.profilePhotoUrl!)
                            : null,
                        child: appUser.profilePhotoUrl == null
                            ? Text(
                                _agencyInitials(displayName),
                                style: GoogleFonts.inter(
                                  color: FigmaColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _agencyInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

class _AgencySideNav extends StatelessWidget {
  const _AgencySideNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<({String label, IconData icon})> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: FigmaColors.white,
        border: Border(right: BorderSide(color: FigmaColors.gray200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: Text(
              'Agency console',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FigmaColors.gray500,
                letterSpacing: 0.4,
              ),
            ),
          ),
          for (var i = 0; i < tabs.length; i++) ...[
            Material(
              color: i == selectedIndex ? FigmaColors.tintBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                dense: true,
                leading: Icon(
                  tabs[i].icon,
                  color: i == selectedIndex ? FigmaColors.navy : FigmaColors.gray500,
                ),
                title: Text(
                  tabs[i].label,
                  style: GoogleFonts.inter(
                    fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                    color: i == selectedIndex ? FigmaColors.navy : FigmaColors.gray800,
                  ),
                ),
                onTap: () => onSelect(i),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _AgencyAboutPage extends StatelessWidget {
  const _AgencyAboutPage();

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Verification Agency role',
      subtitle: 'How identity verification fits NeighborHelp',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FigmaColors.gray200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your responsibilities',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _bullet('Review government ID and Didit facial verification results.'),
            _bullet('Approve or reject provider and customer identity requests.'),
            _bullet('Authenticate provider-submitted certificates and licenses.'),
            _bullet('Send results back to NeighborHelp (verified badge + cert status).'),
            const SizedBox(height: 20),
            Text(
              'What you do not approve',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _bullet('Service listings, pricing, and categories — reviewed by the Administrator.'),
            _bullet('Booking disputes and platform moderation — Administrator.'),
            const SizedBox(height: 20),
            Text(
              'Workflow',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _bullet('1. Provider submits ID + selfie through Didit.'),
            _bullet('2. Verification Agency reviews and approves/rejects identity.'),
            _bullet('3. For technical jobs (e.g. Electrical / Plumbing), provider submits certificates → Agency authenticates them.'),
            _bullet('4. Soft services (Cleaning, Tutoring, etc.) can be listed without certificates after identity approval.'),
            _bullet('5. Provider publishes → Administrator reviews the listing. Marketplace shows approved + active services.'),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: FigmaColors.gray700)),
          ),
        ],
      ),
    );
  }
}
