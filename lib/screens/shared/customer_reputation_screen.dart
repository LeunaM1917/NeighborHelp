import 'package:flutter/material.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../widgets/app_scroll_chrome.dart';
import '../../widgets/member_profile/member_profile_kit.dart';
import 'public_customer_profile_body.dart';

/// Provider-facing public customer profile.
class CustomerReputationScreen extends StatelessWidget {
  const CustomerReputationScreen({
    super.key,
    required this.appUser,
    required this.customer,
    this.booking,
  });

  final AppUser appUser;
  final AppUser customer;
  final Booking? booking;

  static void open(
    BuildContext context, {
    required AppUser appUser,
    required AppUser customer,
    Booking? booking,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerReputationScreen(
          appUser: appUser,
          customer: customer,
          booking: booking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: AppScrollChrome(
          child: SingleChildScrollView(
            child: FigmaWideContainer(
              child: MemberProfilePage(
                title: 'Customer profile',
                subtitle: 'Feedback from providers on NeighborHelp',
                onBack: () => Navigator.pop(context),
                child: PublicCustomerProfileBody(
                  viewer: appUser,
                  customer: customer,
                  bookingForMessage: booking,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
