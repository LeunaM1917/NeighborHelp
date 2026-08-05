import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/widgets/figma_network_image.dart';
import '../../models/provider_portfolio_project.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';
import '../../widgets/app_scroll_chrome.dart';

class _PortfolioPhotoDraft {
  _PortfolioPhotoDraft({this.url, this.bytes, this.filename = 'photo.jpg', this.caption = ''});

  final String? url;
  final Uint8List? bytes;
  final String filename;
  String caption;

  bool get hasSource => (url != null && url!.isNotEmpty) || bytes != null;
}

enum _PortfolioStep { edit, preview }

/// Multi-step portfolio editor: form → preview → thumbnail picker → save.
class ProviderPortfolioFlow extends StatefulWidget {
  const ProviderPortfolioFlow({
    super.key,
    required this.providerId,
    this.initial,
    this.editIndex,
    this.inDialog = true,
  });

  final String providerId;
  final ProviderPortfolioProject? initial;
  final int? editIndex;
  final bool inDialog;

  bool get isEditing => initial != null && !initial!.isEmpty;

  static Future<bool?> open(
    BuildContext context, {
    required String providerId,
    ProviderPortfolioProject? initial,
    int? editIndex,
  }) {
    final body = ProviderPortfolioFlow(
      providerId: providerId,
      initial: initial,
      editIndex: editIndex,
      inDialog: !MobileLayout.useMobileChrome(context),
    );

    if (MobileLayout.useMobileChrome(context)) {
      return Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => providerThemed(
            Scaffold(
              backgroundColor: FigmaColors.white,
              body: SafeArea(
                minimum: EdgeInsets.only(
                  top: MobileLayout.isNativeApp(context) ? 8 : 0,
                  bottom: MobileLayout.isNativeApp(context) ? 8 : 0,
                ),
                child: body,
              ),
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960, maxHeight: 820),
            child: body,
          ),
        ),
      ),
    );
  }

  @override
  State<ProviderPortfolioFlow> createState() => _ProviderPortfolioFlowState();
}

class _ProviderPortfolioFlowState extends State<ProviderPortfolioFlow> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _role = TextEditingController();
  final _description = TextEditingController();
  final _skillInput = TextEditingController();
  final _picker = ImagePicker();

  _PortfolioStep _step = _PortfolioStep.edit;
  late String _projectId;
  final List<String> _skills = [];
  final List<_PortfolioPhotoDraft> _photos = [];
  int _thumbnailIndex = 0;
  double _thumbnailZoom = 1.0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _projectId = e?.id.isNotEmpty == true ? e!.id : DateTime.now().millisecondsSinceEpoch.toString();
    _title.text = e?.title ?? '';
    _role.text = e?.role ?? '';
    _description.text = e?.description ?? '';
    _skills.addAll(e?.skills ?? []);
    _thumbnailIndex = e?.thumbnailIndex ?? 0;
    if (e != null) {
      for (final p in e.photos) {
        _photos.add(_PortfolioPhotoDraft(url: p.url, caption: p.caption));
      }
    }
    _title.addListener(_refresh);
    _description.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _title.removeListener(_refresh);
    _description.removeListener(_refresh);
    _title.dispose();
    _role.dispose();
    _description.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  int get _skillsLeft => ProviderPortfolioProject.maxSkills - _skills.length;

  bool get _canPreview =>
      _title.text.trim().isNotEmpty &&
      _description.text.trim().isNotEmpty &&
      _skills.isNotEmpty &&
      _photos.any((p) => p.hasSource);

  @override
  Widget build(BuildContext context) {
    if (_step == _PortfolioStep.preview) {
      return _buildPreviewShell(context);
    }
    return _buildEditShell(context);
  }

  Widget _buildEditShell(BuildContext context) {
    final title = widget.isEditing ? 'Edit portfolio project' : 'Add a new portfolio project';
    final content = LayoutBuilder(
      builder: (context, c) {
        final stack = !widget.inDialog || c.maxWidth < 720;
        final form = _editForm();
        final media = _mediaPanel(context);
        if (stack) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [form, const SizedBox(height: 20), media],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 12, 8), child: form)),
            Expanded(flex: 4, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 8, 20, 8), child: media)),
          ],
        );
      },
    );

    final footer = _editFooter(context);

    if (!widget.inDialog) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flowHeader(context, title, onClose: () => Navigator.pop(context)),
          Expanded(child: AppScrollChrome(child: content)),
          footer,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _flowHeader(context, title, onClose: () => Navigator.pop(context)),
        Flexible(child: content),
        footer,
      ],
    );
  }

  Widget _buildPreviewShell(BuildContext context) {
    final rc = context.roleColors;
    final title = _title.text.trim();
    final body = LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < 720;
        final details = _previewDetails();
        final gallery = _previewGallery();
        if (stack) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [details, const SizedBox(height: 20), gallery]),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 12, 8), child: details)),
            Expanded(flex: 6, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 8, 20, 8), child: gallery)),
          ],
        );
      },
    );

    return Column(
      mainAxisSize: widget.inDialog ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _flowHeader(context, title, onClose: () => Navigator.pop(context)),
        if (widget.inDialog) Flexible(child: body) else Expanded(child: AppScrollChrome(child: body)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => setState(() => _step = _PortfolioStep.edit),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FigmaColors.gray800,
                  side: const BorderSide(color: FigmaColors.gray300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Back', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _openThumbnailDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: rc.primary,
                  foregroundColor: FigmaColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text('Next: Thumbnail', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _flowHeader(BuildContext context, String title, {required VoidCallback onClose}) {
    final topPad = widget.inDialog ? 18.0 : 12.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                const SizedBox(height: 4),
                Text(
                  'All fields are required unless otherwise indicated.',
                  style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 22), color: FigmaColors.gray600),
        ],
      ),
    );
  }

  Widget _editForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            label: 'Project title *',
            field: TextFormField(
              controller: _title,
              maxLength: ProviderPortfolioProject.maxTitleLength,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  Text('${maxLength! - currentLength} characters left', style: _counterStyle),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a project title' : null,
              decoration: _inputDecoration(hint: 'Enter a brief but descriptive title.'),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Your role (optional)',
            field: TextFormField(
              controller: _role,
              maxLength: ProviderPortfolioProject.maxRoleLength,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  Text('${maxLength! - currentLength} characters left', style: _counterStyle),
              decoration: _inputDecoration(hint: 'e.g., Front-end engineer or Marketing analyst'),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Project description *',
            field: TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: ProviderPortfolioProject.maxDescriptionLength,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  Text('${maxLength! - currentLength} characters left', style: _counterStyle),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a project description' : null,
              decoration: _inputDecoration(
                hint: "Briefly describe the project's goals, your solution and the impact you made here.",
              ),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            label: 'Skills and deliverables *',
            field: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_skills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _skills
                          .map(
                            (s) => Chip(
                              label: Text(s, style: GoogleFonts.inter(fontSize: 13)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setState(() => _skills.remove(s)),
                              backgroundColor: FigmaColors.gray100,
                              side: BorderSide.none,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                TextField(
                  controller: _skillInput,
                  enabled: _skillsLeft > 0,
                  decoration: _inputDecoration(hint: 'Type to add skills relevant to this project'),
                  onSubmitted: _addSkill,
                ),
                const SizedBox(height: 4),
                Text('$_skillsLeft skills left', style: _counterStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaPanel(BuildContext context) {
    final rc = context.roleColors;
    final hasPhotos = _photos.any((p) => p.hasSource);

    if (hasPhotos) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = _photos[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 200,
                        height: 280,
                        child: _photoImage(p, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() {
                            _photos.removeAt(i);
                            if (_thumbnailIndex >= _photos.length) _thumbnailIndex = 0;
                          }),
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 18, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _photos.length >= ProviderPortfolioProject.maxPhotos ? null : _pickPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add more photos'),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickPhotos,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 320),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rc.primary.withValues(alpha: 0.45), width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _mediaTypeIcon(Icons.image_outlined, 'Image', onTap: _pickPhotos),
                _mediaTypeIcon(Icons.videocam_outlined, 'Video', onTap: () => _snack('Video uploads coming soon')),
                _mediaTypeIcon(Icons.text_fields, 'Text', onTap: () => _snack('Text content coming soon')),
                _mediaTypeIcon(Icons.link, 'Link', onTap: () => _snack('Links coming soon')),
                _mediaTypeIcon(Icons.description_outlined, 'Document', onTap: () => _snack('Documents coming soon')),
                _mediaTypeIcon(Icons.audiotrack_outlined, 'Audio', onTap: () => _snack('Audio coming soon')),
              ],
            ),
            const SizedBox(height: 16),
            Text('Add content', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray700)),
            const SizedBox(height: 6),
            Text(
              'Up to ${ProviderPortfolioProject.maxPhotos} photos',
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaTypeIcon(IconData icon, String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: FigmaColors.gray300),
            ),
            child: Icon(icon, color: FigmaColors.gray600, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600)),
        ],
      ),
    );
  }

  Widget _editFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => _save(isDraft: true),
            child: Text('Save as draft', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _saving || !_canPreview ? null : _goPreview,
            style: FilledButton.styleFrom(
              backgroundColor: _canPreview ? context.roleColors.primary : FigmaColors.gray300,
              foregroundColor: FigmaColors.white,
              disabledBackgroundColor: FigmaColors.gray300,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Next: Preview', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _previewDetails() {
    final role = _role.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (role.isNotEmpty) ...[
          Text('My role', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
          const SizedBox(height: 4),
          Text(role, style: GoogleFonts.inter(fontSize: 15, color: FigmaColors.gray900)),
          const SizedBox(height: 18),
        ],
        Text('Project description', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
        const SizedBox(height: 4),
        Text(_description.text.trim(), style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.5)),
        const SizedBox(height: 18),
        Text('Skills and deliverables', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _skills
              .map(
                (s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: FigmaColors.gray100, borderRadius: BorderRadius.circular(20)),
                  child: Text(s, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _previewGallery() {
    return Column(
      children: [
        for (var i = 0; i < _photos.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _photoImage(_photos[i], fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('caption_$i'),
            initialValue: _photos[i].caption,
            decoration: _inputDecoration(hint: 'Caption (optional)'),
            onChanged: (v) => _photos[i].caption = v,
          ),
        ],
      ],
    );
  }

  Future<void> _openThumbnailDialog() async {
    if (_photos.isEmpty) return;
    _thumbnailIndex = _thumbnailIndex.clamp(0, _photos.length - 1);
    _thumbnailZoom = 1.0;

    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => providerThemed(
        StatefulBuilder(
        builder: (ctx, setDialogState) {
          final rc = ctx.providerColors;
          final draft = _photos[_thumbnailIndex];

          return Dialog(
            backgroundColor: FigmaColors.white,
            insetPadding: EdgeInsets.symmetric(
              horizontal: MobileLayout.useMobileChrome(ctx) ? 12 : 48,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thumbnail preview',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Transform.scale(
                          scale: _thumbnailZoom,
                          child: _photoImage(draft, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Icon(Icons.zoom_out, size: 20, color: FigmaColors.gray500),
                        Expanded(
                          child: Slider(
                            value: _thumbnailZoom,
                            min: 0.8,
                            max: 1.6,
                            onChanged: (v) => setDialogState(() => _thumbnailZoom = v),
                            activeColor: rc.primary,
                          ),
                        ),
                        Icon(Icons.zoom_in, size: 20, color: rc.primary),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 88,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        if (_photos.length < ProviderPortfolioProject.maxPhotos)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () async {
                                await _pickPhotos();
                                setDialogState(() {});
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  border: Border.all(color: FigmaColors.gray300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add, color: FigmaColors.gray500),
                              ),
                            ),
                          ),
                        for (var i = 0; i < _photos.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => setDialogState(() => _thumbnailIndex = i),
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: i == _thumbnailIndex ? rc.primary : FigmaColors.gray200,
                                    width: i == _thumbnailIndex ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: _photoImage(_photos[i], fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: rc.primary,
                          foregroundColor: FigmaColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );

    if (saved == true && mounted) {
      await _save(isDraft: false);
    }
  }

  void _goPreview() {
    if (!_formKey.currentState!.validate()) return;
    if (_skills.isEmpty) {
      _snack('Add at least one skill');
      return;
    }
    if (!_photos.any((p) => p.hasSource)) {
      _snack('Add at least one photo');
      return;
    }
    setState(() => _step = _PortfolioStep.preview);
  }

  void _addSkill(String value) {
    final s = value.trim();
    if (s.isEmpty || _skills.contains(s) || _skills.length >= ProviderPortfolioProject.maxSkills) return;
    setState(() {
      _skills.add(s);
      _skillInput.clear();
    });
  }

  Future<void> _pickPhotos() async {
    final remaining = ProviderPortfolioProject.maxPhotos - _photos.length;
    if (remaining <= 0) {
      _snack('You can add up to ${ProviderPortfolioProject.maxPhotos} photos');
      return;
    }
    try {
      final picks = await _picker.pickMultiImage(imageQuality: 85);
      if (picks.isEmpty) return;
      for (final x in picks.take(remaining)) {
        final bytes = await x.readAsBytes();
        if (bytes.isEmpty) continue;
        setState(() {
          _photos.add(_PortfolioPhotoDraft(bytes: bytes, filename: x.name));
        });
      }
    } catch (_) {
      _snack('Could not pick photos');
    }
  }

  Future<List<PortfolioProjectPhoto>> _uploadPhotos() async {
    final storage = StorageService();
    final out = <PortfolioProjectPhoto>[];
    for (var i = 0; i < _photos.length; i++) {
      final d = _photos[i];
      var url = d.url ?? '';
      if (d.bytes != null) {
        url = await storage.uploadPortfolioPhoto(
          providerId: widget.providerId,
          projectId: _projectId,
          bytes: d.bytes!,
          filename: '${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
      }
      if (url.isNotEmpty) {
        out.add(PortfolioProjectPhoto(url: url, caption: d.caption));
      }
    }
    return out;
  }

  Future<void> _save({required bool isDraft}) async {
    if (!isDraft) {
      if (!_formKey.currentState!.validate() || _skills.isEmpty || !_photos.any((p) => p.hasSource)) {
        _snack('Complete required fields and add photos before publishing');
        return;
      }
    } else if (_title.text.trim().isEmpty) {
      _snack('Add a project title to save draft');
      return;
    }
    setState(() => _saving = true);
    try {
      final photos = await _uploadPhotos();
      if (photos.isEmpty && !isDraft) {
        _snack('Add at least one photo');
        return;
      }
      final thumbIdx = _thumbnailIndex.clamp(0, photos.isEmpty ? 0 : photos.length - 1);
      final thumbUrl = photos.isEmpty ? '' : photos[thumbIdx].url;

      final project = ProviderPortfolioProject(
        id: _projectId,
        title: _title.text.trim(),
        role: _role.text.trim(),
        description: _description.text.trim(),
        skills: List<String>.from(_skills),
        photos: photos,
        thumbnailUrl: thumbUrl,
        thumbnailIndex: thumbIdx,
        isDraft: isDraft,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

      final profile = await FirestoreService().getProviderProfile(widget.providerId);
      final updated = List<ProviderPortfolioProject>.from(profile?.portfolioProjects ?? []);
      if (updated.isEmpty && (profile?.portfolioUrls.isNotEmpty ?? false)) {
        updated.addAll(ProviderPortfolioProject.fromLegacyUrls(profile!.portfolioUrls));
      }

      if (widget.editIndex != null && widget.editIndex! >= 0 && widget.editIndex! < updated.length) {
        updated[widget.editIndex!] = project;
      } else if (widget.initial != null) {
        final idx = updated.indexWhere((p) => p.id == widget.initial!.id);
        if (idx >= 0) {
          updated[idx] = project;
        } else {
          updated.add(project);
        }
      } else {
        updated.add(project);
      }

      final publishedUrls = updated
          .where((p) => !p.isDraft && p.thumbnailUrl.isNotEmpty)
          .map((p) => p.thumbnailUrl)
          .toList();

      await FirestoreService().updateServiceProvider(
        providerId: profile?.providerId ?? widget.providerId,
        data: {
          'portfolioProjects': ProviderPortfolioProject.listToFirestore(updated),
          'portfolioUrls': publishedUrls,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _snack('Could not save portfolio. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoImage(_PortfolioPhotoDraft p, {required BoxFit fit}) {
    if (p.bytes != null) {
      return Image.memory(p.bytes!, fit: fit);
    }
    if (p.url != null && p.url!.isNotEmpty) {
      return FigmaNetworkImage(url: p.url!, fit: fit);
    }
    return ColoredBox(color: FigmaColors.gray100, child: Icon(Icons.image_outlined, color: FigmaColors.gray400, size: 48));
  }

  Widget _field({required String label, required Widget field}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
        const SizedBox(height: 8),
        field,
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
