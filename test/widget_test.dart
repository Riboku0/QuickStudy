import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/ui/core/ui/buttons.dart';

void main() {
  testWidgets('AppButton accepts taps only when enabled', (tester) async {
    var presses = 0;

    Future<void> showButton(VoidCallback? onPressed) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(label: 'Save', onPressed: onPressed),
        ),
      ),
    );

    await showButton(() => presses++);
    await tester.tap(find.text('Save'));
    expect(presses, 1);

    await showButton(null);
    await tester.tap(find.text('Save'));
    expect(presses, 1);
  });
}