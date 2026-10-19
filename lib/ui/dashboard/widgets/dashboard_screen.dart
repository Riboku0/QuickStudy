import 'package:flutter/material.dart';

import '../../core/ui/core_ui.dart';
import '../../home/view_models/home_view_model.dart' show DayPart;
import '../../shell/profile_menu.dart';
import '../view_models/dashboard_view_model.dart';

// الرئيسية: لوحة أرقام للمكتبة والمذاكرة (عرض فقط).
// الرأس + قائمة الحساب ⋮ ← بطاقة وقت القراءة اليوم وآخر 7 أيام ←
// أرقام المكتبة ← أرقام المذاكرة ← الإجمالي.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final s = AppStrings.of(context);
    final vm = viewModel;

    return ColoredBox(
      color: StudyTone.background,
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final chapters = vm.chapters;
          final completion =
              chapters == 0 ? 0 : (vm.chaptersFinished * 100 / chapters).round();

          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              insets.top + 18,
              20,
              insets.bottom + 28,
            ),
            children: [
              ConstrainedContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(dayPart: vm.dayPart, name: vm.userName),
                    const SizedBox(height: 22),
                    _TodayCard(
                      today: vm.todaySeconds,
                      week: vm.weekSeconds,
                      streak: vm.streakDays,
                      days: vm.lastWeek,
                    ),

                    const SizedBox(height: 26),
                    _SectionTitle(icon: AppIcons.libraryTab, title: s.library),
                    const SizedBox(height: 12),
                    _StatGrid(
                      stats: [
                        _Stat(AppIcons.book, '${vm.books}', s.statBooks),
                        _Stat(AppIcons.correct, '${vm.booksFinished}',
                            s.statFinished),
                        _Stat(AppIcons.timer, '${vm.booksInProgress}',
                            s.statReadingNow),
                        _Stat(AppIcons.bookmarkSaved, '${vm.bookmarks}',
                            s.statBookmarks),
                      ],
                    ),

                    const SizedBox(height: 26),
                    _SectionTitle(icon: AppIcons.study, title: s.study),
                    const SizedBox(height: 12),
                    _StatGrid(
                      stats: [
                        _Stat(AppIcons.folder, '${vm.subjects}',
                            s.statSubjects),
                        _Stat(
                          AppIcons.correct,
                          '${vm.chaptersFinished} / $chapters',
                          s.statChaptersDone,
                        ),
                        _Stat(AppIcons.target, '$completion%',
                            s.statCompletion),
                      ],
                    ),

                    const SizedBox(height: 26),
                    _SectionTitle(icon: AppIcons.chart, title: s.allTime),
                    const SizedBox(height: 12),
                    _StatGrid(
                      stats: [
                        _Stat(AppIcons.timer, s.duration(vm.totalSeconds),
                            s.statReadingTime),
                        _Stat(AppIcons.files, '${vm.pagesRead}', s.statPages),
                        _Stat(AppIcons.book, '${vm.sessions}', s.statSessions),
                        _Stat(AppIcons.calendar, '${vm.streakDays}',
                            s.dayStreak),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الرأس: التحية بالبنفسجي + "الرئيسية" + سطر قصير + قائمة الحساب ⋮
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
// بطاقة اليوم البنفسجية: وقت القراءة اليوم كبير، ثم الأسبوع والأيام المتتالية،
// ثم أعمدة آخر 7 أيام
// ---------------------------------------------------------------------------

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.today,
    required this.week,
    required this.streak,
    required this.days,
  });

  final int today;
  final int week;
  final int streak;
  final List<(DateTime, int)> days;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final soft = Colors.white.withValues(alpha: 0.78);
    final most = days.fold(0, (a, d) => d.$2 > a ? d.$2 : a);

    return Semantics(
      label: '${s.readingToday}: ${s.duration(today)}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: StudyTone.goalGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: StudyTone.purple.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.readingToday, style: AppText.body.copyWith(color: soft)),
            const SizedBox(height: 4),
            Text(
              s.duration(today),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                height: 1.15,
                fontFeatures: AppText.tabular,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniStat(
                  icon: AppIcons.calendar,
                  value: s.duration(week),
                  label: s.thisWeek,
                ),
                const SizedBox(width: 22),
                _MiniStat(
                  icon: AppIcons.fire,
                  value: '$streak',
                  label: s.dayStreak,
                ),
              ],
            ),
            const SizedBox(height: 18),
            // أعمدة آخر 7 أيام (اليوم آخرها وأوضحها)
            SizedBox(
              height: 74,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, (day, seconds)) in days.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: most == 0
                                ? 4
                                : (4 + 46 * seconds / most).toDouble(),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: i == days.length - 1 ? 0.95 : 0.4,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${day.day}',
                            style: AppText.caption.copyWith(
                              color: soft,
                              fontSize: 11,
                              fontFeatures: AppText.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final AppIconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: 0.78);

    return Row(
      children: [
        AppIcon(icon, size: 18, color: soft),
        const SizedBox(width: 6),
        Text(
          value,
          style: AppText.label.copyWith(
            color: Colors.white,
            fontFeatures: AppText.tabular,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppText.caption.copyWith(color: soft)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// عنوان قسم + شبكة أرقام (رقم كبير وتسمية صغيرة)
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final AppIconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(icon, size: 22, color: StudyTone.purple),
        const SizedBox(width: 8),
        Text(title, style: AppText.headline.copyWith(fontSize: 17)),
      ],
    );
  }
}

class _Stat {
  const _Stat(this.icon, this.value, this.label);

  final AppIconData icon;
  final String value;
  final String label;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // عمودان على الهاتف، وأربعة على الشاشات العريضة
        final columns = box.maxWidth >= 560 ? 4 : 2;
        const gap = 12.0;
        // العرض يكون صفرًا في أول إطار عند فتح التطبيق
        final width = ((box.maxWidth - gap * (columns - 1)) / columns)
            .clamp(0.0, double.infinity);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(width: width, child: _StatTile(stat: stat)),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${stat.label}: ${stat.value}',
      excludeSemantics: true,
      child: StudyCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: StudyTone.purple.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: AppIcon(stat.icon, size: 18, color: StudyTone.purple),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              stat.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: textDirectionFor(stat.value),
              style: AppText.display.copyWith(
                fontSize: 24,
                height: 1.1,
                fontFeatures: AppText.tabular,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
