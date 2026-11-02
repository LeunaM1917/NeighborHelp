import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../utils/session_data_cache.dart';

/// Retains the last successful page while a stream refreshes or reports errors.
class DataStreamBuilder<T> extends StatefulWidget {
  const DataStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    required this.onRetry,
    this.label = 'data',
  });

  final Stream<T> stream;
  final AsyncWidgetBuilder<T> builder;
  final VoidCallback onRetry;
  final String label;

  @override
  State<DataStreamBuilder<T>> createState() => _DataStreamBuilderState<T>();
}

class _DataStreamBuilderState<T> extends State<DataStreamBuilder<T>> {
  T? _last;
  bool _hasValue = false;

  void _prime() {
    final source = widget.stream;
    if (source is ReplayDataStream<T> && source.hasValue) {
      _last = source.latest;
      _hasValue = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _prime();
  }

  @override
  void didUpdateWidget(DataStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stream, widget.stream)) {
      _last = null;
      _hasValue = false;
      _prime();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: widget.stream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          !_hasValue &&
          !snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 12),
                Text('Loading ${widget.label}…'),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasError &&
          snapshot.connectionState != ConnectionState.waiting &&
          snapshot.connectionState != ConnectionState.none) {
        _last = snapshot.data;
        _hasValue = true;
      }
      if (snapshot.hasError) {
        final failure = DataLoadFailure(
          label: widget.label,
          error: snapshot.error,
          onRetry: widget.onRetry,
          showingCachedData: _hasValue,
        );
        if (!_hasValue) return failure;
        return LayoutBuilder(
          builder: (context, constraints) {
            final content = widget.builder(
              context,
              AsyncSnapshot<T>.withData(ConnectionState.active, _last as T),
            );
            return Column(
              mainAxisSize: constraints.hasBoundedHeight
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                failure,
                if (constraints.hasBoundedHeight)
                  Expanded(child: content)
                else
                  content,
              ],
            );
          },
        );
      }
      return widget.builder(
        context,
        _hasValue
            ? AsyncSnapshot<T>.withData(ConnectionState.active, _last as T)
            : snapshot,
      );
    },
  );
}

class DataLoadFailure extends StatelessWidget {
  const DataLoadFailure({
    super.key,
    required this.label,
    required this.onRetry,
    this.error,
    this.showingCachedData = false,
  });
  final String label;
  final Object? error;
  final VoidCallback onRetry;
  final bool showingCachedData;

  @override
  Widget build(BuildContext context) {
    final backendUnavailable =
        error is FirebaseFunctionsException &&
        [
          'internal',
          'unavailable',
          'not-found',
        ].contains((error as FirebaseFunctionsException).code);
    final message = showingCachedData
        ? 'Showing saved $label. Refresh is temporarily unavailable.'
        : backendUnavailable
        ? 'The $label service is temporarily unavailable. Please try again.'
        : 'Could not load $label. Check your connection and try again.';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
