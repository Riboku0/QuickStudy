import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// اتجاه النص: عربي (RTL) أو إنجليزي (LTR) حسب المحتوى
// ---------------------------------------------------------------------------

final RegExp _rtlChars = RegExp(r'[֐-ࣿ]');

TextDirection textDirectionFor(String text) =>
    _rtlChars.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;

// ---------------------------------------------------------------------------
// صندوق بحدود سميكة وظل صلب، ينضغط عند اللمس إن كان قابلًا للضغط
// ---------------------------------------------------------------------------

class BrutalBox extends StatefulWidget {
  const BrutalBox({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.shadow = true,
    this.semanticLabel,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool shadow;
  final String? semanticLabel;

  @override
  State<BrutalBox> createState() => _BrutalBoxState();
}

class _BrutalBoxState extends State<BrutalBox> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);
    final interactive = widget.onTap != null;
    final pressed = interactive && _pressed;
    final offset = widget.shadow ? t.shadowOffset : 0.0;

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(
        pressed ? offset : 0,
        pressed ? offset : 0,
        0,
      ),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? t.surface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.ink, width: t.borderWidth),
        boxShadow: widget.shadow && !pressed
            ? [BoxShadow(color: t.ink, offset: Offset(offset, offset))]
            : const [],
      ),
      child: widget.child,
    );

    // مساحة للظل حتى لا يُقص
    final spaced = Padding(
      padding: EdgeInsets.only(right: offset, bottom: offset),
      child: box,
    );

    if (!interactive) return spaced;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: spaced,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// زر
// ---------------------------------------------------------------------------

enum BrutalVariant { dark, accent, light }

class BrutalButton extends StatelessWidget {
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = BrutalVariant.dark,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BrutalVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);

    final (background, foreground) = switch (variant) {
      BrutalVariant.dark => (t.ink, t.surface),
      BrutalVariant.accent => (t.accent, t.ink),
      BrutalVariant.light => (t.surface, t.ink),
    };

    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: BrutalBox(
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onPressed,
        semanticLabel: label,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// وسم صغير
// ---------------------------------------------------------------------------

class BrutalTag extends StatelessWidget {
  const BrutalTag(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.ink, width: 2),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: t.ink,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          height: 1.1,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// شريط تقدم
// ---------------------------------------------------------------------------

class BrutalProgressBar extends StatelessWidget {
  const BrutalProgressBar({super.key, required this.value});

  final double value; // 0..1

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);
    final v = value.clamp(0.0, 1.0).toDouble();

    return Semantics(
      value: '${(v * 100).round()}%',
      child: Container(
        height: 16,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.radius),
          border: Border.all(color: t.ink, width: t.borderWidth),
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            widthFactor: v,
            heightFactor: 1,
            child: ColoredBox(color: t.accent),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// عنوان قسم مع خط
// ---------------------------------------------------------------------------

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);
    final style = TextStyle(
      color: t.ink,
      fontSize: 13,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
    );

    return Row(
      children: [
        Text(text.toUpperCase(), style: style),
        const SizedBox(width: 10),
        Expanded(child: Container(height: t.borderWidth, color: t.ink)),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Text(trailing!, style: style),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// حالة فارغة / خطأ
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
    final t = BrutalTheme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(t.radius),
                border: Border.all(color: t.ink, width: t.borderWidth),
              ),
              child: Icon(icon, size: 36, color: t.ink),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              BrutalButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// شريط علوي للصفحات الفرعية (Flashcards / Quiz)
// ---------------------------------------------------------------------------

PreferredSizeWidget brutalAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
}) {
  final t = BrutalTheme.of(context);

  return AppBar(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    foregroundColor: t.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleSpacing: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitle != null)
          Text(
            subtitle.toUpperCase(),
            style: TextStyle(
              color: t.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: t.ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
    bottom: PreferredSize(
      preferredSize: Size.fromHeight(t.borderWidth),
      child: Container(height: t.borderWidth, color: t.ink),
    ),
  );
}
