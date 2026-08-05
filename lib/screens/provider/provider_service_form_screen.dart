import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/marketing_service_catalog.dart';
import '../../figma_ui/marketing_service_images.dart';
import '../../figma_ui/service_categories.dart';
import '../../figma_ui/widgets/figma_network_image.dart';
import '../../models/app_user.dart';
import '../../models/service.dart';
import '../../models/service_approval_status.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../utils/service_certification_policy.dart';
import '../admin/widgets/admin_services_widgets.dart' show serviceCategoryIcon;

/// Add / edit provider service — modal on wide web, full screen on compact/native.
class ProviderServiceFormScreen extends StatefulWidget {
  const ProviderServiceFormScreen({
    super.key,
    required this.appUser,
    this.existing,
    this.inDialog = false,
  });

  final AppUser appUser;
  final ServiceListing? existing;
  final bool inDialog;

  bool get isEditing => existing != null;

  static Future<bool?> open(
    BuildContext context, {
    required AppUser appUser,
    ServiceListing? existing,
  }) {
    if (MobileLayout.useMobileChrome(context)) {
      return Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => providerThemed(
            ProviderServiceFormScreen(appUser: appUser, existing: existing),
          ),
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => providerThemed(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 900),
            child: ProviderServiceFormScreen(
              appUser: appUser,
              existing: existing,
              inDialog: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<ProviderServiceFormScreen> createState() => _ProviderServiceFormScreenState();
}

class _LocalServiceImage {
  _LocalServiceImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

class _ProviderServiceFormScreenState extends State<ProviderServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();

  String? _category;
  String _priceType = 'per hour';
  String? _duration;
  bool _isActive = true;
  bool _saving = false;

  final List<String> _imageUrls = [];
  final List<_LocalServiceImage> _localImages = [];
  final _picker = ImagePicker();

  static const _priceTypes = ['per hour', 'fixed', 'negotiable'];
  static const _durations = [
    '30 minutes',
    '1 hour',
    '1–2 hours',
    '2–3 hours',
    '3–4 hours',
    'Half day',
    'Full day',
  ];

  static const _maxDescription = 500;
  static const _maxPhotos = 6;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.serviceTitle;
      _description.text = e.description;
      _price.text = e.estimatedPrice.toStringAsFixed(0);
      _category = e.category;
      _priceType = e.priceType;
      _isActive = e.isActive;
      _duration = _durations.contains(e.estimatedDuration) ? e.estimatedDuration : e.estimatedDuration;
      _imageUrls.addAll(e.serviceImages);
    } else {
      _category = ServiceCategories.categoryNames.isNotEmpty
          ? ServiceCategories.categoryNames.first
          : null;
      _duration = '1–2 hours';
    }
    _title.addListener(_onFieldsChanged);
    _description.addListener(_onFieldsChanged);
    _price.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() => setState(() {});

  @override
  void dispose() {
    _title.removeListener(_onFieldsChanged);
    _description.removeListener(_onFieldsChanged);
    _price.removeListener(_onFieldsChanged);
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  MarketingServiceCategory? get _marketingCategory =>
      _category != null ? MarketingServiceCatalog.categoryByName(_category!) : null;

  List<String> get _templates =>
      _category != null ? ServiceCategories.serviceNamesForCategory(_category!) : const [];

  void _applyTemplate(String serviceName) {
    final cat = _marketingCategory;
    if (cat == null) return;
    for (final s in cat.services) {
      if (s.name == serviceName) {
        setState(() {
          _title.text = s.name;
          _description.text = s.description;
          if (_price.text.trim().isEmpty) {
            _price.text = s.startingPricePhp.toString();
          }
        });
        return;
      }
    }
    setState(() => _title.text = serviceName);
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _imageUrls.length - _localImages.length;
    if (remaining <= 0) {
      _snack('You can add up to $_maxPhotos photos');
      return;
    }
    try {
      final picks = await _picker.pickMultiImage(imageQuality: 85);
      if (picks.isEmpty) return;
      for (final x in picks.take(remaining)) {
        final bytes = await x.readAsBytes();
        if (bytes.isEmpty) continue;
        setState(() {
          _localImages.add(_LocalServiceImage(bytes: bytes, filename: x.name));
        });
      }
    } catch (_) {
      _snack('Could not pick photos');
    }
  }

  Future<List<String>> _uploadImages(String serviceId) async {
    final storage = StorageService();
    final urls = List<String>.from(_imageUrls);
    for (var i = 0; i < _localImages.length; i++) {
      final local = _localImages[i];
      final url = await storage.uploadServiceImage(
        providerId: widget.appUser.userId,
        serviceId: serviceId,
        bytes: local.bytes,
        filename: '${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
      );
      urls.add(url);
    }
    return urls;
  }

  List<String> _defaultImageUrls() {
    final category = _category;
    if (category == null) return [];
    return [
      MarketingServiceImages.urlFor(
        serviceName: _title.text.trim(),
        categoryId: ServiceCategories.categoryIdForName(category),
        categoryName: category,
      ),
    ];
  }

  bool _materialChanged(ServiceListing existing) {
    return _title.text.trim() != existing.serviceTitle ||
        (_category ?? '') != existing.category ||
        _description.text.trim() != existing.description ||
        (double.tryParse(_price.text.trim()) ?? 0) != existing.estimatedPrice ||
        _priceType != existing.priceType ||
        (_duration ?? '') != existing.estimatedDuration;
  }

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    final category = _category;
    final duration = _duration;
    if (category == null) {
      _snack('Choose a category');
      return;
    }
    if (duration == null || duration.isEmpty) {
      _snack('Select estimated duration');
      return;
    }

    setState(() => _saving = true);
    final firestore = FirestoreService();
    final price = double.tryParse(_price.text.trim()) ?? 0;

    if (publish) {
      final profile = await firestore.getProviderProfile(widget.appUser.userId);
      if (!(profile?.isVerifiedProvider ?? false)) {
        if (mounted) {
          setState(() => _saving = false);
          _snack('Complete identity verification (Verification Agency approval) before publishing.');
        }
        return;
      }
      final title = _title.text.trim();
      // Only services that need credentials are gated — not the whole provider.
      if (serviceRequiresCertification(category: category, serviceTitle: title) &&
          !(profile?.hasApprovedCertifications ?? false)) {
        if (mounted) {
          setState(() => _saving = false);
          _snack(
            'This service needs an authenticated certificate. '
            'Submit one on your profile for Verification Agency review, then try again.',
          );
        }
        return;
      }
    }

    final existing = widget.existing;
    final approval = publish
        ? ServiceApprovalStatus.pending
        : (existing?.approvalStatus ?? ServiceApprovalStatus.draft);
    final titleForPolicy = _title.text.trim();
    final needsCert = serviceRequiresCertification(
      category: category,
      serviceTitle: titleForPolicy,
    );

    try {
      if (widget.isEditing) {
        final id = existing!.serviceId;
        var images = await _uploadImages(id);
        if (images.isEmpty) images = _defaultImageUrls();
        final updates = <String, dynamic>{
          'serviceTitle': titleForPolicy,
          'category': category,
          'description': _description.text.trim(),
          'estimatedPrice': price,
          'priceType': _priceType,
          'estimatedDuration': duration,
          'serviceImages': images,
          'requiresCertification': needsCert,
        };
        if (publish || _materialChanged(existing)) {
          updates['approvalStatus'] = ServiceApprovalStatus.pending.firestoreValue;
          updates['isActive'] = false;
          updates['rejectionReason'] = '';
        } else if (existing.approvalStatus.isApproved) {
          updates['isActive'] = _isActive;
        } else {
          updates['isActive'] = false;
        }
        await firestore.updateService(id, updates);
      } else {
        final id = await firestore.createServiceListing(
          providerId: widget.appUser.userId,
          serviceTitle: titleForPolicy,
          category: category,
          description: _description.text.trim(),
          estimatedPrice: price,
          priceType: _priceType,
          estimatedDuration: duration,
          serviceImages: _defaultImageUrls(),
          isActive: false,
          approvalStatus: approval,
        );
        await firestore.updateService(id, {'requiresCertification': needsCert});
        var images = await _uploadImages(id);
        if (images.length > 1 || _localImages.isNotEmpty) {
          await firestore.updateService(id, {'serviceImages': images});
        }
      }
      if (!mounted) return;
      if (publish) {
        _snack('Listing submitted for admin review. You will be notified when it is approved.');
      }
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _snack('Could not save service. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _close() => Navigator.pop(context, false);

  String get _previewPrice {
    final n = double.tryParse(_price.text.trim());
    if (n == null || n <= 0) return '₱---';
    final pt = _priceType.toLowerCase();
    if (pt.contains('hour')) return '₱${n.toStringAsFixed(0)} per hour';
    if (pt == 'fixed') return '₱${n.toStringAsFixed(0)} fixed';
    return '₱${n.toStringAsFixed(0)} $_priceType';
  }

  @override
  Widget build(BuildContext context) {
    final body = Material(
      color: FigmaColors.white,
      borderRadius: widget.inDialog ? BorderRadius.circular(16) : null,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          Expanded(
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 860;
                  final form = _buildFormColumn(context);
                  final side = _buildSideColumn(context);
                  if (!wide) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [form, const SizedBox(height: 20), side],
                      ),
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
                          child: form,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(8, 0, 24, 24),
                          child: side,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );

    if (widget.inDialog) return body;

    return providerThemed(
      Scaffold(
        backgroundColor: FigmaColors.gray50,
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerIconButton(Icons.arrow_back_rounded, _close),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.isEditing ? 'Edit service' : 'Add service',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'List a service so customers can browse and send booking requests.',
                  style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          _headerIconButton(Icons.close_rounded, _close),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: FigmaColors.gray50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: FigmaColors.gray700),
        ),
      ),
    );
  }

  static const _categoryInputTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: FigmaColors.navy, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: FigmaColors.navy, width: 2),
    ),
  );

  Widget _buildCategoryField() {
    return FormField<String>(
      initialValue: _category,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      builder: (field) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              initialSelection: _category,
              width: constraints.maxWidth,
              expandedInsets: EdgeInsets.zero,
              enableSearch: false,
              enableFilter: false,
              requestFocusOnTap: true,
              label: const Text('Category'),
              errorText: field.errorText,
              inputDecorationTheme: _categoryInputTheme,
              dropdownMenuEntries: [
                for (final c in MarketingServiceCatalog.categories)
                  DropdownMenuEntry<String>(
                    value: c.name,
                    label: c.name,
                    leadingIcon: Icon(c.icon, size: 20, color: c.fg),
                  ),
              ],
              onSelected: (value) {
                field.didChange(value);
                setState(() => _category = value);
              },
              menuStyle: MenuStyle(
                alignment: Alignment.bottomLeft,
                maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 320)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormColumn(BuildContext context) {
    final templates = _templates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategoryField(),
        if (templates.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Quick fill from catalog (optional)',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a suggested title or type your own custom service name below.',
            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in templates)
                _CatalogChip(label: name, onTap: () => _applyTemplate(name)),
            ],
          ),
        ] else if (_category == 'Custom Services') ...[
          const SizedBox(height: 20),
          Text(
            'Custom service',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter any service title that fits your skills. The Administrator will review it before customers can see it.',
            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.35),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Upload service photos (optional)',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
        ),
        const SizedBox(height: 10),
        _PhotoStrip(
          imageUrls: _imageUrls,
          localImages: _localImages,
          onAdd: _pickPhotos,
          onRemoveUrl: (url) => setState(() => _imageUrls.remove(url)),
          onRemoveLocal: (i) => setState(() => _localImages.removeAt(i)),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Service title *',
            hintText: 'Catalog suggestion or your own custom service name',
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _description,
          maxLines: 5,
          maxLength: _maxDescription,
          decoration: const InputDecoration(
            labelText: 'Description *',
            hintText: 'Describe what you offer, what is included, and any requirements…',
            alignLabelWithHint: true,
            counterText: '',
          ),
          validator: (v) =>
              v == null || v.trim().length < 10 ? 'Add at least 10 characters' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_description.text.length} / $_maxDescription',
            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (₱) *',
                  hintText: 'e.g., 500',
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a valid price';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _priceType,
                decoration: const InputDecoration(labelText: 'Price type *'),
                items: [
                  for (final p in _priceTypes)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _priceType = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _durations.contains(_duration) ? _duration : null,
          decoration: const InputDecoration(
            labelText: 'Estimated duration *',
            hintText: 'Select duration',
          ),
          items: [
            for (final d in _durations)
              DropdownMenuItem(value: d, child: Text(d)),
          ],
          onChanged: (v) => setState(() => _duration = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        if (widget.isEditing && widget.existing!.approvalStatus.isApproved) ...[
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Listing visible', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Turn off to pause this approved listing on the marketplace.',
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
            ),
            value: _isActive,
            activeTrackColor: FigmaColors.tintBlue,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? FigmaColors.navy : null,
            ),
            onChanged: (v) => setState(() => _isActive = v),
          ),
        ] else if (widget.isEditing) ...[
          const SizedBox(height: 16),
          _ListingReviewBanner(status: widget.existing!.approvalStatus),
        ],
        if (_category != null) ...[
          const SizedBox(height: 16),
          _CertificationPolicyBanner(
            requiresCert: serviceRequiresCertification(
              category: _category!,
              serviceTitle: _title.text.trim(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSideColumn(BuildContext context) {
    final title = _title.text.trim().isEmpty ? 'Service title' : _title.text.trim();
    final desc = _description.text.trim().isEmpty
        ? 'Your description will appear here.'
        : _description.text.trim();
    final category = _category ?? 'Category';
    final cat = _marketingCategory;
    final previewUrl = _imageUrls.isNotEmpty
        ? _imageUrls.first
        : (_localImages.isNotEmpty
            ? null
            : (_category != null
                ? MarketingServiceImages.urlFor(
                    serviceName: title,
                    categoryName: _category!,
                  )
                : null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Live preview',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
        ),
        const SizedBox(height: 4),
        Text(
          'This is how customers will see your service.',
          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FigmaColors.gray200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: previewUrl != null
                    ? FigmaNetworkImage(url: previewUrl, fit: BoxFit.cover)
                    : (_localImages.isNotEmpty
                        ? Image.memory(_localImages.first.bytes, fit: BoxFit.cover)
                        : Container(
                            color: FigmaColors.gray100,
                            child: const Icon(Icons.image_outlined, size: 48, color: FigmaColors.gray300),
                          )),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          cat?.icon ?? serviceCategoryIcon(category, title),
                          size: 16,
                          color: cat?.fg ?? FigmaColors.gray600,
                        ),
                        const SizedBox(width: 6),
                        Text(category, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _previewPrice,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: FigmaColors.gray500),
                        const SizedBox(width: 6),
                        Text(
                          _duration ?? '1–2 hours',
                          style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      desc,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FigmaColors.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FigmaColors.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: FigmaColors.orange600, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Tips for a great listing',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final tip in const [
                'Use clear photos of your work or tools.',
                'Write a detailed description of what is included.',
                'Set a fair price for your area and experience.',
                'Respond quickly when customers send requests.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: FigmaColors.navy, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: FigmaColors.gray200)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 640;
          final publishLabel = widget.isEditing ? 'Save changes' : 'Publish service';

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _footerOutlined('Cancel', _close)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _footerOutlined(
                        'Save as draft',
                        _saving ? null : () => _save(publish: false),
                        textColor: FigmaColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _footerFilled(publishLabel, _saving ? null : () => _save(publish: true)),
              ],
            );
          }

          return Row(
            children: [
              _footerOutlined('Cancel', _close),
              const SizedBox(width: 10),
              _footerOutlined(
                'Save as draft',
                _saving ? null : () => _save(publish: false),
                textColor: FigmaColors.navy,
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: _footerFilled(
                  publishLabel,
                  _saving ? null : () => _save(publish: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _footerOutlined(String label, VoidCallback? onPressed, {Color? textColor}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor ?? FigmaColors.gray800,
        side: const BorderSide(color: FigmaColors.gray300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
    );
  }

  Widget _footerFilled(String label, VoidCallback? onPressed) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: FigmaColors.navy,
        foregroundColor: FigmaColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: _saving
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
            )
          : Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}

class _CatalogChip extends StatelessWidget {
  const _CatalogChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FigmaColors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FigmaColors.gray200),
          ),
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.imageUrls,
    required this.localImages,
    required this.onAdd,
    required this.onRemoveUrl,
    required this.onRemoveLocal,
  });

  final List<String> imageUrls;
  final List<_LocalServiceImage> localImages;
  final VoidCallback onAdd;
  final void Function(String url) onRemoveUrl;
  final void Function(int index) onRemoveLocal;

  static const _slot = 96.0;

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[
      _AddPhotoSlot(onTap: onAdd, isPrimary: imageUrls.isEmpty && localImages.isEmpty),
      for (final url in imageUrls) _UrlPhotoSlot(url: url, onRemove: () => onRemoveUrl(url)),
      for (var i = 0; i < localImages.length; i++)
        _MemoryPhotoSlot(bytes: localImages[i].bytes, onRemove: () => onRemoveLocal(i)),
      if (imageUrls.isNotEmpty || localImages.isNotEmpty) _AddMoreSlot(onTap: onAdd),
    ];

    return SizedBox(
      height: _slot,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => slots[i],
      ),
    );
  }
}

class _AddPhotoSlot extends StatelessWidget {
  const _AddPhotoSlot({required this.onTap, this.isPrimary = false});

  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PhotoStrip._slot,
      child: Material(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPrimary ? FigmaColors.navy : FigmaColors.gray300,
                width: isPrimary ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: isPrimary ? FigmaColors.navy : FigmaColors.gray500,
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  'Add photos',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.gray800,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'PNG, JPG up to 10MB',
                  style: GoogleFonts.inter(fontSize: 9, color: FigmaColors.gray500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMoreSlot extends StatelessWidget {
  const _AddMoreSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PhotoStrip._slot,
      child: Material(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FigmaColors.gray200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_outlined, color: FigmaColors.gray500, size: 28),
                const SizedBox(height: 4),
                Text('Add more', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UrlPhotoSlot extends StatelessWidget {
  const _UrlPhotoSlot({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PhotoStrip._slot,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FigmaNetworkImage(url: url, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _RemovePhotoButton(onTap: onRemove),
          ),
        ],
      ),
    );
  }
}

class _MemoryPhotoSlot extends StatelessWidget {
  const _MemoryPhotoSlot({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PhotoStrip._slot,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _RemovePhotoButton(onTap: onRemove),
          ),
        ],
      ),
    );
  }
}

class _ListingReviewBanner extends StatelessWidget {
  const _ListingReviewBanner({required this.status});

  final ServiceApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (title, body, color, bg) = switch (status) {
      ServiceApprovalStatus.pending => (
          'Pending admin review',
          'This listing is not visible to customers until an administrator approves it.',
          FigmaColors.orange600,
          FigmaColors.orange50,
        ),
      ServiceApprovalStatus.rejected => (
          'Listing rejected',
          'Update the listing and publish again to resubmit for review.',
          FigmaColors.red600,
          FigmaColors.red50,
        ),
      ServiceApprovalStatus.draft => (
          'Draft',
          'Save as draft or publish to submit for admin review.',
          FigmaColors.gray600,
          FigmaColors.gray100,
        ),
      ServiceApprovalStatus.approved => (
          '',
          '',
          FigmaColors.green,
          FigmaColors.tintGreen,
        ),
    };
    if (title.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(body, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700, height: 1.4)),
        ],
      ),
    );
  }
}

class _CertificationPolicyBanner extends StatelessWidget {
  const _CertificationPolicyBanner({required this.requiresCert});

  final bool requiresCert;

  @override
  Widget build(BuildContext context) {
    final color = requiresCert ? FigmaColors.orange600 : FigmaColors.green;
    final bg = requiresCert ? FigmaColors.orange50 : FigmaColors.tintGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            requiresCert ? Icons.workspace_premium_outlined : Icons.check_circle_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              requiresCert
                  ? 'Certificate required — Verification Agency must authenticate a credential on your profile before you can publish this listing. Admin still reviews the listing after that.'
                  : 'No certificate required for this service — you can publish after identity verification. Admin reviews the listing as usual.',
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovePhotoButton extends StatelessWidget {
  const _RemovePhotoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, size: 14, color: FigmaColors.white),
        ),
      ),
    );
  }
}
