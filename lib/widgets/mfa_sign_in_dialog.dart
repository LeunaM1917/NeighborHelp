import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<bool> finishMfaSignIn(
  BuildContext context,
  FirebaseAuthMultiFactorException error,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MfaDialog(resolver: error.resolver),
    ) ??
    false;

class _MfaDialog extends StatefulWidget {
  const _MfaDialog({required this.resolver});
  final MultiFactorResolver resolver;
  @override
  State<_MfaDialog> createState() => _MfaDialogState();
}

class _MfaDialogState extends State<_MfaDialog> {
  final _code = TextEditingController();
  PhoneMultiFactorInfo? _factor;
  String? _verificationId, _error;
  bool _busy = false, _resolved = false, _resolving = false;
  @override
  void initState() {
    super.initState();
    _factor = widget.resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .firstOrNull;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _resolve(PhoneAuthCredential credential) async {
    if (_resolved || _resolving) return;
    _resolving = true;
    if (mounted) setState(() => _busy = true);
    try {
      await widget.resolver.resolveSignIn(
        PhoneMultiFactorGenerator.getAssertion(credential),
      );
      _resolved = true;
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException {
      if (mounted) {
        setState(
          () => _error = 'Verification failed. Check the code and retry.',
        );
      }
    } finally {
      _resolving = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_factor == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: widget.resolver.session,
        multiFactorInfo: _factor!,
        verificationCompleted: _resolve,
        verificationFailed: (e) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error =
                  'Could not send the verification code. Retry or contact your administrator.';
            });
          }
        },
        codeSent: (id, token) {
          if (mounted) {
            setState(() {
              _verificationId = id;
              _busy = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (id) {
          if (mounted) {
            setState(() {
              _verificationId = id;
              _busy = false;
            });
          }
        },
      );
    } on FirebaseAuthException {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Two-step sign-in is unavailable. Contact your administrator.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Two-step sign-in'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_factor == null)
            const Text(
              'This account has no supported phone factor. Contact your administrator for account recovery.',
            )
          else ...[
            DropdownButtonFormField<PhoneMultiFactorInfo>(
              initialValue: _factor,
              items: [
                for (final hint
                    in widget.resolver.hints.whereType<PhoneMultiFactorInfo>())
                  DropdownMenuItem(
                    value: hint,
                    child: Text(hint.displayName ?? hint.phoneNumber),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _factor = value),
            ),
            if (_verificationId != null)
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
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy || _factor == null
            ? null
            : () => _verificationId == null
                  ? _send()
                  : _resolve(
                      PhoneAuthProvider.credential(
                        verificationId: _verificationId!,
                        smsCode: _code.text.trim(),
                      ),
                    ),
        child: Text(_verificationId == null ? 'Send code' : 'Verify'),
      ),
    ],
  );
}
