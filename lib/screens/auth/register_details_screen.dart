import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/google_oauth.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_tokens.dart';
import '../../widgets/marketplace_ui.dart';
import 'login_screen.dart';

/// Sign-up form (email + password) for hiring or offering services.
class RegisterDetailsScreen extends StatefulWidget {
  const RegisterDetailsScreen({super.key, required this.selectedRole});

  final UserRole selectedRole;

  @override
  State<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
}

class _RegisterDetailsScreenState extends State<RegisterDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();

  bool _obscure = true;
  bool _busy = false;
  bool _marketing = true;
  bool _terms = false;
  String? _error;

  static const _countries = [
    'Philippines',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Singapore',
    'Other',
  ];

  String _country = 'Philippines';
  late UserRole _role;

  late final TapGestureRecognizer _tosTap;
  late final TapGestureRecognizer _userAgreementTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _role = widget.selectedRole;
    _tosTap = TapGestureRecognizer()..onTap = _openTermsOfService;
    _userAgreementTap = TapGestureRecognizer()..onTap = _openUserAgreement;
    _privacyTap = TapGestureRecognizer()..onTap = _openPrivacyPolicy;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _password.dispose();
    _tosTap.dispose();
    _userAgreementTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_terms) {
      setState(() => _error = 'Please agree to the Terms of Service and Privacy Policy.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final fullName = '${_first.text.trim()} ${_last.text.trim()}'.trim();
    try {
      await _auth.register(
        email: _email.text.trim(),
        password: _password.text,
        fullName: fullName,
        role: _role,
        country: _country,
        marketingOptIn: _marketing,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = AuthService.messageForUser(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchTo(UserRole other) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RegisterDetailsScreen(selectedRole: other),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    if (!_terms) {
      setState(() => _error = 'Please agree to the Terms of Service and Privacy Policy.');
      return;
    }
    if (!isGoogleOAuthConfigured) {
      setState(
        () => _error = 'Add your Web client ID in lib/config/google_oauth.dart '
            '(Firebase → Authentication → Google → Web client ID).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle(registrationRole: _role);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'aborted-by-user') {
        if (mounted) setState(() => _error = null);
      } else if (mounted) {
        setState(() => _error = AuthService.messageForUser(e));
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.messageForUser(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  TextStyle get _legalLinkStyle => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ProviderTokens.green,
        decoration: TextDecoration.underline,
        decorationColor: ProviderTokens.green,
      );

  Future<void> _showLegalDialog(String title, List<List<String>> sections) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.8;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ProviderTokens.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: ProviderTokens.inkSecondary,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: ProviderTokens.border),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last updated: May 30, 2026',
                          style: GoogleFonts.inter(fontSize: 12, color: ProviderTokens.inkSecondary),
                        ),
                        const SizedBox(height: 16),
                        for (final section in sections) _legalSection(section[0], section[1]),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: ProviderTokens.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legalSection(String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ProviderTokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(fontSize: 13, color: ProviderTokens.inkSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _openTermsOfService() {
    _showLegalDialog('NeighborHelp Terms of Service', const [
      [
        '1. Agreement to these terms',
        'These Terms of Service ("Terms") govern your access to and use of the NeighborHelp '
            'platform, including our website and mobile applications (the "Service"). By creating '
            'an account or using the Service, you agree to be bound by these Terms. If you do not '
            'agree, you must not use the Service.',
      ],
      [
        '2. What NeighborHelp is',
        'NeighborHelp is an online marketplace that connects customers who need local help with '
            'independent service providers who offer home services, errands, tutoring, and similar '
            'tasks. NeighborHelp is not the employer of any service provider and is not a party to '
            'the actual service performed between a customer and a provider.',
      ],
      [
        '3. Eligibility and accounts',
        'You must be at least 18 years old and able to form a binding contract to use NeighborHelp. '
            'You agree to provide accurate information, keep your password secure, and remain '
            'responsible for all activity under your account. Service providers may be required to '
            'complete identity verification before being listed.',
      ],
      [
        '4. Bookings and payments',
        'Customers may request bookings from providers through the Service. Prices, availability, '
            'and the scope of work are set between the customer and the provider. You agree to pay '
            'all fees for services you book, including any applicable platform or processing fees '
            'shown to you before you confirm.',
      ],
      [
        '5. Provider responsibilities',
        'Service providers are independent contractors. As a provider, you are solely responsible '
            'for the quality, safety, and legality of the services you offer, for holding any '
            'licenses or permits required by law, and for honoring the commitments you make to '
            'customers through the Service.',
      ],
      [
        '6. Conduct and prohibited activity',
        'You agree not to misuse the Service, including by posting false information, harassing '
            'other users, circumventing fees, attempting to access accounts that are not yours, or '
            'using the Service for any unlawful purpose. We may suspend or terminate accounts that '
            'violate these Terms.',
      ],
      [
        '7. Reviews and content',
        'You may submit reviews, messages, and other content. You are responsible for the content '
            'you post and grant NeighborHelp a license to host and display it for the operation of '
            'the Service. Reviews must reflect genuine experiences and must not be fraudulent or '
            'misleading.',
      ],
      [
        '8. Disclaimers and limitation of liability',
        'The Service is provided "as is" without warranties of any kind. To the maximum extent '
            'permitted by law, NeighborHelp is not liable for the acts or omissions of any customer '
            'or provider, or for any indirect, incidental, or consequential damages arising from '
            'your use of the Service.',
      ],
      [
        '9. Changes to these terms',
        'We may update these Terms from time to time. If we make material changes, we will notify '
            'you through the Service or by email. Your continued use of NeighborHelp after the '
            'changes take effect means you accept the updated Terms.',
      ],
      [
        '10. Contact us',
        'If you have questions about these Terms, please contact us at support@neighborhelp.com.',
      ],
    ]);
  }

  void _openUserAgreement() {
    _showLegalDialog('NeighborHelp User Agreement', const [
      [
        '1. Your relationship with NeighborHelp',
        'This User Agreement explains the rules that apply to everyone who uses NeighborHelp, '
            'whether as a customer or as a service provider. It works together with our Terms of '
            'Service and Privacy Policy.',
      ],
      [
        '2. Acting honestly and respectfully',
        'You agree to communicate respectfully, to show up for confirmed bookings, and to deal '
            'with other members in good faith. Customers should provide clear and safe working '
            'conditions; providers should arrive prepared and complete work as agreed.',
      ],
      [
        '3. Keeping transactions on the platform',
        'To protect both sides, payments and communication for a booking should stay within '
            'NeighborHelp. Taking transactions off-platform removes protections such as records, '
            'support, and dispute handling, and may breach this Agreement.',
      ],
      [
        '4. Cancellations and no-shows',
        'If you need to cancel, do so as early as possible. Repeated late cancellations or '
            'no-shows may affect your account standing, your visibility in search, or your ability '
            'to book or be booked.',
      ],
      [
        '5. Safety and verification',
        'Service providers may be asked to verify their identity through our verification partner '
            'before being listed. Identity verification helps build trust but does not guarantee '
            'the conduct of any member. Always use your own judgment and report concerns.',
      ],
      [
        '6. Disputes between members',
        'Customers and providers should first try to resolve disputes directly. If that fails, '
            'NeighborHelp may, at its discretion, help mediate, but we are not obligated to resolve '
            'disputes and are not responsible for the outcome of any service.',
      ],
      [
        '7. Suspension and termination',
        'We may limit, suspend, or close your account if you violate this Agreement or the Terms '
            'of Service, create risk for other members, or use the Service in a way that harms '
            'NeighborHelp. You may close your account at any time.',
      ],
      [
        '8. Updates to this Agreement',
        'We may revise this User Agreement as the Service evolves. We will let you know about '
            'significant changes, and continued use means you accept the updated Agreement.',
      ],
    ]);
  }

  void _openPrivacyPolicy() {
    _showLegalDialog('NeighborHelp Privacy Policy', const [
      [
        '1. Information we collect',
        'We collect information you provide when you create an account (such as your name, email, '
            'contact number, and country), information about bookings and messages, reviews you '
            'submit, and, for service providers, identity verification data processed by our '
            'verification partner.',
      ],
      [
        '2. How we use your information',
        'We use your information to operate the Service, match customers with providers, process '
            'bookings, enable messaging, prevent fraud, verify provider identities, provide support, '
            'and—where you have opted in—send you product updates and offers.',
      ],
      [
        '3. Location information',
        'To show nearby providers and relevant services, we may use the service area and location '
            'details you provide. You can control device location permissions through your device '
            'settings.',
      ],
      [
        '4. Sharing your information',
        'We share limited information between customers and providers as needed to complete a '
            'booking (for example, a first name and the details of a request). We also work with '
            'service providers such as hosting, analytics, payment, and identity verification '
            'partners who process data on our behalf. We do not sell your personal information.',
      ],
      [
        '5. Identity verification',
        'When a provider verifies their identity, the verification is handled by a third-party '
            'provider. We receive the result of that check (such as approved or declined) and store '
            'a verification status on your profile. We do not store your government ID images on our '
            'own servers.',
      ],
      [
        '6. Data retention',
        'We keep your information for as long as your account is active and as needed to provide '
            'the Service, comply with our legal obligations, resolve disputes, and enforce our '
            'agreements. You may request deletion of your account and associated data.',
      ],
      [
        '7. Your choices and rights',
        'You can review and update your profile information at any time, opt out of marketing '
            'emails, and request access to or deletion of your personal data. Some information may '
            'be retained where we are required or permitted by law.',
      ],
      [
        '8. Security',
        'We use reasonable technical and organizational measures to protect your information. '
            'However, no method of transmission or storage is completely secure, and we cannot '
            'guarantee absolute security.',
      ],
      [
        '9. Changes to this policy',
        'We may update this Privacy Policy from time to time. We will notify you of material '
            'changes through the Service or by email, and the "Last updated" date above will '
            'reflect the latest revision.',
      ],
      [
        '10. Contact us',
        'For privacy questions or requests, contact us at privacy@neighborhelp.com.',
      ],
    ]);
  }

  Widget _buildRoleSwitchLink(
    BuildContext context, {
    required bool hire,
    TextAlign textAlign = TextAlign.end,
  }) {
    final subLinkLabel = hire ? 'Looking for work?' : 'Looking to hire?';
    final subLinkAction = hire ? 'Apply as service provider' : 'Sign up as customer';
    return TextButton(
      onPressed: () => _switchTo(hire ? UserRole.provider : UserRole.customer),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerRight,
      ),
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.inter(fontSize: 12, color: ProviderTokens.inkSecondary),
          children: [
            TextSpan(text: '$subLinkLabel '),
            TextSpan(
              text: subLinkAction,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ProviderTokens.green,
              ),
            ),
          ],
        ),
        textAlign: textAlign,
        softWrap: true,
      ),
    );
  }

  Widget _buildRegisterHeader(BuildContext context, {required bool hire}) {
    final stackHeader = MobileLayout.useMobileChrome(context);
    final back = IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => Navigator.of(context).maybePop(),
      color: ProviderTokens.ink,
      visualDensity: VisualDensity.compact,
    );

    if (stackHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              back,
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BrandLockup(compact: true),
                ),
              ),
            ],
          ),
          _buildRoleSwitchLink(context, hire: hire, textAlign: TextAlign.center),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        back,
        const Expanded(child: BrandLockup(compact: true)),
        Flexible(child: _buildRoleSwitchLink(context, hire: hire)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hire = _role == UserRole.customer;
    final headline = hire ? 'Sign up to hire service providers' : 'Sign up as a service provider';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRegisterHeader(context, hire: hire),
                        const SizedBox(height: 28),
                        Text(
                          headline,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: ProviderTokens.ink,
                            letterSpacing: -0.6,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _socialRow(context, onGoogle: _signInWithGoogle),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: ProviderTokens.border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: GoogleFonts.inter(fontSize: 13, color: ProviderTokens.inkSecondary),
                              ),
                            ),
                            const Expanded(child: Divider(color: ProviderTokens.border)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _first,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(labelText: 'First name'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _last,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(labelText: 'Last name'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Work email address'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter your email';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Password (8 or more characters)',
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter a password';
                            if (v.length < 8) return 'Use at least 8 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_country),
                          initialValue: _country,
                          decoration: const InputDecoration(labelText: 'Country'),
                          items: _countries
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => _country = v ?? _country),
                        ),
                        const SizedBox(height: 18),
                        _CheckboxRow(
                          value: _marketing,
                          onChanged: (v) => setState(() => _marketing = v),
                          child: Text(
                            'Send me email notifications for updates, tips, and special offers from NeighborHelp.',
                            style: GoogleFonts.inter(fontSize: 13, color: ProviderTokens.ink, height: 1.35),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _CheckboxRow(
                          value: _terms,
                          onChanged: (v) => setState(() => _terms = v),
                          child: Text.rich(
                            TextSpan(
                              style: GoogleFonts.inter(fontSize: 13, color: ProviderTokens.ink, height: 1.35),
                              children: [
                                const TextSpan(text: 'Yes, I understand and agree to the '),
                                TextSpan(
                                  text: 'NeighborHelp Terms of Service',
                                  recognizer: _tosTap,
                                  style: _legalLinkStyle,
                                ),
                                const TextSpan(text: ', including the '),
                                TextSpan(
                                  text: 'User Agreement',
                                  recognizer: _userAgreementTap,
                                  style: _legalLinkStyle,
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  recognizer: _privacyTap,
                                  style: _legalLinkStyle,
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: ProviderTokens.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ProviderTokens.danger.withValues(alpha: 0.35)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _error!,
                                style: GoogleFonts.inter(fontSize: 13, color: ProviderTokens.danger, height: 1.35),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Create my account'),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text.rich(
                            TextSpan(
                              style: GoogleFonts.inter(fontSize: 15, color: ProviderTokens.inkSecondary),
                              children: [
                                const TextSpan(text: 'Already have an account? '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).pushReplacement(
                                      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                                    ),
                                    child: Text(
                                      'Log In',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ProviderTokens.green,
                                        decoration: TextDecoration.underline,
                                        decorationColor: ProviderTokens.green,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _socialRow(BuildContext context, {required Future<void> Function() onGoogle}) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 420;
        final apple = OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Apple sign-in coming soon')),
          ),
          icon: const Icon(Icons.apple, size: 22, color: ProviderTokens.ink),
          label: Text('Continue with Apple', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, narrow ? 48 : 52),
            backgroundColor: Colors.white,
            foregroundColor: ProviderTokens.ink,
            side: const BorderSide(color: ProviderTokens.ink),
          ),
        );
        final google = FilledButton.icon(
          onPressed: _busy ? null : () => onGoogle(),
          icon: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Center(
              child: Text('G', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.blue.shade700, fontSize: 14)),
            ),
          ),
          label: Text('Continue with Google', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
          style: FilledButton.styleFrom(
            minimumSize: Size(0, narrow ? 48 : 52),
            backgroundColor: const Color(0xFF4285F4),
            foregroundColor: Colors.white,
          ),
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              apple,
              const SizedBox(height: 12),
              google,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: apple),
            const SizedBox(width: 12),
            Expanded(child: google),
          ],
        );
      },
    );
  }
}

/// A checkbox where only the box toggles the value — the [child] text is not a
/// tap target, so links inside it (e.g. Terms of Service) remain independently
/// clickable.
class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({
    required this.value,
    required this.onChanged,
    required this.child,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 32,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            activeColor: ProviderTokens.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: child,
          ),
        ),
      ],
    );
  }
}
