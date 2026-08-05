import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/service.dart';
import '../figma_colors.dart';
import '../marketing_service_images.dart';
import 'figma_network_image.dart';

class FigmaServiceCard extends StatelessWidget {
  const FigmaServiceCard({
    super.key,
    required this.listing,
    this.rating,
    this.reviewCount,
    this.onTap,
  });

  final ServiceListing listing;
  final double? rating;
  final int? reviewCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.serviceImages.isNotEmpty
        ? listing.serviceImages.first
        : MarketingServiceImages.urlFor(
            serviceName: listing.serviceTitle,
            categoryName: listing.category,
          );
    final ratingText = rating != null ? rating!.toStringAsFixed(1) : '—';
    final reviews = reviewCount ?? 0;

    return Material(
      color: FigmaColors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: FigmaColors.gray50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: FigmaColors.gray200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: FigmaNetworkImage(url: imageUrl, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.category,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEAB308)),
                        const SizedBox(width: 4),
                        Text(
                          '$ratingText ($reviews)',
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                        ),
                        const Spacer(),
                        Text(
                          '₱${listing.estimatedPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: FigmaColors.navy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
