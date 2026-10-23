import 'package:flutter/material.dart';

import '../../core/themes/study_tone.dart';

// ثيم ليلي واحد: كل ألوان القارئ في مكان واحد (مواصفات المستخدم 23 أكتوبر).
// ألوان مسطحة، والتمييز (accent) للاختيار النشط والشرائح والتقدم فقط.
@immutable
class NightTheme {
  const NightTheme({
    required this.reader,
    required this.page,
    required this.text,
    required this.icon,
    required this.sheet,
    required this.card,
    required this.border,
    required this.accent,
  });

  final Color reader; // خلفية القارئ والشريط العلوي
  final Color page; // خلفية صفحة الكتاب
  final Color text; // النص الأساسي
  final Color icon; // الأيقونات
  final Color sheet; // لوحة الإعدادات والقوائم
  final Color card; // البطاقات وعناصر التحكم
  final Color border; // الحدود
  final Color accent; // التحديد والتحكم

  static const obsidian = NightTheme(
    reader: Color(0xFF111315),
    page: Color(0xFF1B1E21),
    text: Color(0xFFD3D1CB),
    icon: Color(0xFFB9BEC4),
    sheet: Color(0xFF202428),
    card: Color(0xFF2A2F34),
    border: Color(0xFF383E45),
    accent: Color(0xFFB7C5D5),
  );

  static const ink = NightTheme(
    reader: Color(0xFF10141A),
    page: Color(0xFF19212B),
    text: Color(0xFFD4D9DF),
    icon: Color(0xFFBBC9D8),
    sheet: Color(0xFF1D2733),
    card: Color(0xFF283545),
    border: Color(0xFF39495C),
    accent: Color(0xFFA5B8FF),
  );

  static const oliveSmoke = NightTheme(
    reader: Color(0xFF141714),
    page: Color(0xFF20261F),
    text: Color(0xFFD5D7CA),
    icon: Color(0xFFC2C9B6),
    sheet: Color(0xFF252D24),
    card: Color(0xFF303B2E),
    border: Color(0xFF424F3D),
    accent: Color(0xFFB6C79D),
  );

  static const mocha = NightTheme(
    reader: Color(0xFF191614),
    page: Color(0xFF29231F),
    text: Color(0xFFDDD2C5),
    icon: Color(0xFFCDBDAA),
    sheet: Color(0xFF302822),
    card: Color(0xFF3D322A),
    border: Color(0xFF514237),
    accent: Color(0xFFD8B28A),
  );
}

// ألوان واجهة القراءة (لوحة الإعدادات، قائمة التحديد، شريط القلم، الشريط
// العلوي). نهارًا مشتقة من لون الورق المختار حتى تطابقه، والتمييز بلون ثيم
// التطبيق. ليلًا كلها من الثيم الليلي المختار (night)، فتتغير معًا في نفس اللحظة.
@immutable
class ReaderChrome {
  const ReaderChrome({required this.dark, this.paper, this.night});

  final bool dark;
  // لون الورق الحالي (null = أبيض نهارًا / كحلي ليلًا)
  final Color? paper;
  // الثيم الليلي (null = نهارًا)
  final NightTheme? night;

  Color get _base => paper ?? (dark ? const Color(0xFF222733) : Colors.white);

  // خلفية القارئ والشريط العلوي (نهارًا = الورق نفسه)
  Color get reader => night?.reader ?? _base;

  // اللوحة: لون الورق نفسه أفتح قليلًا، فتطابق الصفحة، والحد والظل يفصلانها
  Color get surface =>
      night?.sheet ??
      (dark
          ? Color.lerp(_base, Colors.white, 0.07)!
          : Color.lerp(_base, Colors.white, 0.15)!);
  // البطاقات داخل اللوحة (أعلى قليلًا من اللوحة)
  Color get card =>
      night?.card ??
      (dark
          ? Color.lerp(_base, Colors.white, 0.11)!
          : Color.lerp(_base, Colors.white, 0.45)!);
  Color get ink =>
      night?.text ?? (dark ? const Color(0xFFE6E8EC) : const Color(0xFF202020));
  Color get muted => night != null
      ? night!.icon.withValues(alpha: 0.78)
      : dark
      ? const Color(0x99E6E8EC)
      : const Color(0x8A000000);
  // الأيقونات
  Color get icon => night?.icon ?? muted;
  Color get line =>
      night?.border ??
      (dark ? const Color(0x1FFFFFFF) : const Color(0x14000000));
  Color get chip =>
      night?.card ??
      (dark
          ? Color.lerp(_base, Colors.white, 0.14)!
          : Color.lerp(surface, Colors.black, 0.06)!);

  // التمييز: لون الثيم الليلي، ونهارًا لون ثيم التطبيق
  Color get strong =>
      night?.accent ?? (dark ? StudyTone.tone.mainDark : StudyTone.tone.main);
  Color get accent => strong.withValues(alpha: dark ? 0.22 : 0.18);
  Color get onAccent => strong;
  // النص والأيقونات فوق زر بلون التمييز (ألوان الليلي فاتحة فنصها داكن)
  Color get onStrong =>
      strong.computeLuminance() > 0.45 ? const Color(0xFF15181D) : Colors.white;

  // تحديد النص بلون التمييز بدل الأزرق الافتراضي
  Color get selection => strong.withValues(alpha: dark ? 0.36 : 0.28);

  // الأزرار العائمة (رقم الصفحة على شريط السحب)
  Color get fab =>
      night?.card ??
      (dark ? Color.lerp(_base, Colors.white, 0.20)! : const Color(0xFF202020));
  Color get onFab =>
      night?.text ?? (dark ? const Color(0xFFE6E8EC) : Colors.white);
}
