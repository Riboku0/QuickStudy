import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

// اتجاه النص حسب المحتوى بقاعدة "أول حرف قوي" (مثل dir=auto في الويب):
// أول حرف (لا رقم ولا رمز ولا مسافة) يحدد الاتجاه. الكتابات من اليمين:
// العبرية والعربية (ومنها الفارسية والأردية) والسريانية والثانا والنكو وما يتبعها،
// وأي لغة أخرى من اليسار.
final RegExp _firstLetter = RegExp(r'\p{L}', unicode: true);
final RegExp _rtlLetter = RegExp(
  r'[֐-ࣿיִ-﷿ﹰ-﻿\u{10800}-\u{10FFF}\u{1E800}-\u{1EFFF}]',
  unicode: true,
);

// null إن لم يكن في النص حرف بعد (فارغ أو أرقام فقط)
TextDirection? strongDirection(String text) {
  final letter = _firstLetter.firstMatch(text)?.group(0);
  if (letter == null) return null;
  return _rtlLetter.hasMatch(letter) ? TextDirection.rtl : TextDirection.ltr;
}

TextDirection textDirectionFor(String text) =>
    strongDirection(text) ?? TextDirection.ltr;

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
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;

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
