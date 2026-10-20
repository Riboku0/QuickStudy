import 'package:flutter/material.dart';

import '../../core/themes/study_tone.dart';

// ألوان واجهة القراءة (لوحة الإعدادات، قائمة التحديد، شريط القلم).
// كلها مشتقة من لون الورق المختار (فاتحًا أو داكنًا) حتى تطابقه،
// ولون التمييز (الشرائح والمفاتيح والاختيار والتحديد) هو لون ثيم التطبيق.
@immutable
class ReaderChrome {
  const ReaderChrome({required this.dark, this.paper});

  final bool dark;
  // لون الورق الحالي (null = أبيض نهارًا / كحلي ليلًا)
  final Color? paper;

  Color get _base => paper ?? (dark ? const Color(0xFF222733) : Colors.white);

  // اللوحة: لون الورق نفسه أفتح قليلًا (نهارًا وليلًا)، فتطابق الصفحة،
  // والحد والظل يفصلانها عنها
  Color get surface => dark
      ? Color.lerp(_base, Colors.white, 0.07)!
      : Color.lerp(_base, Colors.white, 0.15)!;
  Color get ink => dark ? const Color(0xFFE6E8EC) : const Color(0xFF202020);
  Color get muted => dark ? const Color(0x99E6E8EC) : const Color(0x8A000000);
  Color get line => dark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
  Color get chip => dark
      ? Color.lerp(_base, Colors.white, 0.14)!
      : Color.lerp(surface, Colors.black, 0.06)!;

  // لون الثيم: خفيف للخلفيات وقوي للتمييز
  Color get strong => dark ? StudyTone.tone.mainDark : StudyTone.tone.main;
  Color get accent => strong.withValues(alpha: dark ? 0.30 : 0.18);
  Color get onAccent => strong;

  // تحديد النص بلون الثيم بدل الأزرق الافتراضي
  Color get selection => strong.withValues(alpha: dark ? 0.40 : 0.28);

  // الأزرار العائمة (رقم الصفحة على شريط السحب)
  Color get fab =>
      dark ? Color.lerp(_base, Colors.white, 0.20)! : const Color(0xFF202020);
  Color get onFab => dark ? const Color(0xFFE6E8EC) : Colors.white;
}
