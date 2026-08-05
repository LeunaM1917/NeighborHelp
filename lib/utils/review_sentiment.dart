import '../models/review.dart';

/// Lightweight keyword fallback when the LSTM sentiment has not run yet.
String? inferSentimentFromComment(String? comment) {
  final text = comment?.trim().toLowerCase() ?? '';
  if (text.isEmpty) return null;

  const positive = [
    'great',
    'excellent',
    'amazing',
    'love',
    'wonderful',
    'fantastic',
    'perfect',
    'thank',
    'care',
    'best',
    'happy',
    'good',
    'awesome',
    'helpful',
    'professional',
    'recommend',
    'friendly',
  ];
  const negative = [
    'bad',
    'terrible',
    'awful',
    'worst',
    'hate',
    'poor',
    'rude',
    'never',
    'disappoint',
    'horrible',
    'late',
    'unprofessional',
    'slow',
    'mess',
    'broken',
  ];

  var pos = 0;
  var neg = 0;
  for (final word in positive) {
    if (text.contains(word)) pos++;
  }
  for (final word in negative) {
    if (text.contains(word)) neg++;
  }
  if (pos > neg) return 'positive';
  if (neg > pos) return 'negative';
  return 'neutral';
}

/// Prefer live review average when reviews are loaded; otherwise denormalized profile average.
double effectiveProviderRating({required double profileAverage, required List<Review> reviews}) {
  if (reviews.isNotEmpty) {
    return reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviews.length;
  }
  if (profileAverage > 0) return profileAverage;
  return 0;
}

/// Mean rating from provider feedback about a customer.
double effectiveCustomerRating(List<Review> reviews) {
  if (reviews.isEmpty) return 0;
  return reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviews.length;
}

class SentimentCounts {
  const SentimentCounts({
    this.positive = 0,
    this.neutral = 0,
    this.negative = 0,
  });

  final int positive;
  final int neutral;
  final int negative;

  int get total => positive + neutral + negative;
  bool get isEmpty => total == 0;
}

SentimentCounts countReviewSentiments(List<Review> reviews) {
  var positive = 0;
  var neutral = 0;
  var negative = 0;

  for (final review in reviews) {
    final label = review.displaySentimentLabel;
    if (label == null) continue;
    switch (label) {
      case 'positive':
        positive++;
      case 'negative':
        negative++;
      default:
        neutral++;
    }
  }

  return SentimentCounts(positive: positive, neutral: neutral, negative: negative);
}

extension ReviewSentimentDisplay on Review {
  /// LSTM label when present; otherwise a keyword fallback from the comment.
  String? get displaySentimentLabel =>
      hasSentiment ? normalizedSentimentLabel : inferSentimentFromComment(comment);

  bool get hasDisplaySentiment => (displaySentimentLabel ?? '').trim().isNotEmpty;

  bool get isSentimentPending => !hasSentiment && (comment ?? '').trim().isNotEmpty;
}
