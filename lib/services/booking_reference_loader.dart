import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/provider.dart';
import '../models/service.dart';

/// Optional display data must never hide the customer's own booking records.
class BookingReferenceData {
  final services = <String, ServiceListing?>{};
  final providers = <String, AppUser?>{};
  final profiles = <String, ServiceProviderProfile?>{};
  final unavailable = <String>{};
}

Future<BookingReferenceData> loadBookingReferences({
  required List<Booking> bookings,
  required Future<ServiceListing?> Function(String) service,
  required Future<AppUser?> Function(String) provider,
  required Future<ServiceProviderProfile?> Function(String) profile,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final result = BookingReferenceData();
  Future<void> load<T>(
    String kind,
    String id,
    Map<String, T?> target,
    Future<T?> Function(String) read,
  ) async {
    try {
      target[id] = await Future<T?>.sync(() => read(id)).timeout(timeout);
      if (target[id] == null) result.unavailable.add('$kind:$id');
    } catch (_) {
      target[id] = null;
      result.unavailable.add('$kind:$id');
    }
  }

  await Future.wait([
    for (final id in bookings.map((b) => b.serviceId).toSet())
      load('service', id, result.services, service),
    for (final id in bookings.map((b) => b.providerId).toSet()) ...[
      load('provider', id, result.providers, provider),
      load('profile', id, result.profiles, profile),
    ],
  ]);
  return result;
}
