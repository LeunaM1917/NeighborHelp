import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/functions_config.dart';
import '../services/auth_service.dart';

class SessionIdleGuard extends StatefulWidget {
  const SessionIdleGuard({super.key, required this.child});
  final Widget child;
  @override
  State<SessionIdleGuard> createState() => _SessionIdleGuardState();
}

class _SessionIdleGuardState extends State<SessionIdleGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _limit = const Duration(minutes: 15);
  DateTime _lastActivity = DateTime.now();
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRole();
    _arm();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final user = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      _limit = user.data()?['role'] == 'Administrator'
          ? const Duration(minutes: 15)
          : const Duration(hours: 1);
      _arm();
      await FirebaseFunctions.instanceFor(
        region: kNeighborHelpFunctionsRegion,
      ).httpsCallable('recordSessionEvent').call({'action': 'login'});
    } catch (_) {
      /* Session protection still applies when logging is unavailable. */
    }
  }

  void _arm() {
    _timer?.cancel();
    final remaining = _limit - DateTime.now().difference(_lastActivity);
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, _expire);
  }

  void _activity() {
    if (_expired ||
        DateTime.now().difference(_lastActivity) < const Duration(seconds: 1)) {
      return;
    }
    _lastActivity = DateTime.now();
    _arm();
  }

  Future<void> _expire() async {
    if (_expired) return;
    _expired = true;
    try {
      await FirebaseFunctions.instanceFor(region: kNeighborHelpFunctionsRegion)
          .httpsCallable('recordSessionEvent')
          .call({'action': 'timeout'})
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    await AuthService().signOut();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _activity(),
    onPointerSignal: (_) => _activity(),
    child: Focus(
      onKeyEvent: (_, event) {
        _activity();
        return KeyEventResult.ignored;
      },
      child: widget.child,
    ),
  );
}
