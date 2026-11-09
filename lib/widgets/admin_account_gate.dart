import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_mfa_panel.dart';
import '../services/auth_service.dart';

/// Email verification is enforced by rules and callable admin commands too.
class AdminAccountGate extends StatefulWidget {
  const AdminAccountGate({super.key, required this.child});
  final Widget child;
  @override
  State<AdminAccountGate> createState() => _AdminAccountGateState();
}

class _AdminAccountGateState extends State<AdminAccountGate> {
  bool _busy = false;
  String? _message;
  Future<IdTokenResult>? _token;
  Future<void> _check({bool send = false}) async {
    setState(() => _busy = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (send) {
        await user?.sendEmailVerification();
        _message =
            'Verification email sent. Follow the link, then select Check verification.';
      } else {
        await user?.reload();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        _token = null;
        _message =
            'If you have verified the email, sign out and sign in again to refresh access.';
      }
    } on FirebaseAuthException catch (e) {
      _message = e.code == 'too-many-requests'
          ? 'Please wait before trying again.'
          : 'Could not check your account. Please retry.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.emailVerified == true) {
      _token ??= user!.getIdTokenResult();
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .doc('securityPolicy/admin')
            .snapshots(),
        builder: (context, policy) {
          if (policy.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not check administrator account protection. Check your connection and sign in again.',
                    ),
                    TextButton(
                      onPressed: () => AuthService().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!policy.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return FutureBuilder<IdTokenResult>(
            future: _token,
            builder: (context, token) {
              if (token.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not refresh administrator sign-in. Check your connection and retry.',
                        ),
                        TextButton(
                          onPressed: () => setState(() => _token = null),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!token.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final required = policy.data?.data()?['requireMfa'] == true;
              final firebase = token.data?.claims?['firebase'];
              if (!required ||
                  (firebase is Map &&
                      firebase['sign_in_second_factor'] is String &&
                      (firebase['sign_in_second_factor'] as String).isNotEmpty)) {
                return widget.child;
              }
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Two-step administrator sign-in required'),
                ),
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      const AdminMfaPanel(),
                      TextButton(
                        onPressed: () => AuthService().signOut(),
                        child: const Text(
                          'Sign out and sign in with your second factor',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Protect your administrator account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Use your individual administrator email and verify that you own it before opening the console.',
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_message!),
                  ),
                FilledButton(
                  onPressed: _busy ? null : () => _check(send: true),
                  child: const Text('Send verification email'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _check,
                  child: const Text('Check verification'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => AuthService().signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
