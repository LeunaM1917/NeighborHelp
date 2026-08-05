import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../theme/role_theme.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../widgets/app_footer.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.appUser,
    this.scrollController,
    this.bottomSection,
    this.footerRoleLabel,
  });

  final AppUser appUser;
  final ScrollController? scrollController;
  final Widget? bottomSection;
  final String? footerRoleLabel;

  @override
  Widget build(BuildContext context) {
    final created = DateFormat.yMMMMd().format(appUser.createdAt.toDate());

    return ColoredBox(
      color: FigmaColors.white,
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FigmaWideContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 768;
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 280, child: _ProfileCard(appUser: appUser, memberSince: created)),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _DetailsPanel(appUser: appUser),
                                if (bottomSection != null) ...[
                                  const SizedBox(height: 24),
                                  bottomSection!,
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileCard(appUser: appUser, memberSince: created),
                          const SizedBox(height: 24),
                          _DetailsPanel(appUser: appUser),
                          if (bottomSection != null) ...[
                            const SizedBox(height: 24),
                            bottomSection!,
                          ],
                        ],
                      );
              },
            ),
          ),
        ),
            if (footerRoleLabel != null) CachedAppFooter(roleLabel: footerRoleLabel!),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.appUser, required this.memberSince});

  final AppUser appUser;
  final String memberSince;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: rc.tint,
            backgroundImage: appUser.profilePhotoUrl != null ? NetworkImage(appUser.profilePhotoUrl!) : null,
            child: appUser.profilePhotoUrl == null
                ? Text(
                    _initials(appUser.fullName),
                    style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: rc.primary),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            appUser.fullName,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 4),
          Text(
            appUser.role == UserRole.provider ? 'Service Provider' : 'Customer',
            style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: rc.tint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              appUser.accountStatus.firestoreValue,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.green),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Member since $memberSince',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.appUser});

  final AppUser appUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account details', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: FigmaColors.gray900)),
          const SizedBox(height: 20),
          _DetailRow(label: 'Email', value: appUser.email),
          if (appUser.contactNumber != null) _DetailRow(label: 'Phone', value: appUser.contactNumber!),
          if (appUser.address != null) _DetailRow(label: 'Address', value: appUser.address!),
          const SizedBox(height: 24),
          Text(
            'Profile editing will be available in a future update.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: FigmaColors.gray500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray900)),
          ),
        ],
      ),
    );
  }
}
