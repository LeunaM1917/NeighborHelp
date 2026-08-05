import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account_status.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../models/provider_weekly_availability.dart';
import '../models/service.dart';
import '../models/service_approval_status.dart';
import '../models/user_role.dart';
import '../services/provider_recommendation_service.dart';
import 'ranking_demo_providers.dart';

/// UI-only listings + profiles for job-title ranking demos (panel script).
class JobTitleDemoPack {
  const JobTitleDemoPack({
    required this.listings,
    required this.profiles,
    required this.users,
  });

  final List<ServiceListing> listings;
  final Map<String, ServiceProviderProfile> profiles;
  final Map<String, AppUser> users;
}

bool isJobTitleDemoProviderId(String id) => id.startsWith('demo_job_');

/// Panel-friendly samples for selected job titles (merged with live listings).
JobTitleDemoPack? jobTitleRankingDemosFor(String serviceTitle, {DateTime? now}) {
  final title = serviceTitle.trim().toLowerCase();
  if (title == 'ceiling repair') {
    return _ceilingRepairDemos(now: now);
  }
  return null;
}

/// Brance (live) stays; add 1 rated + 3 new-for-service demos for ranking fairness.
JobTitleDemoPack _ceilingRepairDemos({DateTime? now}) {
  return _buildPack(
    serviceTitle: 'Ceiling Repair',
    category: 'Home Repair',
    description: 'Repair cracks, stains, and minor ceiling damage.',
    price: 300,
    now: now,
    rows: const [
      // Rated peer — shows stars "for this service" next to Brance.
      _DemoRow(
        id: 'demo_job_ceil_rated',
        name: 'Rico Ceiling Pro (Demo)',
        area: 'Panabo City',
        location: GeoPoint(7.3140, 125.6860),
        rating: 4.5,
        reviews: 6,
        serviceReviews: 6,
        completed: 9,
        accepted: 10,
      ),
      // New for this service (cold-start R) — still compete on P / A / C.
      _DemoRow(
        id: 'demo_job_ceil_new_a',
        name: 'Liza Patchworks (Demo · New)',
        area: 'Panabo City',
        location: GeoPoint(7.3095, 125.6815),
        rating: 0,
        reviews: 0,
        serviceReviews: 0,
        completed: 0,
        accepted: 0,
      ),
      _DemoRow(
        id: 'demo_job_ceil_new_b',
        name: 'Marco Height Fix (Demo · New)',
        area: 'Panabo City',
        location: GeoPoint(7.3180, 125.6900),
        rating: 0,
        reviews: 0,
        serviceReviews: 0,
        completed: 2,
        accepted: 3,
      ),
      _DemoRow(
        id: 'demo_job_ceil_new_c',
        name: 'Nova Ceiling Co. (Demo · New)',
        area: 'Carmen, Davao del Norte',
        location: GeoPoint(7.3400, 125.7200),
        rating: 0,
        reviews: 0,
        serviceReviews: 0,
        completed: 0,
        accepted: 0,
      ),
    ],
  );
}

class _DemoRow {
  const _DemoRow({
    required this.id,
    required this.name,
    required this.area,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.completed,
    required this.accepted,
    this.serviceReviews,
  });

  final String id;
  final String name;
  final String area;
  final GeoPoint location;
  final double rating;
  final int reviews;
  /// Reviews for this job title (drives "New for this service" vs star count).
  final int? serviceReviews;
  final int completed;
  final int accepted;

  int get serviceReviewCount => serviceReviews ?? reviews;
}

JobTitleDemoPack _buildPack({
  required String serviceTitle,
  required String category,
  required String description,
  required double price,
  required List<_DemoRow> rows,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final ts = Timestamp.fromDate(at);

  ProviderWeeklyAvailability schedule(bool on) => ProviderWeeklyAvailability(
        days: {
          for (final d in ProviderWeeklyAvailability.dayOrder)
            d: ProviderDaySchedule(
              enabled: on,
              start: '6:00 AM',
              end: '10:00 PM',
            ),
        },
      );

  final profiles = <String, ServiceProviderProfile>{};
  final users = <String, AppUser>{};
  final listings = <ServiceListing>[];

  for (final row in rows) {
    profiles[row.id] = ServiceProviderProfile(
      providerId: row.id,
      userId: row.id,
      bio: 'Sample $serviceTitle provider for job-title ranking demo.',
      serviceArea: row.area,
      location: row.location,
      serviceRadiusKm: 15,
      averageRating: row.rating,
      completedBookings: row.completed,
      acceptedBookings: row.accepted,
      reviewCount: row.serviceReviewCount,
      isVerified: true,
      verificationStatus: 'Approved',
      createdAt: ts,
      updatedAt: ts,
      weeklyAvailability: schedule(true),
      approvedCertificationIds: const ['demo_cert'],
    );
    users[row.id] = AppUser(
      userId: row.id,
      fullName: row.name,
      email: '${row.id}@demo.neighborhelp.local',
      role: UserRole.provider,
      accountStatus: AccountStatus.active,
      createdAt: ts,
      updatedAt: ts,
      location: kRankingDemoOrigin,
    );
    listings.add(
      ServiceListing(
        serviceId: 'listing_${row.id}',
        providerId: row.id,
        serviceTitle: serviceTitle,
        category: category,
        description: description,
        estimatedPrice: price,
        priceType: 'fixed',
        estimatedDuration: '2 hours',
        availability: const {},
        serviceImages: const [],
        isActive: true,
        approvalStatus: ServiceApprovalStatus.approved,
        createdAt: ts,
        updatedAt: ts,
      ),
    );
  }

  return JobTitleDemoPack(listings: listings, profiles: profiles, users: users);
}

/// Merge live listings with job-title demos and sort by RS for that service.
List<ServiceListing> mergeAndRankListingsForJobTitle({
  required String serviceTitle,
  required List<ServiceListing> liveListings,
  required Map<String, ServiceProviderProfile?> liveProfiles,
  required Map<String, AppUser?> liveUsers,
  GeoPoint? customerOrigin,
  DateTime? now,
  void Function(Map<String, ServiceProviderProfile?> profiles, Map<String, AppUser?> users)? absorbDemoMaps,
}) {
  final demo = jobTitleRankingDemosFor(serviceTitle, now: now);
  final listings = List<ServiceListing>.from(liveListings);
  final profiles = Map<String, ServiceProviderProfile?>.from(liveProfiles);
  final users = Map<String, AppUser?>.from(liveUsers);

  if (demo != null) {
    final liveIds = liveListings.map((l) => l.providerId).toSet();
    for (final listing in demo.listings) {
      if (liveIds.contains(listing.providerId)) continue;
      listings.add(listing);
      profiles[listing.providerId] = demo.profiles[listing.providerId];
      users[listing.providerId] = demo.users[listing.providerId];
    }
  }

  absorbDemoMaps?.call(profiles, users);

  return sortListingsByProviderRecommendation(
    listings: listings,
    profilesByProviderId: profiles,
    customerOrigin: customerOrigin ?? kRankingDemoOrigin,
    now: now,
  );
}
