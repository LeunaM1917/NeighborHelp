import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_report.dart';
import '../models/booking.dart';
import '../models/provider.dart';
import '../models/review.dart';
import '../models/service.dart';
import '../utils/report_analytics.dart';

/// Server snapshots are retained across local filter/chart changes. Date changes
/// read only bookings/reviews in that interval; refresh also reloads metadata.
class AdminReportRepository {
  AdminReportRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  Future<List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>? _metadata;
  void refresh() => _metadata = null;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _read(
    Query<Map<String, dynamic>> query,
  ) async {
    final docs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    QueryDocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      var page = query.limit(500);
      if (last != null) page = page.startAfterDocument(last);
      final snapshot = await page.get(const GetOptions(source: Source.server));
      for (final doc in snapshot.docs) {
        docs[doc.id] = doc;
      }
      if (snapshot.docs.length < 500) return docs.values.toList();
      last = snapshot.docs.last;
    }
  }

  Future<AdminReportData> load(ReportPeriod period, String uid) async {
    final admin =
        (await _db
                .collection('users')
                .doc(uid)
                .get(const GetOptions(source: Source.server)))
            .data();
    if (admin?['role'] != 'Administrator' ||
        admin?['accountStatus'] != 'Active') {
      throw StateError('Active administrator access required.');
    }
    Query<Map<String, dynamic>> dated(String collection) => _db
        .collection(collection)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(period.start),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(period.endExclusive))
        .orderBy('createdAt')
        .orderBy(FieldPath.documentId);
    final metadata = _metadata ??= Future.wait([
      for (final collection in ['services', 'serviceProviders', 'users'])
        _read(_db.collection(collection).orderBy(FieldPath.documentId)),
    ]);
    try {
      final result = await Future.wait([
        _read(dated('bookings')),
        _read(dated('reviews')),
        metadata,
      ]);
      final bookings =
          result[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final reviews =
          result[1] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final meta =
          result[2] as List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>;
      final identities = <String, ReportVerification>{};
      // The identity workflow updates providers in serviceProviders and customers
      // in users. Never count the provider's mirrored user record a second time.
      for (final user in meta[2]) {
        if (const ['Customer', 'Provider'].contains(user.data()['role'])) {
          identities[user.id] = ReportVerification.fromMap(
            user.id,
            user.data(),
          );
        }
      }
      for (final provider in meta[1]) {
        final id = provider.data()['userId'] as String? ?? provider.id;
        identities[id] = ReportVerification.fromMap(id, {
          ...provider.data(),
          'role': 'Provider',
        });
      }
      return AdminReportData(
        period: period,
        loadedAt: DateTime.now().toUtc(),
        bookings: bookings
            .map((d) => Booking.fromFirestore(d.id, d.data()))
            .toList(),
        reviews: reviews
            .map((d) => Review.fromFirestore(d.id, d.data()))
            .toList(),
        services: {
          for (final d in meta[0])
            d.id: ServiceListing.fromFirestore(d.id, d.data()),
        },
        providers: meta[1]
            .map((d) => ServiceProviderProfile.fromFirestore(d.id, d.data()))
            .toList(),
        verifications: identities.values.toList(),
        missingDates: identities.values.where((v) => v.at == null).length,
      );
    } catch (_) {
      _metadata = null;
      rethrow;
    }
  }
}
