import 'package:flutter/material.dart';

import '../../../data/repositories/settings/settings_repository.dart';
import 'app_theme.dart';

// ثيمات التطبيق (لون رئيسي + خلفية + بطاقات + تدرج)، لكل ثيم نسخة فاتحة وداكنة.
// تستخدمها المكتبة والمذاكرة والرئيسية وقائمة الحساب والشريط السفلي.
// main.dart يستدعي StudyTone.use(accent) قبل بناء الشجرة، مثل AppColors.use.
@immutable
class AppTone {
  const AppTone({
    required this.main,
    required this.mainDark,
    required this.gradient,
    required this.gradientDark,
    required this.background,
    required this.backgroundDark,
    required this.cardDark,
    this.onMainDark = Colors.white,
  });

  final Color main;
  final Color mainDark;
  final List<Color> gradient;
  final List<Color> gradientDark;
  final Color background;
  final Color backgroundDark;
  final Color cardDark;
  // النص فوق اللون الرئيسي في الوضع الداكن (أبيض، إلا الرمادي الفاتح)
  final Color onMainDark;

  static const Map<AppAccent, AppTone> all = {
    // بنفسجي (الأصلي من مرجع المستخدم)
    AppAccent.violet: AppTone(
      main: Color(0xFF7259DA),
      mainDark: Color(0xFF9483EE),
      gradient: [Color(0xFF7A62E0), Color(0xFF9C88EE)],
      gradientDark: [Color(0xFF5C4AB8), Color(0xFF7A68D6)],
      background: Color(0xFFF8F6FB),
      backgroundDark: Color(0xFF15131B),
      cardDark: Color(0xFF201D29),
    ),
    // أزرق محيطي
    AppAccent.ocean: AppTone(
      main: Color(0xFF2F6FDB),
      mainDark: Color(0xFF6EA2F5),
      gradient: [Color(0xFF3A7BE8), Color(0xFF62A0F7)],
      gradientDark: [Color(0xFF2A56B0), Color(0xFF3F78D6)],
      background: Color(0xFFF4F7FC),
      backgroundDark: Color(0xFF11151C),
      cardDark: Color(0xFF1B2130),
    ),
    // أخضر زمردي
    AppAccent.emerald: AppTone(
      main: Color(0xFF1C9A6F),
      mainDark: Color(0xFF4FCB9E),
      gradient: [Color(0xFF22A77A), Color(0xFF4FC79A)],
      gradientDark: [Color(0xFF17775A), Color(0xFF249273)],
      background: Color(0xFFF3F9F6),
      backgroundDark: Color(0xFF101714),
      cardDark: Color(0xFF1A2420),
    ),
    // وردي
    AppAccent.rose: AppTone(
      main: Color(0xFFD2477A),
      mainDark: Color(0xFFF07AA5),
      gradient: [Color(0xFFDB4F84), Color(0xFFF07EA8)],
      gradientDark: [Color(0xFFA93763), Color(0xFFC54E7C)],
      background: Color(0xFFFCF5F8),
      backgroundDark: Color(0xFF19121A),
      cardDark: Color(0xFF261C26),
    ),
    // برتقالي غروب
    AppAccent.sunset: AppTone(
      main: Color(0xFFDD6B26),
      mainDark: Color(0xFFF59A5E),
      gradient: [Color(0xFFE67A33), Color(0xFFF5A15F)],
      gradientDark: [Color(0xFFB0561F), Color(0xFFCB6D30)],
      background: Color(0xFFFCF7F2),
      backgroundDark: Color(0xFF18130F),
      cardDark: Color(0xFF261E18),
    ),
    // رمادي داكن أنيق (أحادي)
    AppAccent.graphite: AppTone(
      main: Color(0xFF3A3F4A),
      mainDark: Color(0xFFC9CED8),
      gradient: [Color(0xFF353A44), Color(0xFF5B6270)],
      gradientDark: [Color(0xFF2E323B), Color(0xFF474D59)],
      background: Color(0xFFF5F5F6),
      backgroundDark: Color(0xFF121315),
      cardDark: Color(0xFF1D1F23),
      onMainDark: Color(0xFF15171B),
    ),
  };
}

abstract final class StudyTone {
  static AppTone _tone = AppTone.all[AppAccent.violet]!;
  static AppAccent _accent = AppAccent.violet;

  static AppAccent get accent => _accent;

  // الثيم الحالي بنسختيه (للعارض: ألوانه تتبع الورق لا مظهر التطبيق)
  static AppTone get tone => _tone;

  static void use(AppAccent accent) {
    _accent = accent;
    _tone = AppTone.all[accent]!;
  }

  static bool get _dark => AppColors.isDark;

  static Color get background =>
      _dark ? _tone.backgroundDark : _tone.background;
  static Color get card => _dark ? _tone.cardDark : Colors.white;

  // اللون الرئيسي للثيم (الاسم بقي purple من الثيم الأول)
  static Color get purple => _dark ? _tone.mainDark : _tone.main;

  // النص والأيقونات فوق اللون الرئيسي
  static Color get onPurple => _dark ? _tone.onMainDark : Colors.white;

  // تدرج البطاقات المميزة (الهدف، وقت القراءة)
  static List<Color> get goalGradient =>
      _dark ? _tone.gradientDark : _tone.gradient;

  static List<BoxShadow> get shadow => [
        BoxShadow(
          color: (_dark ? Colors.black : _tone.main)
              .withValues(alpha: _dark ? 0.30 : 0.07),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
