import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../figma_ui/marketing_featured_services.dart';
import '../../utils/geo_location.dart';
import '../../figma_ui/marketing_service_images.dart';
import '../../models/app_user.dart';
import '../../models/provider.dart';
import '../../models/service.dart';

/// Demo / preview service row for customer home browse grids.
class CustomerDemoService {
  const CustomerDemoService({
    required this.title,
    required this.category,
    required this.categoryId,
    required this.providerName,
    required this.rating,
    required this.reviews,
    required this.pricePhp,
    this.providerPhotoUrl,
    this.providerInitial,
    this.providerAvatarColor,
    this.verified = true,
  });

  final String title;
  final String category;
  final String categoryId;
  final String providerName;
  final double rating;
  final int reviews;
  final int pricePhp;
  final String? providerPhotoUrl;
  final String? providerInitial;
  final Color? providerAvatarColor;
  final bool verified;

  String get imageUrl => MarketingServiceImages.urlFor(
        serviceName: title,
        categoryId: categoryId,
      );
}

/// Curated preview listings aligned with marketing mockups.
const customerDemoServices = [
  CustomerDemoService(
    title: 'House Cleaning',
    category: 'Cleaning',
    categoryId: 'cleaning',
    providerName: 'Maria Santos',
    rating: 4.9,
    reviews: 18,
    pricePhp: 400,
    providerInitial: 'M',
    providerAvatarColor: Color(0xFF16A34A),
  ),
  CustomerDemoService(
    title: 'Aircon Cleaning',
    category: 'Repair and Technical Services',
    categoryId: 'repair_technical',
    providerName: 'Kent Repair Services',
    rating: 5.0,
    reviews: 20,
    pricePhp: 350,
    providerPhotoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=100&q=80',
  ),
  CustomerDemoService(
    title: 'Laundry Assistance',
    category: 'Cleaning',
    categoryId: 'cleaning',
    providerName: 'Care Assist PH',
    rating: 4.8,
    reviews: 14,
    pricePhp: 240,
    providerInitial: 'C',
    providerAvatarColor: Color(0xFF16A34A),
  ),
  CustomerDemoService(
    title: 'Moving Help',
    category: 'Moving and Errands',
    categoryId: 'moving_errands',
    providerName: 'Juan Dela Cruz',
    rating: 4.8,
    reviews: 15,
    pricePhp: 600,
    providerInitial: 'J',
    providerAvatarColor: Color(0xFF86EFAC),
  ),
  CustomerDemoService(
    title: 'Math Tutoring',
    category: 'Tutoring and Lessons',
    categoryId: 'tutoring',
    providerName: 'Teacher Ana',
    rating: 5.0,
    reviews: 9,
    pricePhp: 350,
    providerPhotoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
  ),
];

class CustomerBrowseServiceItem {
  const CustomerBrowseServiceItem({
    required this.title,
    required this.category,
    required this.categoryId,
    required this.imageUrl,
    required this.providerName,
    required this.price,
    required this.rating,
    required this.reviews,
    this.providerPhotoUrl,
    this.providerInitial,
    this.providerAvatarColor,
    this.verified = true,
    this.isDemo = false,
    this.listing,
    this.sortKey = 0,
    this.providerLocation,
  });

  final String title;
  final String category;
  final String categoryId;
  final String imageUrl;
  final String providerName;
  final double price;
  final double rating;
  final int reviews;
  final String? providerPhotoUrl;
  final String? providerInitial;
  final Color? providerAvatarColor;
  final bool verified;
  final bool isDemo;
  final ServiceListing? listing;
  final double sortKey;
  final GeoPoint? providerLocation;

  factory CustomerBrowseServiceItem.fromListing({
    required ServiceListing listing,
    required String providerName,
    String? providerPhotoUrl,
    double? rating,
    int? reviewCount,
    bool verified = true,
    GeoPoint? providerLocation,
  }) {
    final imageUrl = listing.serviceImages.isNotEmpty
        ? listing.serviceImages.first
        : MarketingServiceImages.urlFor(
            serviceName: listing.serviceTitle,
            categoryName: listing.category,
          );
    return CustomerBrowseServiceItem(
      title: listing.serviceTitle,
      category: listing.category,
      categoryId: listing.category.toLowerCase().replaceAll(' ', '_'),
      imageUrl: imageUrl,
      providerName: providerName,
      price: listing.estimatedPrice,
      rating: rating ?? 0,
      reviews: reviewCount ?? 0,
      providerPhotoUrl: providerPhotoUrl,
      verified: verified,
      listing: listing,
      sortKey: listing.createdAt.millisecondsSinceEpoch.toDouble(),
      providerLocation: providerLocation,
    );
  }

  factory CustomerBrowseServiceItem.fromDemo(CustomerDemoService demo) {
    return CustomerBrowseServiceItem(
      title: demo.title,
      category: demo.category,
      categoryId: demo.categoryId,
      imageUrl: demo.imageUrl,
      providerName: demo.providerName,
      price: demo.pricePhp.toDouble(),
      rating: demo.rating,
      reviews: demo.reviews,
      providerPhotoUrl: demo.providerPhotoUrl,
      providerInitial: demo.providerInitial,
      providerAvatarColor: demo.providerAvatarColor,
      verified: demo.verified,
      isDemo: true,
      sortKey: demo.pricePhp.toDouble(),
    );
  }

  factory CustomerBrowseServiceItem.fromFeatured(MarketingFeaturedService f) {
    return CustomerBrowseServiceItem(
      title: f.title,
      category: f.categoryName,
      categoryId: f.categoryId,
      imageUrl: f.imageUrl,
      providerName: 'Local provider',
      price: f.pricePhp.toDouble(),
      rating: f.rating,
      reviews: f.reviews,
      verified: true,
      isDemo: true,
      sortKey: f.reviews.toDouble(),
    );
  }
}

List<CustomerBrowseServiceItem> buildCustomerBrowseServices({
  required List<ServiceListing> live,
  required List<ServiceProviderProfile> profiles,
  required Map<String, AppUser> users,
}) {
  ServiceProviderProfile? profileFor(ServiceListing listing) {
    for (final p in profiles) {
      if (p.providerId == listing.providerId || p.userId == listing.providerId) {
        return p;
      }
    }
    return null;
  }

  AppUser? userFor(ServiceListing listing) {
    final profile = profileFor(listing);
    if (profile != null) return users[profile.userId];
    return users[listing.providerId];
  }

  final items = <CustomerBrowseServiceItem>[];
  final usedTitles = <String>{};

  for (final listing in live) {
    final profile = profileFor(listing);
    final user = userFor(listing);
    items.add(
      CustomerBrowseServiceItem.fromListing(
        listing: listing,
        providerName: user?.fullName.isNotEmpty == true ? user!.fullName : 'Local provider',
        providerPhotoUrl: user?.profilePhotoUrl,
        rating: profile?.averageRating,
        reviewCount: profile?.reviewCount ?? 0,
        verified: profile?.isVerifiedProvider ?? true,
        providerLocation: geoPointOrNull(profile?.location),
      ),
    );
    usedTitles.add(listing.serviceTitle.trim().toLowerCase());
  }

  for (final demo in customerDemoServices) {
    if (usedTitles.contains(demo.title.trim().toLowerCase())) continue;
    items.add(CustomerBrowseServiceItem.fromDemo(demo));
    usedTitles.add(demo.title.trim().toLowerCase());
  }

  for (final featured in MarketingFeaturedServices.all) {
    if (usedTitles.contains(featured.title.trim().toLowerCase())) continue;
    items.add(CustomerBrowseServiceItem.fromFeatured(featured));
    usedTitles.add(featured.title.trim().toLowerCase());
  }

  return items;
}
