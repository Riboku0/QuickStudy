import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// اتجاه النص حسب المحتوى (عربي = RTL)
// ---------------------------------------------------------------------------

final RegExp _rtlChars = RegExp(r'[֐-ࣿ]');

TextDirection textDirectionFor(String text) =>
    _rtlChars.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;

// ---------------------------------------------------------------------------
// حد أقصى لعرض المحتوى على الشاشات الكبيرة
// ---------------------------------------------------------------------------

class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// عنوان الصفحة الكبير (Home / Study / Library)
// ---------------------------------------------------------------------------

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppText.largeTitle),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة بيضاء بظل ناعم
// ---------------------------------------------------------------------------

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.radius,
    this.border,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double? radius;
  final BorderSide? border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final shape = BorderRadius.circular(radius ?? t.radiusLarge);

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) content = InkWell(onTap: onTap, child: content);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow ? t.shadow : null,
      ),
      child: Material(
        color: color ?? t.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: border ?? BorderSide.none,
        ),
        child: content,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الأزرار
// primary: حبر (الإجراء الأساسي) · accent: قلم التحديد (الإجراء الأهم في الشاشة)
// secondary: أبيض بحد خفيف
// ---------------------------------------------------------------------------

enum AppButtonKind { primary, accent, secondary }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAfter = false,
    this.kind = AppButtonKind.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconAfter;
  final AppButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final (background, foreground) = switch (kind) {
      AppButtonKind.primary => (t.ink, t.surface),
      AppButtonKind.accent => (t.accent, t.ink),
      AppButtonKind.secondary => (t.surface, t.ink),
    };

    final style = FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: t.ink.withValues(alpha: 0.07),
      disabledForegroundColor: t.muted,
      elevation: 0,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: kind == AppButtonKind.secondary
            ? BorderSide(color: t.ink.withValues(alpha: 0.1))
            : BorderSide.none,
      ),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );

    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style, child: text);
    }

    final iconWidget = Icon(icon, size: 20);

    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: iconAfter
            ? [Flexible(child: text), const SizedBox(width: 8), iconWidget]
            : [iconWidget, const SizedBox(width: 8), Flexible(child: text)],
      ),
    );
  }
}

// زر دائري (السابق، خيارات الملف...)
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 52,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? (background ?? t.surface)
            : t.ink.withValues(alpha: 0.05),
        shape: CircleBorder(
          side: background == null && enabled
              ? BorderSide(color: t.ink.withValues(alpha: 0.1))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: 21,
              color: enabled ? (foreground ?? t.ink) : t.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// وسم صغير
// ---------------------------------------------------------------------------

class AppPill extends StatelessWidget {
  const AppPill(
    this.text, {
    super.key,
    required this.background,
    required this.foreground,
    this.dot = false,
  });

  final String text;
  final Color background;
  final Color foreground;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: AppText.caption.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontFeatures: AppText.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// عنوان قسم: نص واضح + عدد خافت (بدون زخارف)
// ---------------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: AppText.headline)),
          if (trailing != null)
            Text(
              trailing!,
              style: AppText.caption.copyWith(
                color: t.muted,
                fontFeatures: AppText.tabular,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// شريط تقدم رفيع
// ---------------------------------------------------------------------------

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value});

  final double value; // 0..1

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final v = value.clamp(0.0, 1.0).toDouble();

    return Semantics(
      value: '${(v * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 6,
          child: ColoredBox(
            color: t.chip,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.ink,
                    borderRadius: BorderRadius.circular(4),
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
// ملاحظة معلومات
// ---------------------------------------------------------------------------

class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.infoSoft,
        borderRadius: BorderRadius.circular(t.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: t.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppText.caption.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// حالة فارغة / خطأ: توجيه واضح + إجراء
// ---------------------------------------------------------------------------

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: t.ink),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: AppText.title),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: t.muted),
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

// ---------------------------------------------------------------------------
// شريط علوي لصفحات Flashcards وQuiz
// ---------------------------------------------------------------------------

PreferredSizeWidget studyAppBar(
  BuildContext context, {
  required String title,
  required String subtitle,
}) {
  final t = AppTokens.of(context);

  return AppBar(
    titleSpacing: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(subtitle, style: AppText.caption.copyWith(color: t.muted)),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.headline,
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// تأكيد حذف ملف (مشترك بين Home وLibrary). يرجع true عند الموافقة.
// ---------------------------------------------------------------------------

Future<bool> confirmDeleteFile(BuildContext context, String name) async {
  final t = AppTokens.of(context);

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: t.wrongSoft, shape: BoxShape.circle),
        child: Icon(Icons.delete_outline_rounded, color: t.wrong, size: 28),
      ),
      title: const Text('Delete this file?', style: AppText.title),
      content: Text(
        '"$name" and its notes will be removed from QuickStudy. '
        'The original file on your phone stays where it is.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: t.muted),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: t.wrong,
            foregroundColor: t.surface,
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Delete file'),
        ),
      ],
    ),
  );

  return result ?? false;
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
    MessageTone.success => (AppColors.correct, Icons.check_circle_outline),
    MessageTone.error => (AppColors.wrong, Icons.error_outline),
    MessageTone.neutral => (AppColors.ink, Icons.info_outline),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
