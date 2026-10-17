import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

// اتجاه النص حسب المحتوى (عربي = RTL)
final RegExp _rtlChars = RegExp(r'[֐-ࣿ]');

TextDirection textDirectionFor(String text) =>
    _rtlChars.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;

// حد أقصى لعرض المحتوى على الشاشات الكبيرة (تابلت / وضع أفقي)
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

// تنسيق الحجم والتاريخ (بدون حزم إضافية)
String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String formatDay(DateTime? date, AppStrings s) {
  if (date == null) return s.unknownDate;

  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(date.year, date.month, date.day))
      .inDays;

  if (days == 0) return s.today;
  if (days == 1) return s.yesterday;

  final month = s.monthsShort[date.month - 1];
  if (s.isArabic) {
    return date.year == now.year
        ? '${date.day} $month'
        : '${date.day} $month ${date.year}';
  }
  return date.year == now.year
      ? '$month ${date.day}'
      : '$month ${date.day}, ${date.year}';
}
