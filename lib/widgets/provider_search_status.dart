import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProviderSearchStatus extends StatelessWidget {
  const ProviderSearchStatus({
    super.key,
    required this.candidates,
    required this.matches,
    required this.days,
    required this.hours,
    this.checkedAt,
  });
  final int candidates, matches, days;
  final double hours;
  final DateTime? checkedAt;
  @override
  Widget build(BuildContext context) {
    if (candidates == 0) {
      return const Text(
        'No providers are ready for search yet. Providers need approved certification and selected base and service barangays before they can appear.',
      );
    }
    if (matches == 0) {
      return const Text(
        'No providers matched this schedule and location. Try another date, time, duration or work location.',
      );
    }
    final duration = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toString();
    final checked = checkedAt == null
        ? ''
        : ' Checked ${DateFormat('h:mm a').format(checkedAt!.toUtc().add(const Duration(hours: 8)))} Manila time.';
    return Text(
      '$matches ${matches == 1 ? 'provider is' : 'providers are'} available for all $days ${days == 1 ? 'workday' : 'workdays'}, $duration ${hours == 1 ? 'hour' : 'hours'} each. A 15-minute gap between jobs is included.$checked',
    );
  }
}
