import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account_status.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../models/provider_weekly_availability.dart';
import '../models/user_role.dart';
import '../services/provider_recommendation_service.dart';

/// Prefix for UI-only sample providers used to demonstrate RS ranking.
const String kRankingDemoProviderIdPrefix = 'demo_rank_';

bool isRankingDemoProviderId(String id) => id.startsWith(kRankingDemoProviderIdPrefix);

/// Panabo City center (approx.) — sample providers are placed around this point.
const GeoPoint kRankingDemoOrigin = GeoPoint(7.3081, 125.6822);

/// UI-only demo pack: never written to Firestore; merged into live ranking for demos.
class RankingDemoPack {
  const RankingDemoPack({required this.profiles, required this.users});

  final List<ServiceProviderProfile> profiles;
  final Map<String, AppUser> users;
}

/// Six verified sample providers with deliberately different P / R / A / C so the
/// panel can see manuscript fairness (nearby vs far, new vs experienced, available vs not).
RankingDemoPack buildRankingDemoPack({DateTime? now}) {
  final at = now ?? DateTime.now();
  final ts = Timestamp.fromDate(at);

  ProviderWeeklyAvailability alwaysOn() => ProviderWeeklyAvailability(
        days: {
          for (final d in ProviderWeeklyAvailability.dayOrder)
            d: const ProviderDaySchedule(enabled: true, start: '6:00 AM', end: '10:00 PM'),
        },
      );

  ProviderWeeklyAvailability alwaysOff() => ProviderWeeklyAvailability(
        days: {
          for (final d in ProviderWeeklyAvailability.dayOrder)
            d: const ProviderDaySchedule(enabled: false, start: '8:00 AM', end: '5:00 PM'),
        },
      );

  ServiceProviderProfile profile({
    required String id,
    required String area,
    required GeoPoint location,
    required double averageRating,
    required int reviewCount,
    required int completed,
    required int accepted,
    required ProviderWeeklyAvailability schedule,
  }) {
    return ServiceProviderProfile(
      providerId: id,
      userId: id,
      bio: 'Sample provider for recommendation ranking demonstration.',
      serviceArea: area,
      location: location,
      serviceRadiusKm: 15,
      averageRating: averageRating,
      completedBookings: completed,
      acceptedBookings: accepted,
      reviewCount: reviewCount,
      isVerified: true,
      verificationStatus: 'Approved',
      createdAt: ts,
      updatedAt: ts,
      weeklyAvailability: schedule,
      approvedCertificationIds: const ['demo_cert'],
    );
  }

  AppUser user(String id, String name) {
    return AppUser(
      userId: id,
      fullName: name,
      email: '$id@demo.neighborhelp.local',
      role: UserRole.provider,
      accountStatus: AccountStatus.active,
      createdAt: ts,
      updatedAt: ts,
      location: kRankingDemoOrigin,
    );
  }

  // Distances are approximate from Panabo center (Haversine in ranking).
  final profiles = <ServiceProviderProfile>[
    // ~1 km, available, solid history → strong overall RS (proximity + A + C).
    profile(
      id: '${kRankingDemoProviderIdPrefix}ana_nearby',
      area: 'Panabo City',
      location: const GeoPoint(7.3160, 125.6850),
      averageRating: 4.4,
      reviewCount: 18,
      completed: 16,
      accepted: 18,
      schedule: alwaysOn(),
    ),
    // ~11 km, available, excellent rating/history → quality strong, proximity weaker.
    profile(
      id: '${kRankingDemoProviderIdPrefix}ben_far_star',
      area: 'Carmen, Davao del Norte',
      location: const GeoPoint(7.3600, 125.7700),
      averageRating: 4.9,
      reviewCount: 55,
      completed: 50,
      accepted: 52,
      schedule: alwaysOn(),
    ),
    // ~2 km, available, NEW (0 reviews) → Bayesian prior + cold-start completion.
    profile(
      id: '${kRankingDemoProviderIdPrefix}cora_new_local',
      area: 'Panabo City',
      location: const GeoPoint(7.3205, 125.6900),
      averageRating: 0,
      reviewCount: 0,
      completed: 0,
      accepted: 0,
      schedule: alwaysOn(),
    ),
    // ~1.5 km, UNAVAILABLE, strong rating → proximity helps, A = 0 hurts.
    profile(
      id: '${kRankingDemoProviderIdPrefix}diego_unavailable',
      area: 'Panabo City',
      location: const GeoPoint(7.3188, 125.6780),
      averageRating: 4.8,
      reviewCount: 30,
      completed: 28,
      accepted: 30,
      schedule: alwaysOff(),
    ),
    // ~5 km, available, mid ratings → middle of the pack.
    profile(
      id: '${kRankingDemoProviderIdPrefix}elena_mid',
      area: 'Panabo City',
      location: const GeoPoint(7.2850, 125.7100),
      averageRating: 4.1,
      reviewCount: 10,
      completed: 8,
      accepted: 12,
      schedule: alwaysOn(),
    ),
    // ~13 km, available, new → farthest cold-start (usually lowest among demos).
    profile(
      id: '${kRankingDemoProviderIdPrefix}felix_far_new',
      area: 'Davao City (edge)',
      location: const GeoPoint(7.2500, 125.5800),
      averageRating: 0,
      reviewCount: 0,
      completed: 1,
      accepted: 1,
      schedule: alwaysOn(),
    ),
  ];

  final users = <String, AppUser>{
    for (final p in profiles)
      p.userId: user(
        p.userId,
        switch (p.userId) {
          '${kRankingDemoProviderIdPrefix}ana_nearby' => 'Ana Nearby (Demo)',
          '${kRankingDemoProviderIdPrefix}ben_far_star' => 'Ben Far-Star (Demo)',
          '${kRankingDemoProviderIdPrefix}cora_new_local' => 'Cora New-Local (Demo)',
          '${kRankingDemoProviderIdPrefix}diego_unavailable' => 'Diego Off-Duty (Demo)',
          '${kRankingDemoProviderIdPrefix}elena_mid' => 'Elena Mid-Range (Demo)',
          '${kRankingDemoProviderIdPrefix}felix_far_new' => 'Felix Far-New (Demo)',
          _ => 'Demo Provider',
        },
      ),
  };

  return RankingDemoPack(profiles: profiles, users: users);
}

/// Live Firestore providers + UI-only demos, ranked with the manuscript RS formula.
///
/// Real providers are never removed. Demo ids are prefixed with [kRankingDemoProviderIdPrefix].
List<RankedProvider> rankProvidersWithRankingDemos({
  required List<ServiceProviderProfile> liveProviders,
  GeoPoint? customerOrigin,
  DateTime? now,
}) {
  final demo = buildRankingDemoPack(now: now);
  // Stable tie-break for panel demos (fair shuffle still applies within bands).
  return rankProvidersByRecommendation(
    providers: [...liveProviders, ...demo.profiles],
    customerOrigin: customerOrigin ?? kRankingDemoOrigin,
    now: now,
    random: null, // keep fair shuffle; demos are labeled in UI
  );
}

Map<String, AppUser> rankingDemoUsers({DateTime? now}) => buildRankingDemoPack(now: now).users;
