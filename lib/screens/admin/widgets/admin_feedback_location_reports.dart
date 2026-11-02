import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/booking.dart';
import '../../../models/review.dart';
import '../../../utils/report_analytics.dart';
import '../../../figma_ui/figma_colors.dart';
import 'admin_dashboard_widgets.dart';

class AdminFeedbackLocationReports extends StatelessWidget {
  const AdminFeedbackLocationReports({
    super.key,
    required this.bookings,
    required this.range,
  });
  final List<Booking> bookings;
  final String range;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('reviews').snapshots(),
    builder: (context, snap) {
      if (snap.hasError) {
        return const Text(
          'Feedback reports could not load. Check access and connection.',
        );
      }
      if (!snap.hasData) return const LinearProgressIndicator();
      final docs = snap.data!.docs.where((d) {
        final r = Review.fromFirestore(d.id, d.data());
        return r.isCustomerReview && inReportRange(r.createdAt.toDate(), range);
      }).toList();
      final counts = {'positive': 0, 'neutral': 0, 'negative': 0};
      var lstm = 0, fallback = 0, pending = 0;
      final providers = <String, Map<String, int>>{};
      for (final doc in docs) {
        final row = doc.data();
        final sentiment = row['sentiment'] as Map?;
        final label = sentiment?['label']?.toString();
        if (counts.containsKey(label)) {
          counts[label!] = counts[label]! + 1;
          final perProvider = providers.putIfAbsent(
            '${row['providerId']}',
            () => {'positive': 0, 'neutral': 0, 'negative': 0},
          );
          perProvider[label] = perProvider[label]! + 1;
          if (sentiment?['source'] == 'lstm') {
            lstm++;
          } else {
            fallback++;
          }
        } else {
          pending++;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reviews submitted in $range. $lstm LSTM results, $fallback fallback results, $pending without an analyzed comment.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    for (final entry in counts.entries)
                      Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                if (counts.values.any((n) => n > 0))
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY:
                            counts.values
                                .reduce((a, b) => a > b ? a : b)
                                .toDouble() +
                            1,
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            axisNameWidget: Text('Review count'),
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, _) => Text(
                                counts.keys.elementAt(
                                  value.toInt().clamp(0, 2),
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < 3; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: counts.values.elementAt(i).toDouble(),
                                  color: FigmaColors.green,
                                  width: 24,
                                ),
                              ],
                            ),
                        ],
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                      ),
                    ),
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
          const SizedBox(height: 16),
          AdminPanelCard(
            title: 'Service demand by location',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bookings requested in $range, grouped into approximately 1 km map cells. Marker values show booking counts.',
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
                  SizedBox(
                    height: 320,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          bookings.first.location.latitude,
                          bookings.first.location.longitude,
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
                              title: '${cell.value.length} bookings',
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
                        '${cell.value.length} bookings near ${cell.value.first.serviceLocation}',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}
