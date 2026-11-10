import 'package:flutter/material.dart';

class BookingReferenceNotice extends StatelessWidget {
  const BookingReferenceNotice({
    super.key,
    required this.loading,
    required this.unavailable,
    required this.onRetry,
  });
  final bool loading, unavailable;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LinearProgressIndicator(
          semanticsLabel: 'Loading optional service and provider details',
        ),
      );
    }
    if (!unavailable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Some service or provider details are unavailable. Your booking records are still shown.',
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry service and provider details'),
          ),
        ],
      ),
    );
  }
}
