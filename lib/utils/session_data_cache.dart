import 'dart:async';

/// Shares a source subscription and its latest value for one signed-in session.
/// The public stream keeps its identity across page rebuilds and retries.
class ReplayDataStream<T> extends Stream<T> {
  ReplayDataStream(this._create) {
    _stream = Stream<T>.multi((listener) {
      final sub = _events.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener.onCancel = sub.cancel;
      if (_hasValue) listener.add(_latest as T);
      if (_error != null) listener.addError(_error!, _stack);
    }, isBroadcast: true);
    _start();
  }

  final Stream<T> Function() _create;
  final _events = StreamController<T>.broadcast();
  late final Stream<T> _stream;
  Stream<T> get stream => this;
  bool get hasValue => _hasValue;
  T? get latest => _latest;
  @override
  bool get isBroadcast => true;
  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  StreamSubscription<T>? _subscription;
  T? _latest;
  bool _hasValue = false;
  Object? _error;
  StackTrace? _stack;
  bool _disposed = false;
  int _generation = 0;

  void _start() {
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    void report(Object error, StackTrace stack) {
      if (!current()) return;
      _error = error;
      _stack = stack;
      _events.addError(error, stack);
    }

    try {
      _subscription = _create().listen((value) {
        if (!current()) return;
        _latest = value;
        _hasValue = true;
        _error = null;
        _stack = null;
        _events.add(value);
      }, onError: report);
    } catch (error, stack) {
      report(error, stack);
    }
  }

  Future<void> retry() async {
    if (_disposed) return;
    ++_generation;
    await _subscription?.cancel();
    if (_disposed) return;
    _error = null;
    _stack = null;
    _start();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    await _subscription?.cancel();
    await _events.close();
    _latest = null;
    _error = null;
  }
}

/// Coalesces concurrent reads. Failed reads are never kept as cached failures.
class SessionFutureCache {
  final Map<String, _FutureEntry<dynamic>> _entries = {};

  Future<T> get<T>(
    String key,
    Future<T> Function() load, {
    Duration maxAge = const Duration(minutes: 1),
  }) {
    final existing = _entries[key];
    if (existing != null &&
        (existing.completedAt == null ||
            DateTime.now().difference(existing.completedAt!) < maxAge)) {
      return existing.future as Future<T>;
    }
    final entry = _FutureEntry<T>();
    entry.future = Future<T>.sync(load).then(
      (value) {
        entry.completedAt = DateTime.now();
        return value;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[key], entry)) _entries.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
    _entries[key] = entry;
    return entry.future;
  }

  void clear() => _entries.clear();
}

class _FutureEntry<T> {
  late Future<T> future;
  DateTime? completedAt;
}
