import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_role.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_details_screen.dart';
import '../../theme/mobile_layout.dart';
import '../figma_colors.dart';
import '../figma_layout.dart';
import '../figma_marketing_assets.dart';
import '../../widgets/app_scrollable_page.dart';
import '../widgets/figma_brand_row.dart';

/// Matches `figma_design/src/app/pages/SignUp.tsx` (standalone, no marketing shell).
class FigmaSignUpLandingPage extends StatelessWidget {
  const FigmaSignUpLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final nativeMobile = MobileLayout.isNativeApp(context);

    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, nativeMobile ? 28 : 24, 16, nativeMobile ? 8 : 24),
            child: FigmaWideContainer(
              child: nativeMobile
                  ? _MobileSignUpHeader(onBack: () => Navigator.of(context).pop())
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: FigmaBrandRow(
                        logoHeight: 48,
                        titleFontSize: 20,
                        logoAssetPath: FigmaMarketingAssets.navLogo,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
            ),
          ),
          Expanded(
            child: FigmaWideContainer(
              child: FigmaNarrowContent(
                maxWidth: 760,
                child: AppScrollablePage(
                  padding: EdgeInsets.symmetric(
                    vertical: nativeMobile ? 20 : 48,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                        Text(
                          nativeMobile ? 'Welcome' : 'Welcome to NeighborHelp',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: nativeMobile ? 26 : 48,
                            fontWeight: FontWeight.w700,
                            color: FigmaColors.gray900,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: nativeMobile ? 10 : 16),
                        Text(
                          'Which describes you best?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: nativeMobile ? 15 : 20,
                            color: FigmaColors.gray600,
                          ),
                        ),
                        SizedBox(height: nativeMobile ? 24 : 48),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Expanded(child: _RoleCard(customer: true)),
                              SizedBox(width: 24),
                              Expanded(child: _RoleCard(customer: false)),
                            ],
                          )
                        else
                          Align(
                            alignment: Alignment.center,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: nativeMobile ? 300 : 420,
                              ),
                              child: Column(
                                children: [
                                  _RoleCard(customer: true, compact: nativeMobile),
                                  SizedBox(height: nativeMobile ? 14 : 24),
                                  _RoleCard(customer: false, compact: nativeMobile),
                                ],
                              ),
                            ),
                          ),
                        SizedBox(height: nativeMobile ? 28 : 48),
                        Text.rich(
                          TextSpan(
                            style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              WidgetSpan(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                                      );
                                    },
                                    child: Text(
                                      'Log in',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: FigmaColors.navy,
                                        decoration: TextDecoration.underline,
                                        decorationColor: FigmaColors.navy,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileSignUpHeader extends StatelessWidget {
  const _MobileSignUpHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: FigmaColors.white,
              foregroundColor: FigmaColors.gray800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.4,
            ),
            children: const [
              TextSpan(text: 'Neighbor', style: TextStyle(color: FigmaColors.navy)),
              TextSpan(text: 'Help', style: TextStyle(color: FigmaColors.green)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Center(
          child: Image.asset(
            FigmaMarketingAssets.navLogo,
            height: 132,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.customer, this.compact = false});

  final bool customer;
  final bool compact;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hire = widget.customer;
    final borderHover = hire ? FigmaColors.navy : FigmaColors.green;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(widget.compact ? 14 : 16),
          border: Border.all(color: _hover ? borderHover : FigmaColors.gray200, width: widget.compact ? 1.5 : 2),
          boxShadow: _hover ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              final role = hire ? UserRole.customer : UserRole.provider;
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => RegisterDetailsScreen(selectedRole: role)),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? 14 : 22),
              child: Column(
                children: [
                  AnimatedScale(
                    scale: _hover ? 1.05 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: widget.compact ? 20 : 32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.compact ? 12 : 14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: hire
                              ? [FigmaColors.tintGreen, FigmaColors.tintGreen2]
                              : [FigmaColors.tintGreen, FigmaColors.tintGreen3],
                        ),
                      ),
                      child: Icon(
                        hire ? Icons.business_center_outlined : Icons.home_repair_service_outlined,
                        size: widget.compact ? 40 : 56,
                        color: hire ? FigmaColors.navy : FigmaColors.green,
                      ),
                    ),
                  ),
                  SizedBox(height: widget.compact ? 12 : 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hire ? 'Customer' : 'Service Provider',
                        style: GoogleFonts.inter(
                          fontSize: widget.compact ? 17 : 20,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.gray900,
                        ),
                      ),
                      SizedBox(width: widget.compact ? 6 : 8),
                      Icon(Icons.arrow_forward_rounded, size: widget.compact ? 20 : 22, color: FigmaColors.gray900),
                    ],
                  ),
                  SizedBox(height: widget.compact ? 6 : 8),
                  Text(
                    hire ? 'Browse services and book providers' : 'List services and get booked',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: widget.compact ? 13 : 14,
                      color: FigmaColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
