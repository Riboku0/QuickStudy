import 'package:flutter/material.dart';

import '../../../domain/models/subject.dart';
import '../../../routing/app_navigator.dart';
import '../../../utils/result.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/study_view_model.dart';
import '../../shell/profile_menu.dart';
import 'subject_widgets.dart';
import 'study_tone.dart';

// Study (مقتبسة من مرجع المستخدم): تحية وصورة الحساب، بطاقة هدف بنفسجية،
// ثم المواد صفوفًا بأيقونات ملوّنة ونسبة القراءة. ألوانها في StudyTone.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.viewModel});

  final StudyViewModel viewModel;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  StudyViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    vm.create.addListener(_onCreated);
    vm.update.addListener(_onSaved);
    vm.delete.addListener(_onDeleted);
  }

  @override
  void dispose() {
    vm.create.removeListener(_onCreated);
    vm.update.removeListener(_onSaved);
    vm.delete.removeListener(_onDeleted);
    super.dispose();
  }

  // بعد الإنشاء تفتح المادة مباشرة لإضافة الشباتر
  void _onCreated() {
    final result = vm.create.result;
    if (result == null || !mounted) return;
    vm.create.clearResult();
    switch (result) {
      case Ok(:final value):
        AppNavigator.openSubject(context, value);
      case Err():
        _failed();
    }
  }

  void _onSaved() {
    final result = vm.update.result;
    if (result == null || !mounted) return;
    vm.update.clearResult();
    if (result is Err) _failed();
  }

  void _onDeleted() {
    final result = vm.delete.result;
    if (result == null || !mounted) return;
    vm.delete.clearResult();
    if (result is Err) _failed();
  }

  void _failed() => showAppMessage(
        context,
        AppStrings.of(context).studySaveFailed,
        tone: MessageTone.error,
      );

  Future<void> _newSubject() async {
    final input = await SubjectDialog.show(
      context,
      pickImage: vm.pickCoverImage,
    );
    if (input != null) vm.create.execute(input);
  }

  Future<void> _subjectActions(Subject subject) {
    final s = AppStrings.of(context);
    return showActionSheet(
      context,
      title: subject.name,
      items: [
        ActionSheetItem(
          icon: AppIcons.edit,
          label: s.editSubject,
          onTap: () async {
            final input = await SubjectDialog.show(
              context,
              subject: subject,
              pickImage: vm.pickCoverImage,
            );
            if (input != null) vm.update.execute((subject, input));
          },
        ),
        ActionSheetItem(
          icon: AppIcons.trash,
          label: s.delete,
          destructive: true,
          onTap: () async {
            if (await confirmDeleteSubject(context, subject.name)) {
              vm.delete.execute(subject);
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final s = AppStrings.of(context);

    return ColoredBox(
      color: StudyTone.background,
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final subjects = vm.subjects;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              22,
              insets.top + 22,
              22,
              insets.bottom + 28,
            ),
            children: [
              ConstrainedContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Greeting(),
                    const SizedBox(height: 22),
                    _GoalCard(
                      done: vm.finishedChapters,
                      total: vm.totalChapters,
                    ),
                    const SizedBox(height: 28),

                    // عنوان القسم + "مادة جديدة" مكان "View All" في المرجع
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.allSubjects,
                            style: AppText.headline.copyWith(fontSize: 17),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _newSubject,
                          style: TextButton.styleFrom(
                            foregroundColor: StudyTone.purple,
                            minimumSize: const Size(44, 44),
                          ),
                          icon: AppIcon(
                            AppIcons.add,
                            size: 18,
                            color: StudyTone.purple,
                          ),
                          label: Text(
                            s.newSubject,
                            style: AppText.label.copyWith(
                              color: StudyTone.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (!vm.isLoaded)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (subjects.isEmpty)
                      _NoSubjects(onCreate: _newSubject)
                    else
                      for (final subject in subjects) ...[
                        _SubjectRow(
                          subject: subject,
                          chapters: vm.chapterCount(subject),
                          progress: vm.progressFor(subject),
                          onTap: () =>
                              AppNavigator.openSubject(context, subject.id),
                          onLongPress: () => _subjectActions(subject),
                        ),
                        const SizedBox(height: 12),
                      ],
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
// الرأس
// ---------------------------------------------------------------------------

// الرأس: "المواد" (مثل عنوان المكتبة) + سطر قصير + قائمة الحساب ⋮
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(AppIcons.study, size: 28, color: StudyTone.purple),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        s.subjectsTitle,
                        style: AppText.display.copyWith(fontSize: 30),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.studyTagline,
                style: AppText.body.copyWith(
                  color: AppColors.muted,
                  height: 1.5,
                ),
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
// بطاقة الهدف البنفسجية: الشباتر المنتهية من كل المواد + شريط + عبارة قصيرة
// ---------------------------------------------------------------------------

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final fraction = total == 0 ? 0.0 : done / total;
    final soft = Colors.white.withValues(alpha: 0.78);

    return Semantics(
      label: '${s.yourProgress}: $done / $total',
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // زخرفة: قبعة تخرج كبيرة شفافة ونجوم صغيرة (مكان الشخصية في المرجع)
            PositionedDirectional(
              end: -14,
              top: 18,
              child: AppIcon(
                AppIcons.study,
                size: 120,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            PositionedDirectional(
              end: 22,
              top: 16,
              child: AppIcon(
                AppIcons.sparkles,
                size: 22,
                color: const Color(0xFFFFD84D).withValues(alpha: 0.9),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.yourProgress,
                    style: AppText.body.copyWith(color: soft),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$done',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                      Text(
                        ' / $total  ',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: soft,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          s.chaptersDone,
                          style: AppText.body.copyWith(color: soft),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // شريط التقدم الأبيض
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 9,
                      width: 210,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction.clamp(0.0, 1.0),
                            alignment: AlignmentDirectional.centerStart,
                            child: const ColoredBox(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(AppIcons.quote, size: 18, color: soft),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.studyQuote,
                          style: AppText.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// صف مادة (مثل "Today's Schedule" في المرجع):
// أيقونة ملوّنة + الاسم + عدد الشباتر، ونسبة القراءة في الطرف
// ---------------------------------------------------------------------------

class _SubjectRow extends StatefulWidget {
  const _SubjectRow({
    required this.subject,
    required this.chapters,
    required this.progress,
    required this.onTap,
    required this.onLongPress,
  });

  final Subject subject;
  final int chapters;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_SubjectRow> createState() => _SubjectRowState();
}

class _SubjectRowState extends State<_SubjectRow> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final subject = widget.subject;
    final percent = (widget.progress * 100).round();

    return Semantics(
      button: true,
      label: '${subject.name}, ${s.chapters(widget.chapters)}, $percent%',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedScale(
          // حركة خفيفة عند اللمس فقط
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: StudyTone.shadow,
            ),
            child: Material(
              color: StudyTone.card,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
                  child: Row(
                    children: [
                      SubjectIconTile(iconKey: subjectIconKey(subject)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: textDirectionFor(subject.name),
                              style: AppText.headline,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.chapters(widget.chapters),
                              style: AppText.caption.copyWith(
                                color: AppColors.muted,
                                fontFeatures: AppText.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$percent%',
                        textDirection: TextDirection.ltr,
                        style: AppText.label.copyWith(
                          color: AppColors.muted,
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// لا مواد بعد: بطاقة بزر واحد واضح
class _NoSubjects extends StatelessWidget {
  const _NoSubjects({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
      decoration: BoxDecoration(
        color: StudyTone.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: StudyTone.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SubjectIconTile(iconKey: 'book', size: 56)),
          const SizedBox(height: 14),
          Text(
            s.noSubjectsTitle,
            textAlign: TextAlign.center,
            style: AppText.headline,
          ),
          const SizedBox(height: 6),
          Text(
            s.noSubjectsBody,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: StudyTone.purple,
              foregroundColor: StudyTone.onPurple,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: AppIcon(AppIcons.add, size: 20, color: StudyTone.onPurple),
            label: Text(s.newSubject),
          ),
        ],
      ),
    );
  }
}
