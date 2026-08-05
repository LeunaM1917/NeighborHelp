import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/philippine_government_id_type.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';

/// Choose which Philippine government ID to submit for Didit verification.
class ProviderGovernmentIdPickerDialog extends StatefulWidget {
  const ProviderGovernmentIdPickerDialog({
    super.key,
    this.initialCode,
    this.inDialog = true,
  });

  final String? initialCode;
  final bool inDialog;

  static Future<PhilippineGovernmentIdType?> open(BuildContext context, {String? initialCode}) {
    final body = ProviderGovernmentIdPickerDialog(initialCode: initialCode, inDialog: !MobileLayout.useMobileChrome(context));

    if (MobileLayout.useMobileChrome(context)) {
      return Navigator.of(context).push<PhilippineGovernmentIdType>(
        MaterialPageRoute(
          builder: (_) => providerThemed(
            Scaffold(
              backgroundColor: FigmaColors.white,
              appBar: AppBar(
                backgroundColor: FigmaColors.white,
                foregroundColor: FigmaColors.gray900,
                elevation: 0,
                title: Text(
                  'Government ID',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              body: body,
            ),
          ),
        ),
      );
    }

    return showDialog<PhilippineGovernmentIdType>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => providerThemed(
        Dialog(
          backgroundColor: FigmaColors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
            child: body,
          ),
        ),
      ),
    );
  }

  @override
  State<ProviderGovernmentIdPickerDialog> createState() => _ProviderGovernmentIdPickerDialogState();
}

class _ProviderGovernmentIdPickerDialogState extends State<ProviderGovernmentIdPickerDialog> {
  PhilippineGovernmentIdType? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _selected = PhilippineGovernmentIdType.fromCode(widget.initialCode!);
    }
  }

  void _continue() {
    if (_selected == null) return;
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    final list = Flexible(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        itemCount: PhilippineGovernmentIdType.options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final option = PhilippineGovernmentIdType.options[i];
          final selected = _selected?.label == option.label;
          return Material(
            color: selected ? rc.tint : FigmaColors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => setState(() => _selected = option),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? rc.primary : FigmaColors.gray200, width: selected ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 22,
                      color: selected ? rc.primary : FigmaColors.gray400,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: FigmaColors.gray900,
                            ),
                          ),
                          if (option.hint != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              option.hint!,
                              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.3),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.gray800,
              side: const BorderSide(color: FigmaColors.gray300),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _selected == null ? null : _continue,
            style: FilledButton.styleFrom(
              backgroundColor: _selected == null ? FigmaColors.gray300 : rc.primary,
              foregroundColor: FigmaColors.white,
              disabledBackgroundColor: FigmaColors.gray300,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Continue to Didit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (!widget.inDialog) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Pick the document you will use on Didit. Only these four types are supported.',
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.45),
            ),
          ),
          list,
          footer,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose your government ID',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Same document types as Didit (Philippines)',
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 22),
                color: FigmaColors.gray600,
              ),
            ],
          ),
        ),
        list,
        footer,
      ],
    );
  }
}
