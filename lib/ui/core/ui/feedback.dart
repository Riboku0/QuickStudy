import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../themes/app_icons.dart';
import '../themes/app_theme.dart';
import 'app_icon.dart';
import 'buttons.dart';
import 'surfaces.dart';

// حالة فارغة أو خطأ: أيقونة + عنوان + توجيه + إجراء اختياري
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final AppIconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTile(icon: icon, size: 72, glow: true),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: AppText.title),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                AppButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// صندوق معلومات أزرق (نفس صندوق Home الأصلي)
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.icon = AppIcons.info});

  final String text;
  final AppIconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.indigoSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: AppIcon(icon, size: 20, color: AppColors.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppText.caption.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// شريط تقدم: مسار خفيف + تعبئة سوداء + طرف أصفر
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value});

  final double value; // 0..1

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0).toDouble();

    return Semantics(
      value: '${(v * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 8,
          child: ColoredBox(
            color: AppColors.ink.withValues(alpha: 0.07),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                    // الطرف الأصفر في اتجاه التقدم (يسارًا في العربية)
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [AppColors.ink, AppColors.ink, AppColors.yellow],
                      stops: [0, 0.7, 1],
                    ),
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

// ---------------------------------------------------------------------------
// رسالة سفلية فوق شريط التنقل العائم
// ---------------------------------------------------------------------------

enum MessageTone { neutral, success, error }

void showAppMessage(
  BuildContext context,
  String message, {
  MessageTone tone = MessageTone.neutral,
}) {
  final (color, icon) = switch (tone) {
    MessageTone.success => (AppColors.green, AppIcons.correct),
    MessageTone.error => (AppColors.red, AppIcons.error),
    MessageTone.neutral => (const Color(0xFF6D6250), AppIcons.info),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        content: Row(
          children: [
            AppIcon(icon, size: 21, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

// ---------------------------------------------------------------------------
// تأكيد حذف ملف
// ---------------------------------------------------------------------------

Future<bool> confirmDeleteFile(BuildContext context, String name) async {
  final s = AppStrings.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: IconTile(icon: AppIcons.trash, tint: Tint.pdf, size: 56),
      title: Text(s.deleteFileTitle, style: AppText.title),
      content: Text(
        s.deleteFileBody(name),
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
          child: Text(s.deleteFile),
        ),
      ],
    ),
  );

  return result ?? false;
}
