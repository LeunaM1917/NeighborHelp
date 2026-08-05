import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../demo/job_title_ranking_demos.dart';
import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/provider_recommendation_service.dart';
import '../../../utils/weighted_scoring.dart';
import '../../../widgets/loading_indicator.dart';
import '../widgets/admin_widgets.dart';

/// Default customer origin for Admin distance (P) scoring — Panabo City approx.
const GeoPoint _kAdminRankingOrigin = GeoPoint(7.3081, 125.6822);

/// Admin page: RS inputs (Distance, Rating, Availability, Completion) + live what-if re-rank.
class AdminRecommendationRankingPage extends StatefulWidget {
  const AdminRecommendationRankingPage({
    super.key,
    required this.auth,
  });

  final AuthService auth;

  @override
  State<AdminRecommendationRankingPage> createState() => _AdminRecommendationRankingPageState();
}

class _SimOverride {
  double? rating;
  int? reviewCount;
  bool? available;
  int? completed;
  int? accepted;
}

class _AdminRecommendationRankingPageState extends State<AdminRecommendationRankingPage> {
  final _overrides = <String, _SimOverride>{};
  String? _selectedId;
  final GeoPoint _origin = _kAdminRankingOrigin;

  _SimOverride _overrideFor(String id) => _overrides.putIfAbsent(id, _SimOverride.new);

  Future<void> _applyRatingToFirestore(ServiceProviderProfile profile, double rating) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply rating to Firestore?'),
        content: Text(
          'This writes averageRating=${rating.toStringAsFixed(1)} on ${profile.providerId} '
          'so Customer Nearby / job-title lists re-rank after refresh. Use for panel demos only.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirestoreService().updateServiceProvider(
        providerId: profile.providerId,
        data: {
          'averageRating': rating,
          if ((_overrideFor(profile.providerId).reviewCount ?? profile.reviewCount) > 0)
            'reviewCount': _overrideFor(profile.providerId).reviewCount ?? profile.reviewCount,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved. Open Customer Nearby / Ceiling Repair to see new order.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  List<_RankRow> _buildRows({
    required List<ServiceProviderProfile> providers,
    required Map<String, AppUser> users,
  }) {
    final rows = <_RankRow>[];
    for (final profile in providers) {
      if (!profile.isVerifiedProvider) continue;
      final o = _overrides[profile.providerId];
      final breakdown = breakdownForProvider(
        profile: profile,
        customerOrigin: _origin,
        ratingOverride: o?.rating,
        reviewCountOverride: o?.reviewCount,
        availableOverride: o?.available,
        completedOverride: o?.completed,
        acceptedOverride: o?.accepted,
      );
      // Filter like live ranking when within radius
      if (breakdown.distanceKm > kDefaultMaxSearchRadiusKm) continue;
      rows.add(
        _RankRow(
          profile: profile,
          user: users[profile.userId],
          breakdown: breakdown,
        ),
      );
    }
    rows.sort((a, b) => b.breakdown.recommendationScore.compareTo(a.breakdown.recommendationScore));
    return [
      for (var i = 0; i < rows.length; i++)
        _RankRow(
          profile: rows[i].profile,
          user: rows[i].user,
          breakdown: rows[i].breakdown,
          rank: i + 1,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        title: 'Recommendation ranking',
        subtitle: 'Connect Firebase Admin to score live providers.',
        child: const AdminErrorBox(message: 'Local admin cannot stream Firestore providers.'),
      );
    }

    final firestore = FirestoreService();
    return AdminPageFrame(
      title: 'Recommendation ranking',
      subtitle: 'RS = 0.40×P + 0.30×R + 0.20×A + 0.10×C · change a factor below to watch the list re-sort',
      child: StreamBuilder<List<ServiceProviderProfile>>(
        stream: firestore.serviceProvidersStream(),
        builder: (context, providerSnap) {
          return StreamBuilder<List<AppUser>>(
            stream: firestore.allUsersStream(),
            builder: (context, userSnap) {
              if (!providerSnap.hasData || !userSnap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: LoadingIndicator(message: 'Loading ranking inputs…'),
                );
              }
              final users = {for (final u in userSnap.data!) u.userId: u};
              final live = providerSnap.data ?? const <ServiceProviderProfile>[];
              // Same 4 Ceiling Repair UI demos as the customer job-title modal (no other sample packs).
              final ceilingDemos = jobTitleRankingDemosFor('Ceiling Repair');
              final mergedProfiles = <ServiceProviderProfile>[
                ...live,
                if (ceilingDemos != null) ...ceilingDemos.profiles.values,
              ];
              final allUsers = <String, AppUser>{
                ...users,
                if (ceilingDemos != null) ...ceilingDemos.users,
              };
              final rows = _buildRows(providers: mergedProfiles, users: allUsers);
              _RankRow? selected;
              for (final r in rows) {
                if (r.profile.providerId == _selectedId) {
                  selected = r;
                  break;
                }
              }
              selected ??= rows.isEmpty ? null : rows.first;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Origin for distance (P): Panabo City. Live verified providers plus the 4 Ceiling Repair '
                    'demo peers (1 rated + 3 new). Other sample packs are not included.',
                    style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  AdminMetricGrid(
                    children: [
                      _metric('${rows.length}', 'In ranking'),
                      _metric(
                        rows.isEmpty ? '—' : '#1 ${rows.first.user?.fullName.split(' ').first ?? '—'}',
                        'Top RS',
                      ),
                      _metric('40/30/20/10', 'Weights P/R/A/C'),
                      _metric('15 km', 'Search radius'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 1000;
                      final table = _RankingTable(
                        rows: rows,
                        selectedId: selected?.profile.providerId,
                        onSelect: (id) => setState(() => _selectedId = id),
                      );
                      final sel = selected;
                      final isDemo = sel != null && isJobTitleDemoProviderId(sel.profile.providerId);
                      final detail = sel == null
                          ? const SizedBox.shrink()
                          : _WhatIfPanel(
                              row: sel,
                              sim: _overrideFor(sel.profile.providerId),
                              onChanged: () => setState(() {}),
                              onApplyFirestore: isDemo
                                  ? null
                                  : () => _applyRatingToFirestore(
                                        sel.profile,
                                        _overrideFor(sel.profile.providerId).rating ??
                                            sel.profile.averageRating,
                                      ),
                              onReset: () {
                                setState(() => _overrides.remove(sel.profile.providerId));
                              },
                            );
                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [table, const SizedBox(height: 16), detail],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: table),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: detail),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
        ],
      ),
    );
  }
}

class _RankRow {
  const _RankRow({
    required this.profile,
    required this.user,
    required this.breakdown,
    this.rank = 0,
  });

  final ServiceProviderProfile profile;
  final AppUser? user;
  final WeightedScoreBreakdown breakdown;
  final int rank;
}

class _RankingTable extends StatelessWidget {
  const _RankingTable({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_RankRow> rows;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
          dataTextStyle: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray900),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Provider')),
            DataColumn(label: Text('Distance')),
            DataColumn(label: Text('Rating')),
            DataColumn(label: Text('Available')),
            DataColumn(label: Text('Completion')),
            DataColumn(label: Text('RS')),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                selected: r.profile.providerId == selectedId,
                onSelectChanged: (_) => onSelect(r.profile.providerId),
                cells: [
                  DataCell(Text('${r.rank}')),
                  DataCell(
                    Text(
                      '${r.user?.fullName ?? 'Provider'}'
                      '${isJobTitleDemoProviderId(r.profile.providerId) ? ' · Demo' : ''}',
                    ),
                  ),
                  DataCell(Text('${r.breakdown.distanceKm.toStringAsFixed(1)} km')),
                  DataCell(Text(r.breakdown.bayesianRatingOutOfFive.toStringAsFixed(1))),
                  DataCell(Text(r.breakdown.isAvailable ? 'Yes' : 'No')),
                  DataCell(Text('${(r.breakdown.completionRateDisplay * 100).round()}%')),
                  DataCell(
                    Text(
                      '${r.breakdown.scorePercent}%',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: FigmaColors.navy),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WhatIfPanel extends StatelessWidget {
  const _WhatIfPanel({
    required this.row,
    required this.sim,
    required this.onChanged,
    required this.onReset,
    this.onApplyFirestore,
  });

  final _RankRow row;
  final _SimOverride sim;
  final VoidCallback onChanged;
  final VoidCallback onReset;
  final VoidCallback? onApplyFirestore;

  @override
  Widget build(BuildContext context) {
    final b = row.breakdown;
    final rating = sim.rating ?? row.profile.averageRating;
    final available = sim.available ?? b.isAvailable;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What-if simulation',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            row.user?.fullName ?? 'Provider',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
          ),
          const SizedBox(height: 12),
          Text(
            'P=${b.proximity.toStringAsFixed(2)} · R=${b.rating.toStringAsFixed(2)} · '
            'A=${b.availability.toStringAsFixed(0)} · C=${b.completion.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray700, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'RS = 0.40×P + 0.30×R + 0.20×A + 0.10×C = ${b.recommendationScore.toStringAsFixed(3)} '
            '(${b.scorePercent}%)',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.navy),
          ),
          const SizedBox(height: 16),
          Text('Simulated rating (1–5)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
          Slider(
            value: rating.clamp(1, 5),
            min: 1,
            max: 5,
            divisions: 40,
            label: rating.toStringAsFixed(1),
            onChanged: (v) {
              sim.rating = v;
              sim.reviewCount ??= (row.profile.reviewCount > 0 ? row.profile.reviewCount : 10);
              onChanged();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available now'),
            value: available,
            onChanged: (v) {
              sim.available = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: onReset, child: const Text('Reset simulation')),
              if (onApplyFirestore != null)
                FilledButton(
                  onPressed: onApplyFirestore,
                  child: const Text('Apply rating to Firestore'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Move the rating slider or toggle availability — the table re-sorts immediately. '
            'That proves ranking is computed, not hardcoded.',
            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600, height: 1.4),
          ),
        ],
      ),
    );
  }
}
