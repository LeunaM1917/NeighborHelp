import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/role_theme.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/app_scroll_chrome.dart';

/// Customer profile settings (dialog on web, full screen on native).
class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({
    super.key,
    required this.appUser,
    this.inDialog = false,
  });

  final AppUser appUser;
  final bool inDialog;

  static Future<bool?> open(BuildContext context, {required AppUser appUser}) {
    if (MobileLayout.useMobileChrome(context)) {
      return Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _customerThemed(
            CustomerSettingsScreen(appUser: appUser),
          ),
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierColor: Colors.black54,
      builder: (ctx) => _customerThemed(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 920),
            child: Material(
              color: FigmaColors.gray50,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: CustomerSettingsScreen(appUser: appUser, inDialog: true),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

Widget _customerThemed(Widget child) {
  return RoleThemeScope(palette: RoleTheme.customer, child: child);
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _bio;
  late final TextEditingController _email;

  static const _maxBioLength = 300;
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
    _address = TextEditingController(text: widget.appUser.address ?? '');
    _bio = TextEditingController(text: widget.appUser.bio ?? '');
    _email = TextEditingController(text: widget.appUser.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _bio.dispose();
    _email.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final address = _address.text.trim();
      final bio = _bio.text.trim();
      await FirestoreService().updateUserProfile(
        userId: widget.appUser.userId,
        data: {
          'fullName': _name.text.trim(),
          'contactNumber': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'address': address.isEmpty ? null : address,
          'bio': bio.isEmpty ? null : bio,
        },
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: false).pop(true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Customer settings save failed: $e\n$st');
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
    final verified = widget.appUser.isVerifiedCustomer;

    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.inDialog)
            AppPageHeader(
              title: 'Profile settings',
              subtitle: 'Update your account information',
              onBack: () => Navigator.pop(context),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context, rootNavigator: false).pop(),
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
                          'Update your account information',
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _profileSummaryCard(rc, verified: verified),
          const SizedBox(height: 20),
          _field(
            label: 'Full name',
            helper: 'This is the name displayed on your account.',
            field: TextFormField(
              controller: _name,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
              decoration: _inputDecoration(context, prefixIcon: Icons.person_outline),
            ),
          ),
          const SizedBox(height: 18),
          _field(
            label: 'Phone number',
            helper: 'We\'ll use this to contact you about your account.',
            field: TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(context, prefixIcon: Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 18),
          _field(
            label: 'Address',
            helper: 'Used for service deliveries and local matching.',
            field: TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: _inputDecoration(
                context,
                prefixIcon: Icons.place_outlined,
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _field(
            label: 'Bio',
            helper: 'A short introduction providers can read on your profile.',
            field: TextFormField(
              controller: _bio,
              maxLines: 4,
              maxLength: _maxBioLength,
              decoration: _inputDecoration(
                context,
                prefixIcon: Icons.notes_outlined,
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _field(
            label: 'Email address',
            helper: 'Email cannot be changed.',
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
          const SizedBox(height: 20),
          _privacyCard(rc),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context, rootNavigator: false).pop(),
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

    return _customerThemed(
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

  Widget _profileSummaryCard(RolePalette rc, {required bool verified}) {
    final initials = widget.appUser.fullName.isNotEmpty
        ? widget.appUser.fullName.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase()
        : 'C';

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
                      decoration: BoxDecoration(color: rc.primary, shape: BoxShape.circle),
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
                    : Icon(Icons.photo_camera_outlined, size: 16, color: rc.primary),
                label: Text(
                  'Change photo',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: rc.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: rc.primary),
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
                  widget.appUser.fullName.isNotEmpty ? widget.appUser.fullName : 'Your account',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('Customer account', style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
                if (verified) ...[
                  const SizedBox(height: 10),
                  _badge('Verified', FigmaColors.tintGreen, FigmaColors.green, Icons.verified),
                ],
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

  Widget _privacyCard(RolePalette rc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: rc.tint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: rc.tint, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.shield_outlined, color: rc.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'Your privacy & security',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 8),
          Text(
            'We keep your information safe and only use it to improve your NeighborHelp experience.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.5),
          ),
          const SizedBox(height: 18),
          _privacyPoint(Icons.lock_outline, 'Your data is encrypted and securely stored.'),
          const SizedBox(height: 14),
          _privacyPoint(Icons.visibility_off_outlined, 'We never share your info with third parties.'),
          const SizedBox(height: 14),
          _privacyPoint(Icons.account_circle_outlined, 'You\'re in control of your account settings.'),
        ],
      ),
    );
  }

  Widget _privacyPoint(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: FigmaColors.gray500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600, height: 1.45)),
        ),
      ],
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
