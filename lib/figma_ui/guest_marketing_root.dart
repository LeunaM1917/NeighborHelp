import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import 'marketing_layout.dart';
import 'marketing_route.dart';
import 'pages/figma_about_us_page.dart';
import 'pages/figma_browse_services_page.dart';
import 'pages/figma_for_providers_page.dart';
import 'pages/figma_how_it_works_page.dart';
import 'pages/figma_home_page.dart';
import 'pages/figma_signup_landing_page.dart';

/// Public marketing site from `figma_design` for signed-out users.
class GuestMarketingRoot extends StatefulWidget {
  const GuestMarketingRoot({super.key});

  @override
  State<GuestMarketingRoot> createState() => _GuestMarketingRootState();
}

class _GuestMarketingRootState extends State<GuestMarketingRoot> {
  MarketingRoute _route = MarketingRoute.home;

  void _openSignUp() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const FigmaSignUpLandingPage()),
    );
  }

  void _openLogin() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _goBrowse() {
    setState(() => _route = MarketingRoute.browseServices);
  }

  Widget _page() {
    switch (_route) {
      case MarketingRoute.home:
        return const FigmaHomePage();
      case MarketingRoute.browseServices:
        return const FigmaBrowseServicesPage();
      case MarketingRoute.howItWorks:
        return FigmaHowItWorksPage(onSignUpCta: _openSignUp);
      case MarketingRoute.forProviders:
        return FigmaForProvidersPage(onSignUpCta: _openSignUp);
      case MarketingRoute.aboutUs:
        return FigmaAboutUsPage(onBrowseServices: _goBrowse, onSignUpCta: _openSignUp);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold gives the marketing Column a bounded height on web; without it,
    // Expanded + SingleChildScrollView hits unbounded constraints and the UI fails.
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: MarketingLayout(
        currentRoute: _route,
        onNavigate: (r) => setState(() => _route = r),
        onLogin: _openLogin,
        onSignUp: _openSignUp,
        child: _page(),
      ),
    );
  }
}
