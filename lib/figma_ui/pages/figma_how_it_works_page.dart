import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_colors.dart';
import '../figma_layout.dart';

class FigmaHowItWorksPage extends StatelessWidget {
  const FigmaHowItWorksPage({super.key, required this.onSignUpCta});

  final VoidCallback onSignUpCta;

  static const _steps = <_HowStep>[
    _HowStep(Icons.person_add_alt_1_outlined, '1. Create Your Account', 'Sign up for free and complete your profile in minutes. Tell us about your needs and preferences.'),
    _HowStep(Icons.search, '2. Browse or Search Services', 'Explore categories or search for the exact service you need in your area.'),
    _HowStep(Icons.person_search_outlined, '3. Choose a Service Provider', 'Compare provider profiles, ratings, reviews, and pricing to find the best fit.'),
    _HowStep(Icons.event_available_outlined, '4. Send a Booking Request', 'Pick a date, add details, and send a booking request. The provider confirms before the job starts.'),
    _HowStep(Icons.star_outline, '5. Leave a Review', 'After the service is complete, share your experience to help the community make informed decisions.'),
  ];

  static const _features = <_HowFeature>[
    _HowFeature(Icons.shield_outlined, 'Verified Providers', 'All service providers go through our verification process including background checks and credential verification.'),
    _HowFeature(Icons.credit_card, 'Secure Payments', 'Your payment is held securely and only released when you confirm the job is done to your satisfaction.'),
    _HowFeature(Icons.star_outline, 'Trusted Reviews', 'Read authentic reviews from real customers in your community who have used the services.'),
    _HowFeature(Icons.notifications_none_rounded, 'Real-time Updates', 'Stay informed with instant notifications about booking requests, messages, and service updates.'),
  ];

  static const _faqs = <_Faq>[
    _Faq('Is NeighborHelp free to use?', 'Yes! Creating an account and browsing services is completely free. We only charge a small service fee when you successfully book a provider through our platform.'),
    _Faq('How are providers vetted?', 'All providers must pass our verification process, which includes identity verification, background checks, and credential verification for licensed services.'),
    _Faq('What if I\'m not satisfied with the service?', 'We have a satisfaction guarantee. If you\'re not satisfied, contact our support team within 48 hours, and we\'ll work to resolve the issue or provide a refund.'),
    _Faq('How does payment work?', 'Payment is made securely through our platform. Your funds are held in escrow and only released to the provider once you confirm the work is complete.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigmaHeroGradientBackground(
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Text(
                    'How NeighborHelp Works',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Getting the help you need is simple. Follow these easy steps to connect with trusted service providers in your community.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 20, color: FigmaColors.gray600, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.white,
          child: FigmaNarrowContent(
            maxWidth: 1024,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              child: Column(
                  children: _steps
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 48),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(color: FigmaColors.navy, shape: BoxShape.circle),
                                child: Icon(s.icon, size: 32, color: FigmaColors.white),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.title, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                                    const SizedBox(height: 8),
                                    Text(s.body, style: GoogleFonts.inter(fontSize: 18, color: FigmaColors.gray600, height: 1.45)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
              ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.gray50,
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Text('Why Choose NeighborHelp?', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text('Trust and safety are our top priorities', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 1024 ? 4 : (c.maxWidth >= 768 ? 2 : 1);
                      return FigmaWrapCardGrid(
                        maxWidth: c.maxWidth,
                        columns: cols,
                        children: [
                          for (final f in _features)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: FigmaColors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(color: FigmaColors.tintBlue, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(f.icon, size: 26, color: FigmaColors.navy),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(f.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                                  const SizedBox(height: 8),
                                  Text(f.body, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.4)),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.white,
          child: FigmaNarrowContent(
            maxWidth: 896,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              child: Column(
                children: [
                  Text('Frequently Asked Questions', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text('Got questions? We\'ve got answers.', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  for (final f in _faqs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: FigmaColors.gray50, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.q, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                            const SizedBox(height: 8),
                            Text(f.a, style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.45)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        FigmaNavyCtaGradient(
          child: FigmaNarrowContent(
            maxWidth: 896,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              child: Column(
                children: [
                  Text('Ready to Get Started?', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.white)),
                  const SizedBox(height: 16),
                  Text(
                    'Join thousands of satisfied customers who found the perfect service provider on NeighborHelp.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 18, color: Color(0xFFE5E7EB), height: 1.45),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: onSignUpCta,
                    style: FilledButton.styleFrom(
                      backgroundColor: FigmaColors.green,
                      foregroundColor: FigmaColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text('Browse Services', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HowStep {
  const _HowStep(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _HowFeature {
  const _HowFeature(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _Faq {
  const _Faq(this.q, this.a);
  final String q;
  final String a;
}
