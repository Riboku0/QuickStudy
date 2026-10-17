import 'package:flutter/material.dart';

import '../themes/app_icons.dart';
import '../themes/app_theme.dart';
import 'app_icon.dart';

// بطاقة بيضاء بزوايا كبيرة وظل ناعم (أسلوب Home الأصلي)
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.gradient,
    this.padding = const EdgeInsets.all(18),
    this.radius,
    this.border,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
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
        gradient: gradient,
      ),
      child: Material(
        color: gradient == null ? (color ?? AppColors.surface) : Colors.transparent,
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

// مربع أيقونة ملوّن (مثل أيقونات الملفات والإحصائيات في Home الأصلية)
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    Tint? tint,
    this.size = 48,
    this.glow = false,
  }) : _tint = tint;

  final AppIconData icon;
  final Tint? _tint;
  final double size;
  final bool glow;

  // توهج أصفر خفيف (للأيقونة الرئيسية) عبر glow
  Tint get tint => _tint ?? Tint.yellow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: glow
            ? const [
                BoxShadow(
                  color: Color(0x55FFD84D),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Center(
        child: AppIcon(icon, size: size * 0.5, color: tint.foreground),
      ),
    );
  }
}

// زخرفة العنصر المختار في القوائم
BoxDecoration selectableDecoration(
  BuildContext context, {
  required bool selected,
}) {
  final t = AppTokens.of(context);

  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(t.radiusMedium),
    border: Border.all(
      color: selected ? AppColors.ink : Colors.transparent,
      width: 2,
    ),
    boxShadow: t.shadow,
  );
}
