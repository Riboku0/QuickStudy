import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/ui/viewer/widgets/note_lines_editor.dart';
import 'package:project/ui/viewer/widgets/styled_text.dart';

// محرر المذكرة: كل سطر باتجاه أول حرف فيه، Enter يقسم، والحذف في أول السطر يدمج
void main() {
  late String saved;
  List<StyledRun> savedRuns = const [];
  late NoteLinesController lines;

  Future<void> pump(WidgetTester tester, String text) async {
    saved = text;
    lines = NoteLinesController();
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
                controller: lines,
                onChanged: (v, runs) {
                  saved = v;
                  savedRuns = runs;
                },
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

  testWidgets('a new color after Enter leaves the line above unchanged', (
    tester,
  ) async {
    const orange = 0xFFEB8A2E;
    await pump(tester, 'black line');
    final first = fields(tester).first.controller!;
    // المؤشر في آخر السطر الأول ثم Enter
    first.value = const TextEditingValue(
      text: '​black line\n',
      selection: TextSelection.collapsed(offset: 12),
    );
    await tester.pumpAndSettle();
    // اختيار البرتقالي بلا تحديد ثم الكتابة في السطر الثاني
    lines.applyStyle((s) => s.copyWith(color: orange));
    await tester.pump();
    final second = fields(tester)[1].controller!;
    second.value = const TextEditingValue(
      text: '​new',
      selection: TextSelection.collapsed(offset: 4),
    );
    await tester.pumpAndSettle();

    expect(saved, 'black line\nnew');
    expect(Runs.styleAt(savedRuns, 0).color, isNull); // السطر الأول كما هو
    expect(Runs.styleAt(savedRuns, 9).color, isNull);
    expect(Runs.styleAt(savedRuns, 11).color, orange);
    expect(Runs.styleAt(savedRuns, 13).color, orange);
  });

  testWidgets('saved runs reload into the same lines', (tester) async {
    const orange = 0xFFEB8A2E;
    // "ab\ncd" والسطر الثاني برتقالي، كما يُقرأ من ملف المذكرة
    saved = '';
    lines = NoteLinesController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: NoteLinesEditor(
              text: 'ab\ncd',
              runs: const [
                StyledRun(3, RunStyle.plain),
                StyledRun(2, RunStyle(color: orange)),
              ],
              style: const TextStyle(fontSize: 16),
              cursorColor: Colors.purple,
              controller: lines,
              onChanged: (v, runs) => savedRuns = runs,
            ),
          ),
        ),
      ),
    );
    final f = fields(tester);
    expect(f.length, 2);
    final c2 = f[1].controller! as StyledTextController;
    expect(Runs.styleAt(c2.runs, 1).color, orange); // بعد الحرف الخفي
    final c1 = f[0].controller! as StyledTextController;
    expect(Runs.styleAt(c1.runs, 1).color, isNull);
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
