import 'package:flutter/material.dart';

import '../themes/app_theme.dart';

// عنوان الصفحة: سطر صغير فوق عنوان كبير + عنصر اختياري في الطرف الآخر
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.overline,
    this.trailing,
  });

  final String title;
  final String? overline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null)
                Text(
                  overline!,
                  style: AppText.caption.copyWith(color: AppColors.muted),
                ),
              Semantics(
                header: true,
                child: Text(title, style: AppText.display),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// عنوان قسم: شريط أصفر + نص (نفس أسلوب Home الأصلي)
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.action,
  });

  final String title;
  final String? trailing; // رقم صغير
  final Widget? action; // زر نصي مثل "See all"

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppText.tracked(context, AppText.label),
            ),
          ),
          if (trailing != null)
            AppPill(
              trailing!,
              background: AppColors.ink.withValues(alpha: 0.06),
              foreground: AppColors.ink,
            ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// وسم صغير بشكل حبة
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
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            text,
            style: AppText.tracked(
              context,
              AppText.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 0.5,
                fontFeatures: AppText.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// عنوان بسطرين للشريط العلوي في الشاشات الفرعية (Flashcards / Quiz)
class TwoLineTitle extends StatelessWidget {
  const TwoLineTitle({super.key, required this.overline, required this.title});

  final String overline;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          overline.toUpperCase(),
          style: AppText.tracked(
            context,
            AppText.caption.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontSize: 10.5,
            ),
          ),
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.headline,
        ),
      ],
    );
  }
}
