import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_mfa_panel.dart';
import '../services/auth_service.dart';

/// Administrator roles are checked by the root; this gate applies optional MFA.
class AdminAccountGate extends StatefulWidget {
  const AdminAccountGate({super.key, required this.child});
  final Widget child;
  @override
  State<AdminAccountGate> createState() => _AdminAccountGateState();
}

class _AdminAccountGateState extends State<AdminAccountGate> {
  Future<IdTokenResult>? _token;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in required.')));
    }
    _token ??= user.getIdTokenResult();
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
}
