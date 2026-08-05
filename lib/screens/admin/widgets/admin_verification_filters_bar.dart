import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';

/// Search + filter controls for the admin verification queue (overflow-safe).
class AdminVerificationFiltersBar extends StatelessWidget {
  const AdminVerificationFiltersBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.dateSort,
    required this.onDateSortChanged,
    this.onFiltersTap,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String statusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final String dateSort;
  final ValueChanged<String> onDateSortChanged;
  final VoidCallback? onFiltersTap;

  static const statusOptions = ['All status', 'Pending', 'Approved', 'Rejected'];
  static const dateOptions = ['Newest first', 'Oldest first'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final stackVertically = w < 720;

        final search = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by provider name, email, or business name…',
            hintStyle: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 14),
            prefixIcon: const Icon(Icons.search, size: 20, color: FigmaColors.gray500),
            filled: true,
            fillColor: FigmaColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FigmaColors.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FigmaColors.gray300),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        );

        final statusMenu = _FilterPopupMenu(
          label: 'Verification status',
          value: statusFilter,
          options: statusOptions,
          onSelected: onStatusFilterChanged,
          width: stackVertically ? w : 180,
        );
        final dateMenu = _FilterPopupMenu(
          label: 'Submission date',
          value: dateSort,
          options: dateOptions,
          onSelected: onDateSortChanged,
          width: stackVertically ? w : 180,
        );
        final filtersBtn = OutlinedButton.icon(
          onPressed: onFiltersTap,
          icon: const Icon(Icons.tune, size: 18),
          label: Text('Filters', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: FigmaColors.gray800,
            backgroundColor: FigmaColors.white,
            side: const BorderSide(color: FigmaColors.gray300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 12),
              statusMenu,
              const SizedBox(height: 12),
              dateMenu,
              const SizedBox(height: 12),
              filtersBtn,
            ],
          );
        }

        final searchWidth = math.max(200.0, w - 420);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(width: searchWidth, child: search),
            statusMenu,
            dateMenu,
            filtersBtn,
          ],
        );
      },
    );
  }
}

/// Popup menu styled as a field — avoids [DropdownButton] layout crashes on rebuild.
class _FilterPopupMenu extends StatelessWidget {
  const _FilterPopupMenu({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.width,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray600),
          ),
          const SizedBox(height: 6),
          PopupMenuButton<String>(
            initialValue: value,
            onSelected: onSelected,
            itemBuilder: (context) => [
              for (final o in options)
                PopupMenuItem<String>(
                  value: o,
                  child: Text(
                    o,
                    style: GoogleFonts.inter(
                      fontWeight: o == value ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
            ],
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: FigmaColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FigmaColors.gray300),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: FigmaColors.gray600),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
