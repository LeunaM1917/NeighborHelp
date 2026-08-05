import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../figma_ui/figma_colors.dart';
import '../theme/role_theme.dart';
import '../models/review.dart';
import '../utils/review_sentiment.dart';

class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.review,
    this.subtitle,
    this.fromLabel,
    this.jobLabel,
    this.youLeftFeedback,
    this.feedbackLeftMessage = 'You left feedback for this customer',
    this.feedbackMissingMessage = 'You have not left feedback yet',
  });

  final Review review;
  final String? subtitle;
  /// e.g. "From Jane Smith" or "For Kent Gabito".
  final String? fromLabel;
  /// Service / booking context, e.g. "Dog Walking · Milestone 2".
  final String? jobLabel;
  /// When set, shows reciprocal milestone feedback on the same booking.
  final bool? youLeftFeedback;
  final String feedbackLeftMessage;
  final String feedbackMissingMessage;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final date = DateFormat('MMM d, yyyy').format(review.createdAt.toDate());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: rc.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              review.rating.toString(),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: rc.primary),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ...List.generate(5, (i) {
                    return Icon(
                      i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: i < review.rating ? const Color(0xFFEAB308) : FigmaColors.gray300,
                    );
                  }),
                  const Spacer(),
                  Text(date, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray400)),
                ],
              ),
              if (jobLabel != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: FigmaColors.gray50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: FigmaColors.gray200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.work_outline, size: 14, color: rc.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          jobLabel!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FigmaColors.gray800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (fromLabel != null) ...[
                const SizedBox(height: 6),
                Text(fromLabel!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray900)),
              ],
              if (review.hasDisplaySentiment) ...[
                const SizedBox(height: 8),
                SentimentChip(
                  label: review.displaySentimentLabel!,
                  confidence: review.hasSentiment ? review.sentimentConfidence : null,
                  isInferred: !review.hasSentiment,
                ),
              ] else if (review.isSentimentPending) ...[
                const SizedBox(height: 8),
                const SentimentChip(label: 'neutral', pending: true),
              ],
              if (youLeftFeedback != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      youLeftFeedback! ? Icons.reply_rounded : Icons.reply_outlined,
                      size: 16,
                      color: youLeftFeedback! ? FigmaColors.green : FigmaColors.gray400,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        youLeftFeedback! ? feedbackLeftMessage : feedbackMissingMessage,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: youLeftFeedback! ? FigmaColors.green : FigmaColors.gray500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
              ],
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  review.comment!,
                  style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SentimentChip extends StatelessWidget {
  const SentimentChip({
    super.key,
    required this.label,
    this.confidence,
    this.isInferred = false,
    this.pending = false,
  });

  final String label;
  final double? confidence;
  final bool isInferred;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: FigmaColors.gray100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: FigmaColors.gray300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.gray500),
            ),
            const SizedBox(width: 6),
            Text(
              'Sentiment: Analyzing…',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: FigmaColors.gray600),
            ),
          ],
        ),
      );
    }

    final isPositive = label == 'positive';
    final isNegative = label == 'negative';

    final bg = isPositive
        ? FigmaColors.tintGreen
        : isNegative
            ? FigmaColors.red50
            : FigmaColors.gray100;
    final fg = isPositive
        ? FigmaColors.green
        : isNegative
            ? FigmaColors.red600
            : FigmaColors.gray700;
    final icon = isPositive
        ? Icons.sentiment_very_satisfied_rounded
        : isNegative
            ? Icons.sentiment_very_dissatisfied_rounded
            : Icons.sentiment_neutral_rounded;

    final confidenceText = confidence == null ? '' : ' ${(confidence! * 100).toStringAsFixed(0)}%';
    final title = '${label[0].toUpperCase()}${label.substring(1)}$confidenceText';
    final prefix = isInferred ? 'Likely' : 'Sentiment';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            '$prefix: $title',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
