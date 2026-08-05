import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/widgets/figma_network_image.dart';
import '../../models/app_user.dart';
import '../../models/provider_certification.dart';
import '../../models/provider_portfolio_project.dart';
import '../../models/review.dart';
import '../../services/firestore_service.dart';
import '../../theme/role_theme.dart';
import '../../utils/review_job_label.dart';
import '../../utils/review_sentiment.dart';
import '../../widgets/review_tile.dart';

/// Professional profile layout using NeighborHelp colors ([RoleColors], [FigmaColors]).
abstract final class MemberProfileLayout {
  static const sidebarWidth = 300.0;
  static const sidebarWidthCompact = 280.0;
  static const twoColumnMin = 900.0;
  static const threeColumnMin = 1100.0;
  static const columnGap = 24.0;
}

/// Gray page background + wide container + optional back header.
class MemberProfilePage extends StatelessWidget {
  const MemberProfilePage({
    super.key,
    this.title,
    this.subtitle,
    this.onBack,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 24),
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FigmaColors.gray50,
      child: SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null && onBack != null) ...[
                _BackHeader(title: title!, subtitle: subtitle, onBack: onBack!),
                const SizedBox(height: 20),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.title, this.subtitle, required this.onBack});

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(backgroundColor: FigmaColors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Sidebar + main (+ optional right rail), stacks on compact/native narrow widths.
class MemberProfileColumns extends StatelessWidget {
  const MemberProfileColumns({
    super.key,
    required this.sidebar,
    required this.main,
    this.rightRail,
    this.threeColumnMinWidth = MemberProfileLayout.threeColumnMin,
    this.twoColumnMinWidth = MemberProfileLayout.twoColumnMin,
  });

  final Widget sidebar;
  final List<Widget> main;
  final Widget? rightRail;
  final double threeColumnMinWidth;
  final double twoColumnMinWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final sidebarW = w >= threeColumnMinWidth
            ? MemberProfileLayout.sidebarWidth
            : MemberProfileLayout.sidebarWidthCompact;

        if (w >= threeColumnMinWidth && rightRail != null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: sidebarW, child: sidebar),
              const SizedBox(width: MemberProfileLayout.columnGap),
              Expanded(child: Column(children: _spaced(main))),
              const SizedBox(width: MemberProfileLayout.columnGap),
              SizedBox(width: 300, child: rightRail!),
            ],
          );
        }

        if (w >= twoColumnMinWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: sidebarW, child: sidebar),
              const SizedBox(width: MemberProfileLayout.columnGap),
              Expanded(
                child: Column(
                  children: [
                    ..._spaced(main),
                    if (rightRail != null) ...[const SizedBox(height: 24), rightRail!],
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sidebar,
            const SizedBox(height: 20),
            ..._spaced(main),
            if (rightRail != null) ...[const SizedBox(height: 20), rightRail!],
          ],
        );
      },
    );
  }

  List<Widget> _spaced(List<Widget> items) {
    if (items.isEmpty) return [];
    final out = <Widget>[items.first];
    for (var i = 1; i < items.length; i++) {
      out.add(const SizedBox(height: 20));
      out.add(items[i]);
    }
    return out;
  }
}

/// Left rail: banner, overlapping avatar, identity, stats (profile sidebar).
class MemberProfileSidebar extends StatelessWidget {
  const MemberProfileSidebar({
    super.key,
    required this.name,
    this.headline,
    this.roleLabel,
    this.photoUrl,
    this.badges = const [],
    this.metaLines = const [],
    this.stats = const [],
    this.footer,
    this.onEditPhoto,
    this.bannerAccent,
  });

  final String name;
  final String? headline;
  final String? roleLabel;
  final String? photoUrl;
  final List<MemberProfileBadge> badges;
  final List<MemberProfileMetaLine> metaLines;
  final List<MemberProfileStat> stats;
  final Widget? footer;
  final VoidCallback? onEditPhoto;
  final Color? bannerAccent;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final accent = bannerAccent ?? rc.primary;

    return MemberProfileSectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: SizedBox(
              height: 88,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [rc.tint, accent.withValues(alpha: 0.18), rc.tint.withValues(alpha: 0.45)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: rc.tint,
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                        child: photoUrl == null
                            ? Text(
                                memberProfileInitials(name),
                                style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: rc.primary),
                              )
                            : null,
                      ),
                      if (onEditPhoto != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: FigmaColors.navy,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: onEditPhoto,
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(7),
                                child: Icon(Icons.photo_camera_outlined, size: 16, color: FigmaColors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
                ),
                if (headline != null && headline!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    headline!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray700),
                  ),
                ],
                if (roleLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(roleLabel!, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
                ],
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: badges.map((b) => _BadgeChip(badge: b)).toList(),
                  ),
                ],
                if (metaLines.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final line in metaLines) ...[
                    _MetaLine(line: line),
                    if (line != metaLines.last) const SizedBox(height: 8),
                  ],
                ],
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: FigmaColors.gray200),
                  const SizedBox(height: 16),
                  MemberProfileStatGrid(stats: stats),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 16),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MemberProfileBadge {
  const MemberProfileBadge({required this.label, this.icon, this.background, this.foreground});

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
}

class MemberProfileMetaLine {
  const MemberProfileMetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class MemberProfileStat {
  const MemberProfileStat({required this.value, required this.label, this.icon, this.iconColor});

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final MemberProfileBadge badge;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final bg = badge.background ?? rc.tint;
    final fg = badge.foreground ?? rc.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge.icon != null) ...[
            Icon(badge.icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(badge.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.line});

  final MemberProfileMetaLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(line.icon, size: 15, color: FigmaColors.gray500),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            line.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
          ),
        ),
      ],
    );
  }
}

class MemberProfileStatGrid extends StatelessWidget {
  const MemberProfileStatGrid({super.key, required this.stats});

  final List<MemberProfileStat> stats;

  static const _gap = 10.0;
  static const _cellMinHeight = 84.0;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += 2) {
      final left = stats[i];
      final right = i + 1 < stats.length ? stats[i + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: _gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _MemberProfileStatCell(stat: left)),
              const SizedBox(width: _gap),
              Expanded(
                child: right != null
                    ? _MemberProfileStatCell(stat: right)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _MemberProfileStatCell extends StatelessWidget {
  const _MemberProfileStatCell({required this.stat});

  final MemberProfileStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: MemberProfileStatGrid._cellMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (stat.icon != null) ...[
            Icon(stat.icon, size: 16, color: stat.iconColor ?? FigmaColors.navy),
            const SizedBox(height: 3),
          ],
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: FigmaColors.gray900, height: 1.15),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 10, color: FigmaColors.gray600, height: 1.15),
          ),
        ],
      ),
    );
  }
}

/// Main column section (Overview, Skills, Reviews, …).
class MemberProfileSectionCard extends StatelessWidget {
  const MemberProfileSectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: MemberProfileSectionHeader(title: title!, icon: icon, trailing: trailing),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class MemberProfileSectionHeader extends StatelessWidget {
  const MemberProfileSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.filledIcon = false,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final bool filledIcon;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: filledIcon ? rc.primary : rc.tint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: filledIcon ? rc.onPrimary : rc.primary),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Uniform Edit control for profile section headers (fixed 72×34).
class MemberProfileSectionEditButton extends StatelessWidget {
  const MemberProfileSectionEditButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const double width = 72;
  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: rc.primary,
          side: BorderSide(color: rc.primary),
          padding: EdgeInsets.zero,
          minimumSize: const Size(width, height),
          fixedSize: const Size(width, height),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Uniform Add control for profile section headers (fixed 34×34, plus icon).
class MemberProfileSectionAddButton extends StatelessWidget {
  const MemberProfileSectionAddButton({super.key, required this.onPressed, this.tooltip = 'Add'});

  final VoidCallback onPressed;
  final String tooltip;

  static const double width = 34;
  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: rc.primary,
            side: BorderSide(color: rc.primary),
            padding: EdgeInsets.zero,
            minimumSize: const Size(width, height),
            fixedSize: const Size(width, height),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Icon(Icons.add, size: 20, color: rc.primary),
        ),
      ),
    );
  }
}

Widget? memberProfileSectionHeaderAction({
  required bool hasContent,
  VoidCallback? onAdd,
  VoidCallback? onEdit,
}) {
  if (!hasContent && onAdd != null) {
    return MemberProfileSectionAddButton(onPressed: onAdd);
  }
  if (hasContent && onEdit != null) {
    return MemberProfileSectionEditButton(onPressed: onEdit);
  }
  return null;
}

/// Horizontal stat row below hero on public provider main column.
class MemberProfileStatStrip extends StatelessWidget {
  const MemberProfileStatStrip({super.key, required this.items});

  final List<({IconData icon, String value, String label})> items;

  @override
  Widget build(BuildContext context) {
    return MemberProfileSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: LayoutBuilder(
        builder: (context, c) {
          final perRow = c.maxWidth >= 560 ? items.length.clamp(2, 4) : 2;
          final spacing = 12.0;
          final itemW = (c.maxWidth - spacing * (perRow - 1)) / perRow;
          return Wrap(
            spacing: spacing,
            runSpacing: 16,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, size: 18, color: FigmaColors.gray500),
                      const SizedBox(height: 6),
                      Text(item.value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(item.label, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class MemberProfileReviewsSection extends StatefulWidget {
  const MemberProfileReviewsSection({
    super.key,
    required this.reviews,
    required this.averageRating,
    this.maxListItems = 6,
    this.emptyMessage = 'No reviews yet.',
  });

  final List<Review> reviews;
  final double averageRating;
  final int maxListItems;
  final String emptyMessage;

  @override
  State<MemberProfileReviewsSection> createState() => _MemberProfileReviewsSectionState();
}

class _MemberProfileReviewsSectionState extends State<MemberProfileReviewsSection> {
  Future<Map<String, String>>? _serviceTitlesFuture;
  String? _serviceTitlesKey;

  @override
  void initState() {
    super.initState();
    _ensureServiceTitles();
  }

  @override
  void didUpdateWidget(covariant MemberProfileReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureServiceTitles();
  }

  void _ensureServiceTitles() {
    final key = widget.reviews.map((r) => r.serviceId).toSet().join('|');
    if (key == _serviceTitlesKey && _serviceTitlesFuture != null) return;
    _serviceTitlesKey = key;
    _serviceTitlesFuture = FirestoreService().serviceTitlesByIds(
      widget.reviews.map((r) => r.serviceId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviews = widget.reviews;
    final counts = List<int>.filled(5, 0);
    for (final r in reviews) {
      final idx = r.rating.round().clamp(1, 5) - 1;
      counts[idx]++;
    }
    final sentiments = countReviewSentiments(reviews);

    return MemberProfileSectionCard(
      title: 'Ratings & reviews',
      icon: Icons.star_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 420;
              final avgBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.averageRating > 0 ? widget.averageRating.toStringAsFixed(1) : '—',
                    style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                  ),
                ],
              );
              final bars = Column(
                children: [
                  for (var star = 5; star >= 1; star--)
                    _RatingBar(star: star, count: counts[star - 1], total: reviews.length),
                ],
              );
              if (stacked) return Column(children: [avgBlock, const SizedBox(height: 12), bars]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [avgBlock, const SizedBox(width: 24), Expanded(child: bars)],
              );
            },
          ),
          if (!sentiments.isEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sentiments.positive > 0)
                  _SentimentSummaryChip(label: 'Positive', count: sentiments.positive, color: FigmaColors.green, bg: FigmaColors.tintGreen),
                if (sentiments.neutral > 0)
                  _SentimentSummaryChip(label: 'Neutral', count: sentiments.neutral, color: FigmaColors.gray700, bg: FigmaColors.gray100),
                if (sentiments.negative > 0)
                  _SentimentSummaryChip(label: 'Negative', count: sentiments.negative, color: FigmaColors.red600, bg: FigmaColors.red50),
              ],
            ),
          ],
          if (reviews.isEmpty) ...[
            const SizedBox(height: 20),
            Text(
              widget.emptyMessage,
              style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45),
            ),
          ] else ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: FigmaColors.gray200),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, String>>(
              future: _serviceTitlesFuture,
              builder: (context, titlesSnap) {
                final titles = titlesSnap.data ?? const <String, String>{};
                return Column(
                  children: [
                    for (final r in reviews.take(widget.maxListItems))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ReviewTile(
                          review: r,
                          jobLabel: formatReviewJobLabel(
                            review: r,
                            serviceTitle: titles[r.serviceId],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SentimentSummaryChip extends StatelessWidget {
  const _SentimentSummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });

  final String label;
  final int count;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label · $count',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.star, required this.count, required this.total});

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$star', style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
          const SizedBox(width: 2),
          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFEAB308)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
                backgroundColor: FigmaColors.gray100,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEAB308)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            child: Text('$count', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
          ),
        ],
      ),
    );
  }
}

class MemberProfileTimelineSection extends StatelessWidget {
  const MemberProfileTimelineSection({
    super.key,
    required this.title,
    required this.entries,
    this.icon = Icons.work_outline,
    this.emptyMessage = 'Nothing added yet.',
    this.onAdd,
    this.onEdit,
  });

  final String title;
  final IconData icon;
  final List<String> entries;
  final String emptyMessage;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return MemberProfileSectionCard(
      title: title,
      icon: icon,
      trailing: memberProfileSectionHeaderAction(
        hasContent: entries.isNotEmpty,
        onAdd: onAdd,
        onEdit: onEdit,
      ),
      child: entries.isEmpty
          ? Text(emptyMessage, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45))
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: FigmaColors.gray200),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(color: rc.primary, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(entries[i], style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800, height: 1.45)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class MemberProfileCertificationsSection extends StatelessWidget {
  const MemberProfileCertificationsSection({
    super.key,
    required this.certifications,
    this.onAdd,
    this.onEdit,
    this.onDelete,
  });

  final List<ProviderCertificationEntry> certifications;
  final VoidCallback? onAdd;
  final void Function(int index)? onEdit;
  final void Function(int index)? onDelete;

  @override
  Widget build(BuildContext context) {
    return MemberProfileSectionCard(
      title: 'Certifications',
      icon: Icons.workspace_premium_outlined,
      trailing: memberProfileSectionHeaderAction(
        hasContent: certifications.isNotEmpty,
        onAdd: onAdd,
        onEdit: onEdit != null ? () => onEdit!(0) : null,
      ),
      child: certifications.isEmpty
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_outlined, size: 40, color: FigmaColors.gray300),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Listing your certifications can help prove your qualifications and build trust with customers.',
                    style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                for (var i = 0; i < certifications.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: FigmaColors.gray200),
                  _CertificationCard(
                    entry: certifications[i],
                    onEdit: onEdit != null ? () => onEdit!(i) : null,
                    onDelete: onDelete != null ? () => onDelete!(i) : null,
                  ),
                ],
              ],
            ),
    );
  }
}

class _CertificationStatusChip extends StatelessWidget {
  const _CertificationStatusChip({required this.status});

  final CertificationVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case CertificationVerificationStatus.approved:
        bg = FigmaColors.tintGreen;
        fg = FigmaColors.green;
        label = 'Authenticated';
      case CertificationVerificationStatus.rejected:
        bg = FigmaColors.red50;
        fg = FigmaColors.red600;
        label = 'Rejected';
      case CertificationVerificationStatus.pending:
        bg = FigmaColors.orange50;
        fg = FigmaColors.orange600;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _CertificationCard extends StatelessWidget {
  const _CertificationCard({
    required this.entry,
    this.onEdit,
    this.onDelete,
  });

  final ProviderCertificationEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: rc.tint, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.card_membership_outlined, color: rc.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CertificationStatusChip(status: entry.status),
                ],
              ),
              if (entry.subtitleLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entry.subtitleLine, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
              ],
              if (entry.isRejected && entry.rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Rejected: ${entry.rejectionReason}',
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.red600, height: 1.35),
                ),
              ] else if (entry.isPending) ...[
                const SizedBox(height: 6),
                Text(
                  'Awaiting Verification Agency authentication',
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.orange600),
                ),
              ],
            ],
          ),
        ),
        if (onEdit != null || onDelete != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 20, color: rc.primary),
                  tooltip: 'Edit',
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20, color: FigmaColors.gray500),
                  tooltip: 'Delete',
                ),
            ],
          ),
      ],
    );
  }
}

class MemberProfilePortfolioSection extends StatelessWidget {
  const MemberProfilePortfolioSection({
    super.key,
    this.urls = const [],
    this.projects = const [],
    this.onAdd,
    this.onEdit,
  });

  final List<String> urls;
  final List<ProviderPortfolioProject> projects;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final published = projects.where((p) => !p.isDraft && p.thumbnailUrl.isNotEmpty).toList();
    final hasContent = published.isNotEmpty || urls.isNotEmpty;

    return MemberProfileSectionCard(
      title: 'Portfolio',
      icon: Icons.photo_library_outlined,
      trailing: memberProfileSectionHeaderAction(
        hasContent: hasContent,
        onAdd: onAdd,
        onEdit: onEdit,
      ),
      child: published.isEmpty && urls.isEmpty
          ? Text('Add photos of your work to help customers trust your skills.', style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45))
          : LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 500 ? 3 : 2;
                final gap = 10.0;
                final cell = (c.maxWidth - gap * (cols - 1)) / cols;
                if (published.isNotEmpty) {
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final p in published)
                        _PortfolioProjectTile(
                          width: cell,
                          height: cell * 0.85,
                          title: p.title.isNotEmpty ? p.title : 'Portfolio',
                          imageUrl: p.thumbnailUrl,
                        ),
                    ],
                  );
                }
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final url in urls)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: cell,
                          height: cell * 0.72,
                          child: FigmaNetworkImage(url: url, fit: BoxFit.cover),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _PortfolioProjectTile extends StatelessWidget {
  const _PortfolioProjectTile({
    required this.width,
    required this.height,
    required this.title,
    required this.imageUrl,
  });

  final double width;
  final double height;
  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: width,
              height: height,
              child: FigmaNetworkImage(url: imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
          ),
        ],
      ),
    );
  }
}

class MemberProfileOverviewSection extends StatelessWidget {
  const MemberProfileOverviewSection({
    super.key,
    required this.body,
    this.onEdit,
    this.tags = const [],
    this.accountUser,
  });

  final String body;
  final VoidCallback? onEdit;
  final List<String> tags;
  /// When set, email/phone rows appear under the overview bio (provider profile).
  final AppUser? accountUser;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final user = accountUser;
    return MemberProfileSectionCard(
      title: 'Overview',
      icon: Icons.article_outlined,
      trailing: onEdit != null ? MemberProfileSectionEditButton(onPressed: onEdit!) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bio',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 8),
          Text(body, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.55)),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Work style',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: rc.tint, borderRadius: BorderRadius.circular(20)),
                      child: Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: rc.primary)),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (user != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: FigmaColors.gray200),
            const SizedBox(height: 16),
            Text(
              'Account Details',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
            ),
            const SizedBox(height: 12),
            if (user.fullName.trim().isNotEmpty) ...[
              MemberProfileAccountField(
                label: 'Full name',
                value: user.fullName,
                verified: false,
              ),
              const SizedBox(height: 16),
            ],
            MemberProfileAccountField(
              label: 'Email',
              value: user.email,
              verified: user.email.isNotEmpty,
            ),
            if (user.contactNumber != null && user.contactNumber!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              MemberProfileAccountField(
                label: 'Phone',
                value: user.contactNumber!.trim(),
                verified: true,
              ),
            ],
            const SizedBox(height: 16),
            MemberProfileAccountField(
              label: 'Address',
              value: memberProfileLocation(user),
              verified: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// Read-only social / web links for public provider profiles.
class MemberProfileLinkedAccountsSection extends StatelessWidget {
  const MemberProfileLinkedAccountsSection({super.key, required this.accounts});

  final Map<String, String> accounts;

  static const _labels = <String, String>{
    'facebook': 'Facebook',
    'instagram': 'Instagram',
    'linkedin': 'LinkedIn',
    'other': 'Website',
  };

  static IconData _iconFor(String key) {
    switch (key) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'linkedin':
        return Icons.work_outline;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final entries = accounts.entries.where((e) => e.value.trim().isNotEmpty).toList();
    return MemberProfileSectionCard(
      title: 'Links',
      icon: Icons.link_outlined,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: FigmaColors.gray200),
            InkWell(
              onTap: () {
                final uri = Uri.tryParse(entries[i].value.trim());
                if (uri != null) {
                  // ignore: unawaited_futures
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(_iconFor(entries[i].key), size: 20, color: rc.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _labels[entries[i].key] ?? entries[i].key,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            entries[i].value.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 16, color: FigmaColors.gray400),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MemberProfileAccountField extends StatelessWidget {
  const MemberProfileAccountField({
    super.key,
    required this.label,
    required this.value,
    required this.verified,
  });

  final String label;
  final String value;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: FigmaColors.gray900)),
              if (verified) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.verified, size: 14, color: rc.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: rc.primary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class MemberProfileSettingsList extends StatelessWidget {
  const MemberProfileSettingsList({super.key, required this.tiles});

  final List<MemberProfileSettingsTile> tiles;

  @override
  Widget build(BuildContext context) {
    return MemberProfileSectionCard(
      title: 'Settings',
      icon: Icons.settings_outlined,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56, color: FigmaColors.gray100),
            tiles[i],
          ],
        ],
      ),
    );
  }
}

class MemberProfileSettingsTile extends StatelessWidget {
  const MemberProfileSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: rc.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FigmaColors.gray400),
          ],
        ),
      ),
    );
  }
}

String memberProfileInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String memberProfileMemberSince(DateTime date) {
  return DateFormat('MMMM yyyy').format(date);
}

String memberProfileLocation(AppUser user) {
  if (user.address?.trim().isNotEmpty == true) return user.address!.trim();
  return 'Panabo City, Davao del Norte';
}
