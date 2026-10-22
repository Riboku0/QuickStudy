import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/ui/viewer/widgets/note_lines_editor.dart';

// محرر المذكرة: كل سطر باتجاه أول حرف فيه، Enter يقسم، والحذف في أول السطر يدمج
void main() {
  late String saved;

  Future<void> pump(WidgetTester tester, String text) async {
    saved = text;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              height: 400,
              child: NoteLinesEditor(
                text: text,
                style: const TextStyle(fontSize: 16),
                cursorColor: Colors.purple,
                onChanged: (v) => saved = v,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<TextField> fields(WidgetTester tester) =>
      tester.widgetList<TextField>(find.byType(TextField)).toList();

  testWidgets('each line takes its own direction', (tester) async {
    await pump(tester, 'Hello\nمرحبا\n');
    final f = fields(tester);
    expect(f.length, 3);
    expect(f[0].textDirection, TextDirection.ltr);
    expect(f[1].textDirection, TextDirection.rtl);
    // الفارغ يأخذ اتجاه السطر قبله
    expect(f[2].textDirection, TextDirection.rtl);
  });

  testWidgets('enter splits the line', (tester) async {
    await pump(tester, 'abcdef');
    final c = fields(tester).first.controller!;
    // المؤشر بعد abc ثم Enter
    c.value = TextEditingValue(
      text: '​abc\ndef',
      selection: const TextSelection.collapsed(offset: 5),
    );
    await tester.pumpAndSettle();
    expect(fields(tester).length, 2);
    expect(saved, 'abc\ndef');
  });

  testWidgets('delete at line start merges with the line above', (tester) async {
    await pump(tester, 'abc\ndef');
    final second = fields(tester)[1].controller!;
    // حذف الحرف الخفي في أول السطر الثاني
    second.value = const TextEditingValue(
      text: 'def',
      selection: TextSelection.collapsed(offset: 0),
    );
    await tester.pumpAndSettle();
    expect(fields(tester).length, 1);
    expect(saved, 'abcdef');
  });
}
