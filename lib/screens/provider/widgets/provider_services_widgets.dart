import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../theme/mobile_layout.dart';
import '../../../widgets/mobile_stat_row.dart';
import '../../../figma_ui/marketing_service_images.dart';
import '../../../figma_ui/widgets/figma_network_image.dart';
import '../../../models/booking.dart';
import '../../../models/review.dart';
import '../../../models/service.dart';
import '../../../models/service_approval_status.dart';
import '../../../theme/role_theme.dart';
import 'provider_dashboard_widgets.dart';

class ProviderServicesHero extends StatelessWidget {
  const ProviderServicesHero({super.key});

  @override
  Widget build(BuildContext context) {
    return FigmaHeroGradientBackground(
      child: FigmaWideContainer(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: MobileLayout.heroVerticalPadding(context)),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final compact = MobileLayout.isNativeApp(context);
              final text = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My services',
                    style: GoogleFonts.inter(
                      fontSize: wide ? 36 : 28,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.gray900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Services customers can browse and book',
                    style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.45),
                  ),
                ],
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text,
                    if (!compact) ...[const SizedBox(height: 20), const _ServicesHeroArt()],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 16),
                  const _ServicesHeroArt(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServicesHeroArt extends StatelessWidget {
  const _ServicesHeroArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Row(
              children: [
                _miniHouse(FigmaColors.tintBlue, FigmaColors.navy),
                const SizedBox(width: 8),
                _miniHouse(FigmaColors.tintBlue, FigmaColors.navy),
                const SizedBox(width: 8),
                Icon(Icons.park_outlined, size: 32, color: FigmaColors.navy.withValues(alpha: 0.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniHouse(Color bg, Color icon) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: icon.withValues(alpha: 0.2)),
      ),
      child: Icon(Icons.home_rounded, color: icon, size: 28),
    );
  }
}

class ProviderServicesStatsRow extends StatelessWidget {
  const ProviderServicesStatsRow({
    super.key,
    required this.total,
    required this.active,
    required this.paused,
    required this.totalBookings,
  });

  final int total;
  final int active;
  final int paused;
  final int totalBookings;

  @override
  Widget build(BuildContext context) {
    final compact = MobileLayout.isNativeApp(context);
    final cards = [
      _ServicesStatCard(
        icon: Icons.layers_outlined,
        iconColor: FigmaColors.navy,
        iconBg: FigmaColors.tintBlue,
        value: '$total',
        title: 'Total Services',
        subtitle: 'All the services you offer',
        compact: compact,
      ),
      _ServicesStatCard(
        icon: Icons.check_circle_outline,
        iconColor: FigmaColors.navy,
        iconBg: FigmaColors.tintBlue,
        value: '$active',
        title: 'Live',
        subtitle: 'Approved and visible',
        subtitleColor: FigmaColors.navy,
        compact: compact,
      ),
      _ServicesStatCard(
        icon: Icons.pause_circle_outline,
        iconColor: FigmaColors.orange600,
        iconBg: FigmaColors.orange50,
        value: '$paused',
        title: 'Pending review',
        subtitle: 'Waiting for admin approval',
        subtitleColor: FigmaColors.orange600,
        compact: compact,
      ),
      _ServicesStatCard(
        icon: Icons.event_note_outlined,
        iconColor: FigmaColors.purple600,
        iconBg: FigmaColors.purple50,
        value: '$totalBookings',
        title: 'Total Bookings',
        subtitle: 'Across all services',
        compact: compact,
      ),
    ];

    return MobileStatCardRow(cards: cards);
  }
}

class _ServicesStatCard extends StatelessWidget {
  const _ServicesStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 36.0 : 44.0;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: compact ? 20 : 24),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: compact ? 26 : 30,
              fontWeight: FontWeight.w700,
              color: FigmaColors.gray900,
              height: 1.05,
            ),
          ),
          SizedBox(height: compact ? 6 : 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: FigmaColors.gray800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: compact ? 11 : 13,
              height: 1.25,
              color: subtitleColor ?? FigmaColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderServicesFilterBar extends StatelessWidget {
  const ProviderServicesFilterBar({
    super.key,
    required this.searchController,
    required this.category,
    required this.status,
    required this.sort,
    required this.categories,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onAddService,
  });

  final TextEditingController searchController;
  final String category;
  final String status;
  final String sort;
  final List<String> categories;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onAddService;

  static const statusOptions = [
    'All statuses',
    'Live',
    'Pending review',
    'Rejected',
    'Draft',
    'Paused',
  ];
  static const sortOptions = ['Newest first', 'Oldest first', 'Price: low to high', 'Price: high to low'];

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final search = TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search services…',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500),
            prefixIcon: const Icon(Icons.search, color: FigmaColors.gray500, size: 20),
            filled: true,
            fillColor: FigmaColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FigmaColors.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FigmaColors.gray300),
            ),
          ),
        );

        final filters = [
          _FilterDropdown(
            label: 'Category',
            value: category,
            items: ['All categories', ...categories],
            onChanged: onCategoryChanged,
          ),
          _FilterDropdown(
            label: 'Status',
            value: status,
            items: statusOptions,
            onChanged: onStatusChanged,
          ),
          _FilterDropdown(
            label: 'Sort by',
            value: sort,
            items: sortOptions,
            onChanged: onSortChanged,
          ),
        ];

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: filters),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onAddService,
                  style: FilledButton.styleFrom(
                    backgroundColor: rc.primary,
                    foregroundColor: rc.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add service'),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 12),
            for (var i = 0; i < filters.length; i++) ...[
              Expanded(flex: 2, child: filters[i]),
              if (i < filters.length - 1) const SizedBox(width: 12),
            ],
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onAddService,
              style: FilledButton.styleFrom(
                backgroundColor: rc.primary,
                foregroundColor: rc.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add service'),
            ),
          ],
        );
      },
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: FigmaColors.gray600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: FigmaColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FigmaColors.gray300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800),
              items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ProviderServiceGridCard extends StatelessWidget {
  const ProviderServiceGridCard({
    super.key,
    required this.listing,
    required this.bookingCount,
    required this.rating,
    required this.reviewCount,
    required this.onEdit,
    required this.onMenu,
  });

  final ServiceListing listing;
  final int bookingCount;
  final double rating;
  final int reviewCount;
  final VoidCallback onEdit;
  final void Function(String action) onMenu;

  static String formatPrice(ServiceListing listing) {
    final amount = '₱${listing.estimatedPrice.toStringAsFixed(0)}';
    final pt = listing.priceType.toLowerCase();
    if (pt.contains('hour')) return '$amount / hour';
    if (pt.contains('walk')) return '$amount / walk';
    if (pt == 'fixed' || pt.contains('session')) return '$amount / session';
    if (pt == 'negotiable') return amount;
    return '$amount / ${listing.priceType}';
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final imageUrl = listing.serviceImages.isNotEmpty
        ? listing.serviceImages.first
        : MarketingServiceImages.urlFor(
            serviceName: listing.serviceTitle,
            categoryName: listing.category,
          );
    final status = _providerListingStatus(listing);
    final statusLabel = status.label;
    final statusColor = status.foreground;
    final statusBg = status.background;
    final canToggleVisibility = listing.approvalStatus.isApproved;
    final ratingText = rating > 0 ? rating.toStringAsFixed(1) : '—';
    final reviewsLabel = reviewCount > 0 ? '($reviewCount reviews)' : '(no reviews yet)';

    return LayoutBuilder(
      builder: (context, constraints) {
        final useHorizontal = constraints.maxWidth >= 480;
        if (useHorizontal) {
          return _buildHorizontalCard(
            context,
            rc: rc,
            imageUrl: imageUrl,
            active: listing.isActive,
            canToggleVisibility: canToggleVisibility,
            statusLabel: statusLabel,
            statusColor: statusColor,
            statusBg: statusBg,
            ratingText: ratingText,
            reviewsLabel: reviewsLabel,
          );
        }
        return _buildVerticalCard(
          context,
          rc: rc,
          imageUrl: imageUrl,
          active: listing.isActive,
          canToggleVisibility: canToggleVisibility,
          statusLabel: statusLabel,
          statusColor: statusColor,
          statusBg: statusBg,
          ratingText: ratingText,
          reviewsLabel: reviewsLabel,
        );
      },
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _menuButton({required bool active, required bool canToggleVisibility}) {
    return Material(
      color: FigmaColors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18, color: FigmaColors.gray700),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onSelected: onMenu,
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (canToggleVisibility)
            PopupMenuItem(
              value: 'toggle',
              child: Text(active ? 'Pause service' : 'Show on marketplace'),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildVerticalCard(
    BuildContext context, {
    required RolePalette rc,
    required String imageUrl,
    required bool active,
    required bool canToggleVisibility,
    required String statusLabel,
    required Color statusColor,
    required Color statusBg,
    required String ratingText,
    required String reviewsLabel,
  }) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: FigmaNetworkImage(url: imageUrl, fit: BoxFit.cover),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _menuButton(active: active, canToggleVisibility: canToggleVisibility),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        listing.serviceTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _statusChip(statusLabel, statusColor, statusBg),
                  ],
                ),
                const SizedBox(height: 2),
                Text(listing.category, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                const SizedBox(height: 6),
                Text(formatPrice(listing), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFEAB308)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '$ratingText $reviewsLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 14, color: FigmaColors.gray500),
                    const SizedBox(width: 4),
                    Text('$bookingCount', style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600)),
                    const SizedBox(width: 10),
                    Icon(
                      active ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 14,
                      color: FigmaColors.gray500,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        foregroundColor: rc.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCard(
    BuildContext context, {
    required RolePalette rc,
    required String imageUrl,
    required bool active,
    required bool canToggleVisibility,
    required String statusLabel,
    required Color statusColor,
    required Color statusBg,
    required String ratingText,
    required String reviewsLabel,
  }) {
    return _cardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FigmaNetworkImage(url: imageUrl, fit: BoxFit.cover),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _menuButton(active: active, canToggleVisibility: canToggleVisibility),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          listing.serviceTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _statusChip(statusLabel, statusColor, statusBg),
                    ],
                  ),
                  Text(listing.category, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500)),
                  const SizedBox(height: 4),
                  Text(formatPrice(listing), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFEAB308)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '$ratingText $reviewsLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 13, color: FigmaColors.gray500),
                      const SizedBox(width: 3),
                      Text(
                        '$bookingCount bookings',
                        style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        active ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 13,
                        color: FigmaColors.gray500,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        active ? 'Visible' : 'Hidden',
                        style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: rc.primary,
                          side: BorderSide(color: rc.primary),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderServicesQuickActionsPanel extends StatelessWidget {
  const ProviderServicesQuickActionsPanel({
    super.key,
    required this.onAddService,
    required this.onManageServices,
    required this.onUpdateAvailability,
    required this.onViewBookings,
    this.onServiceSettings,
  });

  final VoidCallback onAddService;
  final VoidCallback onManageServices;
  final VoidCallback onUpdateAvailability;
  final VoidCallback onViewBookings;
  final VoidCallback? onServiceSettings;

  @override
  Widget build(BuildContext context) {
    return ProviderDashboardPanel(
      title: 'Quick Actions',
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          _ServicesActionTile(
            icon: Icons.add_box_outlined,
            iconColor: FigmaColors.navy,
            iconBg: FigmaColors.tintBlue,
            title: 'Add New Service',
            onTap: onAddService,
          ),
          _ServicesActionTile(
            icon: Icons.grid_view_rounded,
            iconColor: FigmaColors.navy,
            iconBg: FigmaColors.tintBlue,
            title: 'Manage Services',
            onTap: onManageServices,
          ),
          _ServicesActionTile(
            icon: Icons.calendar_month_outlined,
            iconColor: FigmaColors.orange600,
            iconBg: FigmaColors.orange50,
            title: 'Update Availability',
            onTap: onUpdateAvailability,
          ),
          _ServicesActionTile(
            icon: Icons.event_note_outlined,
            iconColor: FigmaColors.purple600,
            iconBg: FigmaColors.purple50,
            title: 'View Bookings',
            onTap: onViewBookings,
          ),
          _ServicesActionTile(
            icon: Icons.settings_outlined,
            iconColor: FigmaColors.gray600,
            iconBg: FigmaColors.gray100,
            title: 'Service Settings',
            onTap: onServiceSettings ?? () {},
          ),
        ],
      ),
    );
  }
}

class _ServicesActionTile extends StatelessWidget {
  const _ServicesActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right, color: FigmaColors.gray400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ProviderServicesPerformancePanel extends StatelessWidget {
  const ProviderServicesPerformancePanel({
    super.key,
    required this.views,
    required this.inquiries,
    required this.bookings,
    required this.conversionPct,
    required this.trendLabel,
  });

  final int views;
  final int inquiries;
  final int bookings;
  final double conversionPct;
  final String trendLabel;

  @override
  Widget build(BuildContext context) {
    return ProviderDashboardPanel(
      title: 'Performance Snapshot',
      trailing: SizedBox(
        width: 130,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: FigmaColors.gray300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: 'This Month',
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              items: const [DropdownMenuItem(value: 'This Month', child: Text('This Month'))],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _MetricCell(label: 'Views', value: '$views', trend: trendLabel)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCell(label: 'Inquiries', value: '$inquiries', trend: trendLabel)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCell(
                  label: 'Bookings',
                  value: '$bookings',
                  trend: trendLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCell(
                  label: 'Conversion Rate',
                  value: '${conversionPct.toStringAsFixed(1)}%',
                  trend: trendLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value, required this.trend});

  final String label;
  final String value;
  final String trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
          const SizedBox(height: 6),
          Text(
            '↗ $trend',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: FigmaColors.navy),
          ),
        ],
      ),
    );
  }
}

class ProviderServicesProfileTipCard extends StatelessWidget {
  const ProviderServicesProfileTipCard({super.key, required this.onAddPhotos});

  final VoidCallback onAddPhotos;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.tintBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.navy.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: FigmaColors.navy, size: 22),
              const SizedBox(width: 8),
              Text(
                'Profile tip',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Add more photos to your services. Services with images get 2× more views.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700, height: 1.45),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onAddPhotos,
            style: OutlinedButton.styleFrom(
              foregroundColor: rc.primary,
              side: BorderSide(color: rc.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Add Photos', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Sort/filter helpers for the services tab.
List<ServiceListing> filterAndSortServices({
  required List<ServiceListing> services,
  required String query,
  required String category,
  required String status,
  required String sort,
}) {
  var list = List<ServiceListing>.from(services);

  if (query.trim().isNotEmpty) {
    final q = query.trim().toLowerCase();
    list = list
        .where((s) =>
            s.serviceTitle.toLowerCase().contains(q) ||
            s.category.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q))
        .toList();
  }

  if (category != 'All categories') {
    list = list.where((s) => s.category == category).toList();
  }

  list = switch (status) {
    'Live' => list.where((s) => s.isMarketplaceVisible).toList(),
    'Pending review' => list.where((s) => s.approvalStatus == ServiceApprovalStatus.pending).toList(),
    'Rejected' => list.where((s) => s.approvalStatus == ServiceApprovalStatus.rejected).toList(),
    'Draft' => list.where((s) => s.approvalStatus == ServiceApprovalStatus.draft).toList(),
    'Paused' => list
        .where((s) => s.approvalStatus == ServiceApprovalStatus.approved && !s.isActive)
        .toList(),
    _ => list,
  };

  switch (sort) {
    case 'Oldest first':
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case 'Price: low to high':
      list.sort((a, b) => a.estimatedPrice.compareTo(b.estimatedPrice));
    case 'Price: high to low':
      list.sort((a, b) => b.estimatedPrice.compareTo(a.estimatedPrice));
    default:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  return list;
}

Map<String, int> bookingCountByService(List<Booking> bookings) {
  final counts = <String, int>{};
  for (final b in bookings) {
    if (b.serviceId.isEmpty) continue;
    counts[b.serviceId] = (counts[b.serviceId] ?? 0) + 1;
  }
  return counts;
}

Map<String, ({double avg, int count})> ratingsByService(List<Review> reviews) {
  final sums = <String, List<int>>{};
  for (final r in reviews) {
    if (r.serviceId.isEmpty) continue;
    sums.putIfAbsent(r.serviceId, () => []).add(r.rating);
  }
  return {
    for (final e in sums.entries)
      e.key: (
        avg: e.value.reduce((a, b) => a + b) / e.value.length,
        count: e.value.length,
      ),
  };
}

String performanceTrendLabel() {
  final now = DateTime.now();
  final prev = DateTime(now.year, now.month - 1);
  final start = DateFormat('MMM d').format(DateTime(prev.year, prev.month, 1));
  final end = DateFormat('MMM d').format(DateTime(prev.year, prev.month + 1, 0));
  return '$start – $end';
}

class _ProviderListingStatusStyle {
  const _ProviderListingStatusStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}

_ProviderListingStatusStyle _providerListingStatus(ServiceListing listing) {
  switch (listing.approvalStatus) {
    case ServiceApprovalStatus.pending:
      return const _ProviderListingStatusStyle(
        label: 'Pending review',
        foreground: FigmaColors.orange600,
        background: FigmaColors.orange50,
      );
    case ServiceApprovalStatus.rejected:
      return const _ProviderListingStatusStyle(
        label: 'Rejected',
        foreground: FigmaColors.red600,
        background: FigmaColors.red50,
      );
    case ServiceApprovalStatus.draft:
      return const _ProviderListingStatusStyle(
        label: 'Draft',
        foreground: FigmaColors.gray600,
        background: FigmaColors.gray100,
      );
    case ServiceApprovalStatus.approved:
      if (listing.isActive) {
        return const _ProviderListingStatusStyle(
          label: 'Live',
          foreground: FigmaColors.navy,
          background: FigmaColors.tintBlue,
        );
      }
      return const _ProviderListingStatusStyle(
        label: 'Paused',
        foreground: FigmaColors.orange600,
        background: FigmaColors.orange50,
      );
  }
}
