import 'package:flutter/material.dart';

// تنسيق النص على مقاطع (rich text): لكل مقطع من الأحرف لونه وعريضه ومائله وحجمه.
// تغيير التنسيق بلا تحديد يخص ما سيُكتب بعده فقط، ومع تحديد يخص المحدد فقط،
// فلا يتغير ما كُتب قبل ذلك أبدًا (طلب المستخدم 22 أكتوبر).

// نمط مقطع: كل قيمة null = نمط النص الأساسي (لونه وحجمه)
@immutable
class RunStyle {
  const RunStyle({
    this.color,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.scale = 1,
  });

  static const RunStyle plain = RunStyle();

  final int? color; // ARGB، null = لون النص الأساسي
  final bool bold;
  final bool italic;
  final bool underline;
  final double scale; // نسبة من حجم الخط الأساسي

  RunStyle copyWith({
    int? color,
    bool? bold,
    bool? italic,
    bool? underline,
    double? scale,
  }) => RunStyle(
    color: color ?? this.color,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    scale: scale ?? this.scale,
  );

  // يدمج مع نمط الأساس للرسم
  TextStyle apply(TextStyle base) {
    final size = base.fontSize;
    return base.copyWith(
      color: color == null ? null : Color(color!),
      fontWeight: bold ? FontWeight.bold : null,
      fontStyle: italic ? FontStyle.italic : null,
      decoration: underline ? TextDecoration.underline : null,
      decorationColor: color == null ? null : Color(color!),
      fontSize: size == null || scale == 1 ? null : size * scale,
    );
  }

  Map<String, Object?> toJson() => {
    'c': ?color,
    if (bold) 'b': 1,
    if (italic) 'i': 1,
    if (underline) 'u': 1,
    if (scale != 1) 's': double.parse(scale.toStringAsFixed(3)),
  };

  factory RunStyle.fromJson(Map<String, dynamic> json) => RunStyle(
    color: (json['c'] as num?)?.toInt(),
    bold: json['b'] == 1 || json['b'] == true,
    italic: json['i'] == 1 || json['i'] == true,
    underline: json['u'] == 1 || json['u'] == true,
    scale: (json['s'] as num?)?.toDouble() ?? 1,
  );

  @override
  bool operator ==(Object other) =>
      other is RunStyle &&
      other.color == color &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(color, bold, italic, underline, scale);
}

// مقطع: عدد أحرف بنمط واحد
@immutable
class StyledRun {
  const StyledRun(this.length, this.style);

  final int length;
  final RunStyle style;

  Map<String, Object?> toJson() => {'l': length, ...style.toJson()};

  factory StyledRun.fromJson(Map<String, dynamic> json) =>
      StyledRun((json['l'] as num).toInt(), RunStyle.fromJson(json));
}

// عمليات على قائمة المقاطع (مجموع أطوالها = طول النص)
abstract final class Runs {
  // يضم المقاطع المتجاورة المتشابهة ويحذف الفارغة
  static List<StyledRun> normalize(Iterable<StyledRun> runs) {
    final out = <StyledRun>[];
    for (final r in runs) {
      if (r.length <= 0) continue;
      if (out.isNotEmpty && out.last.style == r.style) {
        out[out.length - 1] = StyledRun(out.last.length + r.length, r.style);
      } else {
        out.add(r);
      }
    }
    return out;
  }

  static int lengthOf(List<StyledRun> runs) =>
      runs.fold(0, (sum, r) => sum + r.length);

  // نص بلا مقاطع محفوظة (الملاحظات القديمة): مقطع واحد بالنمط المعطى
  static List<StyledRun> uniform(
    int length, [
    RunStyle style = RunStyle.plain,
  ]) => length <= 0 ? const [] : [StyledRun(length, style)];

  // يضمن أن المقاطع تغطي الطول بالضبط (بيانات تالفة أو قديمة)
  static List<StyledRun> fit(List<StyledRun> runs, int length) {
    final total = lengthOf(runs);
    if (total == length) return normalize(runs);
    if (total > length) return slice(runs, 0, length);
    final last = runs.isEmpty ? RunStyle.plain : runs.last.style;
    return normalize([...runs, StyledRun(length - total, last)]);
  }

  // جزء من المقاطع بين موضعين
  static List<StyledRun> slice(List<StyledRun> runs, int start, int end) {
    final out = <StyledRun>[];
    var pos = 0;
    for (final r in runs) {
      final a = pos;
      final b = pos + r.length;
      pos = b;
      final from = a < start ? start : a;
      final to = b > end ? end : b;
      if (to > from) out.add(StyledRun(to - from, r.style));
    }
    return normalize(out);
  }

  static List<StyledRun> concat(List<StyledRun> a, List<StyledRun> b) =>
      normalize([...a, ...b]);

  // نمط الحرف عند موضع (للمؤشر: الحرف قبله)
  static RunStyle styleAt(List<StyledRun> runs, int offset) {
    if (runs.isEmpty) return RunStyle.plain;
    var pos = 0;
    for (final r in runs) {
      pos += r.length;
      if (offset < pos) return r.style;
    }
    return runs.last.style;
  }

  // استبدال [start, end) بنص طوله inserted بنمط واحد
  static List<StyledRun> replace(
    List<StyledRun> runs,
    int start,
    int end,
    int inserted,
    RunStyle style,
  ) {
    final total = lengthOf(runs);
    return normalize([
      ...slice(runs, 0, start),
      if (inserted > 0) StyledRun(inserted, style),
      ...slice(runs, end, total),
    ]);
  }

  // تغيير نمط مقطع [start, end) فقط
  static List<StyledRun> restyle(
    List<StyledRun> runs,
    int start,
    int end,
    RunStyle Function(RunStyle) change,
  ) {
    final total = lengthOf(runs);
    return normalize([
      ...slice(runs, 0, start),
      for (final r in slice(runs, start, end))
        StyledRun(r.length, change(r.style)),
      ...slice(runs, end, total),
    ]);
  }

  static List<Map<String, Object?>> toJson(List<StyledRun> runs) => [
    for (final r in runs) r.toJson(),
  ];

  static List<StyledRun>? fromJson(Object? raw) {
    if (raw is! List) return null;
    try {
      return [
        for (final item in raw)
          StyledRun.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  // رسم النص بمقاطعه فوق نمط الأساس
  static TextSpan span(String text, List<StyledRun> runs, TextStyle base) {
    final fitted = fit(runs, text.length);
    var pos = 0;
    return TextSpan(
      style: base,
      children: [
        for (final r in fitted)
          TextSpan(
            text: text.substring(pos, pos += r.length),
            style: r.style == RunStyle.plain ? null : r.style.apply(base),
          ),
      ],
    );
  }
}

// متحكم نص بمقاطع: يتتبع الكتابة والحذف واللصق، ويعطي الأحرف الجديدة نمط
// الكتابة الحالي (أو نمط الحرف قبلها إن لم يُختر نمط جديد)، ويرسم المقاطع.
class StyledTextController extends TextEditingController {
  StyledTextController({super.text, List<StyledRun>? runs})
    : _runs = Runs.fit(
        runs ?? Runs.uniform(text?.length ?? 0),
        text?.length ?? 0,
      );

  List<StyledRun> _runs;
  RunStyle? _typing; // نمط اختاره المستخدم لما سيُكتب (بلا تحديد)

  List<StyledRun> get runs => _runs;

  // يستبدل النص ومقاطعه معًا (من الكود: تقسيم أو دمج أسطر)
  void setStyled(String text, List<StyledRun> runs, {int? cursor}) {
    _runs = Runs.fit(runs, text.length);
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );
  }

  // النمط الذي ستأخذه الأحرف التالية
  RunStyle get typingStyle {
    if (_typing != null) return _typing!;
    final at = selection.isValid ? selection.start : text.length;
    return at <= 0 ? Runs.styleAt(_runs, 0) : Runs.styleAt(_runs, at - 1);
  }

  // نمط التحديد (أول حرف فيه) أو نمط الكتابة، لإظهار الأزرار المفعلة
  RunStyle get activeStyle {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) return Runs.styleAt(_runs, sel.start);
    return typingStyle;
  }

  // تغيير نمط: على التحديد فقط، أو على ما سيُكتب إن لم يكن تحديد
  void applyStyle(RunStyle Function(RunStyle) change) {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      _runs = Runs.restyle(_runs, sel.start, sel.end, change);
      notifyListeners();
    } else {
      _typing = change(typingStyle);
      notifyListeners();
    }
  }

  @override
  set value(TextEditingValue next) {
    final old = super.value;
    if (next.text != old.text) {
      // الفرق بين النصين: بادئة ولاحقة مشتركتان، وما بينهما تغيّر
      final a = old.text;
      final b = next.text;
      var prefix = 0;
      final maxPrefix = a.length < b.length ? a.length : b.length;
      while (prefix < maxPrefix &&
          a.codeUnitAt(prefix) == b.codeUnitAt(prefix)) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < a.length - prefix &&
          suffix < b.length - prefix &&
          a.codeUnitAt(a.length - 1 - suffix) ==
              b.codeUnitAt(b.length - 1 - suffix)) {
        suffix++;
      }
      final removedEnd = a.length - suffix;
      final inserted = b.length - suffix - prefix;
      final style =
          _typing ??
          (prefix > 0
              ? Runs.styleAt(_runs, prefix - 1)
              : Runs.styleAt(_runs, 0));
      _runs = Runs.replace(_runs, prefix, removedEnd, inserted, style);
      // نمط الكتابة المختار يبقى لما يُكتب بعده حتى يتحرك المؤشر
    } else if (next.selection != old.selection) {
      // تحريك المؤشر يلغي نمط الكتابة المؤقت: يتبع التنسيق في المكان الجديد
      _typing = null;
    }
    super.value = next;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final span = Runs.span(text, _runs, base);
    // الكلمة التي تُركّب الآن (لوحات مثل العربية) بخط تحتها كالمعتاد
    final composing = value.composing;
    if (!withComposing || !composing.isValid || composing.isCollapsed) {
      return span;
    }
    final parts = <InlineSpan>[];
    var pos = 0;
    for (final child in span.children!.cast<TextSpan>()) {
      final t = child.text!;
      final start = pos;
      final end = pos + t.length;
      pos = end;
      final cs = composing.start.clamp(start, end);
      final ce = composing.end.clamp(start, end);
      if (cs >= ce) {
        parts.add(child);
        continue;
      }
      final s = child.style ?? const TextStyle();
      if (cs > start) {
        parts.add(
          TextSpan(text: t.substring(0, cs - start), style: child.style),
        );
      }
      parts.add(
        TextSpan(
          text: t.substring(cs - start, ce - start),
          style: s.merge(const TextStyle(decoration: TextDecoration.underline)),
        ),
      );
      if (ce < end) {
        parts.add(TextSpan(text: t.substring(ce - start), style: child.style));
      }
    }
    return TextSpan(style: base, children: parts);
  }
}
