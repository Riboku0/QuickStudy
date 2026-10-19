import 'package:flutter/material.dart';

import '../../../utils/result.dart';
import '../../core/ui/core_ui.dart';
import '../../study/widgets/subject_widgets.dart' show TextInputDialog;
import '../view_models/add_book_view_model.dart';
import 'home_screen.dart' show categoryStyle;

// نموذج إضافة كتاب للمكتبة: اختيار الملف ← الاسم ← التصنيف (أو تصنيف جديد) ← إضافة
class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key, required this.viewModel});

  final AddBookViewModel viewModel;

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  AddBookViewModel get vm => widget.viewModel;

  late final TextEditingController _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    vm.pickFile.addListener(_onPicked);
    vm.save.addListener(_onSaved);
  }

  @override
  void dispose() {
    vm.pickFile.removeListener(_onPicked);
    vm.save.removeListener(_onSaved);
    vm.dispose();
    _name.dispose();
    super.dispose();
  }

  // بعد اختيار الملف: الاسم يبدأ باسم الملف ويمكن تعديله
  void _onPicked() {
    final result = vm.pickFile.result;
    if (result == null || !mounted) return;
    vm.pickFile.clearResult();
    if (result is Err) {
      showAppMessage(
        context,
        AppStrings.of(context).filesNotSaved,
        tone: MessageTone.error,
      );
      return;
    }
    if (vm.file != null) _name.text = vm.name;
  }

  void _onSaved() {
    final result = vm.save.result;
    if (result == null || !mounted) return;
    vm.save.clearResult();
    final s = AppStrings.of(context);

    switch (result) {
      case Ok(value: AddBookOutcome.added):
        showAppMessage(context, s.bookAdded, tone: MessageTone.success);
        Navigator.of(context).pop();
      case Ok(value: AddBookOutcome.duplicate):
        showAppMessage(context, s.bookAlreadyAdded);
      case Ok(value: AddBookOutcome.needsFile):
        showAppMessage(context, s.chooseFile);
      case Ok(value: AddBookOutcome.needsName):
        showAppMessage(context, s.bookNeedsName);
      case Err():
        showAppMessage(context, s.filesNotSaved, tone: MessageTone.error);
    }
  }

  Future<void> _newCategory() async {
    final s = AppStrings.of(context);
    final name = await TextInputDialog.show(
      context,
      title: s.newCategory,
      label: s.categoryNameLabel,
      initial: '',
    );
    if (name != null) await vm.addCategory(name);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final labelStyle = AppText.label.copyWith(color: AppColors.muted);

    return ListenableBuilder(
      listenable: Listenable.merge([vm, vm.pickFile, vm.save]),
      builder: (context, _) {
        return StudyScaffold(
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: StudyButton(
                label: s.addToLibrary,
                icon: AppIcons.add,
                busy: vm.save.running,
                onPressed: vm.save.running || vm.file == null
                    ? null
                    : vm.save.execute,
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(
                  children: [
                    CircleAction(
                      icon: AppIcons.previous,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(s.addBookTitle, style: AppText.display),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                // الملف
                Text(s.bookFile, style: labelStyle),
                const SizedBox(height: 8),
                _FileField(
                  fileName: vm.file?.name,
                  busy: vm.pickFile.running,
                  onTap: vm.pickFile.execute,
                ),
                const SizedBox(height: 22),

                // الاسم
                Text(s.bookName, style: labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  onChanged: vm.setName,
                  maxLength: 120,
                  textInputAction: TextInputAction.done,
                  textDirection: textDirectionFor(_name.text),
                  style: AppText.body.copyWith(color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: s.bookName,
                    counterText: '',
                    filled: true,
                    fillColor: StudyTone.card,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: StudyTone.purple,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // التصنيف + تصنيف جديد
                Text(s.bookCategory, style: labelStyle),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (final key in <String?>[null, ...vm.categories])
                      _CategoryChip(
                        label: key == null ? s.noCategory : s.categoryName(key),
                        icon: key == null ? null : categoryStyle(key).$2,
                        selected: vm.category == key,
                        onTap: () => vm.setCategory(key),
                      ),
                    _CategoryChip(
                      label: s.newCategory,
                      icon: AppIcons.add,
                      selected: false,
                      dashed: true,
                      onTap: _newCategory,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// خانة الملف: قبل الاختيار "اختر ملف PDF"، وبعده اسم الملف وزر "تغيير"
class _FileField extends StatelessWidget {
  const _FileField({
    required this.fileName,
    required this.busy,
    required this.onTap,
  });

  final String? fileName;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final name = fileName;
    final epub = name?.toLowerCase().endsWith('.epub') ?? false;
    final tint = epub ? Tint.green : Tint.pdf;

    return StudyCard(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: name == null
                  ? StudyTone.purple.withValues(alpha: 0.12)
                  : tint.background,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: StudyTone.purple,
                    ),
                  )
                : AppIcon(
                    name == null
                        ? AppIcons.upload
                        : (epub ? AppIcons.book : AppIcons.pdf),
                    size: 22,
                    color: name == null
                        ? StudyTone.purple
                        : tint.foreground,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name ?? s.chooseFile,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: name == null ? null : textDirectionFor(name),
              style: AppText.headline.copyWith(
                color: name == null ? StudyTone.purple : AppColors.ink,
              ),
            ),
          ),
          if (name != null) ...[
            const SizedBox(width: 8),
            Text(
              s.changeFile,
              style: AppText.label.copyWith(color: StudyTone.purple),
            ),
          ],
        ],
      ),
    );
  }
}

// زر تصنيف: المختار بنفسجي، و"تصنيف جديد" بخلفية وحد بنفسجيين خفيفين
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.dashed = false,
  });

  final String label;
  final AppIconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? StudyTone.onPurple
        : (dashed ? StudyTone.purple : AppColors.ink);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? StudyTone.purple
            : (dashed
                  ? StudyTone.purple.withValues(alpha: 0.08)
                  : StudyTone.card),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? StudyTone.purple
                : (dashed
                      ? StudyTone.purple.withValues(alpha: 0.45)
                      : AppColors.line),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon case final icon?) ...[
                    AppIcon(icon, size: 17, color: fg),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    textDirection: textDirectionFor(label),
                    style: AppText.label.copyWith(color: fg),
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
