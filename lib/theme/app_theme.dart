import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// لوحة الألوان: زمردي + ذهبي على خلفية عاجية
// كل ألوان التطبيق من هنا.
//
//   خلفية عاجية + بطاقات بيضاء  → المساحة الأكبر
//   أخضر زمردي                → الإجراء الأساسي، العنصر المختار، الأرقام المهمة
//   ذهبي                       → لمسات: شريط العناوين، الزخارف، العناوين الفرعية
// ---------------------------------------------------------------------------

abstract final class AppColors {
  // المحايد
  static const Color background = Color(0xFFF7F5EF); // عاجي
  static const Color surface = Color(0xFFFFFFFF);
  static const Color chip = Color(0xFFEEECE6); // أزرار دائرية رمادية / مسارات
  static const Color border = Color(0xFFEDE8DD); // حدود البطاقات

  // النص
  static const Color ink = Color(0xFF1E2421);
  static const Color muted = Color(0xFF7A807C);

  // الأخضر الزمردي
  static const Color primary = Color(0xFF0E6E54);
  static const Color primaryDeep = Color(0xFF0A5440);
  static const Color primarySoft = Color(0xFFE5F0EA);
  static const Color primaryLine = Color(0xFFBFDACD);

  // الذهبي
  static const Color gold = Color(0xFFC3973A);
  static const Color goldDeep = Color(0xFF9C7426);
  static const Color goldSoft = Color(0xFFF7EED7);
  static const Color goldLine = Color(0xFFE7D3A6);

  // الحالات
  static const Color correct = primary;
  static const Color correctSoft = primarySoft;
  static const Color wrong = Color(0xFFD24B45);
  static const Color wrongSoft = Color(0xFFFBE7E4);

  // أسماء تستخدمها صفحات أخرى (لا تحذفها)
  static const Color accent = gold;
  static const Color accentSoft = goldSoft;
  static const Color accentDeep = goldDeep;
  static const Color info = primary;
  static const Color infoSoft = primarySoft;
  static const Color dark = ink;
  static const Color red = wrong;
  static const Color green = primary;
  static const Color blue = primary;
  static const Color blueSoft = primarySoft;
  static const Color yellow = gold;
  static const Color white = surface;
}

// ---------------------------------------------------------------------------
// التدرجات (خفيفة ومحدودة الاستخدام)
// ---------------------------------------------------------------------------

abstract final class AppGradients {
  // مربعات الأيقونات الخضراء والزر الدائري الأساسي
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16865F), AppColors.primaryDeep],
  );

  // مربعات الأيقونات الذهبية
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDDBB68), Color(0xFFB4862F)],
  );

  // شريط التقدم والخط أعلى البطاقة المميزة
  static const LinearGradient progress = LinearGradient(
    colors: [AppColors.primary, Color(0xFF4E8A4E), AppColors.gold],
  );

  // البطاقة الرئيسية الفاتحة (مثل بطاقة أوقات الصلاة)
  static const LinearGradient tinted = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE4F0E9), Color(0xFFF8F3E4)],
  );
}

// ---------------------------------------------------------------------------
// الخطوط: Readex Pro (عربي + إنجليزي) بوزنين 500 و700
// ---------------------------------------------------------------------------

abstract final class AppText {
  static const TextStyle largeTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.15,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  // أرقام كبيرة خضراء (مثل العدّاد في التصميم المرجعي)
  static const TextStyle number = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1,
    color: AppColors.primary,
    fontFeatures: tabular,
  );

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

// ---------------------------------------------------------------------------
// قيم التصميم كامتداد للثيم: final t = AppTokens.of(context);
// ---------------------------------------------------------------------------

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.ink,
    required this.surface,
    required this.chip,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.primaryLine,
    required this.accent,
    required this.accentSoft,
    required this.correct,
    required this.correctSoft,
    required this.wrong,
    required this.wrongSoft,
    required this.info,
    required this.infoSoft,
    required this.muted,
    required this.radiusLarge,
    required this.radiusMedium,
    required this.radiusSmall,
    required this.shadow,
  });

  final Color ink;
  final Color surface;
  final Color chip;
  final Color border;
  final Color primary;
  final Color primarySoft;
  final Color primaryLine;
  final Color accent; // الذهبي
  final Color accentSoft;
  final Color correct;
  final Color correctSoft;
  final Color wrong;
  final Color wrongSoft;
  final Color info;
  final Color infoSoft;
  final Color muted;

  final double radiusLarge; // البطاقات (28)
  final double radiusMedium; // عناصر القوائم (22)
  final double radiusSmall; // مربعات الأيقونات (16)

  final List<BoxShadow> shadow; // ظل دافئ خفيف جدًا

  static const AppTokens standard = AppTokens(
    ink: AppColors.ink,
    surface: AppColors.surface,
    chip: AppColors.chip,
    border: AppColors.border,
    primary: AppColors.primary,
    primarySoft: AppColors.primarySoft,
    primaryLine: AppColors.primaryLine,
    accent: AppColors.gold,
    accentSoft: AppColors.goldSoft,
    correct: AppColors.correct,
    correctSoft: AppColors.correctSoft,
    wrong: AppColors.wrong,
    wrongSoft: AppColors.wrongSoft,
    info: AppColors.info,
    infoSoft: AppColors.infoSoft,
    muted: AppColors.muted,
    radiusLarge: 28,
    radiusMedium: 22,
    radiusSmall: 16,
    shadow: [
      BoxShadow(color: Color(0x0D5A4A26), blurRadius: 20, offset: Offset(0, 6)),
    ],
  );

  // ظل البطاقة الرئيسية
  static const List<BoxShadow> heroShadow = [
    BoxShadow(color: Color(0x1A0A5440), blurRadius: 26, offset: Offset(0, 12)),
  ];

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? standard;

  @override
  AppTokens copyWith({
    Color? ink,
    Color? surface,
    Color? chip,
    Color? border,
    Color? primary,
    Color? primarySoft,
    Color? primaryLine,
    Color? accent,
    Color? accentSoft,
    Color? correct,
    Color? correctSoft,
    Color? wrong,
    Color? wrongSoft,
    Color? info,
    Color? infoSoft,
    Color? muted,
    double? radiusLarge,
    double? radiusMedium,
    double? radiusSmall,
    List<BoxShadow>? shadow,
  }) {
    return AppTokens(
      ink: ink ?? this.ink,
      surface: surface ?? this.surface,
      chip: chip ?? this.chip,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryLine: primaryLine ?? this.primaryLine,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      correct: correct ?? this.correct,
      correctSoft: correctSoft ?? this.correctSoft,
      wrong: wrong ?? this.wrong,
      wrongSoft: wrongSoft ?? this.wrongSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      muted: muted ?? this.muted,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;

    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;

    return AppTokens(
      ink: c(ink, other.ink),
      surface: c(surface, other.surface),
      chip: c(chip, other.chip),
      border: c(border, other.border),
      primary: c(primary, other.primary),
      primarySoft: c(primarySoft, other.primarySoft),
      primaryLine: c(primaryLine, other.primaryLine),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      correct: c(correct, other.correct),
      correctSoft: c(correctSoft, other.correctSoft),
      wrong: c(wrong, other.wrong),
      wrongSoft: c(wrongSoft, other.wrongSoft),
      info: c(info, other.info),
      infoSoft: c(infoSoft, other.infoSoft),
      muted: c(muted, other.muted),
      radiusLarge: d(radiusLarge, other.radiusLarge),
      radiusMedium: d(radiusMedium, other.radiusMedium),
      radiusSmall: d(radiusSmall, other.radiusSmall),
      shadow: BoxShadow.lerpList(shadow, other.shadow, t) ?? shadow,
    );
  }
}

// ---------------------------------------------------------------------------
// لون لكل مادة / نوع ملف (خلفية فاتحة + لون الأيقونة)
// ---------------------------------------------------------------------------

class SubjectStyle {
  const SubjectStyle(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const SubjectStyle pdf =
      SubjectStyle(AppColors.wrongSoft, AppColors.wrong);
  static const SubjectStyle image =
      SubjectStyle(AppColors.goldSoft, AppColors.goldDeep);

  static const List<SubjectStyle> _palette = [
    SubjectStyle(AppColors.primarySoft, AppColors.primary),
    SubjectStyle(AppColors.goldSoft, AppColors.goldDeep),
    SubjectStyle(Color(0xFFE6EEF3), Color(0xFF2F6584)),
  ];

  static SubjectStyle of(String subject) {
    final sum = subject.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[sum % _palette.length];
  }
}

// ---------------------------------------------------------------------------
// الثيم (Material 3) + أنماط المكونات
// ---------------------------------------------------------------------------

abstract final class AppTheme {
  static const String fontName = 'Readex Pro';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      surface: AppColors.background,
      onSurface: AppColors.ink,
      error: AppColors.wrong,
      onError: AppColors.surface,
    );

    String? fontFamily;
    try {
      fontFamily = GoogleFonts.getFont(fontName).fontFamily;
    } catch (_) {
      fontFamily = null; // خط النظام
    }

    final shape16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
      extensions: const <ThemeExtension<dynamic>>[AppTokens.standard],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size(0, 52),
          shape: shape16,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: 0,
          shape: shape16,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          color: AppColors.surface,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        shape: shape16,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape16,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.gold.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }
}