import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../routing/app_navigator.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/chapter_view_model.dart';
import 'subject_widgets.dart';

// صفحة الشابتر (طابع الورق): قراءة الملف، محادثة (قريبًا)، بطاقات واختبار (تجريبية الآن)
class ChapterScreen extends StatefulWidget {
  const ChapterScreen({super.key, required this.chapterId});

  final int chapterId;

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  late final ChapterViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = ChapterViewModel(
      chapterId: widget.chapterId,
      subjects: context.read(),
      lectures: context.read(),
      progress: context.read(),
      studies: context.read(),
    );
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final s = AppStrings.of(context);

    return StudyScaffold(
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final lecture = vm.lecture;
          final subject = vm.subject;
          // الشابتر أُزيل أو حُذف ملفه
          if (lecture == null || subject == null) {
            return Center(
              child: CircleAction(
                icon: AppIcons.previous,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            );
          }

          final progress = vm.progress;
          final started = progress != null && progress.pageCount > 0;
          final deck = vm.deck;
          void read() => AppNavigator.openDocument(context, lecture);

          return ListView(
            padding: EdgeInsets.fromLTRB(
              28,
              insets.top + 12,
              28,
              insets.bottom + 28,
            ),
            children: [
              ConstrainedContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: CircleAction(
                        icon: AppIcons.previous,
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // المادة ورقم الشابتر بالذهبي، ثم العنوان بأميري
                    Row(
                      children: [
                        SubjectIconBadge(subject: subject, size: 18),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${subject.name} · ${s.chapterN(vm.number)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.tracked(context, AppText.label)
                                .copyWith(color: StudyTone.purple),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      header: true,
                      child: Text(
                        vm.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textDirection: textDirectionFor(vm.title),
                        style: AppText.display.copyWith(fontSize: 26, height: 1.3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, thickness: 1, color: AppColors.line),
                    const SizedBox(height: 20),

                    // القراءة: مثل بطاقة "تابع القراءة" في المكتبة
                    StudyCard(
                      onTap: read,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 112,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x22000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: RepaintBoundary(
                                    child: FileThumbnail(
                                      lecture: lecture,
                                      width: 78,
                                      height: 112,
                                      radius: 6,
                                      showBadge: false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.readChapter, style: AppText.title),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              started
                                                  ? s.pageOf(
                                                      progress.page,
                                                      progress.pageCount,
                                                    )
                                                  : s.notStarted,
                                              style: AppText.caption.copyWith(
                                                color: AppColors.muted,
                                                fontFeatures: AppText.tabular,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${started ? progress.percent : 0}%',
                                            style: AppText.caption.copyWith(
                                              color: AppColors.ink,
                                              fontWeight: FontWeight.w700,
                                              fontFeatures: AppText.tabular,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ProgressTrack(
                                        value: started ? progress.fraction : 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: StudyButton(
                              label: started ? s.resumeReading : s.startReading,
                              icon: AppIcons.book,
                              onPressed: read,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    Text(
                      s.chooseMode,
                      style: AppText.headline.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 12),
                    _ActionRow(
                      icon: AppIcons.chat,
                      title: s.chat,
                      detail: s.chatDetail,
                      pill: s.soon,
                      onTap: null,
                    ),
                    const SizedBox(height: 10),
                    _ActionRow(
                      icon: AppIcons.cards,
                      title: s.flashcards,
                      detail: deck == null
                          ? s.nothingYet
                          : s.cards(deck.flashcards.length),
                      pill: s.sampleLabel,
                      onTap: deck == null || deck.flashcards.isEmpty
                          ? null
                          : () => AppNavigator.openFlashcards(context, deck),
                    ),
                    const SizedBox(height: 10),
                    _ActionRow(
                      icon: AppIcons.quiz,
                      title: s.quiz,
                      detail: deck == null
                          ? s.nothingYet
                          : s.questions(deck.quiz.length),
                      pill: s.sampleLabel,
                      onTap: deck == null || deck.quiz.isEmpty
                          ? null
                          : () => AppNavigator.openQuiz(context, deck),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.sampleChapterNote,
                      style: AppText.caption.copyWith(color: AppColors.muted),
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

// صف وضع مذاكرة: أيقونة بإطار ذهبي + الاسم والشارة + التفاصيل
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.pill,
    required this.onTap,
  });

  final AppIconData icon;
  final String title;
  final String detail;
  final String pill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: StudyCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: StudyTone.purple.withValues(alpha: 0.10),
              ),
              child: Center(
                child: AppIcon(icon, size: 21, color: StudyTone.purple),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: AppText.headline)),
                      const SizedBox(width: 8),
                      AppPill(
                        pill,
                        background: StudyTone.purple.withValues(alpha: 0.16),
                        foreground: AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppText.caption.copyWith(
                      color: AppColors.muted,
                      fontFeatures: AppText.tabular,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              AppIcon(AppIcons.next, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
