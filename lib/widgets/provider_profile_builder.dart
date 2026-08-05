import 'dart:async';

import 'package:flutter/material.dart';

import '../models/provider.dart';
import '../services/firestore_service.dart';

/// Loads [ServiceProviderProfile] via a one-shot [Future] first, then listens for
/// live updates — avoids [StreamBuilder] stuck on `waiting` for nullable streams.
class ProviderProfileBuilder extends StatefulWidget {
  const ProviderProfileBuilder({
    super.key,
    required this.userId,
    required this.builder,
    this.loading,
  });

  final String userId;
  final Widget Function(BuildContext context, ServiceProviderProfile? profile) builder;
  final Widget? loading;

  @override
  State<ProviderProfileBuilder> createState() => _ProviderProfileBuilderState();
}

class _ProviderProfileBuilderState extends State<ProviderProfileBuilder> {
  ServiceProviderProfile? _profile;
  var _ready = false;
  Object? _error;
  StreamSubscription<ServiceProviderProfile?>? _sub;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final initial = await FirestoreService()
          .getProviderProfile(widget.userId)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      if (!mounted) return;
      setState(() {
        _profile = initial;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _ready = true;
      });
    }

    _sub = FirestoreService().providerProfileForUser(widget.userId).listen(
      (profile) {
        if (!mounted) return;
        setState(() => _profile = profile);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = e);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return widget.loading ?? const SizedBox.shrink();
    }
    if (_error != null) {
      return Text('Could not load provider profile: $_error');
    }
    return widget.builder(context, _profile);
  }
}
