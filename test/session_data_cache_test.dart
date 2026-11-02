import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/utils/session_data_cache.dart';
import 'package:neighbor_help/widgets/data_stream_builder.dart';
import 'package:neighbor_help/widgets/managed_scrollbar.dart';
import 'package:neighbor_help/screens/shared/help_support_popover.dart';
import 'support/ui_test_support.dart';

void main() {
  setUpOfflineFonts();

  test(
    'one source serves multiple subscribers and replays to a reopened page',
    () async {
      var starts = 0;
      final source = StreamController<int>(onListen: () => starts++);
      final cached = ReplayDataStream<int>(() => source.stream);
      expect(identical(cached.stream, cached.stream), isTrue);
      final first = <int>[];
      final second = <int>[];
      final a = cached.stream.listen(first.add);
      final b = cached.stream.listen(second.add);
      source.add(7);
      await Future<void>.delayed(Duration.zero);
      expect(first, [7]);
      expect(second, [7]);
      expect(starts, 1);
      await a.cancel();
      await b.cancel();
      expect(await cached.stream.first, 7);
      await cached.dispose();
      await source.close();
    },
  );

  test(
    'a failed source retries on the same stream without discarding the saved value',
    () async {
      var attempt = 0;
      final cached = ReplayDataStream<int>(() async* {
        if (attempt++ == 0) {
          yield 1;
          throw StateError('offline');
        }
        yield 2;
      });
      final values = <int>[];
      final errors = <Object>[];
      final sub = cached.stream.listen(values.add, onError: errors.add);
      await Future<void>.delayed(Duration.zero);
      expect(values, [1]);
      expect(errors, hasLength(1));
      expect(cached.latest, 1);
      final stream = cached.stream;
      await cached.retry();
      await Future<void>.delayed(Duration.zero);
      expect(identical(stream, cached.stream), isTrue);
      expect(values, [1, 2]);
      await sub.cancel();
      await cached.dispose();
    },
  );

  test('nullable results replay as loaded data', () async {
    final cached = ReplayDataStream<String?>(() => Stream.value(null));
    expect(await cached.stream.first, isNull);
    expect(cached.hasValue, isTrue);
    expect(await cached.stream.first, isNull);
    await cached.dispose();
  });

  test(
    'concurrent futures share a request; failed futures can be retried',
    () async {
      final cache = SessionFutureCache();
      var calls = 0;
      final pending = Completer<int>();
      Future<int> load() {
        calls++;
        return pending.future;
      }

      final a = cache.get('user', load);
      final b = cache.get('user', load);
      expect(identical(a, b), isTrue);
      pending.complete(3);
      expect(await a, 3);
      expect(await b, 3);
      expect(calls, 1);
      await expectLater(
        cache.get<int>('failed', () => Future.error(StateError('offline'))),
        throwsStateError,
      );
      expect(await cache.get('failed', () async => 9), 9);
      cache.clear();
      expect(await cache.get('user', () async => 4), 4);
    },
  );

  test(
    'clearing a session while a request is pending cannot repopulate its cache',
    () async {
      final cache = SessionFutureCache();
      final old = Completer<int>();
      final first = cache.get('same', () => old.future);
      cache.clear();
      final next = cache.get('same', () async => 2);
      old.complete(1);
      expect(await first, 1);
      expect(await next, 2);
      expect(await cache.get('same', () async => 3), 2);
    },
  );

  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'reopening a loaded page at $width shows saved data on its first frame',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = StreamController<String>();
        final cached = ReplayDataStream<String>(() => source.stream);
        Widget page() => MaterialApp(
          home: Scaffold(
            body: DataStreamBuilder<String>(
              stream: cached.stream,
              onRetry: () {},
              builder: (_, s) => Text(s.data ?? 'empty'),
            ),
          ),
        );
        await tester.pumpWidget(page());
        source.add('Saved providers');
        await tester.pump();
        expect(find.text('Saved providers'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(page());
        expect(find.text('Saved providers'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(() async {
          await cached.dispose();
          await source.close();
        });
      },
    );
  }

  testWidgets(
    'temporary failures retain loaded content and expose a working retry',
    (tester) async {
      final source = StreamController<String>();
      var retries = 0;
      final cached = ReplayDataStream<String>(() => source.stream);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataStreamBuilder<String>(
              stream: cached.stream,
              label: 'providers',
              onRetry: () => retries++,
              builder: (_, s) => ListView(children: [Text(s.data ?? '')]),
            ),
          ),
        ),
      );
      source.add('Loaded provider');
      await tester.pump();
      source.addError(StateError('offline'));
      await tester.pump();
      expect(find.text('Loaded provider'), findsOneWidget);
      expect(find.textContaining('Showing saved providers'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
      source.add('Updated provider');
      await tester.pump();
      expect(find.text('Updated provider'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(() async {
        await cached.dispose();
        await source.close();
      });
    },
  );

  testWidgets('switching accounts does not render the previous stream value', (
    tester,
  ) async {
    final first = ReplayDataStream<String>(() => Stream.value('First account'));
    final second = ReplayDataStream<String>(() => const Stream.empty());
    Widget page(Stream<String> stream) => MaterialApp(
      home: Scaffold(
        body: DataStreamBuilder<String>(
          stream: stream,
          onRetry: () {},
          builder: (_, s) => Text(s.data ?? ''),
        ),
      ),
    );
    await tester.pumpWidget(page(first.stream));
    await tester.pump();
    expect(find.text('First account'), findsOneWidget);
    await tester.pumpWidget(page(second.stream));
    expect(find.text('First account'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() async {
      await first.dispose();
      await second.dispose();
    });
  });

  testWidgets('popup scrollbar shares its controller with its list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 180,
            child: ManagedScrollbar(
              thumbVisibility: true,
              builder: (controller) => ListView.builder(
                controller: controller,
                itemCount: 30,
                itemBuilder: (_, i) =>
                    SizedBox(height: 50, child: Text('Row $i')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(identical(bar.controller, list.controller), isTrue);
    expect(bar.controller!.positions, hasLength(1));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 1280.0]) {
    testOnPlatform(
      'Help popup opens and scrolls at $width without scrollbar assertions',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final anchor = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    key: anchor,
                    onPressed: () => HelpSupportPopover.toggle(
                      context,
                      anchorKey: anchor,
                      roleLabel: 'Customer',
                    ),
                    child: const Text('Open help'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open help'));
        await tester.pumpAndSettle();
        expect(find.text('Getting started'), findsOneWidget);
        expect(tester.takeException(), isNull);
        HelpSupportPopover.hide();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
