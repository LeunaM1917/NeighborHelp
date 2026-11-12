import 'package:flutter/material.dart';
import '../ui/workflow_ui.dart';
import 'marketplace_service.dart';

DateTime manilaCalendar(DateTime value) {
  final local = value.toUtc().add(const Duration(hours: 8));
  return DateTime(local.year, local.month, local.day, local.hour, local.minute);
}

DateTime manilaInstant(DateTime day, TimeOfDay time) =>
    DateTime.utc(day.year, day.month, day.day, time.hour - 8, time.minute);

/// Matches the server's provider-authored listing estimate; it is never a
/// customer-selected final duration. Available starts come from the server.
double listingDurationHours(String value) {
  final text = value.toLowerCase();
  final range = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:-|–|to)\s*(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?)',
  ).firstMatch(text);
  final hours = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b',
  ).firstMatch(text);
  final minutes = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:minutes?|mins?)\b',
  ).firstMatch(text);
  final parsed = range != null
      ? double.parse(range[2]!) * (range[3]!.startsWith('m') ? 1 / 60 : 1)
      : hours != null || minutes != null
      ? double.parse(hours?[1] ?? '0') + double.parse(minutes?[1] ?? '0') / 60
      : double.tryParse(
              RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(text)?[1] ?? '',
            ) ??
            1;
  return ((parsed * 4).ceil() / 4).clamp(.25, 24).toDouble();
}

/// Contains only available starts, never another customer's booking details.
class BookingAvailability {
  BookingAvailability({
    required this.starts,
    required this.durationHours,
    required this.estimatedTotal,
    required this.pricingType,
    this.hourlyRate,
  });
  final List<DateTime> starts;
  final double durationHours, estimatedTotal;
  final String pricingType;
  final double? hourlyRate;
  factory BookingAvailability.fromMap(Map<String, dynamic> data) =>
      BookingAvailability(
        starts: [
          for (final day in data['days'] as List? ?? const [])
            for (final start in (day as Map)['starts'] as List)
              DateTime.fromMillisecondsSinceEpoch(
                (start as num).toInt(),
                isUtc: true,
              ),
        ]..sort(),
        durationHours: (data['estimatedDurationHours'] as num).toDouble(),
        estimatedTotal: (data['estimatedTotalFee'] as num).toDouble(),
        pricingType: data['pricingType'] as String,
        hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
      );
  List<DateTime> forDay(DateTime day) => starts.where((instant) {
    final local = manilaCalendar(instant);
    return local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }).toList();
  bool hasDay(DateTime day) => forDay(day).isNotEmpty;
  static Future<BookingAvailability> load({
    required String providerId,
    required String serviceId,
    double? durationHours,
    String? excludeBookingId,
  }) async {
    final today = manilaCalendar(DateTime.now());
    final result = await MarketplaceService.command('providerAvailability', {
      'action': 'slots',
      'providerIds': [providerId],
      'serviceId': serviceId,
      'startDay': DateTime.utc(
        today.year,
        today.month,
        today.day,
        -8,
      ).millisecondsSinceEpoch,
      'days': 90,
      if (durationHours != null) 'durationHours': durationHours,
      if (excludeBookingId != null) 'excludeBookingId': excludeBookingId,
    });
    return BookingAvailability.fromMap(result);
  }
}

Future<DateTime?> chooseAvailableDay(
  BuildContext context,
  BookingAvailability availability, {
  DateTime? initial,
}) async {
  if (availability.starts.isEmpty) {
    throw StateError(
      'No available start times in the next 90 days. Ask the provider about their schedule.',
    );
  }
  final first = manilaCalendar(availability.starts.first),
      last = manilaCalendar(availability.starts.last);
  return showDatePicker(
    context: context,
    firstDate: DateTime(first.year, first.month, first.day),
    lastDate: DateTime(last.year, last.month, last.day),
    initialDate: initial != null && availability.hasDay(initial)
        ? initial
        : first,
    selectableDayPredicate: availability.hasDay,
    helpText: 'Available dates · Asia/Manila',
  );
}

Future<DateTime?> chooseAvailableStart(
  BuildContext context,
  BookingAvailability availability,
  DateTime day,
) => showDialog<DateTime>(
  context: context,
  builder: (ctx) => WorkflowDialog(
    title: const Text('Available start times · Manila'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final instant in availability.forDay(day))
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, instant),
                child: Text(
                  TimeOfDay.fromDateTime(manilaCalendar(instant)).format(ctx),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ],
  ),
);
