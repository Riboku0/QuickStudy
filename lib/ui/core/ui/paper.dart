import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../themes/app_theme.dart';
import '../themes/app_icons.dart';
import 'buttons.dart';
import 'surfaces.dart';

// طابع "الورق" المشترك بين المكتبة والمذاكرة والإعدادات:
// خلفية مزخرفة ثابتة، ألوان ذهبية منها، عنوان بخط أميري، ورفوف.

// ---------------------------------------------------------------------------
// خلفية الورق: إطار مزخرف (نهاري كريمي / ليلي)، ثابتة خلف المحتوى
// ---------------------------------------------------------------------------

class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);

    return RepaintBoundary(
      child: ColoredBox(
        color: AppColors.background, // يظهر لحظة قبل تحميل الصورة
        child: Image.asset(
          AppColors.isDark
              ? 'assets/backgrounds/library_dark.webp'
              : 'assets/backgrounds/library_light.webp',
          // fill لا cover: الزخارف على الأطراف الأربعة، والقص يخفي الجانبية
          fit: BoxFit.fill,
          // عرض الشاشة يكون صفرًا في أول إطار عند فتح التطبيق
          cacheWidth: size.width > 0 ? (size.width * ratio).round() : null,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

// صفحة كاملة فوق خلفية الورق (للشاشات المفتوحة فوق التبويبات)
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: PaperBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ألوان مأخوذة من زخارف الخلفية
// ---------------------------------------------------------------------------

abstract final class PaperTone {
  // ذهبي داكن ليلًا، وبيج ذهبي نهارًا
  static Color get gold =>
      AppColors.isDark ? const Color(0xFFB08D57) : const Color(0xFFAE9672);

  // زر الإضافة نهارًا (أغمق قليلًا من gold حتى تظهر الأيقونة البيضاء)
  static const Color button = Color(0xFF9C7F52);

  // الخطوط والإطارات الرفيعة
  static Color get line =>
      gold.withValues(alpha: AppColors.isDark ? 0.32 : 0.42);

  // البطاقات شبه شفافة حتى يظهر ملمس الورق
  static Color get card =>
      AppColors.surface.withValues(alpha: AppColors.isDark ? 0.80 : 0.82);

  // عنوان الصفحة بخط أميري (يُحمَّل من الإنترنت أول مرة ثم يُخزَّن)
  static TextStyle title({double size = 36}) => GoogleFonts.getFont(
        'Amiri',
        textStyle: AppText.display.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      );
}

// بطاقة شبه شفافة بإطار ذهبي رفيع
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: padding,
      radius: radius,
      color: PaperTone.card,
      border: BorderSide(color: PaperTone.line),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// الرأس: سطر صغير ذهبي + عنوان كبير بأميري + أزرار، ثم خط رفيع
// ---------------------------------------------------------------------------

class PaperHeader extends StatelessWidget {
  const PaperHeader({
    super.key,
    required this.overline,
    required this.title,
    this.actions = const [],
  });

  final String overline;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overline,
                    style: AppText.tracked(context, AppText.label).copyWith(
                      color: PaperTone.gold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    header: true,
                    child: Text(title, style: PaperTone.title()),
                  ),
                ],
              ),
            ),
            for (final (i, action) in actions.indexed) ...[
              SizedBox(width: i == 0 ? 12 : 10),
              action,
            ],
          ],
        ),
        const SizedBox(height: 18),
        Divider(height: 1, thickness: 1, color: PaperTone.line),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// الرفوف: مقاسات حسب العرض، ورف واحد (أغلفة + لوح + أسطر تحت اللوح)
// ---------------------------------------------------------------------------

class ShelfLayout {
  const ShelfLayout._({
    required this.side,
    required this.perShelf,
    required this.coverWidth,
  });

  // أقل عرض للغلاف، والمسافة بين الكتب، وأقصى عرض للمحتوى
  static const double minCoverWidth = 92;
  static const double gap = 14;
  static const double maxContentWidth = 640;

  // نسبة الغلاف (أطول من عرضه)
  static const double coverRatio = 1.45;

  final double side; // الهامش الجانبي (28 على الأقل حتى لا يجلس على الزخارف)
  final int perShelf;
  final double coverWidth;

  double get coverHeight => coverWidth * coverRatio;

  EdgeInsets get padding => EdgeInsets.symmetric(horizontal: side);

  // عدد الكتب في الرف حسب العرض المتاح (لا حسب نوع الجهاز)
  factory ShelfLayout.of(double width) {
    final side = math.max(28.0, (width - maxContentWidth) / 2 + 28);
    final content = width - side * 2;
    final perShelf = math.max(
      3,
      ((content + gap) / (minCoverWidth + gap)).floor(),
    );
    final cover = (content - gap * (perShelf - 1)) / perShelf;
    return ShelfLayout._(side: side, perShelf: perShelf, coverWidth: cover);
  }
}

// رف واحد: الأغلفة واقفة على لوح رفيع، وتحته سطر لكل غلاف.
// خانات فارغة في آخر رف حتى تبقى الأغلفة بمقاسها.
class ShelfRow<T> extends StatelessWidget {
  const ShelfRow({
    super.key,
    required this.items,
    required this.layout,
    required this.cover,
    required this.label,
  });

  final List<T> items;
  final ShelfLayout layout;
  final Widget Function(T item) cover;
  final Widget Function(T item) label;

  @override
  Widget build(BuildContext context) {
    List<Widget> cells(Widget Function(T item) build) => [
          for (var i = 0; i < layout.perShelf; i++) ...[
            if (i > 0) const SizedBox(width: ShelfLayout.gap),
            SizedBox(
              width: layout.coverWidth,
              child: i < items.length ? build(items[i]) : null,
            ),
          ],
        ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: cells(cover),
          ),
          const ShelfBoard(),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cells(label),
          ),
        ],
      ),
    );
  }
}

// لوح الرف
class ShelfBoard extends StatelessWidget {
  const ShelfBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: PaperTone.gold.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(2),
        border: Border(bottom: BorderSide(color: PaperTone.line)),
      ),
    );
  }
}

// زر "+" الرئيسي: ذهبي نهارًا بأيقونة بيضاء، وداكن بأيقونة صفراء ليلًا
class PaperAddButton extends StatelessWidget {
  const PaperAddButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleAction(
      icon: AppIcons.add,
      tooltip: tooltip,
      dark: true,
      color: AppColors.isDark ? null : PaperTone.button,
      iconColor: AppColors.isDark ? null : Colors.white,
      onPressed: onPressed,
    );
  }
}
