import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../models/app_user.dart';
import '../../models/provider.dart';
import '../../models/provider_profile_traits.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/app_scroll_chrome.dart';

/// Overview / profile settings popup (provider account + bio + traits).
class ProviderOverviewSettingsScreen extends StatefulWidget {
  const ProviderOverviewSettingsScreen({
    super.key,
    required this.appUser,
    required this.profile,
    this.inDialog = false,
  });

  final AppUser appUser;
  final ServiceProviderProfile profile;
  final bool inDialog;

  static Future<bool?> open(
    BuildContext context, {
    required AppUser appUser,
    required ServiceProviderProfile profile,
  }) {
    if (MobileLayout.useMobileChrome(context)) {
      return Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => providerThemed(
            ProviderOverviewSettingsScreen(appUser: appUser, profile: profile),
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 920),
            child: Material(
              color: FigmaColors.gray50,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: ProviderOverviewSettingsScreen(
                appUser: appUser,
                profile: profile,
                inDialog: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<ProviderOverviewSettingsScreen> createState() => _ProviderOverviewSettingsScreenState();
}

class _ProviderOverviewSettingsScreenState extends State<ProviderOverviewSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _bio;
  late double _radiusKm;
  late Set<String> _selectedTraits;
  String? _photoUrl;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.appUser.profilePhotoUrl;
    _name = TextEditingController(text: widget.appUser.fullName);
    _phone = TextEditingController(
      text: widget.appUser.contactNumber?.trim().isNotEmpty == true
          ? widget.appUser.contactNumber!
          : '',
    );
    _email = TextEditingController(text: widget.appUser.email);
    final addr = widget.appUser.address?.trim().isNotEmpty == true
        ? widget.appUser.address!
        : widget.profile.serviceArea;
    _address = TextEditingController(text: addr);
    _bio = TextEditingController(text: widget.profile.bio);
    _bio.addListener(() => setState(() {}));
    _radiusKm = widget.profile.serviceRadiusKm > 0 ? widget.profile.serviceRadiusKm : 20;
    _selectedTraits = ProviderProfileTraits.normalize(widget.profile.profileTraits).toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await StorageService().uploadProfilePhotoBytes(
        userId: widget.appUser.userId,
        bytes: bytes,
      );
      await FirestoreService().updateUserProfile(
        userId: widget.appUser.userId,
        data: {'profilePhotoUrl': url},
      );
      if (!mounted) return;
      setState(() => _photoUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update photo. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _toggleTrait(String label) {
    setState(() {
      if (_selectedTraits.contains(label)) {
        _selectedTraits.remove(label);
      } else {
        _selectedTraits.add(label);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final address = _address.text.trim();
      final traits = ProviderProfileTraits.normalize(_selectedTraits.toList());
      await FirestoreService().updateUserProfile(
        userId: widget.appUser.userId,
        data: {
          'fullName': _name.text.trim(),
          'contactNumber': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'address': address.isEmpty ? null : address,
        },
      );
      await FirestoreService().updateServiceProvider(
        providerId: widget.appUser.userId,
        data: {
          'bio': _bio.text.trim(),
          'serviceArea': address,
          'serviceRadiusKm': _radiusKm,
          'profileTraits': traits,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Overview settings save failed: $e\n$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kDebugMode
                  ? 'Could not save settings: $e'
                  : 'Could not save settings. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final verified = widget.profile.isVerifiedProvider;
    final approved = widget.profile.verificationStatus.toLowerCase() == 'approved' || verified;

    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.inDialog)
            AppPageHeader(
              title: 'Profile settings',
              subtitle: 'Update your provider account information',
              onBack: () => Navigator.pop(context),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile settings',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Update your provider account information',
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _profileSummaryCard(context, rc, approved: approved, verified: verified),
          const SizedBox(height: 20),
          _field(
            label: 'Full name',
            helper: 'This is the name that will be shown to your clients.',
            field: TextFormField(
              controller: _name,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
              decoration: _inputDecoration(context, prefixIcon: Icons.person_outline),
            ),
          ),
          const SizedBox(height: 18),
          _field(
            label: 'Phone number',
            helper: 'We may use this to contact you about job requests.',
            field: TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(context, prefixIcon: Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 18),
          _field(
            label: 'Email address',
            helper: 'Your email address is used for login and important notifications.',
            field: TextFormField(
              controller: _email,
              enabled: false,
              decoration: _inputDecoration(
                context,
                prefixIcon: Icons.mail_outline,
                filled: true,
                fillColor: FigmaColors.gray50,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _field(
            label: 'Address / City',
            helper: 'This helps clients in your area find and trust you.',
            field: TextFormField(
              controller: _address,
              decoration: _inputDecoration(context, prefixIcon: Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 18),
          _serviceRadiusField(rc),
          const SizedBox(height: 18),
          _field(
            label: 'Bio / About me',
            helper: 'Tell clients about yourself and the services you provide.',
            field: TextFormField(
              controller: _bio,
              maxLines: 4,
              maxLength: ProviderProfileTraits.maxBioLength,
              decoration: _inputDecoration(
                context,
                prefixIcon: Icons.edit_outlined,
                alignLabelWithHint: true,
              ).copyWith(
                counterText: '${_bio.text.length} / ${ProviderProfileTraits.maxBioLength}',
              ),
            ),
          ),
          const SizedBox(height: 18),
          _traitsSection(context, rc),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: rc.primary,
                    foregroundColor: rc.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
                        )
                      : Text('Save changes', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.inDialog) {
      return AppScrollChrome(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: body,
        ),
      );
    }

    return providerThemed(
      Scaffold(
        backgroundColor: FigmaColors.gray50,
        body: SafeArea(
          child: AppScrollChrome(
            child: SingleChildScrollView(
              child: FigmaWideContainer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileSummaryCard(
    BuildContext context,
    RolePalette rc, {
    required bool approved,
    required bool verified,
  }) {
    final initials = widget.appUser.fullName.isNotEmpty
        ? widget.appUser.fullName.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase()
        : 'P';

    return AppSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: rc.tint,
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
                        ? Text(
                            initials,
                            style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: rc.primary),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: FigmaColors.navy, shape: BoxShape.circle),
                      child: const Icon(Icons.photo_camera_outlined, size: 14, color: FigmaColors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _uploadingPhoto ? null : _pickPhoto,
                icon: _uploadingPhoto
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_outlined, size: 16, color: FigmaColors.navy),
                label: Text(
                  'Change photo',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.navy),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FigmaColors.navy),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appUser.fullName.isNotEmpty ? widget.appUser.fullName : 'Service provider',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('Service Provider', style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (approved) _badge('Approved', FigmaColors.tintBlue, FigmaColors.navy, Icons.check_circle),
                    if (verified) _badge('Verified', FigmaColors.tintBlue, FigmaColors.navy, Icons.verified),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _traitsSection(BuildContext context, RolePalette rc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Work style',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose traits that describe how you work with clients. These appear on your overview.',
          style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in ProviderProfileTraits.options)
              FilterChip(
                label: Text(opt.label),
                selected: _selectedTraits.contains(opt.label),
                onSelected: (_) => _toggleTrait(opt.label),
                showCheckmark: true,
                selectedColor: opt.background,
                checkmarkColor: opt.foreground,
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _selectedTraits.contains(opt.label) ? opt.foreground : FigmaColors.gray700,
                ),
                side: BorderSide(
                  color: _selectedTraits.contains(opt.label) ? opt.foreground.withValues(alpha: 0.4) : FigmaColors.gray300,
                ),
                backgroundColor: _selectedTraits.contains(opt.label) ? opt.background : FigmaColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              ),
          ],
        ),
      ],
    );
  }

  Widget _serviceRadiusField(RolePalette rc) {
    return _field(
      label: 'Service radius',
      helper: 'How far you are willing to travel for on-site jobs.',
      field: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FigmaColors.gray300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.my_location_outlined, size: 20, color: rc.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_radiusKm.toStringAsFixed(0)} km',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
                  ),
                  Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: rc.primary,
                    inactiveColor: rc.primary.withValues(alpha: 0.2),
                    thumbColor: rc.primary,
                    label: '${_radiusKm.toStringAsFixed(0)} km',
                    onChanged: (v) => setState(() => _radiusKm = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({required String label, required String helper, required Widget field}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
        const SizedBox(height: 8),
        field,
        const SizedBox(height: 6),
        Text(helper, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.35)),
      ],
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    IconData? prefixIcon,
    bool filled = false,
    Color? fillColor,
    bool alignLabelWithHint = false,
  }) {
    final rc = context.roleColors;
    return InputDecoration(
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: rc.primary) : null,
      filled: filled,
      fillColor: fillColor,
      alignLabelWithHint: alignLabelWithHint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: FigmaColors.gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: rc.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
