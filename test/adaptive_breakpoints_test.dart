import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/theme/adaptive_breakpoints.dart';

void main() {
  testWidgets('AdaptiveBreakpoints size classes', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text(AdaptiveBreakpoints.sizeClassOf(context).name),
        ),
      ),
    );
    expect(find.text('compact'), findsOneWidget);

    tester.view.physicalSize = const Size(700, 800);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text(AdaptiveBreakpoints.sizeClassOf(context).name),
        ),
      ),
    );
    expect(find.text('medium'), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text(AdaptiveBreakpoints.sizeClassOf(context).name),
        ),
      ),
    );
    expect(find.text('expanded'), findsOneWidget);
  });
}
