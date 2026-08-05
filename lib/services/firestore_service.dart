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
import '../models/provider_certification.dart';
import '../models/review.dart';
import '../models/service_contract.dart';
import '../models/account_status.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/service.dart';
import '../models/service_approval_status.dart';
import '../models/user_role.dart';
import '../constants/functions_config.dart';
import '../utils/message_thread.dart';

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
  final Map<String, _ReplayStream<dynamic>> _streams = {};

  /// Memoized stream that **replays the latest event** to every new listener.
  ///
  /// Plain [Stream.asBroadcastStream] does not replay, and a broadcast
  /// `onListen` callback only fires on the 0→1 listener transition. So a second
  /// [StreamBuilder] (e.g. opening a chat while the conversation list is still
  /// subscribed) would stay stuck on "Loading…" until the next Firestore write.
  /// [_ReplayStream] hands every new subscriber the cached latest value (or
  /// error) immediately, then forwards live updates.
  Stream<T> _cache<T>(String key, Stream<T> Function() create) {
    final existing = _streams[key];
    if (existing != null) return (existing as _ReplayStream<T>).stream;

    final replay = _ReplayStream<T>(create());
    _streams[key] = replay;
    return replay.stream;
  }

  DocumentReference<Map<String, dynamic>> userDoc(String userId) {
    return _db.collection(FirestoreCollections.users).doc(userId);
  }

  Stream<AppUser?> userStream(String userId) {
    return _cache('user:$userId', () {
      return userDoc(userId).snapshots().map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return AppUser.fromFirestore(snap.id, snap.data()!);
      });
    });
  }

  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return userDoc(userId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ServiceProviderProfile>> serviceProvidersStream() {
    return _cache('serviceProviders', () {
      return _db.collection(FirestoreCollections.serviceProviders).snapshots().map(
            (s) => s.docs.map((d) => ServiceProviderProfile.fromFirestore(d.id, d.data())).toList(),
          );
    });
  }

  /// Resolves the Firestore document id for a provider (usually equals [userId]).
  Future<String> resolveProviderDocumentId(String userOrProviderId) async {
    final direct = await _db.collection(FirestoreCollections.serviceProviders).doc(userOrProviderId).get();
    if (direct.exists) return userOrProviderId;

    final query = await _db
        .collection(FirestoreCollections.serviceProviders)
        .where('userId', isEqualTo: userOrProviderId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) return query.docs.first.id;
    return userOrProviderId;
  }

  static Map<String, dynamic> _defaultProviderFields(String userId, Timestamp now) => {
        'userId': userId,
        'bio': '',
        'serviceArea': '',
        'location': const GeoPoint(14.5995, 120.9842),
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
  Future<void> _patchProviderVerificationGuardFields(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic>? data,
  ) async {
    if (data == null) return;
    final patches = <String, dynamic>{};
    if (!data.containsKey('isVerified')) patches['isVerified'] = false;
    if (!data.containsKey('verificationStatus')) patches['verificationStatus'] = 'Pending';
    if (!data.containsKey('diditStatus')) patches['diditStatus'] = '';
    if (!data.containsKey('diditSessionId')) patches['diditSessionId'] = '';
    if (!data.containsKey('verificationProvider')) patches['verificationProvider'] = '';
    if (!data.containsKey('governmentIdTypeCode')) patches['governmentIdTypeCode'] = '';
    if (!data.containsKey('governmentIdTypeLabel')) patches['governmentIdTypeLabel'] = '';
    if (patches.isEmpty) return;
    await ref.set(patches, SetOptions(merge: true));
  }

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

    final ref = _db.collection(FirestoreCollections.serviceProviders).doc(userId);
    final snap = await ref.get();
    if (!snap.exists) {
      final now = Timestamp.now();
      await ref.set(_defaultProviderFields(userId, now));
      return;
    }
    await _patchProviderVerificationGuardFields(ref, snap.data());
  }

  /// Removes empty `serviceProviders/{uid}` docs created by mistaken customer Didit flows.
  Future<bool> removeMistakenProviderProfileIfCustomer(String userId) async {
    final userSnap = await userDoc(userId).get();
    if (!userSnap.exists) return false;
    final storedRole = UserRole.fromFirestore(userSnap.data()?['role'] as String?);
    if (storedRole == UserRole.administrator) return false;

    final providerRef = _db.collection(FirestoreCollections.serviceProviders).doc(userId);
    final providerSnap = await providerRef.get();
    if (!providerSnap.exists) return false;

    final data = providerSnap.data() ?? {};
    final bio = (data['bio'] as String? ?? '').trim();
    final completed = (data['completedBookings'] as num?)?.toInt() ?? 0;
    final accepted = (data['acceptedBookings'] as num?)?.toInt() ?? 0;
    if (bio.isNotEmpty || completed > 0 || accepted > 0) return false;

    final services = await _db
        .collection(FirestoreCollections.services)
        .where('providerId', isEqualTo: userId)
        .limit(1)
        .get();
    if (services.docs.isNotEmpty) return false;

    final mistakenForCustomer = storedRole == UserRole.customer;
    final likelyPromotedByMistake = storedRole == UserRole.provider;
    if (!mistakenForCustomer && !likelyPromotedByMistake) return false;

    await providerRef.delete();

    if (likelyPromotedByMistake) {
      await userDoc(userId).update({
        'role': UserRole.customer.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return true;
  }

  Future<void> updateServiceProvider({
    required String providerId,
    required Map<String, dynamic> data,
  }) async {
    // Rules require the document path id to match request.auth.uid.
    await ensureServiceProviderProfile(providerId);
    await _db.collection(FirestoreCollections.serviceProviders).doc(providerId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ServiceListing>> servicesForProvider(String providerId) {
    return _cache('servicesForProvider:$providerId', () {
      return _db
          .collection(FirestoreCollections.services)
          .where('providerId', isEqualTo: providerId)
          .snapshots()
          .map((s) => s.docs.map((d) => ServiceListing.fromFirestore(d.id, d.data())).toList());
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

  /// Emits [seed] immediately so [StreamBuilder] leaves `waiting` without waiting
  /// for Firestore, then forwards [source].
  Stream<T> _withSeed<T>(T seed, Stream<T> source) {
    return Stream.multi((controller) {
      controller.add(seed);
      final sub = source.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
        cancelOnError: false,
      );
      controller.onCancel = sub.cancel;
    });
  }

  Stream<ServiceProviderProfile?> providerProfileForUser(String userId) {
    return _cache('providerProfile:v2:$userId', () {
      return _withSeed<ServiceProviderProfile?>(
        null,
        _db.collection(FirestoreCollections.serviceProviders).doc(userId).snapshots().map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          return ServiceProviderProfile.fromFirestore(snap.id, snap.data()!);
        }),
      );
    });
  }

  /// Bookings where this user is the provider (auth uid and provider document id).
  Stream<List<Booking>> bookingsForProviderUser(String userId) {
    return _cache('bookingsForProviderUser:$userId', () {
      return _withSeed<List<Booking>>(const [], _providerBookingsStream(userId));
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
              .listen(
            (snap) {
              seen.removeWhere((_, b) => b.providerId == providerId);
              for (final doc in snap.docs) {
                final booking = Booking.fromFirestore(doc.id, doc.data());
                seen[booking.bookingId] = booking;
              }
              publish();
            },
            onError: controller.addError,
          ),
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
      return _withSeed<List<ServiceListing>>(const [], _providerServicesStream(userId));
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
              .listen(
            (snap) {
              seen.removeWhere((_, s) => s.providerId == providerId);
              for (final doc in snap.docs) {
                final service = ServiceListing.fromFirestore(doc.id, doc.data());
                seen[service.serviceId] = service;
              }
              publish();
            },
            onError: controller.addError,
          ),
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

  Future<ServiceListing?> getService(String serviceId) async {
    final snap = await _db.collection(FirestoreCollections.services).doc(serviceId).get();
    if (!snap.exists || snap.data() == null) return null;
    return ServiceListing.fromFirestore(snap.id, snap.data()!);
  }

  /// Service titles keyed by listing id (for review job labels on profiles).
  Future<Map<String, String>> serviceTitlesByIds(Iterable<String> serviceIds) async {
    final unique = serviceIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
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
  }

  Future<ServiceProviderProfile?> getProviderProfile(String userId) async {
    final snap = await _db.collection(FirestoreCollections.serviceProviders).doc(userId).get();
    if (snap.exists && snap.data() != null) {
      return ServiceProviderProfile.fromFirestore(snap.id, snap.data()!);
    }
    final query = await _db
        .collection(FirestoreCollections.serviceProviders)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return ServiceProviderProfile.fromFirestore(doc.id, doc.data());
  }

  /// Creates a new service document; returns the new document id.
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
    return ref.set({
      ...listing.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).then((_) => ref);
  }

  Future<void> updateService(String serviceId, Map<String, dynamic> data) {
    return _db.collection(FirestoreCollections.services).doc(serviceId).update({
      ...data,
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
  }) {
    final data = <String, dynamic>{
      'approvalStatus': status.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
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

  Future<void> createBooking(Booking booking) {
    return _db.collection(FirestoreCollections.bookings).doc(booking.bookingId).set(booking.toMap());
  }

  Stream<Booking?> bookingStream(String bookingId) {
    return _cache('booking:$bookingId', () {
      return _db.collection(FirestoreCollections.bookings).doc(bookingId).snapshots().map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return Booking.fromFirestore(snap.id, snap.data()!);
      });
    });
  }

  Future<Booking?> getBooking(String bookingId) async {
    if (bookingId.isEmpty) return null;
    final snap = await _db.collection(FirestoreCollections.bookings).doc(bookingId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Booking.fromFirestore(snap.id, snap.data()!);
  }

  Future<void> updateBookingStatus(String bookingId, String status) {
    return _db.collection(FirestoreCollections.bookings).doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> providerRespondToBooking({
    required String bookingId,
    required String providerId,
    required bool accept,
  }) async {
    final ref = _db.collection(FirestoreCollections.bookings).doc(bookingId);
    if (accept) {
      final snap = await ref.get();
      if (!snap.exists) throw StateError('Booking not found');
      final data = snap.data()!;
      if (data['providerId'] != providerId) throw StateError('Not your booking');
      final customerId = data['customerId'] as String? ?? '';
      final contractId = await _ensureActiveContract(
        customerId: customerId,
        providerId: providerId,
      );
      final milestoneNumber = await _assignNextMilestone(contractId);
      await ref.update({
        'status': 'Accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'contractId': contractId,
        'milestoneNumber': milestoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _db.collection(FirestoreCollections.serviceProviders).doc(providerId).update({
        'acceptedBookings': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({
        'status': 'Cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> _ensureActiveContract({
    required String customerId,
    required String providerId,
  }) async {
    final existing = await _db
        .collection(FirestoreCollections.contracts)
        .where('customerId', isEqualTo: customerId)
        .where('providerId', isEqualTo: providerId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final ref = _db.collection(FirestoreCollections.contracts).doc();
    await ref.set({
      'customerId': customerId,
      'providerId': providerId,
      'status': 'active',
      'milestoneCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<int> _assignNextMilestone(String contractId) async {
    final ref = _db.collection(FirestoreCollections.contracts).doc(contractId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Contract not found');
      final count = (snap.data()?['milestoneCount'] as num?)?.toInt() ?? 0;
      final next = count + 1;
      tx.update(ref, {
        'milestoneCount': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return next;
    });
  }

  Stream<ServiceContract?> contractStream(String contractId) {
    return _db.collection(FirestoreCollections.contracts).doc(contractId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ServiceContract.fromFirestore(snap.id, snap.data()!);
    });
  }

  Future<ServiceContract?> getContract(String contractId) async {
    final snap = await _db.collection(FirestoreCollections.contracts).doc(contractId).get();
    if (!snap.exists || snap.data() == null) return null;
    return ServiceContract.fromFirestore(snap.id, snap.data()!);
  }

  Stream<List<Booking>> bookingsForContract(String contractId) {
    return _db
        .collection(FirestoreCollections.bookings)
        .where('contractId', isEqualTo: contractId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Booking.fromFirestore(d.id, d.data())).toList();
      list.sort((a, b) {
        final ma = a.milestoneNumber ?? 0;
        final mb = b.milestoneNumber ?? 0;
        return ma.compareTo(mb);
      });
      return list;
    });
  }

  Future<void> endContract({
    required String contractId,
    required String endedByUserId,
    required String endedByRole,
  }) async {
    final ref = _db.collection(FirestoreCollections.contracts).doc(contractId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Contract not found');
    final data = snap.data()!;
    final customerId = data['customerId'] as String? ?? '';
    final providerId = data['providerId'] as String? ?? '';
    if (endedByUserId != customerId && endedByUserId != providerId) {
      throw StateError('Only the customer or provider can end this contract');
    }
    if ((data['status'] as String? ?? '').toLowerCase() == 'ended') {
      return;
    }
    await ref.update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'endedByUserId': endedByUserId,
      'endedByRole': endedByRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> customerCancelBooking({
    required String bookingId,
    required String customerId,
    required String reason,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.length < 10) {
      throw StateError('Please provide a cancellation explanation (at least 10 characters).');
    }

    final ref = _db.collection(FirestoreCollections.bookings).doc(bookingId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Booking not found');
    final data = snap.data()!;
    if (data['customerId'] != customerId) throw StateError('Not your booking');

    final status = (data['status'] as String? ?? '').toLowerCase();
    if (status == 'pending') {
      throw StateError('Wait for the provider to respond, or contact support if you need help.');
    }
    if (status == 'cancelled' || status == 'canceled') {
      throw StateError('This booking is already cancelled.');
    }
    if (status == 'completed' || status == 'milestone complete') {
      throw StateError('Completed bookings cannot be cancelled.');
    }
    if (status != 'accepted' && status != 'in progress') {
      throw StateError('This booking cannot be cancelled.');
    }

    await ref.update({
      'status': 'Cancelled',
      'cancellationReason': trimmed,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledByRole': 'customer',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> providerCancelBooking({
    required String bookingId,
    required String providerId,
    required String reason,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.length < 10) {
      throw StateError('Please provide a cancellation explanation (at least 10 characters).');
    }

    final ref = _db.collection(FirestoreCollections.bookings).doc(bookingId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Booking not found');
    final data = snap.data()!;
    if (data['providerId'] != providerId) throw StateError('Not your booking');

    final status = (data['status'] as String? ?? '').toLowerCase();
    if (status == 'pending') {
      throw StateError('Use decline on pending requests instead of cancel.');
    }
    if (status == 'cancelled' || status == 'canceled') {
      throw StateError('This booking is already cancelled.');
    }
    if (status == 'completed' || status == 'milestone complete') {
      throw StateError('Completed bookings cannot be cancelled.');
    }
    if (status != 'accepted' && status != 'in progress') {
      throw StateError('This booking cannot be cancelled.');
    }

    await ref.update({
      'status': 'Cancelled',
      'cancellationReason': trimmed,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledByRole': 'provider',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> providerStartBooking({
    required String bookingId,
    required String providerId,
  }) async {
    final ref = _db.collection(FirestoreCollections.bookings).doc(bookingId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Booking not found');
    final data = snap.data()!;
    if (data['providerId'] != providerId) throw StateError('Not your booking');
    final status = (data['status'] as String? ?? '').toLowerCase();
    if (status != 'accepted') throw StateError('Booking must be accepted before starting');
    if (data['startedAt'] != null) throw StateError('Job already started');

    await ref.update({
      'status': 'In Progress',
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> providerCompleteBooking({
    required String bookingId,
    required String providerId,
  }) async {
    final ref = _db.collection(FirestoreCollections.bookings).doc(bookingId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Booking not found');
    final booking = Booking.fromFirestore(snap.id, snap.data()!);
    if (booking.providerId != providerId) throw StateError('Not your booking');
    if (!booking.canCompleteMilestone) {
      throw StateError('Work period has not finished yet');
    }

    await ref.update({
      'status': 'Milestone Complete',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection(FirestoreCollections.serviceProviders).doc(providerId).update({
      'completedBookings': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 3) {
      throw StateError('Please provide a reason (at least 3 characters).');
    }
    final trimmedDetails = details.trim();

    final reportId = '${bookingId}_${reporterId}_${reportedUserId}';
    final ref = _db.collection(FirestoreCollections.bookingUserReports).doc(reportId);

    final existing = await ref.get();
    if (existing.exists) {
      throw StateError('You have already submitted a report for this booking.');
    }

    await ref.set({
      'bookingId': bookingId,
      'reportId': reportId,
      'reporterId': reporterId,
      'reporterRole': reporterRole,
      'reportedUserId': reportedUserId,
      'reportedRole': reportedRole,
      'reason': trimmedReason,
      'details': trimmedDetails,
      'status': BookingUserReport.statusOpen,
      'createdAt': FieldValue.serverTimestamp(),
      'adminNotes': '',
      'resolvedAt': null,
    });
  }

  /// Admin: stream all booking user reports (newest first).
  Stream<List<BookingUserReport>> allBookingUserReportsStream() {
    return _cache('allBookingUserReports', () {
      return _db.collection(FirestoreCollections.bookingUserReports).limit(250).snapshots().map((s) {
        final list = s.docs.map((d) => BookingUserReport.fromFirestore(d.id, d.data())).toList();
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

    await _db.collection(FirestoreCollections.bookingUserReports).doc(reportId).update({
      'status': normalized,
      'adminNotes': adminNotes.trim(),
      'resolvedAt': FieldValue.serverTimestamp(),
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
    final ref = _db.collection(FirestoreCollections.messages).doc();
    final threadId = messageThreadId(customerId, providerId);
    final message = ChatMessage(
      messageId: ref.id,
      bookingId: bookingId,
      threadId: threadId,
      senderId: senderId,
      receiverId: receiverId,
      messageText: text,
      mediaUrl: null,
      messageType: 'Text',
      isRead: false,
      sentAt: Timestamp.now(),
    );
    await ref.set(message.toMap());
    await _db.collection(FirestoreCollections.bookings).doc(bookingId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks all unread messages in a thread as read for [readerId].
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

  Stream<int> unreadMessageCountStream(String userId) {
    return _cache('unreadMessages:$userId', () {
      return _db
          .collection(FirestoreCollections.messages)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((s) => s.docs.length);
    });
  }

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
            final list = s.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });
    });
  }

  Stream<List<Booking>> bookingsForUser(String userId, {bool asCustomer = true}) {
    final field = asCustomer ? 'customerId' : 'providerId';
    return _cache('bookings:$field:$userId', () {
      return _withSeed(
        const <Booking>[],
        _db.collection(FirestoreCollections.bookings).where(field, isEqualTo: userId).snapshots().map((s) {
          final list = s.docs.map((d) => Booking.fromFirestore(d.id, d.data())).toList();
          list.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
          return list;
        }),
      );
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
            final list = s.docs.map((d) => n.AppNotification.fromFirestore(d.id, d.data())).toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });
    });
  }

  Stream<List<ChatMessage>> messagesForBooking(String bookingId) {
    return _cache('messages:$bookingId', () {
      return _db
          .collection(FirestoreCollections.messages)
          .where('bookingId', isEqualTo: bookingId)
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
    final idsKey = bookingIds.isEmpty ? 'none' : bookingIds.join(',');
    return _cache('messagesThread:$threadId:$idsKey', () {
      final threadStream = _db
          .collection(FirestoreCollections.messages)
          .where('threadId', isEqualTo: threadId)
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
              .where('bookingId', whereIn: chunk)
              .snapshots(),
        );
      }

      final controller = StreamController<List<ChatMessage>>.broadcast();
      QuerySnapshot<Map<String, dynamic>>? threadSnap;
      final legacySnaps = List<QuerySnapshot<Map<String, dynamic>>?>.filled(legacyStreams.length, null);

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
        final list = byId.values.toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        if (!controller.isClosed) controller.add(list);
      }

      final threadSub = threadStream.listen(
        (s) {
          threadSnap = s;
          emitMerged();
        },
        onError: controller.addError,
      );

      final legacySubs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < legacyStreams.length; i++) {
        final index = i;
        legacySubs.add(
          legacyStreams[i].listen(
            (s) {
              legacySnaps[index] = s;
              emitMerged();
            },
            onError: controller.addError,
          ),
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

  static List<ChatMessage> _mapAndSortMessages(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map((d) => ChatMessage.fromFirestore(d.id, d.data())).toList();
    list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return list;
  }

  Future<int> countCollection(String name) async {
    final snapshot = await _db.collection(name).count().get();
    return snapshot.count ?? 0;
  }

  Future<List<Review>> reviewsForProvider(String providerId) async {
    final snap = await _db
        .collection(FirestoreCollections.reviews)
        .where('providerId', isEqualTo: providerId)
        .limit(100)
        .get();
    final list = snap.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList();
    return list.where((r) => r.isCustomerReview).toList();
  }

  /// Feedback from providers about this customer (for provider due diligence).
  Future<List<Review>> reviewsForCustomer(String customerId) async {
    final snap = await _db
        .collection(FirestoreCollections.reviews)
        .where('revieweeId', isEqualTo: customerId)
        .where('reviewerRole', isEqualTo: 'provider')
        .limit(100)
        .get();
    final list = snap.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<Review>> reviewsByCustomer(String customerId) async {
    final snap = await _db
        .collection(FirestoreCollections.reviews)
        .where('customerId', isEqualTo: customerId)
        .limit(100)
        .get();
    final list = snap.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList();
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
          .map((snap) => snap.docs.map((d) => Review.fromFirestore(d.id, d.data())).toList());
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
    final review = await getMilestoneReview(bookingId: bookingId, reviewerId: reviewerId);
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

  Future<Review?> getReviewForBooking(String bookingId, {String? reviewerRole}) async {
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
      return reviewsForBookingStream(bookingId).map((reviews) => _reviewByReviewer(reviews, reviewerId));
    });
  }

  Future<void> createMilestoneReview({
    required Booking booking,
    required String reviewerId,
    required String reviewerRole,
    required int rating,
    String? comment,
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

    final snap = await _db.collection(FirestoreCollections.bookings).doc(booking.bookingId).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Booking not found. Open the booking again and retry.');
    }
    final fresh = Booking.fromFirestore(snap.id, snap.data()!);

    if (!fresh.isMilestoneComplete) {
      throw StateError(
        'Reviews unlock after the provider marks the milestone complete (current status: ${fresh.status}).',
      );
    }
    if (role == 'customer' && fresh.customerId != authUid) {
      throw StateError('Only the customer on this booking can leave this review.');
    }
    if (role == 'provider' && fresh.providerId != authUid) {
      throw StateError('Only the provider on this booking can leave this review.');
    }

    final revieweeId = role == 'customer' ? fresh.providerId : fresh.customerId;
    final existing = await getMilestoneReview(bookingId: fresh.bookingId, reviewerId: reviewerId);
    if (existing != null) throw StateError('You already reviewed this milestone');

    final trimmedComment = comment?.trim();

    try {
      await _submitMilestoneReviewCallable(
        bookingId: fresh.bookingId,
        reviewerRole: role,
        rating: rating,
        comment: trimmedComment,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unavailable') {
        await _submitMilestoneReviewDirect(
          booking: fresh,
          reviewerId: authUid,
          revieweeId: revieweeId,
          reviewerRole: role,
          rating: rating,
          comment: trimmedComment,
        );
        return;
      }
      throw StateError(_milestoneReviewFunctionsMessage(e));
    } on StateError {
      rethrow;
    } catch (_) {
      await _submitMilestoneReviewDirect(
        booking: fresh,
        reviewerId: authUid,
        revieweeId: revieweeId,
        reviewerRole: role,
        rating: rating,
        comment: trimmedComment,
      );
    }
  }

  Future<void> _submitMilestoneReviewCallable({
    required String bookingId,
    required String reviewerRole,
    required int rating,
    String? comment,
  }) async {
    final functions = FirebaseFunctions.instanceFor(region: kNeighborHelpFunctionsRegion);
    final callable = functions.httpsCallable('submitMilestoneReview');
    await callable.call(<String, dynamic>{
      'bookingId': bookingId,
      'reviewerRole': reviewerRole,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<void> _submitMilestoneReviewDirect({
    required Booking booking,
    required String reviewerId,
    required String revieweeId,
    required String reviewerRole,
    required int rating,
    String? comment,
  }) async {
    final ref = _db.collection(FirestoreCollections.reviews).doc();
    final payload = <String, dynamic>{
      'bookingId': booking.bookingId,
      'customerId': booking.customerId,
      'providerId': booking.providerId,
      'serviceId': booking.serviceId,
      'rating': rating,
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'reviewerRole': reviewerRole,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (comment != null && comment.isNotEmpty) payload['comment'] = comment;
    if (booking.contractId != null) payload['contractId'] = booking.contractId;
    if (booking.milestoneNumber != null) payload['milestoneNumber'] = booking.milestoneNumber;

    try {
      await ref.set(payload);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
          'Could not save review (permission denied). '
          'Deploy Firestore rules and Cloud Functions, then try again.',
        );
      }
      rethrow;
    }
  }

  String _milestoneReviewFunctionsMessage(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'You must be signed in to leave a review.';
      case 'permission-denied':
        return e.message ?? 'You cannot leave a review on this booking.';
      case 'failed-precondition':
        return e.message ?? 'Reviews unlock after the milestone is marked complete.';
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
    final snap = await _db.collection(FirestoreCollections.bookings).doc(bookingId).get();
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

  Future<Map<String, dynamic>?> providerAvailability(String providerId) async {
    final snap = await _db.collection(FirestoreCollections.serviceProviders).doc(providerId).get();
    if (!snap.exists) return null;
    final data = snap.data();
    return data?['weeklyAvailability'] as Map<String, dynamic>?;
  }

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
      return _db.collection(FirestoreCollections.notifications).limit(200).snapshots().map((s) {
        final list = s.docs.map((d) => n.AppNotification.fromFirestore(d.id, d.data())).toList();
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
  }) async {
    final ref = _db.collection(FirestoreCollections.notifications).doc();
    await ref.set({
      'userId': userId,
      'title': title,
      'message': message,
      'notificationType': notificationType,
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
  }) async {
    final usersSnap = await _db.collection(FirestoreCollections.users).get();
    var users = usersSnap.docs;
    if (roleFilter != null) {
      users = users.where((d) => d.data()['role'] == roleFilter.firestoreValue).toList();
    }
    var sent = 0;
    for (final doc in users) {
      await adminSendNotification(
        userId: doc.id,
        title: title,
        message: message,
        notificationType: notificationType,
      );
      sent++;
      if (sent >= 100) break;
    }
    return sent;
  }

  // --- Admin ---

  Stream<List<AppUser>> allUsersStream() {
    return _cache('allUsers', () {
      return _db.collection(FirestoreCollections.users).snapshots().map((s) {
        final list = s.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    });
  }

  Stream<List<Booking>> allBookingsStream() {
    return _cache('allBookings', () {
      return _db.collection(FirestoreCollections.bookings).snapshots().map((s) {
        final list = s.docs.map((d) => Booking.fromFirestore(d.id, d.data())).toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return list;
      });
    });
  }

  Stream<List<ServiceListing>> allServicesStream() {
    return _cache('allServices', () {
      return _db.collection(FirestoreCollections.services).snapshots().map((s) {
        final list = s.docs.map((d) => ServiceListing.fromFirestore(d.id, d.data())).toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return list;
      });
    });
  }

  Future<AdminDashboardStats> adminDashboardStats() async {
    final users = await _db.collection(FirestoreCollections.users).get();
    final providers = await _db.collection(FirestoreCollections.serviceProviders).get();
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
    await updateUserProfile(
      userId: userId,
      data: {
        'isVerified': approve,
        'verificationStatus': approve ? 'Approved' : 'Rejected',
        if (reviewedByUserId != null) 'verificationReviewedBy': reviewedByUserId,
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
    final ref = _db.collection(FirestoreCollections.serviceProviders).doc(providerId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Provider profile not found.');
    }
    final profile = ServiceProviderProfile.fromFirestore(snap.id, snap.data() ?? {});
    if (!profile.canAdminReviewVerification) {
      throw StateError('Provider has not completed Didit verification.');
    }
    await updateServiceProvider(
      providerId: providerId,
      data: {
        'isVerified': approve,
        'verificationStatus': approve ? 'Approved' : 'Rejected',
        if (reviewedByUserId != null) 'verificationReviewedBy': reviewedByUserId,
        'verificationReviewedByRole': reviewedByRole,
        'verificationReviewedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Verification Agency authenticates a submitted certification.
  Future<void> agencyReviewCertification({
    required String providerId,
    required String certificationEntryId,
    required bool approve,
    String? reviewedByUserId,
    String reviewedByRole = 'Verification Agency',
    String rejectionReason = '',
  }) async {
    final ref = _db.collection(FirestoreCollections.serviceProviders).doc(providerId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Provider profile not found.');
    }
    final profile = ServiceProviderProfile.fromFirestore(snap.id, snap.data() ?? {});
    final history = List<ProviderCertificationEntry>.from(profile.effectiveCertificationHistory);
    final idx = history.indexWhere((e) => e.id == certificationEntryId);
    if (idx < 0) {
      throw StateError('Certification not found.');
    }

    var entry = history[idx];
    if (entry.id.isEmpty) {
      entry = entry.copyWith(id: certificationEntryId.isNotEmpty ? certificationEntryId : ProviderCertificationEntry.newId());
    }

    history[idx] = entry.copyWith(
      status: approve
          ? CertificationVerificationStatus.approved
          : CertificationVerificationStatus.rejected,
      reviewedBy: reviewedByUserId ?? '',
      reviewedByRole: reviewedByRole,
      reviewedAt: Timestamp.now(),
      rejectionReason: approve ? '' : rejectionReason,
      clearReview: false,
    );

    final approvedIds = List<String>.from(profile.approvedCertificationIds);
    if (approve) {
      if (!approvedIds.contains(entry.id)) approvedIds.add(entry.id);
    } else {
      approvedIds.remove(entry.id);
    }

    await updateServiceProvider(
      providerId: providerId,
      data: {
        'certificationHistory': ProviderCertificationEntry.listToFirestore(history),
        'certifications': history.map((e) => e.displayLine).toList(),
        'approvedCertificationIds': approvedIds,
      },
    );
  }

  Future<void> adminSetUserAccountStatus({
    required String userId,
    required AccountStatus status,
  }) {
    return updateUserProfile(
      userId: userId,
      data: {'accountStatus': status.firestoreValue},
    );
  }

  Future<void> adminSetBookingStatus(String bookingId, String status) {
    return updateBookingStatus(bookingId, status);
  }

  Future<void> markNotificationRead(String notificationId) {
    return _db.collection(FirestoreCollections.notifications).doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<AppUser?> getUser(String userId) async {
    final snap = await userDoc(userId).get();
    if (!snap.exists || snap.data() == null) return null;
    return AppUser.fromFirestore(snap.id, snap.data()!);
  }
}

/// Subscribes once to [source] and replays the latest value (or error) to every
/// new listener, then forwards live events. Unlike a broadcast controller this
/// works no matter how many listeners are already attached, so opening a chat
/// while a preview is still subscribed no longer hangs on "Loading…".
class _ReplayStream<T> {
  _ReplayStream(Stream<T> source) {
    source.listen(
      (event) {
        _hasValue = true;
        _hasError = false;
        _latest = event;
        if (!_controller.isClosed) _controller.add(event);
      },
      onError: (Object error, StackTrace stack) {
        _hasError = true;
        _hasValue = false;
        _error = error;
        _stack = stack;
        if (!_controller.isClosed) _controller.addError(error, stack);
      },
      onDone: () {
        if (!_controller.isClosed) _controller.close();
      },
    );
  }

  final StreamController<T> _controller = StreamController<T>.broadcast();
  bool _hasValue = false;
  bool _hasError = false;
  T? _latest;
  Object? _error;
  StackTrace? _stack;

  Stream<T> get stream {
    return Stream<T>.multi((listener) {
      // Forward live events first so nothing emitted between the replay and the
      // subscription can slip through unobserved.
      final sub = _controller.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener.onCancel = sub.cancel;

      // A closed broadcast controller fires onDone to new listeners on its own,
      // so we only need to replay the cached value/error here.
      if (_hasError && _error != null) {
        listener.addError(_error!, _stack ?? StackTrace.current);
      } else if (_hasValue) {
        listener.add(_latest as T);
      }
    });
  }
}
