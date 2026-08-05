import 'package:flutter/material.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../models/app_user.dart';
import '../../widgets/app_scroll_chrome.dart';
import '../../widgets/member_profile/member_profile_kit.dart';
import '../shared/public_provider_profile_body.dart';

/// Standalone provider profile for the customer browse flow.
class CustomerProviderProfileScreen extends StatelessWidget {
  const CustomerProviderProfileScreen({
    super.key,
    required this.appUser,
    required this.providerId,
    this.providerUser,
  });

  final AppUser appUser;
  final String providerId;
  final AppUser? providerUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: AppScrollChrome(
          child: SingleChildScrollView(
            child: FigmaWideContainer(
              child: MemberProfilePage(
                title: 'Provider profile',
                subtitle: 'View services, reviews, and book',
                onBack: () => Navigator.pop(context),
                child: PublicProviderProfileBody(
                  viewer: appUser,
                  providerId: providerId,
                  providerUser: providerUser,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
