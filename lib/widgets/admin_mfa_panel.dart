import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AdminMfaPanel extends StatefulWidget {
  const AdminMfaPanel({super.key});
  @override
  State<AdminMfaPanel> createState() => _AdminMfaPanelState();
}

class _AdminMfaPanelState extends State<AdminMfaPanel> {
  late Future<List<MultiFactorInfo>> _factors;
  @override
  void initState() {
    super.initState();
    _factors = FirebaseAuth.instance.currentUser!.multiFactor
        .getEnrolledFactors();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<MultiFactorInfo>>(
        future: _factors,
        builder: (context, snap) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Two-step administrator sign-in',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (snap.hasError)
              const Text(
                'Could not check two-step sign-in. Sign in again or contact your Firebase administrator.',
              ),
            if (snap.hasData)
              Text(
                snap.data!.isEmpty
                    ? 'No second factor is enrolled for this account.'
                    : 'A second factor is enrolled. Sign out and sign in again to use it. Keep an approved recovery process in case you lose access.',
              ),
            const Text(
              'Phone enrollment requires your Firebase administrator to configure Identity Platform and SMS multi-factor authentication. SMS may incur provider charges. Enrollment does not enable the platform-wide admin policy by itself.',
            ),
            if (snap.hasData && snap.data!.isEmpty)
              OutlinedButton(
                onPressed: () async {
                  final enrolled = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const _EnrollMfaDialog(),
                  );
                  if (enrolled == true && mounted) {
                    await AuthService().signOut();
                  }
                },
                child: const Text('Enroll a phone second factor'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _EnrollMfaDialog extends StatefulWidget {
  const _EnrollMfaDialog();
  @override
  State<_EnrollMfaDialog> createState() => _EnrollMfaDialogState();
}

class _EnrollMfaDialogState extends State<_EnrollMfaDialog> {
  final _phone = TextEditingController(), _code = TextEditingController();
  bool _consent = false, _busy = false, _finishing = false;
  String? _id, _error;
  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _finish(PhoneAuthCredential credential) async {
    if (_finishing) return;
    _finishing = true;
    try {
      await FirebaseAuth.instance.currentUser!.multiFactor.enroll(
        PhoneMultiFactorGenerator.getAssertion(credential),
        displayName: 'Administrator phone factor',
      );
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == 'requires-recent-login'
              ? 'Sign out and sign in again before enrolling.'
              : 'Enrollment failed. Check the code and Firebase setup, then retry.',
        );
      }
    } finally {
      _finishing = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_id != null) {
      await _finish(
        PhoneAuthProvider.credential(
          verificationId: _id!,
          smsCode: _code.text.trim(),
        ),
      );
      return;
    }
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_phone.text.trim())) {
      setState(() {
        _busy = false;
        _error = 'Enter a full international phone number, such as +63…';
      });
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser!,
          session = await user.multiFactor.getSession();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        multiFactorSession: session,
        verificationCompleted: _finish,
        verificationFailed: (e) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error =
                  'Could not send a code. Check your account, provider setup and SMS limits.';
            });
          }
        },
        codeSent: (id, token) {
          if (mounted) {
            setState(() {
              _id = id;
              _busy = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (id) {
          if (mounted) {
            setState(() {
              _id = id;
              _busy = false;
            });
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.code == 'requires-recent-login'
              ? 'Sign out and sign in again before enrolling.'
              : 'Two-step enrollment is unavailable. Contact your Firebase administrator.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enroll phone verification'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Google uses the submitted phone number for verification and abuse prevention. Continue only if you agree to send this number to Firebase for two-step sign-in.',
            ),
            TextField(
              controller: _phone,
              enabled: _id == null && !_busy,
              keyboardType: TextInputType.phone,
              maxLength: 16,
              decoration: const InputDecoration(
                labelText: 'International phone number',
              ),
            ),
            CheckboxListTile(
              value: _consent,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _consent = value ?? false),
              title: const Text(
                'I agree to phone verification for this account.',
              ),
            ),
            if (_id != null)
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                ),
              ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: _busy || !_consent ? null : _submit,
        child: Text(_id == null ? 'Send code' : 'Enroll and sign out'),
      ),
    ],
  );
}
