import 'marketing_service_images.dart';

/// Curated cards for home / browse marketing grids.
class MarketingFeaturedService {
  const MarketingFeaturedService({
    required this.title,
    required this.categoryName,
    required this.categoryId,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
    required this.pricePhp,
  });

  final String title;
  final String categoryName;
  final String categoryId;
  final String imageUrl;
  final double rating;
  final int reviews;
  final int pricePhp;
}

abstract final class MarketingFeaturedServices {
  static String _img(String name, String categoryId) =>
      MarketingServiceImages.urlFor(serviceName: name, categoryId: categoryId);

  static final List<MarketingFeaturedService> all = [
    MarketingFeaturedService(
      title: 'House Cleaning',
      categoryName: 'Cleaning',
      categoryId: 'cleaning',
      imageUrl: _img('House Cleaning', 'cleaning'),
      rating: 4.9,
      reviews: 127,
      pricePhp: 350,
    ),
    MarketingFeaturedService(
      title: 'Math Tutoring',
      categoryName: 'Tutoring and Lessons',
      categoryId: 'tutoring',
      imageUrl: _img('Math Tutoring', 'tutoring'),
      rating: 4.8,
      reviews: 95,
      pricePhp: 300,
    ),
    MarketingFeaturedService(
      title: 'Home Repair',
      categoryName: 'Home Repair',
      categoryId: 'home_repair',
      imageUrl: _img('Wall Repair', 'home_repair'),
      rating: 5.0,
      reviews: 203,
      pricePhp: 450,
    ),
    MarketingFeaturedService(
      title: 'Pet Sitting',
      categoryName: 'Pet Care',
      categoryId: 'pet_care',
      imageUrl: _img('Pet Sitting', 'pet_care'),
      rating: 4.9,
      reviews: 156,
      pricePhp: 350,
    ),
    MarketingFeaturedService(
      title: 'Gardening',
      categoryName: 'More / Community Help',
      categoryId: 'community',
      imageUrl: _img('Gardening', 'community'),
      rating: 4.7,
      reviews: 89,
      pricePhp: 300,
    ),
    MarketingFeaturedService(
      title: 'Plumbing Repair',
      categoryName: 'Repair and Technical Services',
      categoryId: 'repair_technical',
      imageUrl: _img('Plumbing Repair', 'repair_technical'),
      rating: 4.8,
      reviews: 178,
      pricePhp: 380,
    ),
    MarketingFeaturedService(
      title: 'Electrical Repair',
      categoryName: 'Repair and Technical Services',
      categoryId: 'repair_technical',
      imageUrl: _img('Electrical Repair', 'repair_technical'),
      rating: 4.9,
      reviews: 165,
      pricePhp: 400,
    ),
    MarketingFeaturedService(
      title: 'Furniture Assembly',
      categoryName: 'Handyman',
      categoryId: 'handyman',
      imageUrl: _img('Furniture Assembly', 'handyman'),
      rating: 4.7,
      reviews: 134,
      pricePhp: 300,
    ),
    MarketingFeaturedService(
      title: 'Grocery Pickup',
      categoryName: 'Moving and Errands',
      categoryId: 'moving_errands',
      imageUrl: _img('Grocery Pickup', 'moving_errands'),
      rating: 4.8,
      reviews: 112,
      pricePhp: 180,
    ),
    MarketingFeaturedService(
      title: 'Small Catering',
      categoryName: 'Food and Event Support',
      categoryId: 'food_event',
      imageUrl: _img('Small Catering', 'food_event'),
      rating: 4.9,
      reviews: 76,
      pricePhp: 550,
    ),
    MarketingFeaturedService(
      title: 'Babysitting',
      categoryName: 'Personal and Care Services',
      categoryId: 'personal_care',
      imageUrl: _img('Babysitting', 'personal_care'),
      rating: 4.9,
      reviews: 88,
      pricePhp: 350,
    ),
    MarketingFeaturedService(
      title: 'Deep Cleaning',
      categoryName: 'Cleaning',
      categoryId: 'cleaning',
      imageUrl: _img('Deep Cleaning', 'cleaning'),
      rating: 4.8,
      reviews: 142,
      pricePhp: 550,
    ),
  ];
}
