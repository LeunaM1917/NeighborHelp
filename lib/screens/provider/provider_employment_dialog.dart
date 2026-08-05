import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/provider_employment.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';
import '../../widgets/app_scroll_chrome.dart';

/// Add / edit employment — modal matching reference design.
class ProviderEmploymentDialog extends StatefulWidget {
  const ProviderEmploymentDialog({
    super.key,
    required this.providerId,
    this.initial,
    this.editIndex,
    this.inDialog = true,
  });

  final String providerId;
  final ProviderEmploymentEntry? initial;
  final int? editIndex;
  final bool inDialog;

  bool get isEditing => initial != null && !initial!.isEmpty;

  static Future<bool?> open(
    BuildContext context, {
    required String providerId,
    ProviderEmploymentEntry? initial,
    int? editIndex,
  }) {
    final body = ProviderEmploymentDialog(
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
                  initial != null && !initial.isEmpty ? 'Edit employment' : 'Add employment',
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
  State<ProviderEmploymentDialog> createState() => _ProviderEmploymentDialogState();
}

class _ProviderEmploymentDialogState extends State<ProviderEmploymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _company;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _title;
  late final TextEditingController _description;
  String? _startMonth;
  String? _startYear;
  String? _endMonth;
  String? _endYear;
  bool _currentlyWorking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _company = TextEditingController(text: e?.company ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _country = TextEditingController(text: e?.country ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _startMonth = e?.startMonth.isNotEmpty == true ? e!.startMonth : null;
    _startYear = e?.startYear.isNotEmpty == true ? e!.startYear : null;
    _endMonth = e?.endMonth.isNotEmpty == true ? e!.endMonth : null;
    _endYear = e?.endYear.isNotEmpty == true ? e!.endYear : null;
    _currentlyWorking = e?.currentlyWorking ?? false;
    _company.addListener(_onRequiredChanged);
    _title.addListener(_onRequiredChanged);
  }

  void _onRequiredChanged() => setState(() {});

  bool get _canSave => _company.text.trim().isNotEmpty && _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _company.removeListener(_onRequiredChanged);
    _title.removeListener(_onRequiredChanged);
    _company.dispose();
    _city.dispose();
    _country.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  List<String> get _yearOptions {
    final now = DateTime.now().year;
    return [for (var y = now; y >= 1960; y--) '$y'];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final entry = ProviderEmploymentEntry(
        company: _company.text.trim(),
        city: _city.text.trim(),
        country: _country.text.trim(),
        title: _title.text.trim(),
        startMonth: _startMonth ?? '',
        startYear: _startYear ?? '',
        endMonth: _currentlyWorking ? '' : (_endMonth ?? ''),
        endYear: _currentlyWorking ? '' : (_endYear ?? ''),
        currentlyWorking: _currentlyWorking,
        description: _description.text.trim(),
      );

      final profile = await FirestoreService().getProviderProfile(widget.providerId);
      final updated = List<ProviderEmploymentEntry>.from(profile?.employmentHistory ?? []);

      if (widget.editIndex != null && widget.editIndex! >= 0 && widget.editIndex! < updated.length) {
        updated[widget.editIndex!] = entry;
      } else {
        updated.add(entry);
      }

      await FirestoreService().updateServiceProvider(
        providerId: profile?.providerId ?? widget.providerId,
        data: {
          'employmentHistory': ProviderEmploymentEntry.listToFirestore(updated),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save employment. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final title = widget.isEditing ? 'Edit employment' : 'Add employment';

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labeledField(
            label: 'Company',
            field: TextFormField(
              controller: _company,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a company name' : null,
              decoration: _inputDecoration(hint: 'Ex: Upwork'),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _labeledField(
                  label: 'City',
                  field: TextFormField(
                    controller: _city,
                    decoration: _inputDecoration(hint: 'Enter city'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  label: 'Country',
                  field: TextFormField(
                    controller: _country,
                    decoration: _inputDecoration(hint: 'Ex: United States'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _labeledField(
            label: 'Title',
            field: TextFormField(
              controller: _title,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your job title' : null,
              decoration: _inputDecoration(hint: 'Ex: Senior Software Engineer'),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Start Date',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _monthDropdown(
                  label: 'From, month',
                  value: _startMonth,
                  onChanged: (v) => setState(() => _startMonth = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _yearDropdown(
                  label: 'From, year',
                  value: _startYear,
                  onChanged: (v) => setState(() => _startYear = v),
                ),
              ),
            ],
          ),
          if (!_currentlyWorking) ...[
            const SizedBox(height: 18),
            Text(
              'End Date',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _monthDropdown(
                    label: 'To, month',
                    value: _endMonth,
                    onChanged: (v) => setState(() => _endMonth = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _yearDropdown(
                    label: 'To, year',
                    value: _endYear,
                    onChanged: (v) => setState(() => _endYear = v),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _currentlyWorking,
            onChanged: (v) => setState(() => _currentlyWorking = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'I currently work here',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: FigmaColors.gray800),
            ),
            activeColor: rc.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 8),
          _labeledField(
            label: 'Description (Optional)',
            field: TextFormField(
              controller: _description,
              maxLines: 5,
              decoration: _inputDecoration(hint: 'Enter description'),
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
            onPressed: _saving || !_canSave ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: !_canSave ? FigmaColors.gray300 : rc.primary,
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

  Widget _monthDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(value: null, child: Text(label, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500))),
      ...ProviderEmploymentEntry.monthNames.map(
        (m) => DropdownMenuItem(value: m, child: Text(m)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: value != null && value.isNotEmpty ? value : null,
      isExpanded: true,
      decoration: _inputDecoration(),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _yearDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(value: null, child: Text(label, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500))),
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
