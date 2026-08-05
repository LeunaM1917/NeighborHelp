import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_colors.dart';
import '../figma_layout.dart';

class FigmaAboutUsPage extends StatelessWidget {
  const FigmaAboutUsPage({super.key, required this.onBrowseServices, required this.onSignUpCta});

  final VoidCallback onBrowseServices;
  final VoidCallback onSignUpCta;

  static const _values = <_Val>[
    _Val(Icons.favorite_outline, 'Community First', 'We believe in building strong, supportive communities where neighbors help neighbors thrive.'),
    _Val(Icons.shield_outlined, 'Trust & Safety', 'We prioritize the safety and security of our users through rigorous verification and protection measures.'),
    _Val(Icons.groups_outlined, 'Inclusivity', 'Everyone deserves access to quality services. We welcome providers and customers from all backgrounds.'),
    _Val(Icons.track_changes, 'Excellence', 'We strive for excellence in everything we do, from our platform features to customer support.'),
  ];

  static const _milestones = <_Ms>[
    _Ms('2026', 'Founded', 'NeighborHelp was born from the vision to connect communities with trusted local services.'),
    _Ms('2027', 'Reached 5,000 Users', 'Our platform grew rapidly as word spread about our commitment to quality and trust.'),
    _Ms('2029', 'Expanded Nationwide', 'We expanded our services to cover communities across the entire country.'),
    _Ms('2032', '50,000+ Jobs Completed', 'Celebrating major milestones with a thriving community of customers and providers.'),
  ];

  static const _team = <_TeamM>[
    _TeamM('Cristine Jane Sedollo', 'CEO & Co-Founder', 'Former tech executive with a passion for building community-driven platforms.'),
    _TeamM('Kent Ivan Manuel Gabito', 'CTO & Co-Founder', 'Software engineer with 15+ years of experience building scalable platforms.'),
    _TeamM('Kean Kyle Anilao', 'COO & Co-Founder', 'Operations leader focused on scaling reliable, trusted service across communities.'),
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
                    Text('About NeighborHelp', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                    const SizedBox(height: 16),
                    Text(
                      'Connecting communities with trusted local service providers since 2020',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 20, color: FigmaColors.gray600, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.white,
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Our Mission', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                              const SizedBox(height: 16),
                              Text(
                                'At NeighborHelp, we believe that everyone deserves easy access to reliable, high-quality services in their community. Our mission is to empower local service providers and make it simple for customers to find the help they need.',
                                style: GoogleFonts.inter(fontSize: 18, color: FigmaColors.gray600, height: 1.45),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'We\'re building more than just a platform – we\'re building trust, fostering connections, and strengthening communities one service at a time.',
                                style: GoogleFonts.inter(fontSize: 18, color: FigmaColors.gray600, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                        Expanded(child: _MissionStatsCard()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Our Mission', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                        const SizedBox(height: 16),
                        Text(
                          'At NeighborHelp, we believe that everyone deserves easy access to reliable, high-quality services in their community. Our mission is to empower local service providers and make it simple for customers to find the help they need.',
                          style: GoogleFonts.inter(fontSize: 18, color: FigmaColors.gray600, height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'We\'re building more than just a platform – we\'re building trust, fostering connections, and strengthening communities one service at a time.',
                          style: GoogleFonts.inter(fontSize: 18, color: FigmaColors.gray600, height: 1.45),
                        ),
                        const SizedBox(height: 32),
                        _MissionStatsCard(),
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
                  Text('Our Values', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text('The principles that guide everything we do', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 1024 ? 4 : (c.maxWidth >= 768 ? 2 : 1);
                      return FigmaWrapCardGrid(
                        maxWidth: c.maxWidth,
                        columns: cols,
                        children: [
                          for (final v in _values)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: FigmaColors.white, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: const BoxDecoration(color: FigmaColors.tintBlue, shape: BoxShape.circle),
                                    child: Icon(v.icon, size: 32, color: FigmaColors.navy),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(v.title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                                  const SizedBox(height: 8),
                                  Text(v.body, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.4)),
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
            maxWidth: 1024,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              child: Column(
                  children: [
                    Text('Our Journey', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                    const SizedBox(height: 12),
                    Text('Key milestones in our growth', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                    const SizedBox(height: 48),
                    for (final m in _milestones)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(color: FigmaColors.navy, shape: BoxShape.circle),
                              child: Text(m.year, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.white)),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                                    const SizedBox(height: 8),
                                    Text(m.body, style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.45)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
                  Text('Meet Our Team', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text('The people behind NeighborHelp', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 768 ? 3 : 1;
                      return FigmaWrapCardGrid(
                        maxWidth: c.maxWidth,
                        columns: cols,
                        children: [
                          for (final t in _team)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: FigmaColors.white, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [FigmaColors.navy, FigmaColors.green], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(t.name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                                  const SizedBox(height: 4),
                                  Text(t.role, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.navy)),
                                  const SizedBox(height: 12),
                                  Text(t.bio, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.4)),
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
                    Text('Join Our Growing Community', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.white)),
                    const SizedBox(height: 16),
                    Text(
                      'Whether you\'re looking for services or want to offer your skills, NeighborHelp is the place for you.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 18, color: Color(0xFFE5E7EB), height: 1.45),
                    ),
                    const SizedBox(height: 32),
                    if (wide)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: onBrowseServices,
                            style: FilledButton.styleFrom(
                              backgroundColor: FigmaColors.green,
                              foregroundColor: FigmaColors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: Text('Find Services', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 16),
                          FilledButton(
                            onPressed: onSignUpCta,
                            style: FilledButton.styleFrom(
                              backgroundColor: FigmaColors.white,
                              foregroundColor: FigmaColors.navy,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: Text('Become a Provider', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: onBrowseServices,
                              style: FilledButton.styleFrom(
                                backgroundColor: FigmaColors.green,
                                foregroundColor: FigmaColors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: Text('Find Services', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: onSignUpCta,
                              style: FilledButton.styleFrom(
                                backgroundColor: FigmaColors.white,
                                foregroundColor: FigmaColors.navy,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: Text('Become a Provider', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
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

class _MissionStatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [FigmaColors.navy, FigmaColors.navyHover], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statRow(Icons.public, '20,000+', 'Service Providers'),
          const SizedBox(height: 24),
          _statRow(Icons.groups_outlined, '100,000+', 'Active Customers'),
          const SizedBox(height: 24),
          _statRow(Icons.emoji_events_outlined, '4.8★', 'Average Rating'),
        ],
      ),
    );
  }

  static Widget _statRow(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 48, color: FigmaColors.white),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.white)),
            Text(label, style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray300)),
          ],
        ),
      ],
    );
  }
}

class _Val {
  const _Val(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _Ms {
  const _Ms(this.year, this.title, this.body);
  final String year;
  final String title;
  final String body;
}

class _TeamM {
  const _TeamM(this.name, this.role, this.bio);
  final String name;
  final String role;
  final String bio;
}
