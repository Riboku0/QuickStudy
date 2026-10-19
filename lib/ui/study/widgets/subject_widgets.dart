import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../domain/models/subject.dart';
import '../../core/ui/core_ui.dart';

// نسبة غلاف المادة (عريض مثل غلاف صفحة)
const double subjectCoverRatio = 2.4;

// غلاف المادة: صورة يختارها المستخدم، وبدونها مساحة هادئة عليها اسم المادة.
class SubjectCover extends StatelessWidget {
  const SubjectCover({
    super.key,
    required this.subject,
    this.radius = BorderRadius.zero,
  });

  final Subject subject;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: subjectCoverRatio,
      child: ClipRRect(
        borderRadius: radius,
        child: SubjectCoverImage(
          path: subject.coverPath,
          fallbackText: subject.name,
        ),
      ),
    );
  }
}

// صورة الغلاف أو البديل الهادئ (يُستخدم أيضًا للمعاينة في نافذة المادة)
class SubjectCoverImage extends StatelessWidget {
  const SubjectCoverImage({
    super.key,
    required this.path,
    required this.fallbackText,
  });

  final String? path;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    final fallback = ColoredBox(
      color: AppColors.chip,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            fallbackText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textDirection: textDirectionFor(fallbackText),
            style: AppText.display.copyWith(
              fontSize: 26,
              color: AppColors.ink.withValues(alpha: 0.72),
              height: 1.25,
            ),
          ),
        ),
      ),
    );
    if (path == null) return fallback;

    final width = MediaQuery.sizeOf(context).width;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: width > 0 ? (width * ratio).round() : null,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

// أيقونات المواد: Phosphor Duotone (خط + تعبئة خفيفة بنفس اللون) مثل مرجع المستخدم.
// المفتاح يُحفظ في قاعدة البيانات (subjects.icon)، فلا تغيّر المفاتيح.
// كل أيقونة لها لونها، والمادة بلا أيقونة تأخذ واحدة مختلفة حسب رقمها (تنوع تلقائي).
const Map<String, (PhosphorDuotoneIconData, Color)> subjectIcons = {
  'math': (PhosphorIconsDuotone.calculator, Color(0xFF4A72D9)),
  'nature': (PhosphorIconsDuotone.leaf, Color(0xFF3F9A5B)),
  'history': (PhosphorIconsDuotone.bank, Color(0xFFD5524F)),
  'physics': (PhosphorIconsDuotone.atom, Color(0xFF7259DA)),
  'chemistry': (PhosphorIconsDuotone.flask, Color(0xFF14A3A3)),
  'code': (PhosphorIconsDuotone.code, Color(0xFF3F51C4)),
  'biology': (PhosphorIconsDuotone.dna, Color(0xFF2E9E6E)),
  'brain': (PhosphorIconsDuotone.brain, Color(0xFFD45B93)),
  'medicine': (PhosphorIconsDuotone.stethoscope, Color(0xFFE0605A)),
  'globe': (PhosphorIconsDuotone.globeHemisphereWest, Color(0xFF2A8FD0)),
  'language': (PhosphorIconsDuotone.translate, Color(0xFF16A0B0)),
  'writing': (PhosphorIconsDuotone.pencilLine, Color(0xFFDB8A28)),
  'stats': (PhosphorIconsDuotone.chartLineUp, Color(0xFF4A72D9)),
  'business': (PhosphorIconsDuotone.briefcase, Color(0xFFB7792B)),
  'finance': (PhosphorIconsDuotone.coins, Color(0xFFD9A21E)),
  'law': (PhosphorIconsDuotone.scales, Color(0xFF9A5A3C)),
  'lab': (PhosphorIconsDuotone.microscope, Color(0xFF0F98B8)),
  'engineering': (PhosphorIconsDuotone.gear, Color(0xFF5B6B80)),
  'art': (PhosphorIconsDuotone.palette, Color(0xFFE0567A)),
  'music': (PhosphorIconsDuotone.musicNotes, Color(0xFF8E5BD8)),
  'book': (PhosphorIconsDuotone.bookOpenText, Color(0xFF7259DA)),
  'idea': (PhosphorIconsDuotone.lightbulb, Color(0xFFE2A21A)),
  'space': (PhosphorIconsDuotone.rocket, Color(0xFFE2683A)),
  'geography': (PhosphorIconsDuotone.compass, Color(0xFF1F9C8A)),
};

final List<String> subjectIconKeys = subjectIcons.keys.toList();

// الأيقونة الفعلية للمادة: اختيار المستخدم، وإلا واحدة حسب رقم المادة
String subjectIconKey(Subject subject) {
  final icon = subject.icon;
  if (icon != null && subjectIcons.containsKey(icon)) return icon;
  return subjectIconKeys[subject.id % subjectIconKeys.length];
}

Color subjectIconColor(String key) =>
    (subjectIcons[key] ?? subjectIcons['book']!).$2;

// أيقونة Duotone بلونها
class SubjectGlyph extends StatelessWidget {
  const SubjectGlyph({super.key, required this.iconKey, this.size = 26});

  final String iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (data, color) = subjectIcons[iconKey] ?? subjectIcons['book']!;
    return PhosphorIcon(
      data,
      size: size,
      color: color,
      duotoneSecondaryOpacity: 0.28,
    );
  }
}

// أيقونة المادة بجانب اسمها (صفحتا المادة والشابتر)
class SubjectIconBadge extends StatelessWidget {
  const SubjectIconBadge({super.key, required this.subject, this.size = 22});

  final Subject subject;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SubjectGlyph(iconKey: subjectIconKey(subject), size: size * 1.1);
  }
}

// نافذة إنشاء مادة أو تعديلها: الاسم، الأيقونة، صورة الغلاف.
// تملك الـ controller وتتخلص منه في dispose. ترجع SubjectDraft أو null عند الإلغاء.
// pickImage يأتي من الـ ViewModel (اختيار صورة من الهاتف).
class SubjectDialog extends StatefulWidget {
  const SubjectDialog({super.key, this.subject, required this.pickImage});

  final Subject? subject;
  final Future<String?> Function() pickImage;

  static Future<SubjectDraft?> show(
    BuildContext context, {
    Subject? subject,
    required Future<String?> Function() pickImage,
  }) {
    return showDialog<SubjectDraft>(
      context: context,
      builder: (_) => SubjectDialog(subject: subject, pickImage: pickImage),
    );
  }

  @override
  State<SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<SubjectDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.subject?.name ?? '');
  // مادة جديدة: أيقونة عشوائية حتى لا تتشابه المواد
  late String _icon = widget.subject == null
      ? subjectIconKeys[math.Random().nextInt(subjectIconKeys.length)]
      : subjectIconKey(widget.subject!);
  late String? _cover = widget.subject?.coverPath;

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

  Future<void> _chooseCover() async {
    final path = await widget.pickImage();
    if (path != null && mounted) setState(() => _cover = path);
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context)
        .pop(SubjectDraft(name: name, icon: _icon, cover: _cover));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final editing = widget.subject != null;
    final labelStyle = AppText.label.copyWith(color: AppColors.muted);

    return AlertDialog(
      title: Text(
        editing ? s.editSubject : s.newSubject,
        style: AppText.title,
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
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
              const SizedBox(height: 20),

              // الأيقونة
              Text(s.subjectIcon, style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final key in subjectIconKeys)
                    Semantics(
                      button: true,
                      selected: key == _icon,
                      label: key,
                      child: InkResponse(
                        onTap: () => setState(() => _icon = key),
                        radius: 26,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: key == _icon
                                ? subjectIconColor(key).withValues(alpha: 0.12)
                                : null,
                            border: Border.all(
                              color: key == _icon
                                  ? subjectIconColor(key)
                                  : Colors.transparent,
                              width: 1.6,
                            ),
                          ),
                          child: Center(
                            child: SubjectGlyph(iconKey: key, size: 28),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // صورة الغلاف (اختيارية)
              Text(s.coverImage, style: labelStyle),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: subjectCoverRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _chooseCover,
                      child: _cover == null
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.chip,
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppIcon(
                                      AppIcons.imageAdd,
                                      size: 24,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      s.chooseImage,
                                      style: AppText.caption.copyWith(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SubjectCoverImage(
                              path: _cover,
                              fallbackText: _name.text,
                            ),
                    ),
                  ),
                ),
              ),
              if (_cover != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _chooseCover,
                      child: Text(s.changeImage),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _cover = null),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.red,
                      ),
                      child: Text(s.removeImage),
                    ),
                  ],
                ),
            ],
          ),
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
