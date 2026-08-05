import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/demo/ranking_demo_providers.dart';

void main() {
  test('demo pack has at least 5 verified sample providers', () {
    final pack = buildRankingDemoPack();
    expect(pack.profiles.length, greaterThanOrEqualTo(5));
    expect(pack.profiles.every((p) => p.isVerifiedProvider), isTrue);
    expect(pack.profiles.every((p) => isRankingDemoProviderId(p.providerId)), isTrue);
  });

  test('ranking demos merge with live list without dropping live providers', () {
    final ranked = rankProvidersWithRankingDemos(liveProviders: const []);
    expect(ranked.length, greaterThanOrEqualTo(5));
    expect(ranked.every((r) => isRankingDemoProviderId(r.profile.providerId)), isTrue);
  });

  test('nearby experienced demo outranks farthest cold-start demo', () {
    final ranked = rankProvidersWithRankingDemos(liveProviders: const []);
    expect(ranked.length, 6);
    final byId = {for (final r in ranked) r.profile.providerId: r};
    final ana = byId['${kRankingDemoProviderIdPrefix}ana_nearby']!;
    final felix = byId['${kRankingDemoProviderIdPrefix}felix_far_new']!;
    expect(ana.rank, lessThan(felix.rank));
  });
}
