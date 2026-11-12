import '../../ui/app_notification_dialog.dart';
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
import '../../models/provider.dart';
import '../../models/provider_certification.dart';
import '../../utils/image_upload.dart';
import '../../models/service.dart';
import '../../models/service_approval_status.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../utils/service_certification_policy.dart';
import '../../widgets/account_setup_gate.dart';
import '../../models/user_role.dart';
import 'provider_certification_dialog.dart';
import '../admin/widgets/admin_services_widgets.dart' show serviceCategoryIcon;

/// Add / edit provider service — modal on wide web, full screen on compact/native.
class ProviderServiceFormScreen extends StatefulWidget {
  const ProviderServiceFormScreen({
    super.key,
    required this.appUser,
    this.existing,
    this.inDialog = false,
    this.firestore,
  });

  final AppUser appUser;
  final ServiceListing? existing;
  final bool inDialog;
  final FirestoreService? firestore;

  bool get isEditing => existing != null;

  static Future<bool?> open(
    BuildContext context, {
    required AppUser appUser,
    ServiceListing? existing,
  }) async {
    if (!await requireAccountSetup(
      context,
      appUser: appUser,
      role: UserRole.provider,
      action: 'list a service',
    )) {
      return false;
    }
    if (!context.mounted) return false;
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
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
  State<ProviderServiceFormScreen> createState() =>
      _ProviderServiceFormScreenState();
}

class _LocalServiceImage {
  _LocalServiceImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
  String? uploadedUrl;
}

class _ProviderServiceFormScreenState extends State<ProviderServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _photoSectionKey = GlobalKey();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();

  String? _category;
  String _priceType = 'negotiable';
  String? _duration;
  bool _isActive = true;
  ServiceProviderProfile? _profile;
  String? _certificateId;
  String? _photoError;
  String? _credentialError;
  bool _loadingCertificates = false;
  String? _newServiceId;
  final Set<String> _customCategories = {};
  final Set<String> _customServices = {};
  final List<Map<String, dynamic>> _catalog = [];
  int _categoryMenuVersion = 0;
  bool _saving = false;

  final List<String> _imageUrls = [];
  final List<_LocalServiceImage> _localImages = [];
  final _picker = ImagePicker();

  static const _priceTypes = ['hourly', 'fixed', 'daily', 'negotiable'];
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
      if (!ServiceCategories.categoryNames.contains(e.category)) {
        _customCategories.add(e.category);
      }
      _certificateId = e.certificationEntryId.isEmpty
          ? null
          : e.certificationEntryId;
      _priceType = _priceTypes.contains(e.priceType.toLowerCase())
          ? e.priceType.toLowerCase()
          : 'negotiable';
      _isActive = e.isActive;
      _duration = _durations.contains(e.estimatedDuration)
          ? e.estimatedDuration
          : e.estimatedDuration;
      _imageUrls.addAll(e.serviceImages);
    } else {
      _category = ServiceCategories.categoryNames.isNotEmpty
          ? ServiceCategories.categoryNames.first
          : null;
      _duration = '1–2 hours';
    }
    _loadCertificates();
    _loadCatalog();
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

  MarketingServiceCategory? get _marketingCategory => _category != null
      ? MarketingServiceCatalog.categoryByName(_category!)
      : null;

  List<String> get _templates => [
    ...{
      ...ServiceCategories.serviceNamesForCategory(_category ?? ''),
      ..._catalog
          .where(
            (s) =>
                normalizeCredential('${s['category']}') ==
                normalizeCredential(_category ?? ''),
          )
          .map((s) => '${s['serviceTitle']}'),
      ..._customServices,
    },
  ];

  void _applyTemplate(String serviceName) {
    _certificateId = null;
    final cat = _marketingCategory;
    if (cat == null) {
      setState(() => _title.text = serviceName);
      _selectMatchingCertificate();
      return;
    }
    for (final s in cat.services) {
      if (s.name == serviceName) {
        setState(() {
          _title.text = s.name;
          _description.text = s.description;
          if (_price.text.trim().isEmpty && s.startingPricePhp > 0) {
            _price.text = s.startingPricePhp.toString();
          }
        });
        _selectMatchingCertificate();
        return;
      }
    }
    setState(() => _title.text = serviceName);
    _selectMatchingCertificate();
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
        ImageUploadFormat.inspect(bytes);
        if (_localImages.any((image) => listEquals(image.bytes, bytes))) {
          _snack('This photo is already selected. Choose another photo.');
          continue;
        }
        setState(() {
          _localImages.add(_LocalServiceImage(bytes: bytes, filename: x.name));
          _photoError = null;
        });
      }
    } catch (e) {
      _snack(
        e is ArgumentError ? e.message.toString() : 'Could not pick photos',
      );
    }
  }

  Future<List<String>> _uploadImages(String serviceId) async {
    final urls = List<String>.from(_imageUrls);
    for (var i = 0; i < _localImages.length; i++) {
      final local = _localImages[i];
      final url = local.uploadedUrl ??= await StorageService()
          .uploadServiceImage(
            providerId: widget.appUser.userId,
            serviceId: serviceId,
            bytes: local.bytes,
            filename: '${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          );
      urls.add(url);
    }
    return urls;
  }

  Future<void> _save({required bool publish}) async {
    if (_saving) return;
    if (publish &&
        !await requireAccountSetup(
          context,
          appUser: widget.appUser,
          role: UserRole.provider,
          action: 'list a service',
          firestore: widget.firestore,
        )) {
      return;
    }
    if (!mounted || (publish && !_formKey.currentState!.validate())) return;
    setState(() => _saving = true);
    try {
      final firestore = widget.firestore ?? FirestoreService();
      if (publish) {
        final profile = await firestore.getProviderProfileForListing(
          widget.appUser.userId,
        );
        if (!mounted) return;
        _profile = profile;
        _selectMatchingCertificate();
        final selected = profile?.certificationHistory
            .where((c) => c.id == _certificateId)
            .firstOrNull;
        final family = approvedServiceFamily(
          _category ?? '',
          _title.text.trim(),
        );
        final valid =
            selected != null &&
            isCurrentReviewedCredential(profile!, selected) &&
            (family == null ||
                selected.credentialType == 'equivalent' ||
                (approvedQualifications[family] ?? [])
                    .map(normalizeCredential)
                    .contains(normalizeCredential(selected.name)));
        if (!valid) {
          await _showCertificateHelp(
            selected?.isPending == true
                ? ServiceCertificateStatus.pending
                : selected?.isRejected == true
                ? ServiceCertificateStatus.rejected
                : profile == null
                ? ServiceCertificateStatus.missing
                : serviceCertificateStatus(
                    profile,
                    category: _category ?? '',
                    serviceTitle: _title.text.trim(),
                  ),
            _category ?? '',
            _title.text.trim(),
          );
          return;
        }
        if (!profile.isVerifiedProvider) {
          await _showListingNotice(
            'Identity verification required',
            'Complete government ID verification in your profile and wait for System Administrator approval before submitting your listing. You can save a draft.',
          );
          return;
        }
        if (_imageUrls.length + _localImages.length < 3) {
          setState(
            () => _photoError =
                'Add at least 3 service photos before submitting for approval.',
          );
          final photoContext = _photoSectionKey.currentContext;
          if (photoContext != null && photoContext.mounted) {
            await Scrollable.ensureVisible(
              photoContext,
              duration: const Duration(milliseconds: 250),
              alignment: 0.2,
            );
          }
          return;
        }
      }
      final existing = widget.existing;
      final id =
          existing?.serviceId ?? (_newServiceId ??= firestore.newServiceId());
      final images = await _uploadImages(id);
      // Keep successful uploads for retries; never submit a partially saved listing.
      _imageUrls
        ..clear()
        ..addAll(images);
      _localImages.clear();
      final fields = <String, dynamic>{
        'serviceTitle': _title.text.trim(),
        'category': _category ?? '',
        'description': _description.text.trim(),
        'estimatedPrice': double.tryParse(_price.text.trim()) ?? 0,
        'priceType': _priceType,
        'estimatedDuration': _duration ?? '',
        'serviceImages': images,
        'certificationEntryId': _certificateId ?? '',
        'isActive': false,
        'approvalStatus': publish ? 'Pending' : 'Draft',
      };
      // The server creates or revises this provider's listing atomically.
      await firestore.updateService(id, fields);
      if (!mounted) return;
      if (publish) {
        _snack(
          'Listing submitted for admin review. You will be notified when it is approved.',
        );
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        await _showListingNotice(
          'Could not save service',
          error is StateError
              ? error.message.toString()
              : 'Check your connection and try again. Your listing details are still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadCertificates() async {
    setState(() {
      _loadingCertificates = true;
      _credentialError = null;
    });
    try {
      final profile = await (widget.firestore ?? FirestoreService())
          .getProviderProfileForListing(widget.appUser.userId);
      if (mounted) {
        setState(() => _profile = profile);
        _selectMatchingCertificate();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _credentialError =
              'Could not load certificates. Retry to select your credential.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCertificates = false);
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final options = await (widget.firestore ?? FirestoreService())
          .approvedServiceOptions();
      if (!mounted) return;
      setState(() {
        _catalog.addAll(options);
        _customCategories.addAll(
          options
              .map((s) => '${s['category']}')
              .where((c) => !ServiceCategories.categoryNames.contains(c)),
        );
      });
    } catch (_) {
      /* The built-in catalog remains available while offline. */
    }
  }

  Future<void> _setVisibility(bool value) async {
    setState(() => _saving = true);
    try {
      await (widget.firestore ?? FirestoreService()).setServiceActive(
        widget.existing!.serviceId,
        value,
      );
      if (mounted) setState(() => _isActive = value);
    } catch (error) {
      if (mounted) {
        _snack(
          error is StateError
              ? error.message.toString()
              : 'Could not update listing visibility.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectMatchingCertificate() {
    final profile = _profile;
    if (profile == null || _certificateId != null) return;
    final family = approvedServiceFamily(_category ?? '', _title.text.trim());
    final names = (approvedQualifications[family] ?? [])
        .map(normalizeCredential)
        .toSet();
    final matching = profile.certificationHistory.where(
      (c) =>
          isCurrentReviewedCredential(profile, c) &&
          (family == null || names.contains(normalizeCredential(c.name))),
    );
    if (matching.isNotEmpty) setState(() => _certificateId = matching.first.id);
  }

  Future<void> _addCustomName({required bool category}) async {
    var entered = '';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category ? 'Add Category' : 'Add Service'),
        content: TextField(
          onChanged: (v) => entered = v,
          autofocus: true,
          maxLength: category ? 100 : 140,
          decoration: InputDecoration(
            labelText: category ? 'Category name' : 'Service name',
            helperMaxLines: 3,
            helperText:
                'Certificate alignment will be reviewed with your listing.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (entered.trim().length >= 3) {
                Navigator.pop(ctx, entered.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (category) setState(() => _categoryMenuVersion++);
    if (result == null) return;
    final candidates = category
        ? [...ServiceCategories.categoryNames, ..._customCategories]
        : _templates;
    final name =
        candidates
            .where((n) => normalizeCredential(n) == normalizeCredential(result))
            .firstOrNull ??
        result;
    setState(() {
      if (category) {
        if (!ServiceCategories.categoryNames.contains(name)) {
          _customCategories.add(name);
        }
        _category = name;
        _title.clear();
        _customServices.clear();
      } else {
        if (!_templates.contains(name)) _customServices.add(name);
        _title.text = name;
      }
    });
  }

  Widget _certificateField() {
    final certs =
        _profile?.certificationHistory.where((c) => c.id.isNotEmpty).toList() ??
        <ProviderCertificationEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('credential-$_certificateId-${certs.length}'),
          initialValue: certs.any((c) => c.id == _certificateId)
              ? _certificateId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Certificate for this service *',
          ),
          items: [
            for (final c in certs)
              DropdownMenuItem(
                value: c.id,
                child: Text(
                  '${c.name} (${c.provider}) · ${c.status.firestoreValue}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _loadingCertificates
              ? null
              : (v) => setState(() => _certificateId = v),
        ),
        if (_loadingCertificates) const LinearProgressIndicator(),
        if (_credentialError != null)
          TextButton(
            onPressed: _loadCertificates,
            child: Text(_credentialError!),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Submit a certificate for verification'),
            onPressed: () async {
              final saved = await ProviderCertificationDialog.open(
                context,
                providerId: widget.appUser.userId,
              );
              if (saved == true && mounted) await _loadCertificates();
            },
          ),
        ),
        const Text(
          'TESDA NC or an accepted equivalent. New categories, custom services and credential alignment require administrator approval.',
        ),
      ],
    );
  }

  Future<void> _showListingNotice(String title, String message) =>
      _listingDialog<void>(
        context: context,
        builder: (ctx) => AppNotificationDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep editing'),
            ),
          ],
        ),
      );

  Future<T?> _listingDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    // No request is running while the provider reads guidance or uploads a certificate.
    setState(() => _saving = false);
    return showDialog<T>(context: context, builder: builder);
  }

  Future<void> _showCertificateHelp(
    ServiceCertificateStatus status,
    String category,
    String title,
  ) async {
    final family = approvedServiceFamily(category, title);
    final qualifications =
        approvedQualifications[family] ??
        <String>['a relevant TESDA NC or accepted equivalent credential'];
    final (heading, guidance) = switch (status) {
      ServiceCertificateStatus.pending => (
        'Certificate awaiting review',
        'Your matching certificate is pending System Administrator review. You will receive a status notification. Submit this listing after approval; you can save it as a draft while waiting.',
      ),
      ServiceCertificateStatus.rejected => (
        'Certificate rejected',
        'Your matching certificate was rejected. Check the administrator’s reason in your profile, then upload a corrected certificate for review.',
      ),
      ServiceCertificateStatus.expired => (
        'Certificate expired',
        'Your matching certificate has expired. Upload a renewed certificate and wait for System Administrator approval before submitting this listing.',
      ),
      ServiceCertificateStatus.needsReview => (
        'Certificate needs authentication',
        'Your matching certificate does not have a complete, current approval record. Ask the System Administrator to review it before submitting this listing.',
      ),
      _ => (
        'Matching certificate required',
        'Upload a matching TESDA certificate for System Administrator authentication before submitting this listing. Certificates for other trades do not qualify for this service.',
      ),
    };
    final canUpload =
        status == ServiceCertificateStatus.missing ||
        status == ServiceCertificateStatus.rejected ||
        status == ServiceCertificateStatus.expired;
    final upload = await _listingDialog<bool>(
      context: context,
      builder: (ctx) => AppNotificationDialog(
        title: Text(heading),
        content: Text(
          '$title requires ${qualifications.join(' or ')}.\n\n$guidance\n\nYour listing details will stay here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          if (canUpload)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Upload certificate'),
            ),
        ],
      ),
    );
    if (upload != true || !mounted) return;
    final saved = await ProviderCertificationDialog.open(
      context,
      providerId: widget.appUser.userId,
      initialQualification: qualifications.firstOrNull,
    );
    if (saved == true && mounted) {
      await _loadCertificates();
      if (!mounted) return;
      await _showListingNotice(
        'Certificate submitted',
        'Your certificate is pending System Administrator review. Uploading it does not publish your listing. You will receive a status notification; submit your listing after approval. Your listing details are still here.',
      );
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _close() => Navigator.pop(context, false);

  String get _previewPrice {
    final n = double.tryParse(_price.text.trim());
    if (n == null || !n.isFinite || n <= 0 || n > 10000000) return '₱---';
    final pt = _priceType.toLowerCase();
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
                  widget.isEditing ? 'Edit service' : 'Add your service',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.gray900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'List a certified service so customers can message you and send a booking request.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: FigmaColors.gray600,
                    height: 1.4,
                  ),
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
      key: ValueKey('$_category-$_categoryMenuVersion'),
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
                for (final name in _customCategories)
                  DropdownMenuEntry<String>(value: name, label: name),
                const DropdownMenuEntry<String>(
                  value: '__add_category__',
                  label: 'Add Category',
                  leadingIcon: Icon(Icons.add),
                ),
              ],
              onSelected: (value) {
                if (value == '__add_category__') {
                  _addCustomName(category: true);
                  return;
                }
                field.didChange(value);
                setState(() {
                  _category = value;
                  _title.clear();
                  _customServices.clear();
                  _certificateId = null;
                });
              },
              menuStyle: MenuStyle(
                alignment: Alignment.bottomLeft,
                maximumSize: WidgetStatePropertyAll(
                  Size(constraints.maxWidth, 320),
                ),
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
        if (_category != null) ...[
          const SizedBox(height: 20),
          Text(
            'Choose a TESDA-aligned service',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FigmaColors.gray800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the work you offer. A matching TESDA NC or accepted equivalent credential approved by the System Administrator is required before submitting your listing.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: FigmaColors.gray500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in templates)
                _CatalogChip(label: name, onTap: () => _applyTemplate(name)),
              _CatalogChip(
                label: '+ Add Service',
                onTap: () => _addCustomName(category: false),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Upload service photos (at least 3)',
          key: _photoSectionKey,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: FigmaColors.gray800,
          ),
        ),
        const SizedBox(height: 10),
        _PhotoStrip(
          imageUrls: _imageUrls,
          localImages: _localImages,
          onAdd: _pickPhotos,
          onRemoveUrl: (url) => setState(() => _imageUrls.remove(url)),
          onRemoveLocal: (i) => setState(() => _localImages.removeAt(i)),
        ),
        if (_photoError != null)
          Text(_photoError!, style: const TextStyle(color: Colors.red)),
        Text(
          '${_imageUrls.length + _localImages.length}/6 photos. JPG, PNG or WebP, up to 5 MB each. Remove a photo and add its replacement.',
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Service title *',
            hintText: 'Choose a service above or enter a custom service name',
          ),
          maxLength: 140,
          validator: (v) => (v?.trim().length ?? 0) < 3
              ? 'Enter a service title with at least 3 characters'
              : null,
        ),
        if (isSupportedService(_category ?? '', _title.text.trim())) ...[
          const SizedBox(height: 8),
          Text(
            certificationRequirementMessage(
              category: _category!,
              serviceTitle: _title.text.trim(),
            ),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: FigmaColors.gray600,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _certificateField(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _description,
          maxLines: 5,
          maxLength: _maxDescription,
          decoration: const InputDecoration(
            labelText: 'Description *',
            hintText:
                'Describe what you offer, what is included, and any requirements…',
            alignLabelWithHint: true,
            counterText: '',
          ),
          validator: (v) => v == null || v.trim().length < 10
              ? 'Add at least 10 characters'
              : null,
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
                  if (n == null || !n.isFinite || n <= 0 || n > 10000000) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                // ignore: deprecated_member_use
                value: _priceType,
                decoration: const InputDecoration(
                  labelText: 'Indicative basis',
                ),
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
          isExpanded: true,
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
            title: Text(
              'Listing visible',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Visibility updates immediately. Changes to listing details require a new approval.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: FigmaColors.gray500,
              ),
            ),
            value: _isActive,
            activeTrackColor: FigmaColors.tintBlue,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? FigmaColors.navy
                  : null,
            ),
            onChanged: _saving ? null : _setVisibility,
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
    final title = _title.text.trim().isEmpty
        ? 'Service title'
        : _title.text.trim();
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
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: FigmaColors.gray900,
          ),
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
                          ? Image.memory(
                              _localImages.first.bytes,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: FigmaColors.gray100,
                              child: const Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: FigmaColors.gray300,
                              ),
                            )),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
                        Flexible(
                          child: Text(
                            category,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: FigmaColors.gray600,
                            ),
                          ),
                        ),
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
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: FigmaColors.gray500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _duration ?? '1–2 hours',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: FigmaColors.gray600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      desc,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: FigmaColors.gray600,
                        height: 1.4,
                      ),
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
                  const Icon(
                    Icons.lightbulb_outline,
                    color: FigmaColors.orange600,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tips for a great listing',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                      const Icon(
                        Icons.check_circle,
                        color: FigmaColors.navy,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: FigmaColors.gray700,
                            height: 1.35,
                          ),
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
          const publishLabel = 'Submit for approval';

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
                _footerFilled(
                  publishLabel,
                  _saving ? null : () => _save(publish: true),
                ),
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

  Widget _footerOutlined(
    String label,
    VoidCallback? onPressed, {
    Color? textColor,
  }) {
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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FigmaColors.white,
              ),
            )
          : Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
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
      _AddPhotoSlot(
        onTap: onAdd,
        isPrimary: imageUrls.isEmpty && localImages.isEmpty,
      ),
      for (final url in imageUrls)
        _UrlPhotoSlot(url: url, onRemove: () => onRemoveUrl(url)),
      for (var i = 0; i < localImages.length; i++)
        _MemoryPhotoSlot(
          bytes: localImages[i].bytes,
          onRemove: () => onRemoveLocal(i),
        ),
      if (imageUrls.isNotEmpty || localImages.isNotEmpty)
        _AddMoreSlot(onTap: onAdd),
    ];

    return SizedBox(
      height:
          _slot *
          (MediaQuery.textScalerOf(context).scale(11) / 11).clamp(1.0, 1.75),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.gray800,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'JPG, PNG, WebP up to 5MB',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: FigmaColors.gray500,
                  ),
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
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: FigmaColors.gray500,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  'Add more',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: FigmaColors.gray700,
              height: 1.4,
            ),
          ),
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
            requiresCert
                ? Icons.workspace_premium_outlined
                : Icons.check_circle_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              requiresCert
                  ? 'Certificate required — System Administrator must authenticate a credential on your profile before you can publish this listing. Admin still reviews the listing after that.'
                  : 'No certificate required for this service — you can publish after identity verification. Admin reviews the listing as usual.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: FigmaColors.gray700,
                height: 1.4,
              ),
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
    return Tooltip(
      message: 'Remove photo',
      child: Material(
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
      ),
    );
  }
}
