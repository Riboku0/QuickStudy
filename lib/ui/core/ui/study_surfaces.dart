import 'package:flutter/material.dart';

import '../themes/app_icons.dart';
import '../themes/study_tone.dart';
import 'app_icon.dart';

// صفحة كاملة بثيم المذاكرة (صفحتا المادة والشابتر)
class StudyScaffold extends StatelessWidget {
  const StudyScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
  });

  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudyTone.background,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

// بطاقة بيضاء بظل بنفسجي ناعم (مثل صفوف المواد)
class StudyCard extends StatelessWidget {
  const StudyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: StudyTone.shadow,
      ),
      child: Material(
        color: StudyTone.card,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// الزر الرئيسي بالبنفسجي
class StudyButton extends StatelessWidget {
  const StudyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final leading = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: StudyTone.onPurple,
            ),
          )
        : (icon == null
              ? null
              : AppIcon(icon!, size: 20, color: StudyTone.onPurple));

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: StudyTone.purple,
        foregroundColor: StudyTone.onPurple,
        disabledBackgroundColor: StudyTone.purple.withValues(alpha: 0.4),
        disabledForegroundColor: StudyTone.onPurple,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 8)],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
