import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../theme/role_theme.dart';
import '../../figma_ui/widgets/figma_empty_state.dart';
import '../../models/app_user.dart';
import '../../models/provider.dart';
import '../../models/review.dart';
import '../../services/firestore_service.dart';
import '../../services/provider_recommendation_service.dart';
import '../../utils/review_sentiment.dart';
import '../../widgets/customer_provider_profile_dialog.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/loading_indicator.dart';

class CustomerProvidersListScreen extends StatefulWidget {
  const CustomerProvidersListScreen({super.key, required this.appUser, this.initialQuery = ''});

  final AppUser appUser;
  final String initialQuery;

  @override
  State<CustomerProvidersListScreen> createState() => _CustomerProvidersListScreenState();
}

class _CustomerProvidersListScreenState extends State<CustomerProvidersListScreen> {
  late final TextEditingController _search;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery.trim().toLowerCase();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: AppTabBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Find providers',
                subtitle: 'Verified providers ranked by recommendation score',
                onBack: () => Navigator.pop(context),
              ),
              AppSearchField(
                controller: _search,
                hint: 'Search by name or service area…',
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 24),
              StreamBuilder<List<ServiceProviderProfile>>(
                stream: firestore.serviceProvidersStream(),
                builder: (context, providerSnap) {
                  if (providerSnap.connectionState == ConnectionState.waiting) {
                    return const LoadingIndicator(message: 'Loading providers…');
                  }
                  return StreamBuilder<List<AppUser>>(
                    stream: firestore.allUsersStream(),
                    builder: (context, userSnap) {
                      final users = {
                        for (final u in userSnap.data ?? []) u.userId: u,
                      };
                      var ranked = rankProvidersByRecommendation(
                        providers: providerSnap.data ?? const [],
                        customerOrigin: widget.appUser.location,
                      );
                      if (_query.isNotEmpty) {
                        ranked = ranked.where((r) {
                          final user = users[r.profile.userId];
                          final name = user?.fullName.toLowerCase() ?? '';
                          final area = r.profile.serviceArea.toLowerCase();
                          return name.contains(_query) || area.contains(_query);
                        }).toList();
                      }
                      if (ranked.isEmpty) {
                        return const FigmaEmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'No providers found',
                          message: 'Try another search or check back later.',
                        );
                      }
                      return Column(
                        children: [
                          for (final r in ranked) ...[
                            _ProviderTile(
                              profile: r.profile,
                              user: users[r.profile.userId],
                              isAvailableNow: r.isAvailable,
                              isNewProvider: r.isNewProvider,
                              rank: r.rank,
                              onTap: () {
                                showCustomerProviderProfileDialog(
                                  context,
                                  appUser: widget.appUser,
                                  providerId: r.profile.providerId,
                                  providerUser: users[r.profile.userId],
                                  providerProfile: r.profile,
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.profile,
    required this.user,
    required this.onTap,
    required this.isAvailableNow,
    required this.isNewProvider,
    required this.rank,
  });

  final ServiceProviderProfile profile;
  final AppUser? user;
  final VoidCallback onTap;
  final bool isAvailableNow;
  final bool isNewProvider;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'Provider';

    return AppSurfaceCard(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: rc.primary,
              ),
            ),
          ),
          CircleAvatar(
            radius: 28,
            backgroundColor: rc.tint,
            backgroundImage: user?.profilePhotoUrl != null ? NetworkImage(user!.profilePhotoUrl!) : null,
            child: user?.profilePhotoUrl == null
                ? Text(name[0].toUpperCase(), style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: rc.primary))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600))),
                    if (profile.isVerifiedProvider) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 18, color: FigmaColors.green),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  profile.serviceArea.isEmpty ? 'Service area not set' : profile.serviceArea,
                  style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                ),
                const SizedBox(height: 6),
                StreamBuilder<List<Review>>(
                  stream: FirestoreService().reviewsForProviderStream(profile.userId),
                  builder: (context, snap) {
                    final reviews = snap.data ?? const <Review>[];
                    final rating = effectiveProviderRating(
                      profileAverage: profile.averageRating,
                      reviews: reviews,
                    );
                    final showNew = isNewProvider || rating <= 0;
                    return Text.rich(
                      TextSpan(
                        style: GoogleFonts.inter(fontSize: 13, color: rc.primary, fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(
                            text: showNew ? 'New · ' : '★ ${rating.toStringAsFixed(1)} · ',
                          ),
                          TextSpan(
                            text: isAvailableNow ? 'Available now' : 'Unavailable',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isAvailableNow ? FigmaColors.green : FigmaColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: FigmaColors.gray400),
        ],
      ),
    );
  }
}
