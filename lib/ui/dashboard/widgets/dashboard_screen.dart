import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../routing/app_navigator.dart';
import '../../core/ui/core_ui.dart';
import '../../home/view_models/home_view_model.dart' show DayPart;
import '../../shell/profile_menu.dart';
import '../view_models/dashboard_view_model.dart';
import 'home_scene.dart';

// الرئيسية: الرأس (كما هو) ← مشهد البومة الحي حسب الوقت والثيم ←
// متابعة القراءة ← اختصارا المذاكرة والمكتبة ← إحصائيات اليوم.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.viewModel,
    required this.onOpenTab,
  });

  final DashboardViewModel viewModel;
  final ValueChanged<int> onOpenTab; // 1 = المذاكرة، 2 = المكتبة

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ظهور الأقسام بالتتابع مرة واحدة عند فتح التطبيق
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _enter(int order, Widget child) {
    final start = (order * 0.12).clamp(0.0, 0.6);
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final vm = widget.viewModel;

    return ColoredBox(
      color: StudyTone.background,
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              // المشهد بعرض الشاشة، وارتفاعه محدود في الشاشات العريضة
              final sceneHeight = (width * 0.62).clamp(210.0, 320.0);
              const overlap = 30.0; // بطاقة المتابعة تعلو أسفل المشهد

              return ListView(
                padding: EdgeInsets.only(
                  top: insets.top + 18,
                  bottom: insets.bottom + 110,
                ),
                children: [
                  _padded(
                    _enter(
                      0,
                      _Header(dayPart: vm.dayPart, name: vm.userName),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // المشهد يمتد تحت أعلى بطاقة المتابعة (لا يُلمس فلا يضر التداخل)
                  SizedBox(
                    height: sceneHeight - overlap,
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: sceneHeight,
                      maxHeight: sceneHeight,
                      child: _enter(
                        0,
                        HomeScene(dayPart: vm.dayPart, height: sceneHeight),
                      ),
                    ),
                  ),
                  _padded(
                      _enter(
                        1,
                        _ContinueCard(
                          item: vm.continueItem,
                          dayPart: vm.dayPart,
                          onOpenLibrary: () => widget.onOpenTab(2),
                        ),
                      ),
                  ),
                  const SizedBox(height: 16),
                  _padded(
                    _enter(
                      2,
                      Row(
                        children: [
                          Expanded(
                            child: _Shortcut(
                              icon: AppIcons.study,
                              title: AppStrings.of(context).study,
                              subtitle:
                                  AppStrings.of(context).subjectCount(vm.subjects),
                              tinted: true,
                              onTap: () => widget.onOpenTab(1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Shortcut(
                              icon: AppIcons.libraryTab,
                              title: AppStrings.of(context).library,
                              subtitle:
                                  AppStrings.of(context).bookCount(vm.books),
                              tinted: false,
                              onTap: () => widget.onOpenTab(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _padded(_enter(3, _TodayStats(vm: vm))),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedContent(child: child),
      );
}

// ---------------------------------------------------------------------------
// الرأس: التحية بلون الثيم + "الرئيسية" + سطر قصير + قائمة الحساب ⋮
// (بقي كما كان بطلب المستخدم)
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.dayPart, required this.name});

  final DayPart dayPart;
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final greeting = switch (dayPart) {
      DayPart.morning => s.goodMorning,
      DayPart.afternoon => s.goodAfternoon,
      DayPart.evening => s.goodEvening,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(
                    dayPart == DayPart.evening ? AppIcons.moon : AppIcons.sun,
                    size: 18,
                    color: StudyTone.purple,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name.isEmpty
                          ? greeting
                          : '$greeting${s.isArabic ? '، ' : ', '}$name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(color: StudyTone.purple),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  AppIcon(AppIcons.home, size: 28, color: StudyTone.purple),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        s.home,
                        style: AppText.display.copyWith(fontSize: 30),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.dashboardSubtitle,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const ProfileMenuButton(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// متابعة القراءة: آخر كتاب أو شابتر فُتح. الطرف البعيد مزخرف بتلال وقمر
// (أو شمس نهارًا) بلون الثيم، وزر سهم دائري.
// ---------------------------------------------------------------------------

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.item,
    required this.dayPart,
    required this.onOpenLibrary,
  });

  final ContinueItem? item;
  final DayPart dayPart;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final item = this.item;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final void Function() onTap = item == null
        ? onOpenLibrary
        : () => AppNavigator.openDocument(context, item.lecture);

    final p = item?.progress;
    final subtitle = item == null
        ? s.noReadingYetHint
        : (item.subjectName ?? s.pageOf(p!.page, p.pageCount));

    return Semantics(
      button: true,
      label: item == null ? s.noReadingYet : '${s.continueLabel}: ${item.title}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: (AppColors.isDark ? Colors.black : StudyTone.purple)
                  .withValues(alpha: AppColors.isDark ? 0.35 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: StudyTone.card,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 132,
              child: Stack(
                children: [
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    width: 170,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CardDecor(
                          main: StudyTone.purple,
                          card: StudyTone.card,
                          night: dayPart == DayPart.evening,
                          mirror: rtl,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 76, 16),
                    child: Row(
                      children: [
                        if (item != null)
                          RepaintBoundary(
                            child: FileThumbnail(
                              lecture: item.lecture,
                              width: 72,
                              height: 100,
                              radius: 12,
                              showBadge: false,
                            ),
                          )
                        else
                          Container(
                            width: 72,
                            height: 100,
                            decoration: BoxDecoration(
                              color: StudyTone.purple.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: AppIcon(
                                AppIcons.book,
                                size: 30,
                                color: StudyTone.purple,
                              ),
                            ),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                s.continueLabel,
                                style: AppText.caption.copyWith(
                                  color: StudyTone.purple,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item?.title ?? s.noReadingYet,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: item == null
                                    ? null
                                    : textDirectionFor(item.title),
                                style: AppText.title.copyWith(fontSize: 19),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(
                                  color: AppColors.muted,
                                  fontFeatures: AppText.tabular,
                                ),
                              ),
                              if (p != null) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ProgressBar(value: p.fraction),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${p.percent}%',
                                      textDirection: TextDirection.ltr,
                                      style: AppText.caption.copyWith(
                                        color: StudyTone.purple,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: AppText.tabular,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    end: 14,
                    bottom: 14,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: StudyTone.card,
                        shape: BoxShape.circle,
                        boxShadow: StudyTone.shadow,
                      ),
                      child: Center(
                        child: AppIcon(
                          AppIcons.chevron,
                          size: 22,
                          color: StudyTone.purple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: StudyTone.purple.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => FractionallySizedBox(
          widthFactor: v,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: StudyTone.purple,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

// زخرفة طرف البطاقة: موجة فاتحة، تلال بدرجات الثيم، قمر أو شمس، ونجوم صغيرة
class _CardDecor extends CustomPainter {
  _CardDecor({
    required this.main,
    required this.card,
    required this.night,
    required this.mirror,
  });

  final Color main;
  final Color card;
  final bool night;
  final bool mirror; // في العربية الزخرفة على اليسار فتنعكس

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (mirror) {
      canvas
        ..translate(w, 0)
        ..scale(-1, 1);
    }
    Color mix(double t) => Color.lerp(card, main, t)!;

    final panel = Path()
      ..moveTo(w * 0.22, 0)
      ..cubicTo(w * 0.02, h * 0.35, w * 0.34, h * 0.62, w * 0.06, h)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(panel, Paint()..color = mix(0.12));

    // قمر أو شمس
    final c = Offset(w * 0.6, h * 0.3);
    final r = h * 0.13;
    if (night) {
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: r)),
          Path()
            ..addOval(
              Rect.fromCircle(center: c + Offset(r * 0.5, -r * 0.3), radius: r * 0.85),
            ),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    } else {
      canvas.drawCircle(
        c,
        r * 2.2,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 2.2, [
            const Color(0x66FFD45E),
            const Color(0x00FFD45E),
          ]),
      );
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFD45E));
    }

    // نجوم أو بريق صغير
    final spark = Paint()
      ..color = (night ? Colors.white : main).withValues(alpha: 0.7);
    for (final (x, y, s) in const [(0.38, 0.18, 2.2), (0.86, 0.16, 1.8), (0.78, 0.5, 1.4)]) {
      final o = Offset(w * x, h * y);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - s * 2)
          ..quadraticBezierTo(o.dx, o.dy, o.dx + s * 2, o.dy)
          ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + s * 2)
          ..quadraticBezierTo(o.dx, o.dy, o.dx - s * 2, o.dy)
          ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - s * 2)
          ..close(),
        spark,
      );
    }

    // تلال
    final far = Path()
      ..moveTo(w * 0.15, h)
      ..cubicTo(w * 0.42, h * 0.58, w * 0.7, h * 0.8, w, h * 0.48)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(far, Paint()..color = mix(0.32));
    final near = Path()
      ..moveTo(w * 0.42, h)
      ..cubicTo(w * 0.62, h * 0.74, w * 0.84, h * 0.9, w, h * 0.7)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(near, Paint()..color = mix(0.58));
  }

  @override
  bool shouldRepaint(_CardDecor old) =>
      old.main != main ||
      old.card != card ||
      old.night != night ||
      old.mirror != mirror;
}

// ---------------------------------------------------------------------------
// اختصار لصفحة: أيقونة في مربع ملون + الاسم + العدد + سهم
// ---------------------------------------------------------------------------

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tinted,
    required this.onTap,
  });

  final AppIconData icon;
  final String title;
  final String subtitle;
  final bool tinted; // المذاكرة بخلفية من لون الثيم، والمكتبة بيضاء
  final VoidCallback onTap;

  // لون دافئ لأيقونة المكتبة (مثل المرجع) يميل قليلًا نحو الثيم
  static Color get _warm => Color.lerp(
        AppColors.isDark ? const Color(0xFF5A4038) : const Color(0xFFFBE3D8),
        StudyTone.purple,
        0.08,
      )!;

  @override
  Widget build(BuildContext context) {
    final main = StudyTone.purple;
    final background = tinted
        ? Color.lerp(StudyTone.card, main, AppColors.isDark ? 0.14 : 0.08)!
        : StudyTone.card;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: StudyTone.shadow,
        ),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tinted ? main.withValues(alpha: 0.14) : _warm,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: AppIcon(icon, size: 24, color: main)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.headline,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  AppIcon(AppIcons.chevron, size: 18, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// إحصائيات اليوم: أربعة مربعات بألوان مختلفة، الأرقام تعدّ صعودًا عند التغير
// ---------------------------------------------------------------------------

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.vm});

  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final dark = AppColors.isDark;
    final tiles = [
      _StatData(AppIcons.book, StudyTone.purple, vm.todayPages, '${vm.todayPages}',
          s.statPagesRead, null),
      _StatData(
        AppIcons.timer,
        dark ? const Color(0xFF7EA2F0) : const Color(0xFF4A78D8),
        vm.todaySeconds,
        s.duration(vm.todaySeconds),
        s.statStudyTime,
        s.duration,
      ),
      _StatData(
        AppIcons.cards,
        dark ? const Color(0xFF5CC898) : const Color(0xFF2E9E6E),
        vm.todayCards,
        '${vm.todayCards}',
        s.statCardsReviewed,
        null,
      ),
      _StatData(
        AppIcons.chart,
        dark ? const Color(0xFFF08C84) : const Color(0xFFE0635A),
        vm.todayQuestions,
        '${vm.todayQuestions}',
        s.statQuestionsSolved,
        null,
      ),
    ];

    return StudyCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Text(s.todayStats, style: AppText.title.copyWith(fontSize: 18)),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              // أربعة في سطر، وعلى الشاشات الضيقة جدًا عمودان
              final columns = box.maxWidth >= 300 ? 4 : 2;
              const gap = 8.0;
              final width = ((box.maxWidth - gap * (columns - 1)) / columns)
                  .clamp(0.0, double.infinity);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final t in tiles)
                    SizedBox(width: width, child: _StatTile(data: t)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatData {
  const _StatData(
    this.icon,
    this.color,
    this.value,
    this.text,
    this.label,
    this.format,
  );

  final AppIconData icon;
  final Color color;
  final int value;
  final String text;
  final String label;
  final String Function(int)? format; // للوقت؛ وإلا الرقم نفسه
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final c = data.color;
    final format = data.format ?? (int n) => '$n';

    return Semantics(
      label: '${data.label}: ${data.text}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: AppColors.isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Center(child: AppIcon(data.icon, size: 20, color: c)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 26,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: data.value.toDouble()),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    final text = format(math.max(0, v.round()));
                    return Text(
                      text,
                      maxLines: 1,
                      textDirection: textDirectionFor(text),
                      style: AppText.display.copyWith(
                        fontSize: 21,
                        height: 1.1,
                        fontFeatures: AppText.tabular,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            // مساحة سطرين ثابتة حتى تتساوى المربعات حين يلتف اسم واحد
            SizedBox(
              height: 30,
              child: Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
