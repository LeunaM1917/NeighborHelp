import 'package:flutter/material.dart';

import '../models/service.dart';
import 'figma_colors.dart';

/// Marketing catalog for guest landing / browse (UI preview until Firestore listings exist).
class MarketingServiceCategory {
  const MarketingServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.services,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color bg;
  final Color fg;
  final List<MarketingServiceItem> services;

  int get serviceCount => services.length;
}

class MarketingServiceItem {
  const MarketingServiceItem({
    required this.name,
    required this.description,
    required this.startingPricePhp,
    required this.providers,
  });

  final String name;
  final String description;
  final int startingPricePhp;
  final List<MarketingSampleProvider> providers;
}

class MarketingSampleProvider {
  const MarketingSampleProvider({
    required this.name,
    required this.rating,
    required this.reviews,
    required this.area,
    this.verified = true,
  });

  final String name;
  final double rating;
  final int reviews;
  final String area;
  final bool verified;
}

abstract final class MarketingServiceCatalog {
  static const _providerPool = [
    ('Maria Santos', 'Panabo City', 4.9, 128),
    ('Juan Dela Cruz', 'Tagum City', 4.8, 96),
    ('Kent Repair Services', 'Panabo City', 5.0, 203),
    ('Davao Clean Pro', 'Davao del Norte', 4.8, 156),
    ('FixRight Davao', 'Davao City', 4.7, 89),
    ('Care Assist PH', 'Tagum City', 4.9, 74),
    ('Neighbor Pro', 'Panabo City', 4.6, 52),
    ('Tutor Hub Davao', 'Davao City', 4.9, 112),
    ('Errand Runner', 'Panabo City', 4.7, 67),
    ('Green Thumb Co.', 'Carmen', 4.8, 45),
  ];

  static List<MarketingSampleProvider> _providersFor(String serviceName, int basePrice) {
    final hash = serviceName.codeUnits.fold<int>(0, (a, b) => a + b);
    final count = 3;
    return List.generate(count, (i) {
      final p = _providerPool[(hash + i * 3) % _providerPool.length];
      return MarketingSampleProvider(
        name: p.$1,
        area: p.$2,
        rating: p.$3,
        reviews: p.$4 + (hash % 40),
        verified: i != 2 || hash.isEven,
      );
    });
  }

  static MarketingServiceItem _item(
    String name,
    String blurb,
    int price, {
    int priceOffset = 0,
  }) {
    return MarketingServiceItem(
      name: name,
      description: blurb,
      startingPricePhp: price + priceOffset,
      providers: _providersFor(name, price),
    );
  }

  static final List<MarketingServiceCategory> categories = [
    MarketingServiceCategory(
      id: 'home_repair',
      name: 'Home Repair',
      icon: Icons.home_outlined,
      bg: FigmaColors.tintBlue,
      fg: FigmaColors.navy,
      services: [
        _item('Roof Leak Repair', 'Patch leaks and protect your roof from water damage.', 450),
        _item('Door Repair', 'Fix hinges, alignment, and damaged door panels.', 280),
        _item('Window Repair', 'Repair frames, glass fittings, and sliding issues.', 320),
        _item('Tile Repair', 'Replace or re-seat cracked and loose tiles.', 350),
        _item('Ceiling Repair', 'Repair cracks, stains, and minor ceiling damage.', 300),
        _item('Wall Repair', 'Patch holes, cracks, and wall surface issues.', 250),
        _item('Cabinet Repair', 'Fix cabinet doors, drawers, and hinges.', 270),
        _item('Gate Repair', 'Repair gates, latches, and alignment problems.', 290),
        _item('Fence Repair', 'Fix broken panels, posts, and wire fencing.', 310),
        _item('Flooring Repair', 'Repair loose boards, vinyl, and floor gaps.', 380),
        _item('Basic Carpentry', 'Small wood repairs and custom fittings.', 400),
        _item('Home Maintenance Check', 'General inspection of common home issues.', 350),
        _item('Minor Renovation Help', 'Assist with small upgrade and repair projects.', 500),
        _item('Faucet Replacement', 'Replace kitchen and bathroom faucets.', 280),
        _item('Lock Repair', 'Repair or replace home door locks.', 220),
      ],
    ),
    MarketingServiceCategory(
      id: 'cleaning',
      name: 'Cleaning',
      icon: Icons.cleaning_services,
      bg: FigmaColors.yellow50,
      fg: const Color(0xFFCA8A04),
      services: [
        _item('House Cleaning', 'Regular home cleaning for rooms and common areas.', 350),
        _item('Deep Cleaning', 'Intensive cleaning for kitchens, baths, and floors.', 550),
        _item('Apartment Cleaning', 'Compact unit cleaning for condos and apartments.', 320),
        _item('Move-in Cleaning', 'Prepare a home before new occupants arrive.', 600),
        _item('Move-out Cleaning', 'Full cleaning before turnover or moving out.', 650),
        _item('Kitchen Cleaning', 'Degrease surfaces, appliances, and counters.', 280),
        _item('Bathroom Cleaning', 'Sanitize tiles, fixtures, and mirrors.', 260),
        _item('Window Cleaning', 'Interior and accessible exterior window washing.', 300),
        _item('Laundry Assistance', 'Wash, dry, fold, and organize laundry.', 240),
        _item('Ironing Service', 'Press clothes and household fabrics.', 200),
        _item('Carpet Cleaning', 'Shampoo and refresh carpets and rugs.', 400),
        _item('Upholstery Cleaning', 'Clean sofas, chairs, and fabric furniture.', 380),
        _item('Post-construction Cleaning', 'Remove dust and debris after renovation work.', 700),
        _item('Yard Cleaning', 'Sweep, pick up debris, and tidy outdoor areas.', 280),
        _item('General Decluttering', 'Sort, organize, and clear household clutter.', 320),
      ],
    ),
    MarketingServiceCategory(
      id: 'repair_technical',
      name: 'Repair and Technical Services',
      icon: Icons.electrical_services_outlined,
      bg: FigmaColors.indigo50,
      fg: FigmaColors.indigo600,
      services: [
        _item('Electrical Repair', 'Fix outlets, breakers, and wiring issues.', 400),
        _item('Plumbing Repair', 'Repair leaks, clogs, and pipe fittings.', 380),
        _item('Appliance Repair', 'Diagnose and repair common home appliances.', 450),
        _item('Aircon Cleaning', 'Deep clean AC units for better cooling.', 350),
        _item('Aircon Repair', 'Fix cooling, noise, and refrigerant issues.', 500),
        _item('Washing Machine Repair', 'Repair motors, drums, and water issues.', 480),
        _item('Refrigerator Repair', 'Fix cooling, ice maker, and door seals.', 520),
        _item('TV Repair', 'Troubleshoot display and power problems.', 420),
        _item('Electric Fan Repair', 'Repair blades, motors, and oscillation.', 220),
        _item('Computer Repair', 'Hardware and software troubleshooting for PCs.', 450),
        _item('Laptop Repair', 'Screen, battery, and performance repairs.', 480),
        _item('Printer Repair', 'Fix paper jams, drivers, and print quality.', 300),
        _item('Internet/Wi-Fi Setup', 'Router setup and basic network troubleshooting.', 350),
        _item('CCTV Installation', 'Install and configure security cameras.', 600),
        _item('Basic Phone Troubleshooting', 'Help with apps, storage, and connectivity.', 250),
      ],
    ),
    MarketingServiceCategory(
      id: 'handyman',
      name: 'Handyman',
      icon: Icons.build_outlined,
      bg: FigmaColors.purple50,
      fg: FigmaColors.purple600,
      services: [
        _item('Furniture Assembly', 'Assemble beds, shelves, and flat-pack furniture.', 300),
        _item('Shelf Installation', 'Mount shelves securely on walls.', 280),
        _item('Curtain Rod Installation', 'Install rods, blinds, and curtain hardware.', 250),
        _item('Wall Mounting', 'Mount TVs, frames, and wall decor.', 320),
        _item('Light Fixture Installation', 'Replace bulbs, fixtures, and ceiling lights.', 300),
        _item('Basic Painting', 'Touch-up paint for rooms and trim.', 400),
        _item('Door Knob Replacement', 'Install new knobs and handles.', 200),
        _item('Minor Plumbing Help', 'Small pipe and fixture adjustments.', 280),
        _item('Minor Electrical Help', 'Replace switches, bulbs, and outlets.', 260),
        _item('General Household Fixes', 'Various small repair tasks around the home.', 350),
        _item('Picture Frame Mounting', 'Level and mount frames and artwork.', 220),
        _item('Basic Welding Assistance', 'Small metal repairs for gates and frames.', 450),
        _item('Furniture Repair', 'Fix wobbly chairs, tables, and cabinets.', 320),
        _item('Water Tank Cleaning', 'Clean residential water storage tanks.', 500),
        _item('Drain Declogging', 'Clear clogged sinks and floor drains.', 300),
      ],
    ),
    MarketingServiceCategory(
      id: 'tutoring',
      name: 'Tutoring and Lessons',
      icon: Icons.school_outlined,
      bg: FigmaColors.tintBlue,
      fg: FigmaColors.navy,
      services: [
        _item('Elementary Tutoring', 'Support for primary school subjects.', 280),
        _item('High School Tutoring', 'Help with junior and senior high topics.', 320),
        _item('College Subject Tutoring', 'Tutoring for college-level coursework.', 400),
        _item('Math Tutoring', 'Algebra, geometry, and problem-solving help.', 300),
        _item('English Tutoring', 'Grammar, writing, and reading comprehension.', 300),
        _item('Science Tutoring', 'Biology, chemistry, and physics support.', 320),
        _item('Computer Basics Tutorial', 'Intro to files, email, and safe browsing.', 280),
        _item('Programming Tutorial', 'Beginner coding and logic lessons.', 450),
        _item('Reading Tutorial', 'Phonics and reading fluency practice.', 260),
        _item('Assignment Assistance', 'Guidance on homework and projects.', 250),
        _item('Exam Review Assistance', 'Focused review before quizzes and exams.', 300),
        _item('Music Lessons', 'Basic instrument and music theory lessons.', 350),
        _item('Art Lessons', 'Drawing, painting, and creative skills.', 320),
        _item('Language Tutorial', 'English, Filipino, or other language practice.', 300),
        _item('Online Class Assistance', 'Help navigating online learning platforms.', 280),
      ],
    ),
    MarketingServiceCategory(
      id: 'personal_care',
      name: 'Personal and Care Services',
      icon: Icons.volunteer_activism_outlined,
      bg: FigmaColors.red50,
      fg: FigmaColors.red600,
      services: [
        _item('Babysitting', 'Supervised childcare in your home.', 350),
        _item('Elderly Companion Assistance', 'Friendly companionship and light support.', 400),
        _item('Non-medical Caregiving', 'Daily living help without medical procedures.', 450),
        _item('Personal Errand Assistance', 'Groceries, bills, and personal tasks.', 280),
        _item('Home Organization Help', 'Closet, pantry, and room organization.', 320),
        _item('Basic Meal Preparation', 'Simple home-cooked meals for your household.', 300),
        _item('Grooming Assistance', 'Help with hygiene and grooming routines.', 350),
        _item('Event Makeup', 'Makeup for parties and special events.', 450),
        _item('Haircut Home Service', 'Basic haircut at your location.', 280),
        _item('Manicure/Pedicure Home Service', 'Nail care in the comfort of your home.', 320),
        _item('Laundry Pickup Assistance', 'Pick up and return laundry bundles.', 240),
        _item('House Sitting', 'Watch your home while you are away.', 400),
        _item('Plant Care', 'Water, prune, and maintain indoor plants.', 220),
        _item('Personal Shopping Assistance', 'Shop for items from your list.', 260),
        _item('Document Processing Assistance', 'Help with forms and paperwork.', 250),
      ],
    ),
    MarketingServiceCategory(
      id: 'moving_errands',
      name: 'Moving and Errands',
      icon: Icons.local_shipping_outlined,
      bg: FigmaColors.orange50,
      fg: FigmaColors.orange600,
      services: [
        _item('Delivery Assistance', 'Deliver packages and items locally.', 200),
        _item('Grocery Pickup', 'Buy groceries from your shopping list.', 180),
        _item('Medicine Pickup', 'Pick up prescriptions from pharmacies.', 150),
        _item('Parcel Pickup', 'Collect parcels from couriers or hubs.', 160),
        _item('Furniture Moving', 'Move furniture within or between homes.', 450),
        _item('Small Item Moving', 'Transport boxes and small household items.', 280),
        _item('House Transfer Assistance', 'Help during move-in or move-out days.', 600),
        _item('Loading and Unloading', 'Assist with truck loading and unloading.', 350),
        _item('Appliance Transport Assistance', 'Move washers, fridges, and heavy items.', 400),
        _item('Document Delivery', 'Deliver documents to offices or homes.', 180),
        _item('Market Errands', 'Market shopping and price checking.', 200),
        _item('Queue Assistance', 'Stand in line for bills, permits, or tickets.', 220),
        _item('School Supply Pickup', 'Buy and deliver school materials.', 190),
        _item('Water Delivery Assistance', 'Deliver water containers to your home.', 170),
        _item('General Runner Service', 'General errands around your area.', 250),
      ],
    ),
    MarketingServiceCategory(
      id: 'food_event',
      name: 'Food and Event Support',
      icon: Icons.restaurant_outlined,
      bg: FigmaColors.yellow50,
      fg: const Color(0xFFCA8A04),
      services: [
        _item('Home Cooking Service', 'Cook meals in your kitchen for the family.', 400),
        _item('Packed Meal Preparation', 'Prepare packed lunches and meal boxes.', 320),
        _item('Small Catering', 'Food trays for small gatherings.', 550),
        _item('Birthday Food Preparation', 'Party food prep and setup assistance.', 600),
        _item('Snack Preparation', 'Prepare finger foods and snack platters.', 280),
        _item('Dessert Preparation', 'Cakes, pastries, and sweet platters.', 350),
        _item('Event Setup Assistance', 'Tables, chairs, and basic event layout.', 400),
        _item('Event Cleanup Assistance', 'Clean up after parties and events.', 350),
        _item('Table and Chair Setup', 'Arrange seating for your event space.', 280),
        _item('Party Decoration Assistance', 'Simple balloons, banners, and decor.', 380),
        _item('Dishwashing Assistance', 'Wash dishes during or after events.', 220),
        _item('Food Delivery Assistance', 'Deliver prepared food to your venue.', 250),
        _item('Kitchen Helper', 'Extra hands for cooking and prep work.', 300),
        _item('Serving Assistance', 'Serve food and drinks to guests.', 280),
        _item('Simple Event Coordination', 'Basic timeline and task coordination.', 450),
      ],
    ),
    MarketingServiceCategory(
      id: 'pet_care',
      name: 'Pet Care',
      icon: Icons.pets,
      bg: FigmaColors.tintGreen,
      fg: FigmaColors.green,
      services: [
        _item('Dog Walking', 'Regular walks for exercise and routine.', 200),
        _item('Pet Sitting', 'Care for pets while you are away.', 350),
        _item('Pet Feeding', 'Scheduled feeding and water checks.', 180),
        _item('Pet Bathing', 'Bathe pets at home or mobile setup.', 300),
        _item('Basic Pet Grooming', 'Brush, trim nails, and basic coat care.', 320),
        _item('Litter Cleaning', 'Clean litter boxes and replace litter.', 160),
        _item('Pet Transport Assistance', 'Trips to vet or grooming appointments.', 280),
        _item('Aquarium Cleaning', 'Clean tanks and maintain water quality.', 350),
        _item('Bird Cage Cleaning', 'Wash cages and refresh bedding.', 220),
        _item('Pet Supply Pickup', 'Buy food, litter, and pet supplies.', 180),
        _item('Pet House Cleaning', 'Wash pet beds, crates, and houses.', 240),
        _item('Puppy Care Assistance', 'Extra care for young pets at home.', 300),
        _item('Senior Pet Assistance', 'Gentle care for older pets.', 320),
        _item('Pet Exercise Assistance', 'Playtime and activity for active pets.', 220),
        _item('Vet Visit Assistance', 'Transport and wait during vet visits.', 300),
      ],
    ),
    MarketingServiceCategory(
      id: 'community',
      name: 'More / Community Help',
      icon: Icons.yard_outlined,
      bg: FigmaColors.gray50,
      fg: FigmaColors.gray600,
      services: [
        _item('Gardening', 'Plant care, weeding, and garden upkeep.', 300),
        _item('Grass Cutting', 'Mow lawns and trim grass edges.', 280),
        _item('Tree Trimming', 'Trim branches and clear small overgrowth.', 400),
        _item('Backyard Cleaning', 'Sweep, organize, and tidy outdoor spaces.', 320),
        _item('Car Washing', 'Exterior wash and basic interior cleaning.', 250),
        _item('Motorcycle Washing', 'Wash and wipe down motorcycles.', 180),
        _item('Bicycle Repair', 'Fix tires, brakes, and chains.', 220),
        _item('Shoe Cleaning', 'Clean and polish shoes and sandals.', 120),
        _item('Bag Cleaning', 'Clean bags, backpacks, and luggage.', 150),
        _item('Uniform Repair', 'Sew buttons and patch school uniforms.', 180),
        _item('Simple Sewing Repair', 'Hem pants and fix small tears.', 200),
        _item('Home Inventory Assistance', 'List and organize household items.', 350),
        _item('Barangay Document Assistance', 'Help with local document processing.', 280),
        _item('Printing Assistance', 'Print and organize documents.', 150),
        _item('Encoding Assistance', 'Data entry and document encoding help.', 250),
      ],
    ),
    MarketingServiceCategory(
      id: 'custom',
      name: 'Custom Services',
      icon: Icons.edit_note_outlined,
      bg: FigmaColors.tintBlue,
      fg: FigmaColors.navy,
      services: const [],
    ),
  ];

  /// Top 5 on customer Home — Panabo / Davao everyday demand (not Western pet-walking).
  static const List<String> popularHomeCategoryIds = [
    'cleaning',
    'home_repair',
    'repair_technical',
    'moving_errands',
    'tutoring',
  ];

  static List<MarketingServiceCategory> get popularForHome {
    final list = <MarketingServiceCategory>[];
    for (final id in popularHomeCategoryIds) {
      final cat = categoryById(id);
      if (cat != null) list.add(cat);
    }
    return list;
  }

  static MarketingServiceCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static MarketingServiceCategory? categoryByName(String name) {
    for (final c in categories) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Matches live Firestore listings to a marketing catalog service.
  /// Live listings that advertise this marketing service.
  ///
  /// Exact title match only (case-insensitive). Do not fall back to category or
  /// partial words — otherwise "Ceiling Repair" appears under "Tile Repair".
  static List<ServiceListing> matchActiveListings(
    List<ServiceListing> listings, {
    required String marketingServiceName,
    String? marketingCategoryName,
  }) {
    final name = marketingServiceName.trim().toLowerCase();
    if (name.isEmpty) return const [];

    return listings
        .where((s) => s.serviceTitle.trim().toLowerCase() == name)
        .toList(growable: false);
  }

  /// Resolves a catalog service for marketing cards (exact name, else first in category).
  static ({MarketingServiceCategory category, MarketingServiceItem service})? resolveForCard({
    required String categoryId,
    required String serviceTitle,
  }) {
    final category = categoryById(categoryId);
    if (category == null || category.services.isEmpty) return null;
    for (final s in category.services) {
      if (s.name == serviceTitle) {
        return (category: category, service: s);
      }
    }
    return (category: category, service: category.services.first);
  }
}
