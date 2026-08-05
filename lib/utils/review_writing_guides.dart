/// Star-specific writing prompts for milestone feedback forms.
class ReviewWritingGuide {
  const ReviewWritingGuide({
    required this.headline,
    required this.prompts,
    required this.hintText,
  });

  final String headline;
  final List<String> prompts;
  final String hintText;
}

/// Returns writing guidance for [rating] (1–5).
///
/// [reviewerRole] is `customer` (rating a provider) or `provider` (rating a customer).
ReviewWritingGuide reviewWritingGuideFor({
  required int rating,
  required String reviewerRole,
}) {
  final stars = rating.clamp(1, 5);
  final isCustomer = reviewerRole.toLowerCase() != 'provider';

  if (isCustomer) {
    return switch (stars) {
      5 => const ReviewWritingGuide(
          headline: 'What made this a 5-star experience?',
          prompts: [
            'What impressed you most?',
            'Was the provider professional?',
            'Would you recommend this provider to others?',
          ],
          hintText: 'Share what made the service excellent…',
        ),
      4 => const ReviewWritingGuide(
          headline: 'Almost perfect — tell us more',
          prompts: [
            'What did the provider do well?',
            'What could still be improved?',
          ],
          hintText: 'Share what went well and what could improve…',
        ),
      3 => const ReviewWritingGuide(
          headline: 'Help us understand this mixed experience',
          prompts: [
            'What went well?',
            'What could have made the service better?',
          ],
          hintText: 'Describe what went okay and what fell short…',
        ),
      2 => const ReviewWritingGuide(
          headline: 'Sorry it fell short — what happened?',
          prompts: [
            'What problems did you experience?',
            'Was the service delayed or incomplete?',
          ],
          hintText: 'Describe the problems you experienced…',
        ),
      _ => const ReviewWritingGuide(
          headline: 'Please describe the issue',
          prompts: [
            'Describe the issue.',
            'Did the provider behave unprofessionally?',
            'Was the service unsafe or unacceptable?',
          ],
          hintText: 'Describe the issue clearly so we can improve safety and quality…',
        ),
    };
  }

  return switch (stars) {
    5 => const ReviewWritingGuide(
        headline: 'What made this customer great to work with?',
        prompts: [
          'What went especially well?',
          'Was the customer clear and respectful?',
          'Would you work with this customer again?',
        ],
        hintText: 'Share what made this booking excellent…',
      ),
    4 => const ReviewWritingGuide(
        headline: 'Almost perfect — tell us more',
        prompts: [
          'What did the customer do well?',
          'What could still be improved?',
        ],
        hintText: 'Share what went well and what could improve…',
      ),
    3 => const ReviewWritingGuide(
        headline: 'Help us understand this mixed experience',
        prompts: [
          'What went well?',
          'What could have made the booking better?',
        ],
        hintText: 'Describe what went okay and what fell short…',
      ),
    2 => const ReviewWritingGuide(
        headline: 'What problems did you experience?',
        prompts: [
          'What made this booking difficult?',
          'Were there communication or scope issues?',
        ],
        hintText: 'Describe the problems you experienced…',
      ),
    _ => const ReviewWritingGuide(
        headline: 'Please describe the issue',
        prompts: [
          'Describe the issue.',
          'Was the customer unprofessional or unsafe?',
          'Was the booking unacceptable to continue?',
        ],
        hintText: 'Describe the issue clearly…',
      ),
  };
}
