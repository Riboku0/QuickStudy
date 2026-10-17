import 'package:flutter/material.dart';

import '../../../domain/models/subject.dart';
import '../../core/ui/core_ui.dart';

// ألوان المواد: درجات واضحة تعمل في الفاتح والداكن
abstract final class SubjectColors {
  static const List<Color> values = [
    Color(0xFFFFD84D), // أصفر
    Color(0xFFE8735A), // مرجاني
    Color(0xFF4F7FD9), // أزرق
    Color(0xFF3E9E6A), // أخضر
    Color(0xFF8165D6), // بنفسجي
    Color(0xFFEE9A3A), // برتقالي
    Color(0xFF2F9E9A), // فيروزي
    Color(0xFFD9668F), // وردي
  ];

  static Color of(int index) => values[index % values.length];

  // الحرف أسود فوق الألوان الفاتحة وأبيض فوق الباقي
  static Color onColor(Color c) =>
      c.computeLuminance() > 0.45 ? const Color(0xFF202020) : Colors.white;
}

// غلاف المادة: لونها وأول حرف من اسمها
class SubjectCover extends StatelessWidget {
  const SubjectCover({
    super.key,
    required this.subject,
    this.size = 56,
    this.radius = 18,
  });

  final Subject subject;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = SubjectColors.of(subject.color);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ExcludeSemantics(
        child: Text(
          subject.initial.toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.46,
            fontWeight: FontWeight.w800,
            height: 1,
            color: SubjectColors.onColor(color),
          ),
        ),
      ),
    );
  }
}

// نافذة إنشاء مادة أو تعديلها. تملك الـ controller وتتخلص منه في dispose.
// ترجع (الاسم، رقم اللون) أو null عند الإلغاء.
class SubjectDialog extends StatefulWidget {
  const SubjectDialog({super.key, this.subject, this.suggestedColor = 0});

  final Subject? subject;
  final int suggestedColor;

  static Future<(String, int)?> show(
    BuildContext context, {
    Subject? subject,
    int suggestedColor = 0,
  }) {
    return showDialog<(String, int)>(
      context: context,
      builder: (_) =>
          SubjectDialog(subject: subject, suggestedColor: suggestedColor),
    );
  }

  @override
  State<SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<SubjectDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.subject?.name ?? '');
  late int _color = widget.subject?.color ?? widget.suggestedColor;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name, _color));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final editing = widget.subject != null;
    final preview = Subject(id: 0, name: _name.text, color: _color);

    return AlertDialog(
      title: Text(
        editing ? s.editSubject : s.newSubject,
        style: AppText.title,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SubjectCover(subject: preview, size: 52, radius: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: !editing,
                    maxLength: 40,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: s.subjectName,
                      hintText: s.subjectNameHint,
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              s.subjectColor,
              style: AppText.label.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, c) in SubjectColors.values.indexed)
                  Semantics(
                    button: true,
                    selected: i == _color,
                    label: '${s.subjectColor} ${i + 1}',
                    child: InkResponse(
                      onTap: () => setState(() => _color = i),
                      radius: 24,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: i == _color
                                    ? AppColors.ink
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: i == _color
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: SubjectColors.onColor(c),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.surface,
            minimumSize: const Size(0, 44),
          ),
          child: Text(editing ? s.save : s.create),
        ),
      ],
    );
  }
}

// نافذة نص واحد (اسم الشابتر). تملك الـ controller.
class TextInputDialog extends StatefulWidget {
  const TextInputDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required String initial,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          TextInputDialog(title: title, label: label, initial: initial),
    );
  }

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(widget.title, style: AppText.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: 80,
        textDirection: textDirectionFor(_text.text),
        onSubmitted: (v) => Navigator.of(context).pop(v),
        decoration: InputDecoration(labelText: widget.label, counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.surface,
            minimumSize: const Size(0, 44),
          ),
          child: Text(s.save),
        ),
      ],
    );
  }
}

// قائمة خيارات من الأسفل (تعديل/حذف...)
class ActionSheetItem {
  const ActionSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

Future<void> showActionSheet(
  BuildContext context, {
  required String title,
  required List<ActionSheetItem> items,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: textDirectionFor(title),
                style: AppText.headline,
              ),
            ),
            for (final item in items)
              ListTile(
                minTileHeight: 52,
                leading: AppIcon(
                  item.icon,
                  size: 22,
                  color: item.destructive ? AppColors.red : AppColors.ink,
                ),
                title: Text(
                  item.label,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: item.destructive ? AppColors.red : AppColors.ink,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  item.onTap();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

// تأكيد حذف مادة
Future<bool> confirmDeleteSubject(BuildContext context, String name) async {
  final s = AppStrings.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: IconTile(icon: AppIcons.trash, tint: Tint.pdf, size: 56),
      title: Text(s.deleteSubjectTitle, style: AppText.title),
      content: Text(
        s.deleteSubjectBody(name),
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: AppColors.muted),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: AppColors.surface,
            minimumSize: const Size(0, 44),
          ),
          child: Text(s.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
