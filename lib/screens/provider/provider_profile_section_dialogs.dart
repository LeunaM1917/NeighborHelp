import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';
/// Max characters for the other-experiences textarea (reference UI).
abstract final class ProviderOtherExperiencesLimits {
  static const maxChars = 1000;
}

/// Volunteering, awards, and other experience lines — reference modal layout.
class ProviderOtherExperiencesDialog extends StatefulWidget {
  const ProviderOtherExperiencesDialog({
    super.key,
    required this.providerId,
    required this.initialLines,
    this.inDialog = true,
  });

  final String providerId;
  final List<String> initialLines;
  final bool inDialog;

  static Future<bool?> open(
    BuildContext context, {
    required String providerId,
    required List<String> initialLines,
  }) {
    final inDialog = !MobileLayout.useMobileChrome(context);
    final body = ProviderOtherExperiencesDialog(
      providerId: providerId,
      initialLines: initialLines,
      inDialog: inDialog,
    );

    if (inDialog) {
      return showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => providerThemed(
          Dialog(
            backgroundColor: FigmaColors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
              child: body,
            ),
          ),
        ),
      );
    }

    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => providerThemed(
          Scaffold(
            backgroundColor: FigmaColors.white,
            body: SafeArea(child: body),
          ),
        ),
      ),
    );
  }

  @override
  State<ProviderOtherExperiencesDialog> createState() => _ProviderOtherExperiencesDialogState();
}

class _ProviderOtherExperiencesDialogState extends State<ProviderOtherExperiencesDialog> {
  late final TextEditingController _text;
  bool _saving = false;

  static const _hint =
      'e.g. Volunteer — Barangay clean-up drive (2024)\n'
      'e.g. Certificate of Recognition — Youth Summit (2023)';

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialLines.join('\n'));
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<String> _lines() {
    return _text.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirestoreService().updateServiceProvider(
        providerId: widget.providerId,
        data: {'otherExperiences': _lines()},
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _textareaDecoration() {
    return InputDecoration(
      hintText: _hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray400, height: 1.45),
      alignLabelWithHint: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FigmaColors.gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FigmaColors.navy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(14),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, widget.inDialog ? 22 : 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Other experiences',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 6),
          Text(
            'Volunteering, awards, or community work — one entry per line.',
            style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _body(RolePalette rc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            minLines: 7,
            maxLines: 10,
            maxLength: ProviderOtherExperiencesLimits.maxChars,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$currentLength / $maxLength',
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                ),
              ),
            ),
            decoration: _textareaDecoration(),
          ),
          const SizedBox(height: 10),
          Text(
            'You can list volunteer work, awards, seminars, and community involvement.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _footer(RolePalette rc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: FigmaColors.gray200),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: rc.primary,
                  side: BorderSide(color: rc.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: rc.primary,
                  foregroundColor: rc.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
                      )
                    : Text('Save', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    if (!widget.inDialog) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(child: _body(rc)),
          ),
          _footer(rc),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Flexible(
          child: SingleChildScrollView(child: _body(rc)),
        ),
        _footer(rc),
      ],
    );
  }
}

/// Social / professional profile links — reference modal layout.
class ProviderLinkedAccountsDialog extends StatefulWidget {
  const ProviderLinkedAccountsDialog({
    super.key,
    required this.providerId,
    required this.initial,
    this.inDialog = true,
  });

  final String providerId;
  final Map<String, String> initial;
  final bool inDialog;

  static Future<bool?> open(
    BuildContext context, {
    required String providerId,
    required Map<String, String> initial,
  }) {
    final inDialog = !MobileLayout.useMobileChrome(context);
    final body = ProviderLinkedAccountsDialog(
      providerId: providerId,
      initial: initial,
      inDialog: inDialog,
    );

    if (inDialog) {
      return showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => providerThemed(
          Dialog(
            backgroundColor: FigmaColors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
              child: body,
            ),
          ),
        ),
      );
    }

    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => providerThemed(
          Scaffold(
            backgroundColor: FigmaColors.white,
            body: SafeArea(child: body),
          ),
        ),
      ),
    );
  }

  @override
  State<ProviderLinkedAccountsDialog> createState() => _ProviderLinkedAccountsDialogState();
}

class _ProviderLinkedAccountsDialogState extends State<ProviderLinkedAccountsDialog> {
  late final TextEditingController _facebook;
  late final TextEditingController _instagram;
  late final TextEditingController _linkedin;
  late final TextEditingController _other;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _facebook = TextEditingController(text: widget.initial['facebook'] ?? '');
    _instagram = TextEditingController(text: widget.initial['instagram'] ?? '');
    _linkedin = TextEditingController(text: widget.initial['linkedin'] ?? '');
    _other = TextEditingController(text: widget.initial['other'] ?? '');
  }

  @override
  void dispose() {
    _facebook.dispose();
    _instagram.dispose();
    _linkedin.dispose();
    _other.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final linked = <String, String>{};
    void add(String key, String value) {
      final v = value.trim();
      if (v.isNotEmpty) linked[key] = v;
    }

    add('facebook', _facebook.text);
    add('instagram', _instagram.text);
    add('linkedin', _linkedin.text);
    add('other', _other.text);

    try {
      await FirestoreService().updateServiceProvider(
        providerId: widget.providerId,
        data: {'linkedAccounts': linked},
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save links. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _linkDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray400),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FigmaColors.gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FigmaColors.navy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _labeledLinkField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: _linkDecoration(hint),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.35)),
        ],
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, widget.inDialog ? 22 : 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linked accounts',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 6),
          Text(
            'Social profiles customers can review.',
            style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Add any public profile links you\'d like customers to see.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labeledLinkField(
            label: 'Facebook',
            controller: _facebook,
            hint: 'https://facebook.com/yourprofile',
          ),
          const SizedBox(height: 16),
          _labeledLinkField(
            label: 'Instagram',
            controller: _instagram,
            hint: 'https://instagram.com/yourprofile',
          ),
          const SizedBox(height: 16),
          _labeledLinkField(
            label: 'LinkedIn',
            controller: _linkedin,
            hint: 'https://linkedin.com/in/yourprofile',
          ),
          const SizedBox(height: 16),
          _labeledLinkField(
            label: 'Other link',
            controller: _other,
            hint: 'https://yourwebsite.com',
            helper: 'Add any other relevant profile or website link.',
          ),
        ],
      ),
    );
  }

  Widget _footer(RolePalette rc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: FigmaColors.gray200),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: rc.primary,
                  side: BorderSide(color: rc.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: rc.primary,
                  foregroundColor: rc.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
                      )
                    : Text('Save links', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          child: Text(
            'Links are public and visible to customers.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.35),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    if (!widget.inDialog) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(child: SingleChildScrollView(child: _body())),
          _footer(rc),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Flexible(child: SingleChildScrollView(child: _body())),
        _footer(rc),
      ],
    );
  }
}
