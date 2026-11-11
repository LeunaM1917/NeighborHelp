import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../figma_ui/figma_colors.dart';
import '../figma_ui/widgets/figma_network_image.dart';
import '../theme/role_theme.dart';
import 'profile_avatar.dart';

/// A bounded carousel card with room for both service and overall ratings.
class CustomerServiceCard extends StatelessWidget {
  const CustomerServiceCard({
    super.key,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.providerName,
    required this.rating,
    required this.price,
    required this.onTap,
    this.photoUrl,
    this.compact = false,
  });
  final String title, category, imageUrl, providerName;
  final String? photoUrl;
  final Widget rating;
  final double price;
  final VoidCallback onTap;
  final bool compact;
  static double heightFor(TextScaler scaler, {bool compact = false}) =>
      (compact ? 320 : 360) + (scaler.scale(1) - 1).clamp(0, 2) * 180;
  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Material(
      color: FigmaColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FigmaColors.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: SizedBox(
                  height: compact ? 120 : 140,
                  child: FigmaNetworkImage(url: imageUrl, fit: BoxFit.cover),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: FigmaColors.gray500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ProfileAvatar(
                            radius: 14,
                            backgroundColor: rc.tint,
                            photoUrl: photoUrl,
                            fallback: Text(
                              providerName.isEmpty
                                  ? 'P'
                                  : providerName[0].toUpperCase(),
                              style: TextStyle(color: rc.primary, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: rating),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '₱${price.toStringAsFixed(0)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: rc.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
