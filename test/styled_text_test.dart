import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/ui/viewer/widgets/styled_text.dart';

// تنسيق المقاطع: ما كُتب لا يتغير لونه إلا إن حُدد
const _black = 0xFF202020;
const _orange = 0xFFEB8A2E;

// كتابة حرف بعد حرف كما تفعل لوحة المفاتيح
void type(StyledTextController c, String s) {
  for (final ch in s.split('')) {
    final at = c.selection.isValid ? c.selection.end : c.text.length;
    final next = c.text.substring(0, at) + ch + c.text.substring(at);
    c.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + 1),
    );
  }
}

RunStyle styleOf(StyledTextController c, int i) => Runs.styleAt(c.runs, i);

void main() {
  test('switching color keeps earlier text and colors only new typing', () {
    final c = StyledTextController();
    c.applyStyle((s) => s.copyWith(color: _black));
    type(c, 'Line one');
    type(c, '\n');
    c.applyStyle((s) => s.copyWith(color: _orange));
    type(c, 'Line two');

    expect(styleOf(c, 0).color, _black);
    expect(styleOf(c, 7).color, _black);
    expect(styleOf(c, 9).color, _orange);
    expect(styleOf(c, c.text.length - 1).color, _orange);
  });

  test('recoloring a selected word changes only that word', () {
    final c = StyledTextController(text: 'one two three');
    c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
    c.applyStyle((s) => s.copyWith(color: _orange));

    expect(styleOf(c, 3).color, isNull);
    expect(styleOf(c, 4).color, _orange);
    expect(styleOf(c, 6).color, _orange);
    expect(styleOf(c, 7).color, isNull);
  });

  test('bold and size apply to the selection only', () {
    final c = StyledTextController(text: 'abcdef');
    c.selection = const TextSelection(baseOffset: 2, extentOffset: 4);
    c.applyStyle((s) => s.copyWith(bold: true, scale: 1.4));

    expect(styleOf(c, 1).bold, isFalse);
    expect(styleOf(c, 2).bold, isTrue);
    expect(styleOf(c, 3).scale, 1.4);
    expect(styleOf(c, 4).scale, 1);
  });

  test('moving the cursor follows the formatting at the new spot', () {
    final c = StyledTextController(text: 'ab');
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
    c.applyStyle((s) => s.copyWith(color: _orange));
    // المؤشر بعد الحرف البرتقالي ثم كتابة
    c.selection = const TextSelection.collapsed(offset: 1);
    type(c, 'x');
    expect(styleOf(c, 1).color, _orange);
    // المؤشر في النهاية (بعد حرف بلا لون)
    c.selection = TextSelection.collapsed(offset: c.text.length);
    type(c, 'y');
    expect(styleOf(c, c.text.length - 1).color, isNull);
  });

  test('deleting and pasting keep runs aligned with the text', () {
    final c = StyledTextController(text: 'hello world');
    c.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
    c.applyStyle((s) => s.copyWith(italic: true));
    // حذف "hello "
    c.value = const TextEditingValue(
      text: 'world',
      selection: TextSelection.collapsed(offset: 0),
    );
    expect(Runs.lengthOf(c.runs), 5);
    expect(styleOf(c, 0).italic, isTrue);
  });

  test('runs survive a save and reload, and old notes load plain', () {
    final c = StyledTextController(text: 'abc');
    c.selection = const TextSelection(baseOffset: 1, extentOffset: 2);
    c.applyStyle((s) => s.copyWith(color: _orange, underline: true));
    final saved = Runs.toJson(c.runs);
    final back = Runs.fromJson(saved)!;
    expect(Runs.styleAt(back, 1).color, _orange);
    expect(Runs.styleAt(back, 1).underline, isTrue);
    expect(Runs.styleAt(back, 0), RunStyle.plain);

    // ملاحظة قديمة بلا مقاطع
    expect(Runs.fromJson(null), isNull);
    expect(Runs.fit(Runs.uniform(4), 4).single.length, 4);
    // مقاطع أطول من النص (بيانات تالفة) تُقص
    expect(Runs.lengthOf(Runs.fit(back, 2)), 2);
  });
}
