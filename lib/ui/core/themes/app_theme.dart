import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// الألوان الأصلية للتطبيق: خلفية كريمية + أسود + أصفر، ونسخة داكنة منها.
// كل ألوان التطبيق من هنا فقط.
//
//   60% كريمي + أبيض   → الخلفية والبطاقات
//   30% أسود            → النصوص والأزرار الأساسية والبطاقة الرئيسية في Study
//   10% أصفر            → اللمسة المميزة (مؤشر الشريط، أهم زر، شريط العناوين)
//
// AppColors.x تقرأ من المجموعة الحالية (فاتحة أو داكنة).
// التطبيق يبدّل المجموعة من main.dart ثم يعيد بناء كل الشاشات.
// ---------------------------------------------------------------------------

@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.chip,
    required this.ink,
    required this.muted,
    required this.line,
    required this.hero,
    required this.yellowSoft,
    required this.yellowTint,
    required this.yellowDeep,
    required this.green,
    required this.greenDeep,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.blue,
    required this.blueSoft,
    required this.indigo,
    required this.indigoSoft,
    required this.purple,
    required this.purpleSoft,
    required this.orange,
    required this.orangeSoft,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color chip;
  final Color ink;
  final Color muted;
  final Color line; // حدود وفواصل رفيعة
  final Color hero; // خلفية البطاقات الداكنة المميزة (نصها أبيض/أصفر)
  final Color yellowSoft;
  final Color yellowTint;
  final Color yellowDeep;
  final Color green;
  final Color greenDeep;
  final Color greenSoft;
  final Color red;
  final Color redSoft;
  final Color blue;
  final Color blueSoft;
  final Color indigo;
  final Color indigoSoft;
  final Color purple;
  final Color purpleSoft;
  final Color orange;
  final Color orangeSoft;

  // الألوان الأصلية كما هي
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF3EFE6),
    surface: Color(0xFFFFFFFF),
    chip: Color(0xFFF1EEE6),
    ink: Color(0xFF202020),
    muted: Color(0x8A000000),
    line: Color(0x14000000),
    hero: Color(0xFF202020),
    yellowSoft: Color(0xFFFFF1B8),
    yellowTint: Color(0xFFFFF6CF),
    yellowDeep: Color(0xFF8A6D00),
    green: Color(0xFF218838),
    greenDeep: Color(0xFF2E7D32),
    greenSoft: Color(0xFFDDF3E2),
    red: Color(0xFFC62828),
    redSoft: Color(0xFFFDE4E1),
    blue: Color(0xFF1565C0),
    blueSoft: Color(0xFFDDEBFF),
    indigo: Color(0xFF3949AB),
    indigoSoft: Color(0xFFDCE5FF),
    purple: Color(0xFF6A1B9A),
    purpleSoft: Color(0xFFEBDDF8),
    orange: Color(0xFFE65100),
    orangeSoft: Color(0xFFFFE9D0),
  );

  // داكن دافئ بنفس الروح: أسود بني خفيف بدل الكريمي، والأصفر كما هو
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF141310),
    surface: Color(0xFF1F1D19),
    chip: Color(0xFF2A2823),
    ink: Color(0xFFF2EEE6),
    muted: Color(0x99F2EEE6),
    line: Color(0x1FFFFFFF),
    hero: Color(0xFF2E2B24),
    yellowSoft: Color(0xFF3A3218),
    yellowTint: Color(0xFF29241A),
    yellowDeep: Color(0xFFF2C94C),
    green: Color(0xFF4CC26B),
    greenDeep: Color(0xFF7FD69A),
    greenSoft: Color(0xFF1C3324),
    red: Color(0xFFFF6B60),
    redSoft: Color(0xFF3D1E1B),
    blue: Color(0xFF6EA8FF),
    blueSoft: Color(0xFF1A2B44),
    indigo: Color(0xFF9AA8FF),
    indigoSoft: Color(0xFF232848),
    purple: Color(0xFFCE93D8),
    purpleSoft: Color(0xFF33223D),
    orange: Color(0xFFFFA058),
    orangeSoft: Color(0xFF3A2716),
  );
}

abstract final class AppColors {
  static AppPalette _p = AppPalette.light;

  static AppPalette get palette => _p;
  static bool get isDark => _p.brightness == Brightness.dark;

  // يُستدعى من main.dart فقط
  static void use(AppPalette palette) => _p = palette;

  // المحايد
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get chip => _p.chip;
  static Color get line => _p.line;
  static Color get hero => _p.hero;

  // النص
  static Color get ink => _p.ink;
  static Color get muted => _p.muted;

  // الأصفر (ثابت في الوضعين) + النص فوقه (أسود دائمًا)
  static const Color yellow = Color(0xFFFFD84D);
  static const Color onYellow = Color(0xFF202020);
  static Color get yellowSoft => _p.yellowSoft;
  static Color get yellowTint => _p.yellowTint;
  static Color get yellowDeep => _p.yellowDeep;

  // الأصفر الخفيف للمساحات الكبيرة (الأزرار والبطاقات المميزة)، بنفس درجة مؤشر
  // الشريط السفلي: أصفر 42% على الفاتح، و22% على الداكن مع نص أصفر
  static Color get accentSoft =>
      isDark ? const Color(0xFF4A4128) : const Color(0xFFFAE8A9);
  static Color get onAccentSoft => isDark ? yellow : onYellow;

  // ألوان الحالات والأنواع
  static Color get green => _p.green;
  static Color get greenDeep => _p.greenDeep;
  static Color get greenSoft => _p.greenSoft;
  static Color get red => _p.red;
  static Color get redSoft => _p.redSoft;
  static Color get blue => _p.blue;
  static Color get blueSoft => _p.blueSoft;
  static Color get indigo => _p.indigo;
  static Color get indigoSoft => _p.indigoSoft;
  static Color get purple => _p.purple;
  static Color get purpleSoft => _p.purpleSoft;
  static Color get orange => _p.orange;
  static Color get orangeSoft => _p.orangeSoft;
}

// ---------------------------------------------------------------------------
// الخطوط: Almarai (عربي + إنجليزي)، أوزانه 400 و700 و800 فقط
// بلا تباعد حروف افتراضي حتى لا تنفصل الحروف العربية
// ---------------------------------------------------------------------------

abstract final class AppText {
  static const TextStyle display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  // عناوين الأقسام (نفس أسلوب Home الأصلي)
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  // تباعد الحروف يفصل الحروف العربية، فيُلغى في العربية
  static TextStyle tracked(BuildContext context, TextStyle style) {
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return style.copyWith(letterSpacing: rtl ? 0 : 0.9);
  }
}

// ---------------------------------------------------------------------------
// قيم التصميم كامتداد للثيم: final t = AppTokens.of(context);
// ---------------------------------------------------------------------------

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.radiusLarge,
    required this.radiusMedium,
    required this.radiusSmall,
    required this.shadow,
    required this.heroShadow,
  });

  final double radiusLarge; // 28: البطاقات الكبيرة
  final double radiusMedium; // 22: عناصر القوائم
  final double radiusSmall; // 16: مربعات الأيقونات والأزرار
  final List<BoxShadow> shadow; // ظل ناعم (الأصلي)
  final List<BoxShadow> heroShadow; // ظل البطاقات الداكنة

  static const AppTokens standard = AppTokens(
    radiusLarge: 28,
    radiusMedium: 22,
    radiusSmall: 16,
    shadow: [
      BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 8)),
    ],
    heroShadow: [
      BoxShadow(color: Color(0x33000000), blurRadius: 26, offset: Offset(0, 12)),
    ],
  );

  // في الوضع الداكن الظل أعمق قليلًا لأن الخلفية داكنة
  static const AppTokens darkStandard = AppTokens(
    radiusLarge: 28,
    radiusMedium: 22,
    radiusSmall: 16,
    shadow: [
      BoxShadow(color: Color(0x40000000), blurRadius: 22, offset: Offset(0, 8)),
    ],
    heroShadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 26, offset: Offset(0, 12)),
    ],
  );

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? standard;

  @override
  AppTokens copyWith({
    double? radiusLarge,
    double? radiusMedium,
    double? radiusSmall,
    List<BoxShadow>? shadow,
    List<BoxShadow>? heroShadow,
  }) {
    return AppTokens(
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      shadow: shadow ?? this.shadow,
      heroShadow: heroShadow ?? this.heroShadow,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;

    return AppTokens(
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t)!,
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      shadow: BoxShadow.lerpList(shadow, other.shadow, t) ?? shadow,
      heroShadow:
          BoxShadow.lerpList(heroShadow, other.heroShadow, t) ?? heroShadow,
    );
  }
}

// ---------------------------------------------------------------------------
// لون لكل مادة / نوع ملف (خلفية فاتحة + لون الأيقونة)
// ---------------------------------------------------------------------------

class Tint {
  const Tint(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static Tint get pdf => Tint(AppColors.redSoft, AppColors.red);
  static Tint get image => Tint(AppColors.blueSoft, AppColors.blue);
  static Tint get neutral => Tint(AppColors.chip, AppColors.ink);
  static Tint get yellow => Tint(AppColors.yellowSoft, AppColors.yellowDeep);
  static Tint get green => Tint(AppColors.greenSoft, AppColors.greenDeep);
  static Tint get accent => Tint(AppColors.accentSoft, AppColors.onAccentSoft);

  static Tint forSubject(String subject) {
    switch (subject.trim().toLowerCase()) {
      case 'biology':
        return Tint(AppColors.greenSoft, AppColors.greenDeep);
      case 'chemistry':
        return Tint(AppColors.purpleSoft, AppColors.purple);
      case 'economics':
        return Tint(AppColors.orangeSoft, AppColors.orange);
    }

    final palette = [
      Tint(AppColors.yellowSoft, AppColors.yellowDeep),
      Tint(AppColors.blueSoft, AppColors.blue),
      Tint(AppColors.indigoSoft, AppColors.indigo),
    ];
    final sum = subject.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[sum % palette.length];
  }
}

// ---------------------------------------------------------------------------
// الثيم (Material 3) + أنماط المكونات على مستوى التطبيق
// ---------------------------------------------------------------------------

abstract final class AppTheme {
  // Almarai: أقرب خط مجاني لشكل DIN Next Arabic (طلب المستخدم 19 أكتوبر)
  static const String fontName = 'Almarai';

  // ثيم فاتح ثابت لعارض الملفات (مصمم لخلفية فاتحة فقط)
  static ThemeData? _lightOnly;

  static ThemeData lightOnly() {
    final cached = _lightOnly;
    if (cached != null) return cached;

    final current = AppColors.palette;
    AppColors.use(AppPalette.light);
    final theme = build();
    AppColors.use(current);
    return _lightOnly = theme;
  }

  // يبني الثيم من مجموعة الألوان الحالية (AppColors.use يُستدعى قبله)
  static ThemeData build() {
    final dark = AppColors.isDark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.yellow,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: AppColors.ink,
      onPrimary: AppColors.surface,
      secondary: AppColors.yellow,
      onSecondary: AppColors.onYellow,
      surface: AppColors.background,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.chip,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      error: AppColors.red,
      onError: AppColors.surface,
    );

    // الخط يُحمَّل من Google Fonts عند أول تشغيل مع الإنترنت ثم يُخزَّن.
    // Almarai يدعم العربية والإنجليزية (أوزان 300 / 400 / 700 / 800).
    String? fontFamily;
    try {
      fontFamily = GoogleFonts.getFont(fontName).fontFamily;
    } catch (_) {
      fontFamily = null;
    }

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.line,
      splashFactory: InkRipple.splashFactory,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      iconTheme: IconThemeData(color: AppColors.ink),
      extensions: <ThemeExtension<dynamic>>[
        dark ? AppTokens.darkStandard : AppTokens.standard,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.surface,
          minimumSize: const Size(0, 52),
          shape: shape,
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.surface,
          elevation: 0,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          selectedBackgroundColor: AppColors.hero,
          selectedForegroundColor: AppColors.yellow,
          side: BorderSide(color: AppColors.line),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.hero,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.hero,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: const Color(0x99FFD84D),
        selectionHandleColor: AppColors.ink,
      ),
    );
  }
}
