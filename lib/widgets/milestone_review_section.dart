import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/review.dart';
import '../services/firestore_service.dart';
import '../theme/role_theme.dart';
import '../ui/app_ui_kit.dart';
import '../utils/review_writing_guides.dart';
import 'review_tile.dart';

/// Star rating + comment for one party on a completed milestone.
class MilestoneReviewSection extends StatefulWidget {
  const MilestoneReviewSection({
    super.key,
    required this.appUser,
    required this.booking,
    required this.reviewerRole,
    this.title,
    this.subtitle,
  });

  final AppUser appUser;
  final Booking booking;
  /// `customer` or `provider`
  final String reviewerRole;
  final String? title;
  final String? subtitle;

  @override
  State<MilestoneReviewSection> createState() => _MilestoneReviewSectionState();
}

class _MilestoneReviewSectionState extends State<MilestoneReviewSection> {
  final _firestore = FirestoreService();
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.booking.isMilestoneComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reviews unlock after the milestone is marked complete.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _firestore.createMilestoneReview(
        booking: widget.booking,
        reviewerId: widget.appUser.userId,
        reviewerRole: widget.reviewerRole,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not submit feedback. Try again.')),
        );
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit feedback: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildForm(String title, String subtitle) {
    final guide = reviewWritingGuideFor(
      rating: _rating,
      reviewerRole: widget.reviewerRole,
    );
    final rc = context.roleColors;

    return AppSection(
      title: title,
      subtitle: subtitle,
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: _submitting ? null : () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFEAB308),
                    size: 32,
                  ),
                );
              }),
            ),
            Text(
              '$_rating of 5 stars',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FigmaColors.gray700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: rc.tint.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: rc.primary.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide.headline,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: FigmaColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final prompt in guide.prompts) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•  ',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.35,
                              color: rc.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              prompt,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.35,
                                color: FigmaColors.gray700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              enabled: !_submitting,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: guide.hintText,
                hintStyle: GoogleFonts.inter(color: FigmaColors.gray500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Submit feedback',
              icon: Icons.star_outline,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.booking.isMilestoneComplete) return const SizedBox.shrink();

    final defaultTitle = widget.reviewerRole == 'customer'
        ? 'Rate your provider'
        : 'Rate your customer';
    final defaultSubtitle = widget.reviewerRole == 'customer'
        ? 'Feedback for ${widget.booking.milestoneLabel}'
        : 'Share how this milestone went with ${widget.booking.milestoneLabel}';
    final title = widget.title ?? defaultTitle;
    final subtitle = widget.subtitle ?? defaultSubtitle;

    return StreamBuilder<Review?>(
      stream: _firestore.milestoneReviewStream(
        bookingId: widget.booking.bookingId,
        reviewerId: widget.appUser.userId,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return AppSection(
            title: title,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final existing = snap.data;
        if (existing != null) {
          return AppSection(
            title: title,
            child: AppSurfaceCard(
              child: ReviewTile(
                review: existing,
                fromLabel: widget.reviewerRole == 'customer' ? 'Your review' : 'Your feedback',
                jobLabel: widget.booking.milestoneLabel,
              ),
            ),
          );
        }

        return _buildForm(title, subtitle);
      },
    );
  }
}
