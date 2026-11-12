import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/booking.dart';
import '../../../models/review.dart';
import 'admin_report_count_chart.dart';
import 'admin_dashboard_widgets.dart';

class AdminFeedbackLocationReports extends StatelessWidget {
  const AdminFeedbackLocationReports({
    super.key,
    required this.bookings,
    required this.range,
    required this.reviews,
    required this.periodLabel,
  });
  final List<Booking> bookings;
  final String range, periodLabel;
  final List<Review> reviews;
  @override
  Widget build(BuildContext context) {
    final docs = {
      for (final r in reviews)
        if (r.isCustomerReview) r.reviewId: r,
    }.values;
    final counts = {
      'positive': 0,
      'neutral': 0,
      'negative': 0,
      'Unanalyzed': 0,
    };
    var lstm = 0, linear = 0, fallback = 0, pending = 0;
    final providers = <String, Map<String, int>>{};
    for (final doc in docs) {
      final label = doc.normalizedSentimentLabel;
      if (const ['positive', 'neutral', 'negative'].contains(label)) {
        counts[label] = counts[label]! + 1;
        final perProvider = providers.putIfAbsent(
          doc.providerId,
          () => {'positive': 0, 'neutral': 0, 'negative': 0},
        );
        perProvider[label] = perProvider[label]! + 1;
        if (doc.sentimentSource == 'lstm') {
          lstm++;
        } else if (doc.sentimentSource == 'tfidf_logistic') {
          linear++;
        } else {
          fallback++;
        }
      } else {
        pending++;
        counts['Unanalyzed'] = counts['Unanalyzed']! + 1;
      }
    }
    final cells = <String, List<Booking>>{};
    for (final b in bookings) {
      if (b.location.latitude == 0 && b.location.longitude == 0) continue;
      final key =
          '${b.location.latitude.toStringAsFixed(2)},${b.location.longitude.toStringAsFixed(2)}';
      cells.putIfAbsent(key, () => []).add(b);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelCard(
          title: 'Customer feedback sentiment',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reviews submitted in $periodLabel. $lstm LSTM results, $linear linear-model results, $fallback fallback/other results, $pending without an analyzed comment.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    for (final entry in counts.entries)
                      Text(
                        '${entry.key}: ${entry.value} (${docs.isEmpty ? '0.0' : (entry.value * 100 / docs.length).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                AdminReportCountChart(
                  labels: counts.keys.toList(),
                  series: const ['Reviews'],
                  values: [
                    for (final value in counts.values) [value],
                  ],
                  periodLabel: periodLabel,
                ),
                const SizedBox(height: 12),
                for (final provider in providers.entries.take(20))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Provider ${provider.key}: ${provider.value['positive']} positive, ${provider.value['neutral']} neutral, ${provider.value['negative']} negative',
                    ),
                  ),
                const Text(
                  'Sentiment results do not change provider ranking scores.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AdminPanelCard(
          title: 'Service demand by location',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bookings requested in $periodLabel, grouped into approximately 1 km map cells. Tap a marker for booking counts.',
                ),
                Text(
                  '${cells.values.fold<int>(0, (n, cell) => n + cell.length)} of ${bookings.length} bookings have map locations. Percentages use all filtered bookings.',
                  style: const TextStyle(fontSize: 12),
                ),
                if (cells.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No booking locations are available for this period.',
                    ),
                  )
                else ...[
                  const SizedBox(height: 12),
                  Text(
                    'Top ${cells.length.clamp(0, 10)} of ${cells.length} demand areas',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(
                    height: 320,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          cells.values.first.first.location.latitude,
                          cells.values.first.first.location.longitude,
                        ),
                        zoom: 12,
                      ),
                      markers: {
                        for (final cell in cells.entries)
                          Marker(
                            markerId: MarkerId(cell.key),
                            position: LatLng(
                              double.parse(cell.key.split(',').first),
                              double.parse(cell.key.split(',').last),
                            ),
                            infoWindow: InfoWindow(
                              title:
                                  '${cell.value.length} bookings (${(cell.value.length * 100 / bookings.length).toStringAsFixed(1)}%)',
                              snippet: cell.value.first.serviceLocation,
                            ),
                          ),
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final cell
                      in (cells.entries.toList()..sort(
                            (a, b) => b.value.length.compareTo(a.value.length),
                          ))
                          .take(10))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${cell.value.length} bookings (${(cell.value.length * 100 / bookings.length).toStringAsFixed(1)}%) near ${cell.value.first.serviceLocation}',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
