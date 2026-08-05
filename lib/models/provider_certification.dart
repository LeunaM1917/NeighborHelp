import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Agency review status for a submitted certification.
enum CertificationVerificationStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const CertificationVerificationStatus(this.firestoreValue);
  final String firestoreValue;

  static CertificationVerificationStatus fromFirestore(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'approved') return CertificationVerificationStatus.approved;
    if (v == 'rejected') return CertificationVerificationStatus.rejected;
    return CertificationVerificationStatus.pending;
  }
}

/// One certification on a provider profile.
class ProviderCertificationEntry {
  const ProviderCertificationEntry({
    this.id = '',
    this.name = '',
    this.provider = '',
    this.issueDate = '',
    this.expirationDate = '',
    this.description = '',
    this.certificationId = '',
    this.url = '',
    this.status = CertificationVerificationStatus.pending,
    this.reviewedBy = '',
    this.reviewedByRole = '',
    this.reviewedAt,
    this.rejectionReason = '',
  });

  static const maxDescriptionLength = 4000;

  /// Stable id for agency review (assigned on create).
  final String id;
  final String name;
  final String provider;
  /// ISO `yyyy-MM-dd` when set.
  final String issueDate;
  final String expirationDate;
  final String description;
  final String certificationId;
  final String url;
  final CertificationVerificationStatus status;
  final String reviewedBy;
  final String reviewedByRole;
  final Timestamp? reviewedAt;
  final String rejectionReason;

  bool get isEmpty => name.trim().isEmpty;
  bool get isPending => status == CertificationVerificationStatus.pending;
  bool get isApproved => status == CertificationVerificationStatus.approved;
  bool get isRejected => status == CertificationVerificationStatus.rejected;

  static String newId() {
    final rand = Random().nextInt(0x7fffffff).toRadixString(16);
    return 'cert_${DateTime.now().microsecondsSinceEpoch}_$rand';
  }

  ProviderCertificationEntry copyWith({
    String? id,
    String? name,
    String? provider,
    String? issueDate,
    String? expirationDate,
    String? description,
    String? certificationId,
    String? url,
    CertificationVerificationStatus? status,
    String? reviewedBy,
    String? reviewedByRole,
    Timestamp? reviewedAt,
    String? rejectionReason,
    bool clearReview = false,
  }) {
    return ProviderCertificationEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      issueDate: issueDate ?? this.issueDate,
      expirationDate: expirationDate ?? this.expirationDate,
      description: description ?? this.description,
      certificationId: certificationId ?? this.certificationId,
      url: url ?? this.url,
      status: status ?? this.status,
      reviewedBy: clearReview ? '' : (reviewedBy ?? this.reviewedBy),
      reviewedByRole: clearReview ? '' : (reviewedByRole ?? this.reviewedByRole),
      reviewedAt: clearReview ? null : (reviewedAt ?? this.reviewedAt),
      rejectionReason: clearReview ? '' : (rejectionReason ?? this.rejectionReason),
    );
  }

  factory ProviderCertificationEntry.fromMap(Map<String, dynamic> data) {
    return ProviderCertificationEntry(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      provider: data['provider'] as String? ?? '',
      issueDate: data['issueDate'] as String? ?? '',
      expirationDate: data['expirationDate'] as String? ?? '',
      description: data['description'] as String? ?? '',
      certificationId: data['certificationId'] as String? ?? '',
      url: data['url'] as String? ?? '',
      status: CertificationVerificationStatus.fromFirestore(data['status'] as String?),
      reviewedBy: data['reviewedBy'] as String? ?? '',
      reviewedByRole: data['reviewedByRole'] as String? ?? '',
      reviewedAt: data['reviewedAt'] is Timestamp ? data['reviewedAt'] as Timestamp : null,
      rejectionReason: data['rejectionReason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name.trim(),
      if (provider.isNotEmpty) 'provider': provider.trim(),
      if (issueDate.isNotEmpty) 'issueDate': issueDate,
      if (expirationDate.isNotEmpty) 'expirationDate': expirationDate,
      if (description.isNotEmpty) 'description': description.trim(),
      if (certificationId.isNotEmpty) 'certificationId': certificationId.trim(),
      if (url.isNotEmpty) 'url': url.trim(),
      'status': status.firestoreValue,
      if (reviewedBy.isNotEmpty) 'reviewedBy': reviewedBy,
      if (reviewedByRole.isNotEmpty) 'reviewedByRole': reviewedByRole,
      if (reviewedAt != null) 'reviewedAt': reviewedAt,
      if (rejectionReason.isNotEmpty) 'rejectionReason': rejectionReason.trim(),
    };
  }

  String get displayLine {
    final parts = <String>[name.trim()];
    if (provider.trim().isNotEmpty) parts.add(provider.trim());
    final issued = _formatDate(issueDate);
    if (issued.isNotEmpty) parts.add('Issued $issued');
    return parts.join(' • ');
  }

  String get subtitleLine {
    final parts = <String>[];
    if (provider.trim().isNotEmpty) parts.add(provider.trim());
    final issued = _formatDate(issueDate);
    final expires = _formatDate(expirationDate);
    if (issued.isNotEmpty) parts.add('Issued $issued');
    if (expires.isNotEmpty) parts.add('Expires $expires');
    return parts.join(' · ');
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('MMM yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  static String formatForPicker(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('MM/dd/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  static String? isoFromPicker(DateTime? d) {
    if (d == null) return null;
    return DateFormat('yyyy-MM-dd').format(d);
  }

  static List<ProviderCertificationEntry> listFromFirestore(dynamic raw) {
    if (raw is! List) return [];
    final out = <ProviderCertificationEntry>[];
    for (final item in raw) {
      if (item is Map) {
        final entry = ProviderCertificationEntry.fromMap(Map<String, dynamic>.from(item));
        if (!entry.isEmpty) out.add(entry);
      } else {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) out.add(ProviderCertificationEntry(name: text));
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> listToFirestore(List<ProviderCertificationEntry> list) {
    return list.map((e) => e.toMap()).toList();
  }
}
