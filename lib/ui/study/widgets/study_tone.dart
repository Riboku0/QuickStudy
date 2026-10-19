import 'package:flutter/material.dart';

import '../../core/ui/core_ui.dart';
import 'subject_widgets.dart';

// مربع أيقونة المادة: خلفية فاتحة من لون الأيقونة + أيقونة Duotone
class SubjectIconTile extends StatelessWidget {
  const SubjectIconTile({super.key, required this.iconKey, this.size = 52});

  final String iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = subjectIconColor(iconKey);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(child: SubjectGlyph(iconKey: iconKey, size: size * 0.56)),
    );
  }
}
