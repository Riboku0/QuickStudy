import 'package:flutter/material.dart';

import '../themes/app_icons.dart';
import '../themes/app_theme.dart';
import 'app_icon.dart';

// primary: أسود · accent: أصفر (الإجراء الأهم) · secondary: أبيض بحد خفيف
// gold: زر الصفحات الورقية (ذهبي نهارًا، أصفر خفيف ليلًا)
enum AppButtonKind { primary, accent, secondary, gold }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAfter = false,
    this.kind = AppButtonKind.primary,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIconData? icon;
  final bool iconAfter;
  final AppButtonKind kind;
  final bool busy; // يعرض مؤشر تحميل بدل الأيقونة

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (kind) {
      AppButtonKind.primary => (AppColors.ink, AppColors.surface),
      AppButtonKind.accent => (AppColors.accentSoft, AppColors.onAccentSoft),
      AppButtonKind.secondary => (AppColors.surface, AppColors.ink),
      AppButtonKind.gold => AppColors.isDark
          ? (AppColors.accentSoft, AppColors.onAccentSoft)
          : (const Color(0xFF9C7F52), Colors.white),
    };

    final style = FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.08),
      disabledForegroundColor: AppColors.muted,
      elevation: 0,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: kind == AppButtonKind.secondary
            ? BorderSide(color: AppColors.line)
            : BorderSide.none,
      ),
    );

    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    final Widget? leading = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : (icon == null ? null : AppIcon(icon!, size: 20));

    if (leading == null) {
      return FilledButton(onPressed: onPressed, style: style, child: text);
    }

    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: iconAfter && !busy
            ? [Flexible(child: text), const SizedBox(width: 8), leading]
            : [leading, const SizedBox(width: 8), Flexible(child: text)],
      ),
    );
  }
}

// زر دائري: داكن (الإجراء الأساسي) أو فاتح
class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.dark = false,
    this.size = 48,
    this.color,
    this.iconColor,
  });

  final AppIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool dark;
  final double size;
  // ألوان خاصة (اختيارية) تتجاوز الفاتح/الداكن
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // الزر الداكن يبقى داكنًا بأيقونة صفراء في الوضعين
    final background = color ?? (dark ? AppColors.hero : AppColors.surface);
    final foreground = iconColor ?? (dark ? AppColors.yellow : AppColors.ink);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? background : AppColors.chip,
        shape: CircleBorder(
          side: (dark || color != null) && !AppColors.isDark
              ? BorderSide.none
              : BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: AppIcon(
                icon,
                size: size * 0.44,
                color: enabled ? foreground : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
