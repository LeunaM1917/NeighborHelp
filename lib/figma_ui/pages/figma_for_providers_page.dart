import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_colors.dart';
import '../figma_layout.dart';

class FigmaForProvidersPage extends StatelessWidget {
  const FigmaForProvidersPage({super.key, required this.onSignUpCta});

  final VoidCallback onSignUpCta;

  static const _stats = <_Stat>[
    _Stat('20,000+', 'Active Providers'),
    _Stat('4.8★', 'Average Rating'),
    _Stat('50,000+', 'Jobs Completed'),
    _Stat('₱2M+', 'Earned by Providers'),
  ];

  static const _benefits = <_Ben>[
    _Ben(Icons.groups_outlined, 'Reach More Customers', 'Connect with thousands of potential customers actively looking for services in your area.'),
    _Ben(Icons.attach_money, 'Grow Your Income', 'Set your own rates and increase your earnings by taking on more jobs that fit your schedule.'),
    _Ben(Icons.calendar_today_outlined, 'Flexible Schedule', 'Work on your own terms. Choose which jobs to accept and when you want to work.'),
    _Ben(Icons.shield_outlined, 'Secure Payments', 'Get paid securely and on time through our trusted payment platform. No more chasing payments.'),
    _Ben(Icons.emoji_events_outlined, 'Build Your Reputation', 'Earn reviews and build a stellar reputation that helps you win more jobs in the future.'),
    _Ben(Icons.smartphone, 'Easy to Use', 'Manage your business on the go with our mobile-friendly platform. Accept jobs, chat with clients, and more.'),
  ];

  static const _steps = <_ProvStep>[
    _ProvStep('1', 'Create Your Profile', 'Sign up and create a professional profile showcasing your skills, experience, and services.'),
    _ProvStep('2', 'Get Verified', 'Complete our simple verification process to build trust with potential customers.'),
    _ProvStep('3', 'List Your Services', 'Add the services you offer so customers can find you when they browse and search.'),
    _ProvStep('4', 'Receive Bookings & Get Paid', 'Accept booking requests from customers, complete the job, and receive secure payment.'),
  ];

  static const _quotes = <_Quote>[
    _Quote('John Martinez', 'Home Repair Specialist', 'NeighborHelp has transformed my business. I\'ve doubled my income and built a steady client base in just 6 months.', 5),
    _Quote('Sarah Chen', 'House Cleaning Professional', 'The platform is so easy to use, and I love having the flexibility to choose my own schedule. Highly recommend!', 5),
    _Quote('Michael Thompson', 'Personal Trainer', 'Great way to find new clients! The secure payment system gives me peace of mind, and customers are always responsive.', 5),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigmaHeroGradientBackground(
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: FigmaNarrowContent(
                maxWidth: 768,
                child: Column(
                  children: [
                    Text(
                      'Grow Your Business with NeighborHelp',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: FigmaColors.gray900, height: 1.1),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Join thousands of service providers earning more by connecting with customers in their community.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 20, color: FigmaColors.gray600, height: 1.45),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: onSignUpCta,
                      style: FilledButton.styleFrom(
                        backgroundColor: FigmaColors.navy,
                        foregroundColor: FigmaColors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text('Become a Provider', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.navy,
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 768 ? 4 : 2;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    mainAxisSpacing: 32,
                    crossAxisSpacing: 32,
                    childAspectRatio: 1.8,
                    children: _stats
                        .map(
                          (s) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(s.n, style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, color: FigmaColors.white)),
                              const SizedBox(height: 8),
                              Text(s.label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray300)),
                            ],
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.white,
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Text('Why Providers Love NeighborHelp', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text('Everything you need to succeed', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 1024 ? 3 : (c.maxWidth >= 768 ? 2 : 1);
                      return FigmaWrapCardGrid(
                        maxWidth: c.maxWidth,
                        columns: cols,
                        children: [
                          for (final b in _benefits)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: FigmaColors.gray50, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(color: FigmaColors.navy, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(b.icon, size: 26, color: FigmaColors.white),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(b.title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                                  const SizedBox(height: 8),
                                  Text(b.body, style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.4)),
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
          color: FigmaColors.gray50,
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Text('How to Get Started', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text('Start earning in 4 simple steps', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 1024 ? 4 : (c.maxWidth >= 768 ? 2 : 1);
                      return FigmaWrapCardGrid(
                        maxWidth: c.maxWidth,
                        columns: cols,
                        children: [
                          for (final s in _steps)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: FigmaColors.white, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(color: FigmaColors.green, shape: BoxShape.circle),
                                    child: Text(s.n, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.white)),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(s.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                                  const SizedBox(height: 8),
                                  Text(s.body, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.4)),
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
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Text('Success Stories', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text('Hear from providers who are thriving on NeighborHelp', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 768 ? 3 : 1;
                      return FigmaWrapCardGrid(
                        maxWidth: c.maxWidth,
                        columns: cols,
                        children: [
                          for (final t in _quotes)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: FigmaColors.gray50, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: List.generate(t.stars, (_) => const Text('★', style: TextStyle(color: Color(0xFFEAB308), fontSize: 18)))),
                                  const SizedBox(height: 12),
                                  Text('"${t.quote}"', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray700, fontStyle: FontStyle.italic, height: 1.4)),
                                  const SizedBox(height: 12),
                                  Text(t.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                                  Text(t.role, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600)),
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
        FigmaNavyCtaGradient(
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: FigmaNarrowContent(
                maxWidth: 896,
                child: Column(
                  children: [
                    Text('Ready to Grow Your Business?', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.white)),
                    const SizedBox(height: 16),
                    Text(
                      'Join NeighborHelp today and start connecting with customers who need your services.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 18, color: Color(0xFFE5E7EB), height: 1.45),
                    ),
                    const SizedBox(height: 32),
                    if (wide)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: onSignUpCta,
                            style: FilledButton.styleFrom(
                              backgroundColor: FigmaColors.green,
                              foregroundColor: FigmaColors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: Text('Sign Up Now', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 16),
                          FilledButton(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              backgroundColor: FigmaColors.white,
                              foregroundColor: FigmaColors.navy,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: Text('Learn More', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: onSignUpCta,
                              style: FilledButton.styleFrom(
                                backgroundColor: FigmaColors.green,
                                foregroundColor: FigmaColors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: Text('Sign Up Now', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {},
                              style: FilledButton.styleFrom(
                                backgroundColor: FigmaColors.white,
                                foregroundColor: FigmaColors.navy,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: Text('Learn More', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat {
  const _Stat(this.n, this.label);
  final String n;
  final String label;
}

class _Ben {
  const _Ben(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _ProvStep {
  const _ProvStep(this.n, this.title, this.body);
  final String n;
  final String title;
  final String body;
}

class _Quote {
  const _Quote(this.name, this.role, this.quote, this.stars);
  final String name;
  final String role;
  final String quote;
  final int stars;
}
