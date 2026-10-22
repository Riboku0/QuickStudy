import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/ui/core/ui/layout.dart';

// قاعدة أول حرف قوي: أول حرف يحدد الاتجاه، والأرقام والرموز لا تحدده
void main() {
  test('first strong letter decides the direction', () {
    expect(strongDirection('Hello مرحبا'), TextDirection.ltr);
    expect(strongDirection('مرحبا Hello'), TextDirection.rtl);
    expect(strongDirection('123 - مرحبا'), TextDirection.rtl);
    expect(strongDirection('  (42) Hello'), TextDirection.ltr);
    expect(strongDirection('שלום'), TextDirection.rtl); // عبري
    expect(strongDirection('سلام دوست'), TextDirection.rtl); // فارسي
    expect(strongDirection('Привет'), TextDirection.ltr); // روسي
    expect(strongDirection('こんにちは'), TextDirection.ltr); // ياباني
    expect(strongDirection('你好'), TextDirection.ltr); // صيني
  });

  test('no letter yet gives null', () {
    expect(strongDirection(''), isNull);
    expect(strongDirection('  123 !? '), isNull);
    expect(textDirectionFor(''), TextDirection.ltr);
  });
}
