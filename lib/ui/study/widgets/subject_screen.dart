import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/lecture.dart';
import '../../../routing/app_navigator.dart';
import '../../../utils/result.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/subject_view_model.dart';
import 'subject_widgets.dart';

// صفحة المادة: شباترها بالترتيب، إضافة وتغيير اسم وإزالة وسحب لإعادة الترتيب
class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key, required this.subjectId});

  final int subjectId;

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  late final SubjectViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = SubjectViewModel(
      subjectId: widget.subjectId,
      subjects: context.read(),
      lectures: context.read(),
      progress: context.read(),
      picker: context.read(),
    );
    vm.uploadNew.addListener(_onUploaded);
    vm.rename.addListener(_onSimpleResult);
    vm.updateSubject.addListener(_onSimpleResult);
    vm.remove.addListener(_onRemoved);
    vm.deleteSubject.addListener(_onSubjectDeleted);
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  AppStrings get s => AppStrings.of(context);

  void _failed() =>
      showAppMessage(context, s.studySaveFailed, tone: MessageTone.error);

  void _onUploaded() {
    final result = vm.uploadNew.result;
    if (result == null || !mounted) return;
    vm.uploadNew.clearResult();
    switch (result) {
      case Ok(:final value):
        if (value.added > 0) {
          showAppMessage(
            context,
            s.filesAdded(value.added),
            tone: MessageTone.success,
          );
        } else if (!value.cancelled) {
          // الملف مضاف مسبقًا في المذاكرة
          showAppMessage(context, '${s.noNewFiles}${s.skipped(value.skipped)}');
        }
      case Err():
        showAppMessage(context, s.filesNotSaved, tone: MessageTone.error);
    }
  }

  void _onSimpleResult() {
    for (final c in [vm.rename, vm.updateSubject]) {
      final result = c.result;
      if (result == null) continue;
      c.clearResult();
      if (result is Err && mounted) _failed();
    }
  }

  void _onRemoved() {
    final result = vm.remove.result;
    if (result == null || !mounted) return;
    vm.remove.clearResult();
    switch (result) {
      case Ok():
        showAppMessage(context, s.chapterRemoved);
      case Err():
        _failed();
    }
  }

  void _onSubjectDeleted() {
    final result = vm.deleteSubject.result;
    if (result == null || !mounted) return;
    vm.deleteSubject.clearResult();
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err():
        _failed();
    }
  }

  // كل شابتر ملف PDF يُرفع هنا مباشرة (منفصل عن المكتبة)
  void _addChapter() => vm.uploadNew.execute();

  Future<void> _chapterActions(ChapterItem item, String title) {
    return showActionSheet(
      context,
      title: title,
      items: [
        ActionSheetItem(
          icon: AppIcons.edit,
          label: s.renameChapter,
          onTap: () async {
            final name = await TextInputDialog.show(
              context,
              title: s.renameChapter,
              label: s.chapterName,
              initial: title,
            );
            if (name != null) vm.rename.execute((item.chapter, name));
          },
        ),
        ActionSheetItem(
          icon: AppIcons.trash,
          label: s.removeFromSubject,
          destructive: true,
          onTap: () async {
            if (await confirmDeleteFile(context, title)) {
              vm.remove.execute(item.chapter);
            }
          },
        ),
      ],
    );
  }

  Future<void> _subjectActions() {
    final subject = vm.subject;
    if (subject == null) return Future.value();
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
            if (input != null) vm.updateSubject.execute(input);
          },
        ),
        ActionSheetItem(
          icon: AppIcons.trash,
          label: s.delete,
          destructive: true,
          onTap: () async {
            if (await confirmDeleteSubject(context, subject.name)) {
              vm.deleteSubject.execute();
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);

    return StudyScaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([vm, vm.uploadNew]),
        builder: (context, _) {
          final subject = vm.subject;
          // المادة حُذفت (الشاشة تُغلق بعد لحظة)
          if (subject == null) return const SizedBox.shrink();

          final chapters = vm.chapters;

          final header = Padding(
            padding: EdgeInsets.fromLTRB(28, insets.top + 12, 28, 18),
            child: ConstrainedContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAction(
                        icon: AppIcons.previous,
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      CircleAction(
                        icon: AppIcons.more,
                        tooltip: s.editSubject,
                        onPressed: _subjectActions,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // غلاف المادة (صورة المستخدم إن وُجدت) ثم الأيقونة والاسم بأميري
                  if (subject.coverPath != null) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: SubjectCover(
                        subject: subject,
                        radius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SubjectIconBadge(subject: subject, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.chapters(chapters.length),
                              style: AppText.tracked(context, AppText.label)
                                  .copyWith(
                                color: StudyTone.purple,
                                fontFeatures: AppText.tabular,
                              ),
                            ),
                            Semantics(
                              header: true,
                              child: Text(
                                subject.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textDirection: textDirectionFor(subject.name),
                                style: AppText.display.copyWith(fontSize: 26, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, thickness: 1, color: AppColors.line),
                ],
              ),
            ),
          );

          if (chapters.isEmpty) {
            return Column(
              children: [
                header,
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: insets.bottom + 40),
                    child: EmptyState(
                      icon: AppIcons.pdf,
                      title: s.noChaptersTitle,
                      message: s.noChaptersBody,
                      actionLabel: s.addChapter,
                      onAction: vm.uploadNew.running ? null : _addChapter,
                    ),
                  ),
                ),
              ],
            );
          }

          return ReorderableListView.builder(
            header: header,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.only(bottom: insets.bottom + 100),
            itemCount: chapters.length,
            onReorderItem: vm.reorder,
            proxyDecorator: (child, _, _) =>
                Material(color: Colors.transparent, child: child),
            itemBuilder: (context, i) {
              final item = chapters[i];
              final title = item.chapter.title ?? item.lecture.title;
              return Padding(
                key: ValueKey(item.chapter.id),
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                child: ConstrainedContent(
                  child: _ChapterRow(
                    index: i,
                    title: title,
                    lecture: item.lecture,
                    page: vm.progressFor(item.lecture)?.page,
                    pageCount: vm.progressFor(item.lecture)?.pageCount,
                    onTap: () =>
                        AppNavigator.openChapter(context, item.chapter.id),
                    onMore: () => _chapterActions(item, title),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([vm, vm.uploadNew]),
        builder: (context, _) {
          if (vm.subject == null || vm.chapters.isEmpty) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(28, 8, 28, 12),
            // heightFactor: 1 حتى لا يتمدد الزر ليملأ الشاشة ويغطي القائمة
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: StudyButton(
                label: s.addChapter,
                icon: AppIcons.add,
                busy: vm.uploadNew.running,
                  onPressed: vm.uploadNew.running ? null : _addChapter,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.index,
    required this.title,
    required this.lecture,
    required this.page,
    required this.pageCount,
    required this.onTap,
    required this.onMore,
  });

  final int index;
  final String title;
  final Lecture lecture;
  final int? page;
  final int? pageCount;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final started = page != null && pageCount != null && pageCount! > 0;
    final finished = started && page! >= pageCount!;
    // الحالة: لم تبدأ / صفحة X من Y / انتهيت
    final (AppIconData, String) status = finished
        ? (AppIcons.correct, s.chapterFinished)
        : started
            ? (AppIcons.book, s.pageOf(page!, pageCount!))
            : (AppIcons.bookmark, s.notStarted);

    return StudyCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
      child: Row(
        children: [
          RepaintBoundary(
            child: FileThumbnail(
              lecture: lecture,
              width: 46,
              height: 62,
              radius: 10,
              showBadge: false,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.chapterN(index + 1),
                  style: AppText.caption.copyWith(
                    color: StudyTone.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                // سطر واحد للعنوان وسطر حالة دائمًا: كل الصفوف بنفس الارتفاع
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: textDirectionFor(title),
                  style: AppText.headline,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppIcon(
                      status.$1,
                      size: 15,
                      color: finished ? AppColors.green : AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        status.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: finished ? AppColors.green : AppColors.muted,
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.renameChapter,
            onPressed: onMore,
            icon: AppIcon(AppIcons.more, size: 20, color: AppColors.muted),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: s.reorder,
              child: SizedBox(
                width: 40,
                height: 48,
                child: Center(
                  child: AppIcon(
                    AppIcons.dragHandle,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
