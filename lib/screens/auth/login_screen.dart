import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/google_oauth.dart';
import '../../services/auth_service.dart';
import '../../theme/provider_tokens.dart';
import '../../figma_ui/pages/figma_signup_landing_page.dart';
import '../../widgets/marketplace_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final username = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final adminSignedIn = await _auth.signInAsLocalAdmin(
        username: username,
        password: _password.text,
      );
      if (!adminSignedIn) {
        await _auth.signIn(email: username, password: _password.text);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.messageForUser(e));
    } catch (e) {
      setState(() => _error = AuthService.messageForUser(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your account email and we\'ll send you a link to reset your password.',
                  style: GoogleFonts.inter(fontSize: 13, color: ProviderTokens.inkSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Enter your email';
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
              child: const Text('Send link'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (email == null) return;

    try {
      await _auth.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthService.messageForUser(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthService.messageForUser(e));
    }
  }

  Future<void> _signInWithGoogle() async {
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
      await _auth.signInWithGoogle();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'aborted-by-user') {
        setState(() => _error = AuthService.messageForUser(e));
      }
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = AuthService.messageForUser(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: MarketplacePanel(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandLockup(
                subtitle: 'Hire local service providers for home, errands, and personal services — simple, trusted, and neighborhood-first.',
              ),
              const SizedBox(height: 28),
              Text(
                'Log in',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ProviderTokens.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome back. Use your email and password to continue.',
                style: GoogleFonts.inter(fontSize: 14, color: ProviderTokens.inkSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email or username'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter your email or username';
                  if (value.toLowerCase() == 'admin') return null;
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: ProviderTokens.inkSecondary,
                    ),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password';
                  if (v.length < 8) return 'At least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: ProviderTokens.green,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
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
                    : const Text('Log in'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider(color: ProviderTokens.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: GoogleFonts.inter(fontSize: 13, color: ProviderTokens.inkSecondary)),
                  ),
                  const Expanded(child: Divider(color: ProviderTokens.border)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _signInWithGoogle,
                  icon: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('G', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  label: Text('Continue with Google', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProviderTokens.ink,
                    side: const BorderSide(color: ProviderTokens.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New to NeighborHelp? ', style: GoogleFonts.inter(color: ProviderTokens.inkSecondary, fontSize: 14)),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(builder: (_) => const FigmaSignUpLandingPage()),
                      );
                    },
                    child: const Text('Sign up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
