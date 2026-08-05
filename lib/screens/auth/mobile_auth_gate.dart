import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../figma_ui/figma_marketing_assets.dart';
import '../../figma_ui/pages/figma_signup_landing_page.dart';
import 'login_screen.dart';

/// Signed-out entry for Android/iOS — login and sign up only (no marketing landing).
class MobileAuthGate extends StatelessWidget {
  const MobileAuthGate({super.key});

  void _openLogin(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _openSignUp(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const FigmaSignUpLandingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: FigmaHeroGradientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 52),
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                      children: const [
                        TextSpan(text: 'Neighbor', style: TextStyle(color: FigmaColors.navy)),
                        TextSpan(text: 'Help', style: TextStyle(color: FigmaColors.green)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Image.asset(
                      FigmaMarketingAssets.navLogo,
                      height: 156,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Local help,\nright next door',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.gray900,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Book trusted neighbors for home services, errands, tutoring, and more.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => _openLogin(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: FigmaColors.navy,
                      foregroundColor: FigmaColors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Log in', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _openSignUp(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FigmaColors.navy,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: FigmaColors.navy),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Create account', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
