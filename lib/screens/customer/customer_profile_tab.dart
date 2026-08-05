import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../models/app_user.dart';
import '../../theme/mobile_layout.dart';
import '../shared/self_customer_profile_body.dart';

class CustomerProfileTab extends StatelessWidget {
  const CustomerProfileTab({
    super.key,
    required this.appUser,
    this.scrollController,
    this.onBrowseTap,
    this.onBookingsTap,
    this.onSignOut,
  });

  final AppUser appUser;
  final ScrollController? scrollController;
  final VoidCallback? onBrowseTap;
  final VoidCallback? onBookingsTap;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final nativeMobile = MobileLayout.isNativeApp(context);

    return SingleChildScrollView(
      controller: scrollController,
      child: FigmaWideContainer(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            nativeMobile ? 16 : 32,
            0,
            MobileLayout.pageBottomPadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelfCustomerProfileBody(
                appUser: appUser,
                onBookingsTap: onBookingsTap,
              ),
              if (nativeMobile && onSignOut != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: Text(
                      'Sign out',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FigmaColors.red600,
                      side: const BorderSide(color: FigmaColors.red600),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
