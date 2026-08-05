import '../models/review.dart';

/// Human-readable work label for a review, e.g. "Dog Walking · Milestone 2".
String? formatReviewJobLabel({
  required Review review,
  String? serviceTitle,
}) {
  final parts = <String>[];
  final title = serviceTitle?.trim() ?? '';
  if (title.isNotEmpty) {
    parts.add(title);
  } else if (review.serviceId.trim().isNotEmpty) {
    parts.add('Completed service');
  }
  final milestone = review.milestoneNumber;
  if (milestone != null && milestone > 0) {
    parts.add('Milestone $milestone');
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
