import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';

/// Written explanation before cancelling a booking.
class BookingCancellationReasonDialog extends StatefulWidget {
  const BookingCancellationReasonDialog({
    super.key,
    required this.useBottomSheet,
    required this.audienceLabel,
    this.hintExample,
  });

  final bool useBottomSheet;
  /// Who will read the explanation, e.g. `provider` or `customer`.
  final String audienceLabel;
  final String? hintExample;

  @override
  State<BookingCancellationReasonDialog> createState() => _BookingCancellationReasonDialogState();
}

class _BookingCancellationReasonDialogState extends State<BookingCancellationReasonDialog> {
  final _controller = TextEditingController();
  static const _minLength = 10;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.length < _minLength) return;
    Navigator.pop(context, text);
  }

  Widget _body(BuildContext context) {
    final valid = _controller.text.trim().length >= _minLength;
    final audience = widget.audienceLabel;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, widget.useBottomSheet ? 8 : 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.useBottomSheet)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: FigmaColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Text(
            'Why are you cancelling?',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 8),
          Text(
            'Share a brief explanation for the $audience. At least $_minLength characters.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.hintExample ??
                  'e.g. My plans changed and I need to cancel this booking.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: FigmaColors.gray200),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: const Text('Go back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: valid ? _submit : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: FigmaColors.red600,
                    disabledBackgroundColor: FigmaColors.gray200,
                  ),
                  child: const Text('Confirm cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useBottomSheet) {
      return Material(
        color: FigmaColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SafeArea(child: _body(context)),
      );
    }

    return AlertDialog(
      backgroundColor: FigmaColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: SizedBox(
        width: 420,
        child: _body(context),
      ),
    );
  }
}
