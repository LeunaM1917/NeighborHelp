import 'package:cloud_firestore/cloud_firestore.dart';

/// Feedback for a completed milestone — customer→provider or provider→customer.
class Review {
  Review({
    required this.reviewId,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.reviewerId,
    this.revieweeId,
    this.reviewerRole,
    this.contractId,
    this.milestoneNumber,
    this.sentimentLabel,
    this.sentimentConfidence,
    this.sentimentProbabilities,
  });

  final String reviewId;
  final String bookingId;
  final String customerId;
  final String providerId;
  final String serviceId;
  final int rating;
  final String? comment;
  final Timestamp createdAt;
  final String? reviewerId;
  final String? revieweeId;
  /// `customer` or `provider`
  final String? reviewerRole;
  final String? contractId;
  final int? milestoneNumber;
  final String? sentimentLabel;
  final double? sentimentConfidence;
  final Map<String, double>? sentimentProbabilities;

  bool get isCustomerReview => (reviewerRole ?? 'customer').toLowerCase() == 'customer';
  bool get isProviderReview => (reviewerRole ?? '').toLowerCase() == 'provider';
  bool get hasSentiment => (sentimentLabel ?? '').trim().isNotEmpty;

  String get normalizedSentimentLabel => (sentimentLabel ?? '').trim().toLowerCase();

  factory Review.fromFirestore(String id, Map<String, dynamic> data) {
    final customerId = data['customerId'] as String? ?? '';
    final providerId = data['providerId'] as String? ?? '';
    final sentiment = data['sentiment'];
    final sentimentMap = sentiment is Map ? Map<String, dynamic>.from(sentiment) : const <String, dynamic>{};
    final probabilitiesRaw = sentimentMap['probabilities'];
    final probabilitiesMap = probabilitiesRaw is Map
        ? Map<String, dynamic>.from(probabilitiesRaw)
        : const <String, dynamic>{};

    return Review(
      reviewId: id,
      bookingId: data['bookingId'] as String? ?? '',
      customerId: customerId,
      providerId: providerId,
      serviceId: data['serviceId'] as String? ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      reviewerId: data['reviewerId'] as String? ?? customerId,
      revieweeId: data['revieweeId'] as String? ?? providerId,
      reviewerRole: data['reviewerRole'] as String? ?? 'customer',
      contractId: data['contractId'] as String?,
      milestoneNumber: (data['milestoneNumber'] as num?)?.toInt(),
      sentimentLabel: sentimentMap['label'] as String? ?? sentimentMap['sentiment'] as String?,
      sentimentConfidence: (sentimentMap['confidence'] as num?)?.toDouble(),
      sentimentProbabilities: probabilitiesMap.isEmpty
          ? null
          : probabilitiesMap.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'providerId': providerId,
      'serviceId': serviceId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
      if (reviewerId != null) 'reviewerId': reviewerId,
      if (revieweeId != null) 'revieweeId': revieweeId,
      if (reviewerRole != null) 'reviewerRole': reviewerRole,
      if (contractId != null) 'contractId': contractId,
      if (milestoneNumber != null) 'milestoneNumber': milestoneNumber,
      if (hasSentiment)
        'sentiment': {
          'label': sentimentLabel,
          if (sentimentConfidence != null) 'confidence': sentimentConfidence,
          if (sentimentProbabilities != null) 'probabilities': sentimentProbabilities,
        },
    };
  }
}
