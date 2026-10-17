import 'package:flutter/material.dart';

import '../../../domain/models/subject.dart';
import '../../../routing/app_navigator.dart';
import '../../../utils/result.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/study_view_model.dart';
import 'subject_widgets.dart';

// Study: المواد مثل المجلدات. كل مادة لها لون وأول حرف، وشباترها داخلها.
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
      suggestedColor: vm.suggestedColor,
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
            final input = await SubjectDialog.show(context, subject: subject);
            if (input != null) vm.update.execute((subject, input.$1, input.$2));
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

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final header = PageHeader(
          overline: s.subjectsOverline,
          title: s.study,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAction(
                icon: AppIcons.settings,
                tooltip: s.settings,
                onPressed: () => AppNavigator.openSettings(context),
              ),
              const SizedBox(width: 10),
              CircleAction(
                icon: AppIcons.add,
                tooltip: s.newSubject,
                dark: true,
                onPressed: _newSubject,
              ),
            ],
          ),
        );

        if (!vm.isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 22),
              sliver: SliverToBoxAdapter(
                child: ConstrainedContent(child: header),
              ),
            ),
            if (vm.subjects.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: insets.bottom + 40),
                  child: EmptyState(
                    icon: AppIcons.folderAdd,
                    title: s.noSubjectsTitle,
                    message: s.noSubjectsBody,
                    actionLabel: s.newSubject,
                    onAction: _newSubject,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, insets.bottom + 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 196,
                  ),
                  itemCount: vm.subjects.length,
                  itemBuilder: (context, i) {
                    final subject = vm.subjects[i];
                    return _SubjectCard(
                      subject: subject,
                      chapters: vm.chapterCount(subject),
                      onTap: () => AppNavigator.openSubject(context, subject.id),
                      onLongPress: () => _subjectActions(subject),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// بطاقة مادة: مساحة بلونها وأول حرف كبير، ثم الاسم وعدد الشباتر
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.chapters,
    required this.onTap,
    required this.onLongPress,
  });

  final Subject subject;
  final int chapters;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final t = AppTokens.of(context);
    final color = SubjectColors.of(subject.color);
    final onColor = SubjectColors.onColor(color);

    return Semantics(
      button: true,
      label: '${subject.name}, ${s.chapters(chapters)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusMedium),
          boxShadow: t.shadow,
        ),
        child: Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusMedium),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 6),
                      alignment: AlignmentDirectional.bottomStart,
                      child: Text(
                        subject.initial.toUpperCase(),
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: onColor,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
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
                        const SizedBox(height: 2),
                        Text(
                          s.chapters(chapters),
                          style: AppText.caption.copyWith(
                            color: AppColors.muted,
                            fontFeatures: AppText.tabular,
                          ),
                        ),
                      ],
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
