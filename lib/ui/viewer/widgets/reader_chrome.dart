import 'package:flutter/material.dart';

import '../../core/themes/study_tone.dart';

// ألوان واجهة القراءة (لوحة الإعدادات، قائمة التحديد، شريط القلم، أزرار الزوم).
// نهارًا تأخذ درجة فاتحة من لون الورق المختار، وليلًا (أو مع ورق داكن) كحلية هادئة.
// لون التمييز (الشرائح والمفاتيح والاختيار) هو لون ثيم التطبيق.
@immutable
class ReaderChrome {
  const ReaderChrome({required this.dark, this.paper});

  final bool dark;
  // لون الورق الحالي (null = أبيض)
  final Color? paper;

  // نهارًا: الورق نفسه أفتح قليلًا، فتبدو اللوحة جزءًا من الصفحة
  Color get surface => dark
      ? const Color(0xFF262B36)
      : Color.lerp(paper ?? Colors.white, Colors.white, 0.45)!;
  Color get ink => dark ? const Color(0xFFE3E6EC) : const Color(0xFF202020);
  Color get muted => dark ? const Color(0x99E3E6EC) : const Color(0x8A000000);
  Color get line => dark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
  Color get chip => dark
      ? const Color(0xFF323846)
      : Color.lerp(surface, Colors.black, 0.06)!;

  // لون الثيم: خفيف للخلفيات وقوي للتمييز
  Color get strong => dark ? StudyTone.tone.mainDark : StudyTone.tone.main;
  Color get accent => strong.withValues(alpha: dark ? 0.30 : 0.18);
  Color get onAccent => strong;

  // أزرار الزوم العائمة
  Color get fab => dark ? const Color(0xFF323846) : const Color(0xFF202020);
  Color get onFab => dark ? const Color(0xFFE3E6EC) : Colors.white;
}
