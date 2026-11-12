import 'dart:async';

/// Holds session consumers until Authentication and the application profile agree.
/// Firebase emits its sign-in event before the profile write has completed.
class AccountSetupCoordinator {
  final Set<Future<void>> _pending = {};

  Future<T> run<T>(Future<T> Function() operation) {
    final ready = Completer<void>();
    _pending.add(ready.future);
    return Future<T>.sync(operation).whenComplete(() {
      _pending.remove(ready.future);
      ready.complete();
    });
  }

  Future<void> waitUntilReady() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }
}
