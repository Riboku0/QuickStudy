import 'package:flutter/material.dart';

// ألوان واجهة القراءة (لوحة الإعدادات، قائمة التحديد، شريط القلم، أزرار الزوم).
// نهارًا فاتحة، وليلًا (أو مع ورق داكن) كحلية هادئة بلون الثيم الليلي.
@immutable
class ReaderChrome {
  const ReaderChrome({required this.dark});

  final bool dark;

  // كحلي من خلفية المكتبة الليلية (#1D2129) أفتح قليلًا للبطاقات
  Color get surface => dark ? const Color(0xFF262B36) : Colors.white;
  Color get ink => dark ? const Color(0xFFE3E6EC) : const Color(0xFF202020);
  Color get muted => dark ? const Color(0x99E3E6EC) : const Color(0x8A000000);
  Color get line => dark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
  Color get chip => dark ? const Color(0xFF323846) : const Color(0xFFF0EEE8);

  // الأصفر الخفيف الموحد (مثل مؤشر الشريط السفلي) والأصفر الغامق للتمييز
  Color get accent => dark ? const Color(0xFF4A4128) : const Color(0xFFFAE8A9);
  Color get onAccent => dark ? const Color(0xFFFFD84D) : const Color(0xFF202020);
  Color get strong => dark ? const Color(0xFFFFD84D) : const Color(0xFF8A6D00);

  // أزرار الزوم العائمة
  Color get fab => dark ? const Color(0xFF323846) : const Color(0xFF202020);
  Color get onFab => dark ? const Color(0xFFE3E6EC) : Colors.white;
}
