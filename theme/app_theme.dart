import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// ألوان التطبيق: مصدر واحد بدل تكرارها داخل كل صفحة
// ---------------------------------------------------------------------------

abstract final class AppColors {
  static const Color background = Color(0xFFF3EFE6);
  static const Color dark = Color(0xFF202020);
  static const Color yellow = Color(0xFFFFD84D);
  static const Color white = Color(0xFFFFFFFF);
  static const Color red = Color(0xFFE5483B);
  static const Color blue = Color(0xFF2F5BEA);
  static const Color green = Color(0xFF2E9E5B);
  static const Color muted = Color(0xFF6B6B6B);
}

// ---------------------------------------------------------------------------
// قيم تصميم Neo-Brutalist (حدود سميكة + ظل صلب) كامتداد للثيم
// الاستخدام داخل أي ويدجت: final t = BrutalTheme.of(context);
// ---------------------------------------------------------------------------

@immutable
class BrutalTheme extends ThemeExtension<BrutalTheme> {
  const BrutalTheme({
    required this.ink,
    required this.surface,
    required this.accent,
    required this.correct,
    required this.wrong,
    required this.info,
    required this.muted,
    required this.borderWidth,
    required this.shadowOffset,
    required this.radius,
  });

  final Color ink; // الحدود والنصوص والظل
  final Color surface; // خلفية البطاقات
  final Color accent; // الأصفر
  final Color correct; // إجابة صحيحة
  final Color wrong; // إجابة خاطئة
  final Color info; // الأزرق
  final Color muted; // نص ثانوي
  final double borderWidth;
  final double shadowOffset;
  final double radius;

  static const BrutalTheme standard = BrutalTheme(
    ink: AppColors.dark,
    surface: AppColors.white,
    accent: AppColors.yellow,
    correct: AppColors.green,
    wrong: AppColors.red,
    info: AppColors.blue,
    muted: AppColors.muted,
    borderWidth: 2.5,
    shadowOffset: 4,
    radius: 4,
  );

  static BrutalTheme of(BuildContext context) =>
      Theme.of(context).extension<BrutalTheme>() ?? standard;

  @override
  BrutalTheme copyWith({
    Color? ink,
    Color? surface,
    Color? accent,
    Color? correct,
    Color? wrong,
    Color? info,
    Color? muted,
    double? borderWidth,
    double? shadowOffset,
    double? radius,
  }) {
    return BrutalTheme(
      ink: ink ?? this.ink,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
      info: info ?? this.info,
      muted: muted ?? this.muted,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      radius: radius ?? this.radius,
    );
  }

  @override
  BrutalTheme lerp(covariant ThemeExtension<BrutalTheme>? other, double t) {
    if (other is! BrutalTheme) return this;

    return BrutalTheme(
      ink: Color.lerp(ink, other.ink, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      correct: Color.lerp(correct, other.correct, t)!,
      wrong: Color.lerp(wrong, other.wrong, t)!,
      info: Color.lerp(info, other.info, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      shadowOffset: lerpDouble(shadowOffset, other.shadowOffset, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// ثيم التطبيق (Material 3)
// نفس الإعدادات السابقة في main.dart حتى لا يتغير شكل Home وLibrary،
// مع إضافة BrutalTheme كامتداد.
// ---------------------------------------------------------------------------

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.yellow,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.dark,
      surface: AppColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
      extensions: const <ThemeExtension<dynamic>>[BrutalTheme.standard],
    );
  }
}
