import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/collections.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/booking_user_report.dart';
import '../models/message.dart';
import '../models/notification.dart' as n;
import '../models/provider.dart';
import '../data/panabo_barangays.dart';

import '../models/review.dart';
import '../models/service_contract.dart';
import '../models/account_status.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/service.dart';
import '../models/service_approval_status.dart';
import '../models/user_role.dart';
import '../constants/functions_config.dart';
import '../utils/message_thread.dart';
import '../utils/service_certification_policy.dart';
import '../utils/session_data_cache.dart';
import 'marketplace_service.dart';

/// Shared Firestore access for the app session.
///
/// Uses one instance and memoized **broadcast** query streams so [IndexedStack]
/// tabs can re-subscribe without creating duplicate listeners (fixes stuck
/// loading on Flutter web).
class FirestoreService {
  FirestoreService._internal({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static final FirestoreService _shared = FirestoreService._internal();

  factory FirestoreService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return FirestoreService._internal(firestore: firestore);
    }
    return _shared;
  }

  final FirebaseFirestore _db;
  final Map<String, ReplayDataStream<dynamic>> _streams = {};
  final _reads = SessionFutureCache();
  String _sessionKey(String key) =>
      '${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}:$key';

  Future<T> _read<T>(String key, Future<T> Function() load) =>
      _reads.get(_sessionKey(key), load);

  /// Retry in place: mounted pages keep their stream and last loaded content.
  Future<void> retryDataLoads() async {
    _reads.clear();
    final prefix = _sessionKey('');
    await Future.wait(
      _streams.entries
          .where((e) => e.key.startsWith(prefix))
          .map((e) => e.value.retry()),
    );
  }

  /// Memoized stream that **replays the latest event** to every new listener.
  ///
  /// Plain [Stream.asBroadcastStream] does not replay, and a broadcast
  /// `onListen` callback only fires on the 0→1 listener transition. So a second
  /// [StreamBuilder] (e.g. opening a chat while the conversation list is still
  /// subscribed) would stay stuck on "Loading…" until the next Firestore write.
  /// [ReplayDataStream] hands every new subscriber the cached latest value (or
  /// error) immediately, then forwards live updates.
  Stream<T> _cache<T>(String key, Stream<T> Function() create) {
    key = _sessionKey(key);
    final existing = _streams[key];
    if (existing != null) return (existing as ReplayDataStream<T>).stream;

    final replay = ReplayDataStream<T>(create);
    _streams[key] = replay;
    return replay.stream;
  }

  Future<void> clearSession() async {
    _reads.clear();
    final entries = _streams.values.toList();
    _streams.clear();
    await Future.wait(entries.map((entry) => entry.dispose()));
  }

  DocumentReference<Map<String, dynamic>> userDoc(String userId) {
    return _db.collection(FirestoreCollections.users).doc(userId);
  }

  Future<bool> _isAdministrator() => _read('isAdministrator', () async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return (await userDoc(uid).get()).data()?['role'] == 'Administrator';
  });

  AppUser _publicUser(String id, Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    for (final field in ['createdAt', 'updatedAt']) {
      if (data[field] is num) {
        data[field] = Timestamp.fromMillisecondsSinceEpoch(
          (data[field] as num).toInt(),
        );
      }
    }
    return AppUser.fromFirestore(id, data);
  }

  /// Existing public projections can render even if the bootstrap callable is
  /// temporarily unavailable. Never report a failed bootstrap as an empty list.
  Stream<List<T>> _publicRecords<T>({
    required Query<Map<String, dynamic>> query,
    required Future<List<T>> Function() bootstrap,
    required T Function(String, Map<String, dynamic>) parse,
    required String Function(T) id,
  }) => Stream<List<T>>.multi((controller) {
    final records = <String, T>{};
    final removed = <String>{};
    var ready = false;
    var cancelled = false;
    final sub = query.snapshots().listen((snapshot) {
      if (cancelled) return;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          records.remove(change.doc.id);
          removed.add(change.doc.id);
        } else {
          removed.remove(change.doc.id);
          records[change.doc.id] = parse(change.doc.id, change.doc.data()!);
        }
      }
      if (records.isNotEmpty || ready) controller.add(records.values.toList());
    }, onError: controller.addError);
    unawaited(
      bootstrap().then(
        (initial) {
          if (cancelled) return;
          for (final record in initial) {
            if (!removed.contains(id(record))) {
              records.putIfAbsent(id(record), () => record);
            }
          }
          ready = true;
          controller.add(records.values.toList());
        },
        onError: (Object error, StackTrace stack) {
          if (cancelled) return;
          if (records.isEmpty) controller.addError(error, stack);
        },
      ),
    );
    controller.onCancel = () {
      cancelled = true;
      return sub.cancel();
    };
  });

  Future<List<AppUser>> _publicDirectory({String? userId}) =>
      _read('directory:${userId ?? 'all'}', () async {
        final result = <AppUser>[];
        String? after;
        do {
          final response =
              await FirebaseFunctions.instanceFor(
                region: kNeighborHelpFunctionsRegion,
              ).httpsCallable('getPublicDirectory').call({
                'userId': userId,
                if (after != null) 'after': after,
              });
          final data = Map<String, dynamic>.from(response.data as Map);
          result.addAll(
            (data['records'] as List).map((r) {
              final row = Map<String, dynamic>.from(r as Map);
              return _publicUser(row['userId'] as String, row);
            }),
          );
          after = data['after'] as String?;
        } while (after != null);
        return result;
      });

  Stream<AppUser?> userStream(String userId) =>
      _cache('user:$userId', () async* {
        if (FirebaseAuth.instance.currentUser?.uid == userId ||
            await _isAdministrator()) {
          yield* userDoc(userId).snapshots().map(
            (d) => d.exists ? AppUser.fromFirestore(d.id, d.data()!) : null,
          );
        } else {
          yield* _publicRecords<AppUser>(
            query: _db
                .collection('publicProfiles')
                .where(FieldPath.documentId, isEqualTo: userId),
            bootstrap: () => _publicDirectory(userId: userId),
            parse: _publicUser,
            id: (u) => u.userId,
          ).map((users) => users.firstOrNull);
        }
      });

  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return userDoc(userId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  ServiceProviderProfile _publicProvider(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    final area = panaboBarangays
        .where((b) => b['id'] == data['baseBarangayId'])
        .firstOrNull;
    data['location'] = area == null
        ? null
        : GeoPoint(
            (area['latitude'] as num).toDouble(),
            (area['longitude'] as num).toDouble(),
          );
    for (final field in ['createdAt', 'updatedAt']) {
      if (data[field] is num) {
        data[field] = Timestamp.fromMillisecondsSinceEpoch(
          (data[field] as num).toInt(),
        );
      }
    }
    return ServiceProviderProfile.fromFirestore(
      data['providerId'] as String,
      data,
    );
  }

  Future<List<ServiceProviderProfile>> _publicProviders({String? userId}) =>
      _read('publicProviders:${userId ?? 'all'}', () async {
        final result = <ServiceProviderProfile>[];
        String? after;
        do {
          final response =
              await FirebaseFunctions.instanceFor(
                region: kNeighborHelpFunctionsRegion,
              ).httpsCallable('getPublicProviders').call({
                'userId': userId,
                if (after != null) 'after': after,
              });
          final data = Map<String, dynamic>.from(response.data as Map);
          result.addAll(
            (data['records'] as List).map(
              (r) => _publicProvider(Map<String, dynamic>.from(r as Map)),
            ),
          );
          after = data['after'] as String?;
        } while (after != null);
        return result;
      });

  Stream<List<ServiceProviderProfile>> serviceProvidersStream() =>
      _cache('serviceProviders', () async* {
        if (await _isAdministrator()) {
          yield* _db
              .collection(FirestoreCollections.serviceProviders)
              .snapshots()
              .map(
                (s) => s.docs
                    .map(
                      (d) =>
                          ServiceProviderProfile.fromFirestore(d.id, d.data()),
                    )
                    .toList(),
              );
        } else {
          yield* _publicRecords<ServiceProviderProfile>(
            query: _db
                .collection('publicProviders')
                .where('locationPolicyVersion', isEqualTo: 1),
            bootstrap: () => _publicProviders(),
            parse: (_, row) => _publicProvider(row),
            id: (p) => p.providerId,
          ).map(
            (list) => list
                .where(
                  (p) => p.eligibleServiceIds?.any(p.canOfferService) ?? false,
                )
                .toList(),
          );
        }
      });

  Future<String> resolveProviderDocumentId(String userOrProviderId) async {
    final direct = await _db
        .collection(FirestoreCollections.serviceProviders)
        .doc(userOrProviderId)
        .get();
    if (direct.exists) return userOrProviderId;

    final query = await _db
        .collection(FirestoreCollections.serviceProviders)
        .where('userId', isEqualTo: userOrProviderId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) return query.docs.first.id;
    return userOrProviderId;
  }

  static Map<String, dynamic> _defaultProviderFields(
    String userId,
    Timestamp now,
  ) => {
    'userId': userId,
    'bio': '',
    'serviceArea': '',
    'location': null,
    'serviceRadiusKm': 5,
    'averageRating': 0,
    'completedBookings': 0,
    'reviewCount': 0,
    'acceptedBookings': 0,
    'isVerified': false,
    'verificationStatus': 'Pending',
    'diditStatus': '',
    'diditSessionId': '',
    'verificationProvider': '',
    'governmentIdTypeCode': '',
    'governmentIdTypeLabel': '',
    'createdAt': now,
    'updatedAt': now,
  };

  /// Backfills verification guard fields on older provider docs so security rules allow updates.
  /// Creates `serviceProviders/{userId}` when missing so section editors can save.
  Future<void> ensureServiceProviderProfile(String userId) async {
    final userSnap = await userDoc(userId).get();
    if (userSnap.exists) {
      final role = UserRole.fromFirestore(userSnap.data()?['role'] as String?);
      if (role == UserRole.customer) {
        throw StateError(
          'Cannot create a provider profile for a customer account. '
          'Use customer identity verification instead.',
        );
      }
    }

    final ref = _db
        .collection(FirestoreCollections.serviceProviders)
        .doc(userId);
    final snap = await ref.get();
    if (!snap.exists) {
      final now = Timestamp.now();
      await ref.set(_defaultProviderFields(userId, now));
      return;
    }
  }

  /// Historical stray profiles are preserved. Explicit roles determine access;
  /// any cleanup requires an administrator's retention review.
  Future<bool> removeMistakenProviderProfileIfCustomer(String userId) async =>
      false;

  Future<void> updateServiceProvider({
    required String providerId,
    required Map<String, dynamic> data,
  }) async {
    // Rules require the document path id to match request.auth.uid.
    await ensureServiceProviderProfile(providerId);
    await _db
        .collection(FirestoreCollections.serviceProviders)
        .doc(providerId)
        .update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        });
  }

  Stream<List<ServiceListing>> servicesForProvider(String providerId) {
    return _cache('servicesForProvider:$providerId', () {
      return _db
          .collection(FirestoreCollections.services)
          .where('providerId', isEqualTo: providerId)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => ServiceListing.fromFirestore(d.id, d.data()))
                .toList(),
          );
    });
  }

  Stream<List<ServiceListing>> activeServicesStream() {
    return _cache('activeServices', () {
      return _db.collection(FirestoreCollections.services).snapshots().map((s) {
        final list = s.docs
            .map((d) => ServiceListing.fromFirestore(d.id, d.data()))
            .where((service) => service.isMarketplaceVisible)
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    });
  }

  Future<List<ServiceListing>> fetchActiveServices() async {
    final snap = await _db.collection(FirestoreCollections.services).get();
    final list = snap.docs
        .map((d) => ServiceListing.fromFirestore(d.id, d.data()))
        .where((s) => s.isMarketplaceVisible)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Stream<ServiceProviderProfile?> providerProfileForUser(String userId) =>
      _cache('providerProfileForUser:$userId', () async* {
        if (FirebaseAuth.instance.currentUser?.uid == userId ||
            await _isAdministrator()) {
          yield* _db
              .collection(FirestoreCollections.serviceProviders)
              .doc(userId)
              .snapshots()
              .map(
                (d) => d.exists
                    ? ServiceProviderProfile.fromFirestore(d.id, d.data()!)
                    : null,
              );
        } else {
          yield* _publicRecords<ServiceProviderProfile>(
            query: _db
                .collection('publicProviders')
                .where('locationPolicyVersion', isEqualTo: 1)
                .where(FieldPath.documentId, isEqualTo: userId),
            bootstrap: () => _publicProviders(userId: userId),
            parse: (_, row) => _publicProvider(row),
            id: (p) => p.providerId,
          ).map((profiles) => profiles.firstOrNull);
        }
      });

  Stream<List<Booking>> bookingsForProviderUser(String userId) {
    return _cache('bookingsForProviderUser:$userId', () {
      return _providerBookingsStream(userId);
    });
  }

  Stream<List<Booking>> _providerBookingsStream(String userId) {
    return Stream.multi((controller) {
      final seen = <String, Booking>{};
      final watchedIds = <String>{};
      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

      void publish() {
        if (controller.isClosed) return;
        final list = seen.values.toList()
          ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
        controller.add(list);
      }

      void watchProviderId(String providerId) {
        if (!watchedIds.add(providerId)) return;
        subs.add(
          _db
              .collection(FirestoreCollections.bookings)
              .where('providerId', isEqualTo: providerId)
              .snapshots()
              .listen((snap) {
                seen.removeWhere((_, b) => b.providerId == providerId);
                for (final doc in snap.docs) {
                  final booking = Booking.fromFirestore(doc.id, doc.data());
                  seen[booking.bookingId] = booking;
                }
                publish();
              }, onError: controller.addError),
        );
      }

      watchProviderId(userId);

      unawaited(() async {
        final profile = await getProviderProfile(userId);
        if (controller.isClosed) return;
        final extraId = profile?.providerId;
        if (extraId != null && extraId != userId) watchProviderId(extraId);
      }());

      controller.onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    });
  }

  /// Services owned by this provider account (auth uid and provider document id).
  Stream<List<ServiceListing>> servicesForProviderUser(String userId) {
    return _cache('servicesForProviderUser:$userId', () {
      return _providerServicesStream(userId);
    });
  }

  Stream<List<ServiceListing>> _providerServicesStream(String userId) {
    return Stream.multi((controller) {
      final seen = <String, ServiceListing>{};
      final watchedIds = <String>{};
      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

      void publish() {
        if (controller.isClosed) return;
        controller.add(seen.values.toList());
      }

      void watchProviderId(String providerId) {
        if (!watchedIds.add(providerId)) return;
        subs.add(
          _db
              .collection(FirestoreCollections.services)
              .where('providerId', isEqualTo: providerId)
              .snapshots()
              .listen((snap) {
                seen.removeWhere((_, s) => s.providerId == providerId);
                for (final doc in snap.docs) {
                  final service = ServiceListing.fromFirestore(
                    doc.id,
                    doc.data(),
                  );
                  seen[service.serviceId] = service;
                }
                publish();
              }, onError: controller.addError),
        );
      }

      watchProviderId(userId);

      unawaited(() async {
        final profile = await getProviderProfile(userId);
        if (controller.isClosed) return;
        final extraId = profile?.providerId;
        if (extraId != null && extraId != userId) watchProviderId(extraId);
      }());

      controller.onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    });
  }

  Stream<ServiceListing?> serviceStream(String serviceId) => _cache(
    'service:$serviceId',
    () => _db
        .collection(FirestoreCollections.services)
        .doc(serviceId)
        .snapshots()
        .map(
          (snap) => snap.exists && snap.data() != null
              ? ServiceListing.fromFirestore(snap.id, snap.data()!)
              : null,
        ),
  );

  Future<ServiceListing?> getService(String serviceId) =>
      _read('service:$serviceId', () => serviceStream(serviceId).first);

  /// Service titles keyed by listing id (for review job labels on profiles).
  Future<Map<String, String>> serviceTitlesByIds(Iterable<String> serviceIds) {
    final unique =
        serviceIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return _read('serviceTitles:${unique.join(',')}', () async {
      if (unique.isEmpty) return const {};
      final out = <String, String>{};
      await Future.wait(
        unique.map((id) async {
          final service = await getService(id);
          final title = service?.serviceTitle.trim() ?? '';
          if (title.isNotEmpty) out[id] = title;
        }),
      );
      return out;
    });
  }

  Future<ServiceProviderProfile?> getProviderProfile(String userId) =>
      _read('provider:$userId', () => providerProfileForUser(userId).first);

  Future<String> createServiceListing({
    required String providerId,
    required String serviceTitle,
    required String category,
    required String description,
    required double estimatedPrice,
    required String priceType,
    required String estimatedDuration,
    List<String>? serviceImages,
    bool isActive = false,
    ServiceApprovalStatus approvalStatus = ServiceApprovalStatus.draft,
    String rejectionReason = '',
  }) async {
    final ref = _db.collection(FirestoreCollections.services).doc();
    await ref.set({
      'providerId': providerId,
      'serviceTitle': serviceTitle,
      'category': category,
      'description': description,
      'estimatedPrice': estimatedPrice,
      'priceType': priceType,
      'estimatedDuration': estimatedDuration,
      'availability': <String, dynamic>{},
      'serviceImages': serviceImages ?? <String>[],
      'isActive': isActive,
      'approvalStatus': approvalStatus.firestoreValue,
      'rejectionReason': rejectionReason,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<DocumentReference<Map<String, dynamic>>> createService(
    ServiceListing listing,
  ) {
    final ref = _db.collection(FirestoreCollections.services).doc();
    return ref
        .set({
          ...listing.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .then((_) => ref);
  }

  Future<void> updateService(String serviceId, Map<String, dynamic> data) {
    return _db.collection(FirestoreCollections.services).doc(serviceId).update({
      ...data,
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setServiceActive(String serviceId, bool isActive) {
    return updateService(serviceId, {'isActive': isActive});
  }

  Future<void> adminSetServiceApproval({
    required String serviceId,
    required ServiceApprovalStatus status,
    String? rejectionReason,
  }) async {
    if (status.isApproved) {
      final listing = await getService(serviceId);
      if (listing == null) throw StateError('Service not found.');
      final profile = await getProviderProfile(listing.providerId);
      final owner = await getUser(listing.providerId);
      if (profile == null ||
          !profile.isVerifiedProvider ||
          owner == null ||
          owner.accountStatus.isBlocked ||
          profile.serviceArea.trim().isEmpty) {
        throw StateError(
          'The provider needs a verified identity, active account, and service area.',
        );
      }
      if (!hasMatchingServiceCertificate(
        profile,
        category: listing.category,
        serviceTitle: listing.serviceTitle,
      )) {
        throw StateError(
          'A valid certificate matching this service is required.',
        );
      }
    }
    final data = <String, dynamic>{
      'approvalStatus': status.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      'updatedByRole': 'Administrator',
    };
    switch (status) {
      case ServiceApprovalStatus.approved:
        data['isActive'] = true;
        data['rejectionReason'] = '';
      case ServiceApprovalStatus.rejected:
        data['isActive'] = false;
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty) {
          data['rejectionReason'] = rejectionReason.trim();
        }
      case ServiceApprovalStatus.pending:
        data['isActive'] = false;
      case ServiceApprovalStatus.draft:
        data['isActive'] = false;
    }
    return updateService(serviceId, data);
  }

  Future<void> _bookingCommand(
    String action,
    String bookingId, [
    Map<String, dynamic> data = const {},
  ]) async {
    try {
      await FirebaseFunctions.instanceFor(region: kNeighborHelpFunctionsRegion)
          .httpsCallable('bookingCommand')
          .call({'action': action, 'bookingId': bookingId, ...data});
    } on FirebaseFunctionsException catch (e) {
      throw StateError(
        e.message ?? 'Could not update booking. Please try again.',
      );
    }
  }

  Future<void> createBooking(Booking booking) =>
      _bookingCommand('create', booking.bookingId, {
        'serviceId': booking.serviceId,
        'serviceLocation': booking.serviceLocation,
        'location': {
          'latitude': booking.location.latitude,
          'longitude': booking.location.longitude,
        },
        'scheduledDate': booking.scheduledDate.millisecondsSinceEpoch,
        'scheduledEndDate': booking.scheduledEnd?.millisecondsSinceEpoch,
        'notes': booking.notes,
      });

  Stream<Booking?> bookingStream(String bookingId) {
    return _cache('booking:$bookingId', () {
      return _db
          .collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .snapshots()
          .map((snap) {
            if (!snap.exists || snap.data() == null) return null;
            return Booking.fromFirestore(snap.id, snap.data()!);
          });
    });
  }

  Future<Booking?> getBooking(String bookingId) async {
    if (bookingId.isEmpty) return null;
    final snap = await _db
        .collection(FirestoreCollections.bookings)
        .doc(bookingId)
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return Booking.fromFirestore(snap.id, snap.data()!);
  }

  Future<void> updateBookingStatus(String bookingId, String status) =>
      _bookingCommand('adminStatus', bookingId, {'status': status});

  Future<void> providerRespondToBooking({
    required String bookingId,
    required String providerId,
    required bool accept,
    String? agreementHash,
  }) => _bookingCommand(accept ? 'accept' : 'decline', bookingId, {
    'acceptAgreement': accept,
    'agreementHash': agreementHash,
  });

  Future<void> requestOfferChanges(String bookingId, String reason) =>
      _bookingCommand('requestChanges', bookingId, {'reason': reason});

  Future<void> requestReschedule(String bookingId, DateTime when) =>
      _bookingCommand('requestReschedule', bookingId, {
        'scheduledDate': when.millisecondsSinceEpoch,
      });

  Future<void> respondToReschedule(String bookingId, {required bool approve}) =>
      _bookingCommand(
        approve ? 'approveReschedule' : 'rejectReschedule',
        bookingId,
      );

  Stream<ServiceContract?> contractStream(String contractId) {
    return _cache(
      'contract:$contractId',
      () => _db
          .collection(FirestoreCollections.contracts)
          .doc(contractId)
          .snapshots()
          .map((snap) {
            if (!snap.exists || snap.data() == null) return null;
            return ServiceContract.fromFirestore(snap.id, snap.data()!);
          }),
    );
  }

  Future<ServiceContract?> getContract(String contractId) async {
    final snap = await _db
        .collection(FirestoreCollections.contracts)
        .doc(contractId)
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return ServiceContract.fromFirestore(snap.id, snap.data()!);
  }

  Stream<List<Booking>> bookingsForContract(String contractId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _cache(
      'contractBookings:$contractId',
      () => _db
          .collection(FirestoreCollections.bookings)
          .where(
            Filter.and(
              Filter('contractId', isEqualTo: contractId),
              Filter.or(
                Filter('customerId', isEqualTo: uid),
                Filter('providerId', isEqualTo: uid),
              ),
            ),
          )
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => Booking.fromFirestore(d.id, d.data()))
                .toList();
            list.sort((a, b) {
              final ma = a.milestoneNumber ?? 0;
              final mb = b.milestoneNumber ?? 0;
              return ma.compareTo(mb);
            });
            return list;
          }),
    );
  }

  Future<void> endContract({
    required String contractId,
    required String endedByUserId,
    required String endedByRole,
  }) async {
    try {
      await FirebaseFunctions.instanceFor(
        region: kNeighborHelpFunctionsRegion,
      ).httpsCallable('contractCommand').call({'contractId': contractId});
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'Could not close this contract.');
    }
  }

  Future<void> customerCancelBooking({
    required String bookingId,
    required String customerId,
    required String reason,
  }) => _bookingCommand('cancel', bookingId, {'reason': reason});

  Future<void> providerCancelBooking({
    required String bookingId,
    required String providerId,
    required String reason,
  }) => _bookingCommand('cancel', bookingId, {'reason': reason});

  Future<void> providerStartBooking({
    required String bookingId,
    required String providerId,
  }) => _bookingCommand('start', bookingId);

  Future<void> providerCompleteBooking({
    required String bookingId,
    required String providerId,
  }) => _bookingCommand('complete', bookingId);

  /// Submit a moderation report for the other party in a booking.
  ///
  /// The document id is deterministic to prevent duplicate reports for the same
  /// booking by the same reporter.
  Future<void> createBookingUserReport({
    required String bookingId,
    required String reporterId,
    required String reporterRole, // 'customer' | 'provider'
    required String reportedUserId,
    required String reportedRole, // 'customer' | 'provider'
    required String reason,
    String details = '',
    List<String> photoUrls = const [],
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 3) {
      throw StateError('Please provide a reason (at least 3 characters).');
    }
    final trimmedDetails = details.trim();

    await MarketplaceService.command('reportCommand', {
      'action': 'reportBooking',
      'bookingId': bookingId,
      'reason': trimmedReason,
      'details': trimmedDetails,
      'photoUrls': photoUrls,
    });
  }

  /// Admin: stream all booking user reports (newest first).
  Stream<BookingUserReport?> bookingUserReport(String id) => _db
      .collection(FirestoreCollections.bookingUserReports)
      .doc(id)
      .snapshots()
      .map(
        (s) =>
            s.exists ? BookingUserReport.fromFirestore(s.id, s.data()!) : null,
      );

  Stream<List<BookingUserReport>> allBookingUserReportsStream() {
    return _cache('allBookingUserReports', () {
      return _db
          .collection(FirestoreCollections.bookingUserReports)
          .orderBy('createdAt', descending: true)
          .limit(250)
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => BookingUserReport.fromFirestore(d.id, d.data()))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });
    });
  }

  /// Admin: resolve or dismiss a booking user report.
  Future<void> adminSetBookingUserReportStatus({
    required String reportId,
    required String status, // 'resolved' | 'dismissed'
    String adminNotes = '',
  }) async {
    final normalized = status.trim().toLowerCase();
    if (normalized != BookingUserReport.statusResolved &&
        normalized != BookingUserReport.statusDismissed) {
      throw StateError('Invalid report status.');
    }

    await MarketplaceService.command('reportCommand', {
      'action': 'resolve',
      'reportId': reportId,
      'status': normalized,
      'adminNotes': adminNotes.trim(),
    });
  }

  Future<void> sendTextMessage({
    required String bookingId,
    required String customerId,
    required String providerId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final id = await MarketplaceService.bookingInquiry(bookingId);
    await MarketplaceService.send(id, text: text);
  }

  /// Marks all unread messages in a thread as read for [readerId].
  Future<void> sendImageMessage({
    required String bookingId,
    required String customerId,
    required String providerId,
    required String senderId,
    required String receiverId,
    required String mediaUrl,
  }) async {
    final id = await MarketplaceService.bookingInquiry(bookingId);
    await MarketplaceService.send(id, mediaUrl: mediaUrl);
  }

  Future<void> markConversationMessagesRead({
    required String customerId,
    required String providerId,
    required String readerId,
  }) async {
    final threadId = messageThreadId(customerId, providerId);
    final snap = await _db
        .collection(FirestoreCollections.messages)
        .where('threadId', isEqualTo: threadId)
        .where('receiverId', isEqualTo: readerId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Stream<int> unreadMessageCountStream(String userId) =>
      MarketplaceService.inbox(userId).map(
        (threads) => threads.fold(0, (total, t) => total + t.unreadFor(userId)),
      );

  Stream<List<Review>> reviewsForProviderStream(String providerId) {
    return _cache('reviewsProvider:$providerId', () {
      return _db
          .collection(FirestoreCollections.reviews)
          .where('providerId', isEqualTo: providerId)
          .limit(100)
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => Review.fromFirestore(d.id, d.data()))
                .where((r) => r.isCustomerReview)
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });
    });
  }

  /// Live provider→customer feedback for public customer profiles.
  Stream<List<Review>> reviewsForCustomerStream(String customerId) {
    return _cache('reviewsCustomer:$customerId', () {
      return _db
          .collection(FirestoreCollections.reviews)
          .where('revieweeId', isEqualTo: customerId)
          .where('reviewerRole', isEqualTo: 'provider')
          .limit(100)
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => Review.fromFirestore(d.id, d.data()))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });
    });
  }

  Stream<List<Booking>> bookingsForUser(
    String userId, {
    bool asCustomer = true,
  }) {
    final field = asCustomer ? 'customerId' : 'providerId';
    return _cache('bookings:$field:$userId', () {
      return _db
          .collection(FirestoreCollections.bookings)
          .where(field, isEqualTo: userId)
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => Booking.fromFirestore(d.id, d.data()))
                .toList();
            list.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
            return list;
          });
    });
  }

  Stream<List<n.AppNotification>> notificationsForUser(String userId) {
    return _cache('notifications:$userId', () {
      return _db
          .collection(FirestoreCollections.notifications)
          .where('userId', isEqualTo: userId)
          .limit(50)
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => n.AppNotification.fromFirestore(d.id, d.data()))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });
    });
  }

  Stream<List<ChatMessage>> messagesForBooking(String bookingId) {
    return _cache('messages:$bookingId', () {
      return _db
          .collection(FirestoreCollections.messages)
          .where(
            Filter.and(
              Filter('bookingId', isEqualTo: bookingId),
              Filter.or(
                Filter(
                  'senderId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                ),
                Filter(
                  'receiverId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                ),
              ),
            ),
          )
          .snapshots()
          .map(_mapAndSortMessages);
    });
  }

  /// All messages between a customer and provider (one thread across bookings).
  Stream<List<ChatMessage>> messagesForConversationThread({
    required String customerId,
    required String providerId,
    required List<String> bookingIds,
  }) {
    final threadId = messageThreadId(customerId, providerId);
    final sortedIds = bookingIds.toSet().toList()..sort();
    final idsKey = sortedIds.isEmpty ? 'none' : sortedIds.join(',');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final participantFilter = Filter.or(
      Filter('senderId', isEqualTo: uid),
      Filter('receiverId', isEqualTo: uid),
    );
    return _cache('messagesThread:$threadId:$idsKey', () {
      final threadStream = _db
          .collection(FirestoreCollections.messages)
          .where(
            Filter.and(
              Filter('threadId', isEqualTo: threadId),
              participantFilter,
            ),
          )
          .snapshots();

      if (bookingIds.isEmpty) {
        return threadStream.map(_mapAndSortMessages);
      }

      final legacyStreams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < bookingIds.length; i += 10) {
        final end = i + 10 < bookingIds.length ? i + 10 : bookingIds.length;
        final chunk = bookingIds.sublist(i, end);
        legacyStreams.add(
          _db
              .collection(FirestoreCollections.messages)
              .where(
                Filter.and(
                  Filter('bookingId', whereIn: chunk),
                  participantFilter,
                ),
              )
              .snapshots(),
        );
      }

      final controller = StreamController<List<ChatMessage>>.broadcast();
      QuerySnapshot<Map<String, dynamic>>? threadSnap;
      final legacySnaps = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
        legacyStreams.length,
        null,
      );

      void emitMerged() {
        final byId = <String, ChatMessage>{};
        void addSnap(QuerySnapshot<Map<String, dynamic>>? snap) {
          if (snap == null) return;
          for (final d in snap.docs) {
            byId[d.id] = ChatMessage.fromFirestore(d.id, d.data());
          }
        }

        addSnap(threadSnap);
        for (final s in legacySnaps) {
          addSnap(s);
        }
        final list = byId.values.toList()
          ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        if (!controller.isClosed) controller.add(list);
      }

      final threadSub = threadStream.listen((s) {
        threadSnap = s;
        emitMerged();
      }, onError: controller.addError);

      final legacySubs =
          <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < legacyStreams.length; i++) {
        final index = i;
        legacySubs.add(
          legacyStreams[i].listen((s) {
            legacySnaps[index] = s;
            emitMerged();
          }, onError: controller.addError),
        );
      }

      controller.onCancel = () async {
        await threadSub.cancel();
        for (final sub in legacySubs) {
          await sub.cancel();
        }
      };

      return controller.stream;
    });
  }

  static List<ChatMessage> _mapAndSortMessages(
    QuerySnapshot<Map<String, dynamic>> s,
  ) {
    final list = s.docs
        .map((d) => ChatMessage.fromFirestore(d.id, d.data()))
        .toList();
    list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return list;
  }

  Future<int> countCollection(String name) async {
    final snapshot = await _db.collection(name).count().get();
    return snapshot.count ?? 0;
  }

  Future<List<Review>> reviewsForProvider(String providerId) => _read(
    'reviewsProvider:$providerId',
    () => reviewsForProviderStream(providerId).first,
  );

  /// Feedback from providers about this customer (for provider due diligence).
  Future<List<Review>> reviewsForCustomer(String customerId) async {
    final snap = await _db
        .collection(FirestoreCollections.reviews)
        .where('revieweeId', isEqualTo: customerId)
        .where('reviewerRole', isEqualTo: 'provider')
        .limit(100)
        .get();
    final list = snap.docs
        .map((d) => Review.fromFirestore(d.id, d.data()))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<Review>> reviewsByCustomer(String customerId) async {
    final snap = await _db
        .collection(FirestoreCollections.reviews)
        .where('customerId', isEqualTo: customerId)
        .limit(100)
        .get();
    final list = snap.docs
        .map((d) => Review.fromFirestore(d.id, d.data()))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<Review>> reviewsForBooking(String bookingId) async {
    final snap = await _db
        .collection(FirestoreCollections.reviews)
        .where('bookingId', isEqualTo: bookingId)
        .get();
    return snap.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList();
  }

  Stream<List<Review>> reviewsForBookingStream(String bookingId) {
    return _cache('reviewsBooking:$bookingId', () {
      return _db
          .collection(FirestoreCollections.reviews)
          .where('bookingId', isEqualTo: bookingId)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => Review.fromFirestore(d.id, d.data()))
                .toList(),
          );
    });
  }

  Review? _reviewByReviewer(List<Review> reviews, String reviewerId) {
    for (final r in reviews) {
      if (r.reviewerId == reviewerId) return r;
    }
    return null;
  }

  Future<bool> hasMilestoneReview({
    required String bookingId,
    required String reviewerId,
  }) async {
    final review = await getMilestoneReview(
      bookingId: bookingId,
      reviewerId: reviewerId,
    );
    return review != null;
  }

  Future<Review?> getMilestoneReview({
    required String bookingId,
    required String reviewerId,
  }) async {
    try {
      final snap = await _db
          .collection(FirestoreCollections.reviews)
          .where('bookingId', isEqualTo: bookingId)
          .where('reviewerId', isEqualTo: reviewerId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return Review.fromFirestore(snap.docs.first.id, snap.docs.first.data());
      }
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
    }
    final all = await reviewsForBooking(bookingId);
    return _reviewByReviewer(all, reviewerId);
  }

  Future<bool> hasReviewForBooking(String bookingId) async {
    final reviews = await reviewsForBooking(bookingId);
    return reviews.any((r) => r.isCustomerReview);
  }

  Future<Review?> getReviewForBooking(
    String bookingId, {
    String? reviewerRole,
  }) async {
    if (reviewerRole != null) {
      final snap = await _db
          .collection(FirestoreCollections.reviews)
          .where('bookingId', isEqualTo: bookingId)
          .where('reviewerRole', isEqualTo: reviewerRole)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return Review.fromFirestore(snap.docs.first.id, snap.docs.first.data());
      }
      return null;
    }
    final snap = await _db
        .collection(FirestoreCollections.reviews)
        .where('bookingId', isEqualTo: bookingId)
        .limit(10)
        .get();
    if (snap.docs.isEmpty) return null;
    for (final doc in snap.docs) {
      final r = Review.fromFirestore(doc.id, doc.data());
      if (r.isCustomerReview) return r;
    }
    return Review.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  }

  Stream<Review?> milestoneReviewStream({
    required String bookingId,
    required String reviewerId,
  }) {
    final key = 'milestoneReview:$bookingId:$reviewerId';
    return _cache(key, () {
      return reviewsForBookingStream(
        bookingId,
      ).map((reviews) => _reviewByReviewer(reviews, reviewerId));
    });
  }

  Future<void> createMilestoneReview({
    required Booking booking,
    required String reviewerId,
    required String reviewerRole,
    required int rating,
    String? comment,
    Future<bool> Function(String warning)? onSentimentWarning,
  }) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) {
      throw StateError('You must be signed in to leave a review.');
    }
    if (authUid != reviewerId) {
      throw StateError('Review must be submitted from your signed-in account.');
    }

    final role = reviewerRole.toLowerCase();
    if (role != 'customer' && role != 'provider') {
      throw ArgumentError('reviewerRole must be customer or provider');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }

    final snap = await _db
        .collection(FirestoreCollections.bookings)
        .doc(booking.bookingId)
        .get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Booking not found. Open the booking again and retry.');
    }
    final fresh = Booking.fromFirestore(snap.id, snap.data()!);

    if (!fresh.isMilestoneComplete) {
      throw StateError(
        'Reviews unlock after the customer confirms the reported work is complete (current status: ${fresh.status}).',
      );
    }
    if (role == 'customer' && fresh.customerId != authUid) {
      throw StateError(
        'Only the customer on this booking can leave this review.',
      );
    }
    if (role == 'provider' && fresh.providerId != authUid) {
      throw StateError(
        'Only the provider on this booking can leave this review.',
      );
    }

    final existing = await getMilestoneReview(
      bookingId: fresh.bookingId,
      reviewerId: reviewerId,
    );
    if (existing != null) {
      throw StateError('You already reviewed this milestone');
    }

    final trimmedComment = comment?.trim();

    try {
      final result = await _submitMilestoneReviewCallable(
        bookingId: fresh.bookingId,
        reviewerRole: role,
        rating: rating,
        comment: trimmedComment,
      );
      if (result['requiresConfirmation'] == true) {
        final proceed =
            await onSentimentWarning?.call(result['warning'] as String) ?? true;
        if (!proceed) {
          throw StateError(
            'Review kept as a draft. You can edit it and submit again.',
          );
        }
        await _submitMilestoneReviewCallable(
          bookingId: fresh.bookingId,
          reviewerRole: role,
          rating: rating,
          comment: trimmedComment,
          confirmSentimentMismatch: true,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      throw StateError(_milestoneReviewFunctionsMessage(e));
    }
  }

  Future<Map<String, dynamic>> _submitMilestoneReviewCallable({
    required String bookingId,
    required String reviewerRole,
    required int rating,
    String? comment,
    bool confirmSentimentMismatch = false,
  }) async {
    final functions = FirebaseFunctions.instanceFor(
      region: kNeighborHelpFunctionsRegion,
    );
    final callable = functions.httpsCallable('submitMilestoneReview');
    final result = await callable.call(<String, dynamic>{
      'bookingId': bookingId,
      'reviewerRole': reviewerRole,
      'rating': rating,
      'confirmSentimentMismatch': confirmSentimentMismatch,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  String _milestoneReviewFunctionsMessage(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'You must be signed in to leave a review.';
      case 'permission-denied':
        return e.message ?? 'You cannot leave a review on this booking.';
      case 'failed-precondition':
        return e.message ??
            'Reviews unlock after the milestone is marked complete.';
      case 'already-exists':
        return 'You already reviewed this milestone.';
      case 'not-found':
        return e.message ?? 'Booking not found.';
      case 'invalid-argument':
        return e.message ?? 'Invalid review data.';
      default:
        return e.message ?? 'Could not submit feedback. Try again.';
    }
  }

  Future<void> createReview({
    required String bookingId,
    required String customerId,
    required String providerId,
    required String serviceId,
    required int rating,
    String? comment,
  }) async {
    final snap = await _db
        .collection(FirestoreCollections.bookings)
        .doc(bookingId)
        .get();
    if (!snap.exists) throw StateError('Booking not found');
    final booking = Booking.fromFirestore(snap.id, snap.data()!);
    await createMilestoneReview(
      booking: booking,
      reviewerId: customerId,
      reviewerRole: 'customer',
      rating: rating,
      comment: comment,
    );
  }

  Future<Map<String, dynamic>?> providerAvailability(String providerId) async =>
      (await getProviderProfile(
        providerId,
      ))?.effectiveWeeklyAvailability.toFirestore();

  Future<void> updateProviderAvailability({
    required String providerId,
    required Map<String, dynamic> weeklyAvailability,
  }) {
    return updateServiceProvider(
      providerId: providerId,
      data: {'weeklyAvailability': weeklyAvailability},
    );
  }

  Stream<List<n.AppNotification>> allNotificationsStream() {
    return _cache('allNotifications', () {
      return _db
          .collection(FirestoreCollections.notifications)
          .limit(200)
          .snapshots()
          .map((s) {
            final list = s.docs
                .map((d) => n.AppNotification.fromFirestore(d.id, d.data()))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });
    });
  }

  Future<void> adminSendNotification({
    required String userId,
    required String title,
    required String message,
    String notificationType = 'Announcement',
    bool pushEnabled = true,
  }) async {
    final ref = _db.collection(FirestoreCollections.notifications).doc();
    await ref.set({
      'userId': userId,
      'title': title,
      'message': message,
      'notificationType': notificationType,
      'pushEnabled': pushEnabled,
      'relatedBookingId': null,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> adminBroadcastNotification({
    required String title,
    required String message,
    UserRole? roleFilter,
    String notificationType = 'Broadcast',
    bool pushEnabled = true,
  }) async {
    final usersSnap = await _db.collection(FirestoreCollections.users).get();
    var users = usersSnap.docs
        .where(
          (d) =>
              d.data()['accountStatus'] == 'Active' &&
              [
                'Customer',
                'Provider',
                'Administrator',
              ].contains(d.data()['role']),
        )
        .toList();
    if (roleFilter != null) {
      users = users
          .where((d) => d.data()['role'] == roleFilter.firestoreValue)
          .toList();
    }
    var sent = 0;
    for (final doc in users) {
      await adminSendNotification(
        userId: doc.id,
        title: title,
        message: message,
        notificationType: notificationType,
        pushEnabled: pushEnabled,
      );
      sent++;
    }
    return sent;
  }

  // --- Admin ---

  Stream<List<AppUser>> allUsersStream() => _cache('allUsers', () async* {
    if (await _isAdministrator()) {
      yield* _db
          .collection(FirestoreCollections.users)
          .snapshots()
          .map(
            (s) =>
                s.docs
                    .map((d) => AppUser.fromFirestore(d.id, d.data()))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          );
    } else {
      yield* _publicRecords<AppUser>(
        query: _db.collection('publicProfiles'),
        bootstrap: () => _publicDirectory(),
        parse: _publicUser,
        id: (u) => u.userId,
      );
    }
  });

  Stream<List<Booking>> allBookingsStream() {
    return _cache('allBookings', () {
      return _db.collection(FirestoreCollections.bookings).snapshots().map((s) {
        final list = s.docs
            .map((d) => Booking.fromFirestore(d.id, d.data()))
            .toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return list;
      });
    });
  }

  Stream<List<ServiceListing>> allServicesStream() {
    return _cache('allServices', () {
      return _db.collection(FirestoreCollections.services).snapshots().map((s) {
        final list = s.docs
            .map((d) => ServiceListing.fromFirestore(d.id, d.data()))
            .toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return list;
      });
    });
  }

  Future<AdminDashboardStats> adminDashboardStats() async {
    final users = await _db.collection(FirestoreCollections.users).get();
    final providers = await _db
        .collection(FirestoreCollections.serviceProviders)
        .get();
    final bookings = await _db.collection(FirestoreCollections.bookings).get();
    final services = await _db.collection(FirestoreCollections.services).get();

    var customers = 0;
    for (final d in users.docs) {
      final role = UserRole.fromFirestore(d.data()['role']?.toString());
      if (role == UserRole.customer) customers++;
    }

    var pendingVerification = 0;
    for (final d in providers.docs) {
      final verified = d.data()['isVerified'] as bool? ?? false;
      final status = d.data()['verificationStatus'] as String? ?? 'Pending';
      if (!verified || status.toLowerCase() == 'pending') pendingVerification++;
    }

    var pendingBookings = 0;
    for (final d in bookings.docs) {
      final status = (d.data()['status'] as String? ?? '').toLowerCase();
      if (status == 'pending') pendingBookings++;
    }

    var activeServices = 0;
    for (final d in services.docs) {
      if (d.data()['isActive'] as bool? ?? true) activeServices++;
    }

    return AdminDashboardStats(
      customerCount: customers,
      providerCount: providers.docs.length,
      bookingCount: bookings.docs.length,
      pendingVerificationCount: pendingVerification,
      pendingBookingCount: pendingBookings,
      activeServiceCount: activeServices,
    );
  }

  Future<void> adminVerifyCustomer({
    required String userId,
    required bool approve,
    String? reviewedByUserId,
    String reviewedByRole = 'Administrator',
  }) async {
    final ref = userDoc(userId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Customer profile not found.');
    }
    final user = AppUser.fromFirestore(snap.id, snap.data() ?? {});
    if (!user.canAdminReviewVerification) {
      throw StateError('Customer has not completed Didit verification.');
    }
    if (approve &&
        ![
          'approved',
          'active',
        ].contains(user.identityVerification.diditStatus.toLowerCase())) {
      throw StateError(
        'Didit must approve the identity before it can be verified.',
      );
    }
    await updateUserProfile(
      userId: userId,
      data: {
        'isVerified': approve,
        'verificationStatus': approve ? 'Approved' : 'Rejected',
        'verificationManualDecision': approve ? 'Approved' : 'Rejected',
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedByRole': 'Administrator',
        if (reviewedByUserId != null)
          'verificationReviewedBy': reviewedByUserId,
        'verificationReviewedByRole': reviewedByRole,
        'verificationReviewedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> adminVerifyProvider({
    required String providerId,
    required bool approve,
    String? reviewedByUserId,
    String reviewedByRole = 'Administrator',
  }) async {
    final ref = _db
        .collection(FirestoreCollections.serviceProviders)
        .doc(providerId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Provider profile not found.');
    }
    final profile = ServiceProviderProfile.fromFirestore(
      snap.id,
      snap.data() ?? {},
    );
    if (!profile.canAdminReviewVerification) {
      throw StateError('No identity verification is available for review.');
    }
    if (approve &&
        !['approved', 'active'].contains(profile.diditStatus.toLowerCase())) {
      throw StateError(
        'Didit must approve the identity before it can be verified.',
      );
    }
    await updateServiceProvider(
      providerId: providerId,
      data: {
        'isVerified': approve,
        'verificationStatus': approve ? 'Approved' : 'Rejected',
        'verificationManualDecision': approve ? 'Approved' : 'Rejected',
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedByRole': 'Administrator',
        if (reviewedByUserId != null)
          'verificationReviewedBy': reviewedByUserId,
        'verificationReviewedByRole': reviewedByRole,
        'verificationReviewedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> adminSetUserAccountStatus({
    required String userId,
    required AccountStatus status,
  }) {
    return updateUserProfile(
      userId: userId,
      data: {
        'accountStatus': status.firestoreValue,
        'updatedByRole': 'Administrator',
      },
    );
  }

  Future<void> adminSetBookingStatus(String bookingId, String status) {
    return updateBookingStatus(bookingId, status);
  }

  Future<void> markNotificationRead(String notificationId) {
    return _db
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<AppUser?> getUser(String userId) =>
      _read('user:$userId', () => userStream(userId).first);
}
