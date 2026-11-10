import '../../widgets/provider_search_status.dart';
import '../../l10n/app_strings.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/provider.dart';
import '../../models/requested_work_schedule.dart';
import '../../services/firestore_service.dart';
import '../../services/marketplace_service.dart';
import '../../services/provider_recommendation_service.dart';
import '../../utils/geo_location.dart';
import '../../widgets/customer_provider_profile_dialog.dart';
import '../../widgets/profile_location_editor.dart';
import '../../widgets/your_area_map.dart';

class ScheduledProviderSearchScreen extends StatefulWidget {
  const ScheduledProviderSearchScreen({super.key, required this.appUser});
  final AppUser appUser;
  @override
  State<ScheduledProviderSearchScreen> createState() =>
      _ScheduledProviderSearchScreenState();
}

class _ScheduledProviderSearchScreenState
    extends State<ScheduledProviderSearchScreen> {
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _days = 1;
  double _hours = 1;
  GeoPoint? _origin;
  String? _key;
  Future<Map<String, bool>>? _availability;
  DateTime? _checkedAt;
  final _firestore = FirestoreService();
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    _date = DateTime.utc(now.year, now.month, now.day + 1);
    _origin = geoPointOrNull(widget.appUser.location);
  }

  RequestedWorkSchedule get _request => RequestedWorkSchedule(
    start: DateTime.utc(
      _date.year,
      _date.month,
      _date.day,
      _time.hour - 8,
      _time.minute,
    ),
    days: _days,
    hoursPerDay: _hours,
  );
  Future<Map<String, bool>> _check(
    List<ServiceProviderProfile> providers,
    RequestedWorkSchedule request,
  ) async {
    final result = <String, bool>{};
    for (var i = 0; i < providers.length; i += 30) {
      final response =
          await MarketplaceService.command('providerAvailability', {
            ...request.toMap(),
            'providerIds': providers
                .skip(i)
                .take(30)
                .map((p) => p.providerId)
                .toList(),
          });
      final values = Map<String, dynamic>.from(response['providers'] as Map);
      for (final e in values.entries) {
        result[e.key] = (e.value as Map)['available'] == true;
      }
    }
    _checkedAt = DateTime.now();
    return result;
  }

  Widget _results(
    List<ServiceProviderProfile> providers,
    Map<String, AppUser> users,
  ) {
    final request = _request;
    final key = jsonEncode([
      request.toMap(),
      for (final p in providers)
        [
          p.providerId,
          p.updatedAt.millisecondsSinceEpoch,
          p.effectiveWeeklyAvailability.toFirestore(),
        ],
    ]);
    if (key != _key) {
      _key = key;
      _availability = _check(providers, request);
    }
    return FutureBuilder<Map<String, bool>>(
      future: _availability,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Column(
            children: [
              const Text(
                'Could not check this schedule. Check your connection and retry.',
              ),
              OutlinedButton(
                onPressed: () => setState(() => _key = null),
                child: const Text('Retry availability'),
              ),
            ],
          );
        }
        final ranked = rankProvidersByRecommendation(
          providers: providers,
          customerOrigin: _origin,
          requestedSchedule: request,
          availabilityByProvider: snap.data,
        );
        final pins = [
          for (final r in ranked)
            NearbyMapPin(
              id: r.profile.providerId,
              position: latLngFromGeoPoint(r.profile.location),
              label: users[r.profile.userId]?.fullName ?? 'Provider',
              area: r.profile.serviceArea,
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProviderSearchStatus(
              candidates: providers.length,
              matches: ranked.length,
              days: _days,
              hours: _hours,
              checkedAt: _checkedAt,
            ),
            const SizedBox(height: 12),
            const Text(
              'Distance is an estimate from the provider barangay center. Availability can change and is checked again when an offer is accepted. Discuss travel and requirements in messages.',
            ),
            TextButton.icon(
              onPressed: () => setState(() => _key = null),
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('Refresh availability')),
            ),
            SizedBox(
              height: 320,
              child: YourAreaMapView(
                userPosition: latLngFromGeoPoint(_origin!),
                pins: pins,
                interactive: true,
              ),
            ),
            for (final r in ranked)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${r.rank}')),
                  title: Text(users[r.profile.userId]?.fullName ?? 'Provider'),
                  subtitle: Text(
                    'Available for this schedule · ${r.distanceKm?.toStringAsFixed(1) ?? '?'} km estimated\n${r.profile.serviceArea}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showCustomerProviderProfileDialog(
                    context,
                    appUser: widget.appUser,
                    providerId: r.profile.providerId,
                    providerUser: users[r.profile.userId],
                    providerProfile: r.profile,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Find providers for your schedule'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Choose the work location, start time, consecutive days and hours per day. All times are in Asia/Manila.',
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.place_outlined),
                  label: Text(
                    _origin == null
                        ? 'Choose work location'
                        : 'Change work location',
                  ),
                  onPressed: () async {
                    final p = await showProfileLocationDialog(
                      context,
                      initialLocation: _origin,
                      initialAddress: widget.appUser.address ?? '',
                    );
                    if (p != null && mounted) setState(() => _origin = p);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat.yMMMd().format(_date)),
                  onPressed: () async {
                    final now = DateTime.now().toUtc().add(
                      const Duration(hours: 8),
                    );
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 180)),
                      initialDate: _date,
                    );
                    if (d != null && mounted) setState(() => _date = d);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(_time.format(context)),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (t != null && mounted) setState(() => _time = t);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _days,
              decoration: InputDecoration(
                labelText: context.tr('Consecutive workdays'),
              ),
              items: [
                for (var n = 1; n <= 30; n++)
                  DropdownMenuItem(value: n, child: Text('$n day(s)')),
              ],
              onChanged: (v) => setState(() => _days = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<double>(
              initialValue: _hours,
              decoration: InputDecoration(
                labelText: context.tr('Hours per day'),
              ),
              items: [
                for (var h = .5; h <= 8; h += .5)
                  DropdownMenuItem(value: h, child: Text('$h hours')),
              ],
              onChanged: (v) => setState(() => _hours = v!),
            ),
            const SizedBox(height: 16),
            if (_origin == null)
              const Text('Choose a work location to check service coverage.')
            else
              StreamBuilder<List<ServiceProviderProfile>>(
                stream: _firestore.serviceProvidersStream(),
                builder: (context, p) {
                  if (p.hasError) {
                    return const Text(
                      'Could not load providers. Reopen this screen to retry.',
                    );
                  }
                  if (!p.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return StreamBuilder<List<AppUser>>(
                    stream: _firestore.allUsersStream(),
                    builder: (context, u) => _results(p.data!, {
                      for (final user in u.data ?? <AppUser>[])
                        user.userId: user,
                    }),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}
