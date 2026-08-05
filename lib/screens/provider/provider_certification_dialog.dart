import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../figma_ui/figma_colors.dart';
import '../../models/provider_certification.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';
import '../../widgets/app_scroll_chrome.dart';

/// Add / edit certification — modal matching reference design.
class ProviderCertificationDialog extends StatefulWidget {
  const ProviderCertificationDialog({
    super.key,
    required this.providerId,
    this.initial,
    this.editIndex,
    this.inDialog = true,
  });

  final String providerId;
  final ProviderCertificationEntry? initial;
  final int? editIndex;
  final bool inDialog;

  bool get isEditing => initial != null && !initial!.isEmpty;

  static Future<bool?> open(
    BuildContext context, {
    required String providerId,
    ProviderCertificationEntry? initial,
    int? editIndex,
  }) {
    final body = ProviderCertificationDialog(
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
                  initial != null && !initial.isEmpty ? 'Edit certification' : 'Add certification',
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
  State<ProviderCertificationDialog> createState() => _ProviderCertificationDialogState();
}

class _ProviderCertificationDialogState extends State<ProviderCertificationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _provider;
  late final TextEditingController _description;
  late final TextEditingController _certId;
  late final TextEditingController _url;
  late final TextEditingController _issueDisplay;
  late final TextEditingController _expirationDisplay;
  String? _issueDate;
  String? _expirationDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _name = TextEditingController(text: e?.name ?? '');
    _provider = TextEditingController(text: e?.provider ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _certId = TextEditingController(text: e?.certificationId ?? '');
    _url = TextEditingController(text: e?.url ?? '');
    _issueDate = e?.issueDate.isNotEmpty == true ? e!.issueDate : null;
    _expirationDate = e?.expirationDate.isNotEmpty == true ? e!.expirationDate : null;
    _issueDisplay = TextEditingController(
      text: _issueDate != null ? ProviderCertificationEntry.formatForPicker(_issueDate!) : '',
    );
    _expirationDisplay = TextEditingController(
      text: _expirationDate != null ? ProviderCertificationEntry.formatForPicker(_expirationDate!) : '',
    );
    _name.addListener(_onFieldsChanged);
    _provider.addListener(_onFieldsChanged);
    _description.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() => setState(() {});

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _provider.text.trim().isNotEmpty && (_issueDate?.isNotEmpty ?? false);

  int get _descLeft => ProviderCertificationEntry.maxDescriptionLength - _description.text.length;

  @override
  void dispose() {
    _name.removeListener(_onFieldsChanged);
    _provider.removeListener(_onFieldsChanged);
    _description.removeListener(_onFieldsChanged);
    _name.dispose();
    _provider.dispose();
    _description.dispose();
    _certId.dispose();
    _url.dispose();
    _issueDisplay.dispose();
    _expirationDisplay.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool expiration}) async {
    final initial = expiration ? _expirationDate : _issueDate;
    DateTime? selected;
    if (initial != null && initial.isNotEmpty) {
      try {
        selected = DateTime.parse(initial);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: selected ?? DateTime.now(),
      firstDate: DateTime(1960),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final iso = ProviderCertificationEntry.isoFromPicker(picked)!;
    final display = ProviderCertificationEntry.formatForPicker(iso);
    setState(() {
      if (expiration) {
        _expirationDate = iso;
        _expirationDisplay.text = display;
      } else {
        _issueDate = iso;
        _issueDisplay.text = display;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // New/edited certs always go back to Pending for Verification Agency review.
      final entryId = (widget.initial?.id.isNotEmpty == true)
          ? widget.initial!.id
          : ProviderCertificationEntry.newId();
      final entry = ProviderCertificationEntry(
        id: entryId,
        name: _name.text.trim(),
        provider: _provider.text.trim(),
        issueDate: _issueDate ?? '',
        expirationDate: _expirationDate ?? '',
        description: _description.text.trim(),
        certificationId: _certId.text.trim(),
        url: _url.text.trim(),
        status: CertificationVerificationStatus.pending,
      );

      final profile = await FirestoreService().getProviderProfile(widget.providerId);
      final updated = List<ProviderCertificationEntry>.from(profile?.certificationHistory ?? []);
      if (updated.isEmpty && (profile?.certifications.isNotEmpty ?? false)) {
        for (final line in profile!.certifications) {
          updated.add(
            ProviderCertificationEntry(
              id: ProviderCertificationEntry.newId(),
              name: line,
              status: CertificationVerificationStatus.pending,
            ),
          );
        }
      }

      if (widget.editIndex != null && widget.editIndex! >= 0 && widget.editIndex! < updated.length) {
        updated[widget.editIndex!] = entry;
      } else if (widget.initial != null) {
        final idx = updated.indexWhere(
          (c) =>
              (c.id.isNotEmpty && c.id == widget.initial!.id) ||
              (c.name == widget.initial!.name && c.provider == widget.initial!.provider),
        );
        if (idx >= 0) {
          updated[idx] = entry;
        } else {
          updated.add(entry);
        }
      } else {
        updated.add(entry);
      }

      // Provider may only remove (not add) approved ids — editing clears prior approval.
      final approvedIds = List<String>.from(profile?.approvedCertificationIds ?? [])
        ..removeWhere((id) => id == entryId);

      await FirestoreService().updateServiceProvider(
        providerId: profile?.providerId ?? widget.providerId,
        data: {
          'certificationHistory': ProviderCertificationEntry.listToFirestore(updated),
          'certifications': updated.map((e) => e.displayLine).toList(),
          'approvedCertificationIds': approvedIds,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save certification. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final title = widget.isEditing ? 'Edit certification' : 'Add certification';

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labeledField(
            label: 'Certification name',
            field: TextFormField(
              controller: _name,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a certification name' : null,
              decoration: _inputDecoration(hint: 'Ex: Certified ScrumMaster (CSM)'),
            ),
          ),
          const SizedBox(height: 18),
          _labeledField(
            label: 'Provider',
            field: TextFormField(
              controller: _provider,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the certification provider' : null,
              decoration: _inputDecoration(hint: 'Ex: Scrum Alliance'),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _dateField(label: 'Issue date', value: _issueDate, required: true, onTap: () => _pickDate(expiration: false))),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField(
                  label: 'Expiration date (Optional)',
                  value: _expirationDate,
                  onTap: () => _pickDate(expiration: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _labeledField(
            label: 'Description',
            field: TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: ProviderCertificationEntry.maxDescriptionLength,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  Align(alignment: Alignment.centerRight, child: Text('$_descLeft characters left', style: _counterStyle)),
              decoration: _inputDecoration(),
            ),
          ),
          const SizedBox(height: 18),
          _labeledField(
            label: 'Certification ID (Optional)',
            field: TextFormField(controller: _certId, decoration: _inputDecoration()),
          ),
          const SizedBox(height: 18),
          _labeledField(
            label: 'Certification URL (Optional)',
            field: TextFormField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: _inputDecoration(),
            ),
          ),
        ],
      ),
    );

    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.gray800,
              side: const BorderSide(color: FigmaColors.gray300),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Back', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _saving || !_canSave ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _canSave ? rc.primary : FigmaColors.gray300,
              foregroundColor: FigmaColors.white,
              disabledBackgroundColor: FigmaColors.gray300,
              disabledForegroundColor: FigmaColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
                  )
                : Text(
                    widget.isEditing ? 'Save' : 'Add certification',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
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
              child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: form),
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
                child: Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
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
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: form),
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

  Widget _dateField({
    required String label,
    required String? value,
    required VoidCallback onTap,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
        const SizedBox(height: 8),
        TextFormField(
          readOnly: true,
          onTap: onTap,
          controller: required ? _issueDisplay : _expirationDisplay,
          validator: required
              ? (_) => (_issueDate == null || _issueDate!.isEmpty) ? 'Select an issue date' : null
              : null,
          decoration: _inputDecoration(hint: 'mm/dd/yyyy').copyWith(
            suffixIcon: IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.calendar_today_outlined, size: 20, color: FigmaColors.gray500),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle get _counterStyle => GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500);

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
