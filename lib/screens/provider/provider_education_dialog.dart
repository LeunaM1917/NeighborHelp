import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/provider_education.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';
import '../../widgets/app_scroll_chrome.dart';

/// Add / edit education — modal matching Upwork-style reference.
class ProviderEducationDialog extends StatefulWidget {
  const ProviderEducationDialog({
    super.key,
    required this.providerId,
    this.initial,
    this.editIndex,
    this.inDialog = true,
  });

  final String providerId;
  final ProviderEducationEntry? initial;
  final int? editIndex;
  final bool inDialog;

  bool get isEditing => initial != null && !initial!.isEmpty;

  static Future<bool?> open(
    BuildContext context, {
    required String providerId,
    ProviderEducationEntry? initial,
    int? editIndex,
  }) {
    final body = ProviderEducationDialog(
      providerId: providerId,
      initial: initial,
      editIndex: editIndex,
      inDialog: !MobileLayout.useMobileChrome(context),
    );

    if (MobileLayout.useMobileChrome(context)) {
      return Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => providerThemed(
            Scaffold(
              backgroundColor: FigmaColors.white,
              appBar: AppBar(
                backgroundColor: FigmaColors.white,
                foregroundColor: FigmaColors.gray900,
                elevation: 0,
                title: Text(
                  initial != null && !initial.isEmpty ? 'Edit education' : 'Add education',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              body: body,
            ),
          ),
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => providerThemed(
        Dialog(
          backgroundColor: FigmaColors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: body,
          ),
        ),
      ),
    );
  }

  @override
  State<ProviderEducationDialog> createState() => _ProviderEducationDialogState();
}

class _ProviderEducationDialogState extends State<ProviderEducationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _school;
  late final TextEditingController _areaOfStudy;
  late final TextEditingController _description;
  String? _fromYear;
  String? _toYear;
  String? _degree;
  bool _saving = false;

  static const _degreeOptions = [
    '',
    'High school diploma',
    'Associate degree',
    "Bachelor's degree",
    "Master's degree",
    'Doctorate',
    'Certificate',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _school = TextEditingController(text: e?.school ?? '');
    _areaOfStudy = TextEditingController(text: e?.areaOfStudy ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _fromYear = e?.fromYear.isNotEmpty == true ? e!.fromYear : null;
    _toYear = e?.toYear.isNotEmpty == true ? e!.toYear : null;
    _degree = e?.degree.isNotEmpty == true ? e!.degree : null;
    _school.addListener(_onSchoolChanged);
  }

  void _onSchoolChanged() => setState(() {});

  @override
  void dispose() {
    _school.removeListener(_onSchoolChanged);
    _school.dispose();
    _areaOfStudy.dispose();
    _description.dispose();
    super.dispose();
  }

  List<String> get _yearOptions {
    final now = DateTime.now().year;
    return [for (var y = now + 8; y >= 1960; y--) '$y'];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final entry = ProviderEducationEntry(
        school: _school.text.trim(),
        fromYear: _fromYear ?? '',
        toYear: _toYear ?? '',
        degree: _degree ?? '',
        areaOfStudy: _areaOfStudy.text.trim(),
        description: _description.text.trim(),
      );

      final profile = await FirestoreService().getProviderProfile(widget.providerId);
      final updated = List<ProviderEducationEntry>.from(profile?.effectiveEducationHistory ?? []);

      if (widget.editIndex != null && widget.editIndex! >= 0 && widget.editIndex! < updated.length) {
        updated[widget.editIndex!] = entry;
      } else {
        updated.add(entry);
      }

      await FirestoreService().updateServiceProvider(
        providerId: profile?.providerId ?? widget.providerId,
        data: {
          'educationHistory': ProviderEducationEntry.listToFirestore(updated),
          'education': updated.first.school,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save education. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final title = widget.isEditing ? 'Edit education' : 'Add education';

    final form = Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _labeledField(
                    label: 'School',
                    field: TextFormField(
                      controller: _school,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a school name' : null,
                      decoration: _inputDecoration(hint: 'Ex: Northwestern University'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Dates Attended (Optional)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _yearDropdown(
                          label: 'From',
                          value: _fromYear,
                          onChanged: (v) => setState(() => _fromYear = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _yearDropdown(
                          label: 'To (or expected graduation year)',
                          value: _toYear,
                          includePresent: true,
                          onChanged: (v) => setState(() => _toYear = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: 'Degree (Optional)',
                    field: _degreeDropdown(),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: 'Area of Study (Optional)',
                    field: TextFormField(
                      controller: _areaOfStudy,
                      decoration: _inputDecoration(hint: 'Ex: Computer Science'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: 'Description (Optional)',
                    field: TextFormField(
                      controller: _description,
                      maxLines: 5,
                      decoration: _inputDecoration(hint: ''),
                    ),
                  ),
                ],
              ),
            );

    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray700),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving || _school.text.trim().isEmpty ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _school.text.trim().isEmpty ? FigmaColors.gray300 : rc.primary,
              foregroundColor: FigmaColors.white,
              disabledBackgroundColor: FigmaColors.gray300,
              disabledForegroundColor: FigmaColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
    );

    if (!widget.inDialog) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppScrollChrome(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: form,
              ),
            ),
          ),
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
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
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
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: form,
          ),
        ),
        footer,
      ],
    );
  }

  Widget _labeledField({required String label, required Widget field}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _yearDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    bool includePresent = false,
  }) {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(value: null, child: Text(label, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500))),
      if (includePresent)
        const DropdownMenuItem(value: 'Present', child: Text('Present')),
      ..._yearOptions.map((y) => DropdownMenuItem(value: y, child: Text(y))),
    ];

    return DropdownButtonFormField<String?>(
      value: value != null && value.isNotEmpty ? value : null,
      isExpanded: true,
      decoration: _inputDecoration(),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _degreeDropdown() {
    return DropdownButtonFormField<String?>(
      value: _degree != null && _degree!.isNotEmpty ? _degree : null,
      isExpanded: true,
      decoration: _inputDecoration(hint: 'Degree (Optional)'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Degree (Optional)')),
        ..._degreeOptions.skip(1).map((d) => DropdownMenuItem(value: d, child: Text(d))),
      ],
      onChanged: (v) => setState(() => _degree = v),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: FigmaColors.gray400, fontSize: 14),
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
}
