import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:quickcalc/main.dart';

void main() {
  testWidgets('app loads', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const QuickCalcApp());

    expect(find.text('QuickCalc'), findsOneWidget);
  });
}
