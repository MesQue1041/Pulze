import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulze_app/main.dart';

void main() {
  testWidgets('PulzeApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PulzeApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
