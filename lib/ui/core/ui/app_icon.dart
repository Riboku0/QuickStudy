import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../themes/app_icons.dart';

// يعرض أيقونة Hugeicons. اللون الافتراضي يأتي من IconTheme
// (فيأخذ لون الزر تلقائيًا عندما يكون داخل FilledButton مثلًا).
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.7,
  });

  final AppIconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final glyph = HugeIcon(
      icon: icon,
      size: size,
      color: color ?? IconTheme.of(context).color,
      strokeWidth: strokeWidth,
    );

    // الأسهم تنعكس في العربية
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    if (rtl && AppIcons.directional.contains(icon)) {
      return Transform.flip(flipX: true, child: glyph);
    }
    return glyph;
  }
}
