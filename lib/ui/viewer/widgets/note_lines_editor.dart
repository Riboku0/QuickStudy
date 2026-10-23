import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/core_ui.dart';
import 'styled_text.dart';

// محرر المذكرة سطرًا سطرًا: كل سطر حقل مستقل يأخذ اتجاهه من أول حرف فيه
// (عربي من اليمين، إنجليزي من اليسار، وأي لغة بقاعدتها)، والسطر الفارغ يأخذ
// اتجاه السطر قبله. Enter يقسم السطر، والحذف في أول السطر يدمجه مع السابق،
// ولمسة في الفراغ تحت النص تضيف أسطرًا حتى مكانها وتكتب فيه.
//
// التنسيق على مقاطع (styled_text.dart): اللون والعريض والمائل والحجم تخص
// المحدد فقط، أو ما سيُكتب بعدها إن لم يكن تحديد، والسطر الجديد يرث نمط الكتابة.
// التحديد داخل سطر واحد (كل سطر حقل باتجاهه، اختيار المستخدم 22 أكتوبر).
//
// لوحات مفاتيح أندرويد لا ترسل زر الحذف في حقل فارغ، فكل حقل يبدأ بحرف خفي
// (_mark): حذفه يعني "احذف قبل السطر" فيُدمج مع السابق.
const _mark = '​';

// يصل إلى السطر الذي يُكتب فيه الآن لتغيير التنسيق من خارج المحرر
class NoteLinesController extends ChangeNotifier {
  _NoteLinesEditorState? _state;

  // نمط التحديد أو الكتابة في السطر الحالي (لإظهار الأزرار المفعلة)
  RunStyle get activeStyle =>
      _state?._active?.controller.activeStyle ?? RunStyle.plain;

  void applyStyle(RunStyle Function(RunStyle) change) =>
      _state?._applyStyle(change);

  void _changed() => notifyListeners();
}

class NoteLinesEditor extends StatefulWidget {
  const NoteLinesEditor({
    super.key,
    required this.text,
    this.runs,
    required this.style,
    required this.cursorColor,
    required this.onChanged,
    this.controller,
    this.readOnly = false,
    this.autofocus = false,
    this.padding = 10,
  });

  final String text; // النص الأول فقط (التحديثات بعدها من المحرر نفسه)
  final List<StyledRun>? runs; // مقاطعه (null = ملاحظة قديمة بلا تنسيق)
  final TextStyle style;
  final Color cursorColor;
  // النص كاملًا بأسطره ومقاطعه على النص نفسه (الفواصل ضمنها)
  final void Function(String text, List<StyledRun> runs) onChanged;
  final NoteLinesController? controller;
  final bool readOnly;
  final bool autofocus;
  final double padding;

  @override
  State<NoteLinesEditor> createState() => _NoteLinesEditorState();
}

class _Line {
  _Line(String text, List<StyledRun> runs, RunStyle markStyle)
    : controller = StyledTextController(
        text: '$_mark$text',
        runs: Runs.concat([StyledRun(1, markStyle)], runs),
      ),
      focus = FocusNode();

  final StyledTextController controller;
  final FocusNode focus;

  String get text => controller.text.replaceAll(_mark, '');

  // مقاطع النص بلا الحرف الخفي
  List<StyledRun> get runs {
    final raw = controller.text;
    final all = controller.runs;
    return raw.startsWith(_mark) ? Runs.slice(all, 1, raw.length) : all;
  }

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _NoteLinesEditorState extends State<NoteLinesEditor> {
  final List<_Line> _lines = [];
  bool _syncing = false; // تعديل من الكود نفسه: لا نعالجه كأنه كتابة
  _Line? _active; // السطر الذي فيه المؤشر

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    final texts = widget.text.split('\n');
    final all = Runs.fit(
      widget.runs ?? Runs.uniform(widget.text.length),
      widget.text.length,
    );
    var pos = 0;
    for (final t in texts) {
      final runs = Runs.slice(all, pos, pos + t.length);
      // نمط الحرف الخفي = نمط أول حرف في السطر (أو آخر حرف قبله إن كان فارغًا)
      final mark = t.isEmpty
          ? (pos > 0 ? Runs.styleAt(all, pos - 1) : Runs.styleAt(all, 0))
          : Runs.styleAt(all, pos);
      _add(_lines.length, t, runs, mark);
      pos += t.length + 1;
    }
    _active = _lines.last;
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusEnd(_lines.last),
      );
    }
  }

  @override
  void didUpdateWidget(NoteLinesEditor old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  _Line _add(int at, String text, List<StyledRun> runs, RunStyle mark) {
    final line = _Line(text, runs, mark);
    line.controller.addListener(() => _onEdit(line));
    line.focus.addListener(() {
      if (line.focus.hasFocus) {
        _active = line;
        widget.controller?._changed();
      }
    });
    _lines.insert(at, line);
    return line;
  }

  void _remove(_Line line) {
    _lines.remove(line);
    if (_active == line) _active = null;
    // بعد الإطار: الحقل ما زال يُرسم في هذا الإطار
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  void _focusAt(_Line line, int offset) {
    line.focus.requestFocus();
    line.controller.selection = TextSelection.collapsed(
      offset: offset.clamp(1, line.controller.text.length),
    );
  }

  void _focusEnd(_Line line) => _focusAt(line, line.controller.text.length);

  // نص السطر ومقاطعه من الكود (cursor بلا الحرف الخفي)
  void _set(_Line line, String text, List<StyledRun> runs, {int? cursor}) {
    _syncing = true;
    final mark = runs.isEmpty
        ? Runs.styleAt(line.controller.runs, 0)
        : runs.first.style;
    line.controller.setStyled(
      '$_mark$text',
      Runs.concat([StyledRun(1, mark)], runs),
      cursor: 1 + (cursor ?? text.length),
    );
    _syncing = false;
  }

  void _notify() {
    final text = _lines.map((l) => l.text).join('\n');
    final runs = <StyledRun>[];
    for (final (i, l) in _lines.indexed) {
      if (i > 0) {
        // الفاصل بين سطرين بنمط آخر حرف قبله
        runs.add(StyledRun(1, runs.isEmpty ? RunStyle.plain : runs.last.style));
      }
      runs.addAll(l.runs);
    }
    widget.onChanged(text, Runs.fit(runs, text.length));
  }

  void _applyStyle(RunStyle Function(RunStyle) change) {
    final line = _active ?? _lines.last;
    if (line.text.isEmpty) {
      // سطر فارغ: الحرف الخفي يحمل النمط فيأخذه ما يُكتب ويرثه السطر التالي
      final next = change(line.controller.typingStyle);
      _syncing = true;
      line.controller.setStyled(_mark, [StyledRun(1, next)], cursor: 1);
      _syncing = false;
    } else {
      line.controller.applyStyle(change);
    }
    setState(() {});
    widget.controller?._changed();
    _notify();
  }

  void _onEdit(_Line line) {
    if (_syncing || !_lines.contains(line)) return;
    final c = line.controller;
    final value = c.value;
    final raw = value.text;
    final index = _lines.indexOf(line);

    // حُذف الحرف الخفي: حذف قبل السطر = دمجه مع السابق
    if (!raw.startsWith(_mark)) {
      final restRuns = c.runs; // النص كله بلا الحرف الخفي
      final rest = raw.replaceAll(_mark, '');
      if (index == 0) {
        _set(line, rest, Runs.fit(restRuns, rest.length), cursor: 0);
      } else {
        final prev = _lines[index - 1];
        final join = prev.text.length;
        _set(
          prev,
          prev.text + rest,
          Runs.concat(prev.runs, Runs.fit(restRuns, rest.length)),
          cursor: join,
        );
        _remove(line);
        setState(() {});
        _focusAt(prev, join + 1);
      }
      _notify();
      return;
    }

    // سطر جديد (Enter أو لصق نص بعدة أسطر): يُقسم على حقول، وكل جزء بمقاطعه
    if (raw.contains('\n')) {
      final cursor = value.selection.baseOffset;
      final all = c.runs;
      final parts = raw.substring(1).split('\n');
      var pos = 1;
      final pieces = <(String, List<StyledRun>, RunStyle)>[];
      for (final part in parts) {
        final runs = Runs.slice(all, pos, pos + part.length);
        // السطر الجديد يرث نمط ما قبله (نمط الكتابة)
        final mark = pos > 0 ? Runs.styleAt(all, pos - 1) : RunStyle.plain;
        pieces.add((part, runs, mark));
        pos += part.length + 1;
      }
      _set(line, pieces.first.$1, pieces.first.$2);
      var last = line;
      for (var i = 1; i < pieces.length; i++) {
        final (t, r, m) = pieces[i];
        last = _add(index + i, t, r, m);
      }
      setState(() {});
      // المؤشر في بداية ما بعد آخر فاصل (حيث كان بعد Enter)
      final tail = raw.length - cursor;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusAt(last, last.controller.text.length - tail),
      );
      _notify();
      return;
    }

    // المؤشر لا يقف قبل الحرف الخفي
    if (value.selection.isCollapsed && value.selection.baseOffset == 0) {
      c.selection = const TextSelection.collapsed(offset: 1);
    }
    setState(() {}); // الاتجاه قد يتبدل مع أول حرف
    widget.controller?._changed(); // الأزرار المفعلة تتبع المؤشر
    _notify();
  }

  // اتجاه السطر من أول حرف فيه، والفارغ من السطر قبله، ثم لغة التطبيق
  TextDirection _directionOf(int index) {
    for (var i = index; i >= 0; i--) {
      final d = strongDirection(_lines[i].text);
      if (d != null) return d;
    }
    return Directionality.of(context);
  }

  // لمسة في الفراغ تحت آخر سطر: أسطر فارغة حتى مكانها، ومسافات حتى موضعها
  void _tapBelow(Offset local, double width) {
    if (widget.readOnly) return;
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    final lineHeight = painter.preferredLineHeight;
    final space = math.max(1.0, painter.width);
    painter.dispose();

    final last = _lines.last;
    final count = (local.dy / lineHeight).floor() + (last.text.isEmpty ? 0 : 1);
    final dir = _directionOf(_lines.length - 1);
    final fromStart = dir == TextDirection.rtl
        ? width - widget.padding - local.dx
        : local.dx - widget.padding;
    final spaces = (fromStart / space).floor();
    final indent = spaces > 1 ? ' ' * spaces : '';
    // الأسطر الجديدة بنمط آخر حرف في المذكرة
    final style = last.controller.typingStyle;
    final indentRuns = Runs.uniform(indent.length, style);

    var target = last;
    if (count == 0) {
      _set(last, indent, indentRuns);
    } else {
      for (var i = 0; i < count; i++) {
        final isLast = i == count - 1;
        target = _add(
          _lines.length,
          isLast ? indent : '',
          isLast ? indentRuns : const [],
          style,
        );
      }
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusEnd(target));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.padding;
    return LayoutBuilder(
      builder: (context, box) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
            sliver: SliverList.builder(
              itemCount: _lines.length,
              itemBuilder: (context, i) {
                final line = _lines[i];
                final dir = _directionOf(i);
                return TextField(
                  key: ObjectKey(line),
                  controller: line.controller,
                  focusNode: line.focus,
                  readOnly: widget.readOnly,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  cursorColor: widget.cursorColor,
                  textDirection: dir,
                  textAlign: TextAlign.start,
                  style: widget.style,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                  ),
                );
              },
            ),
          ),
          // باقي المساحة: لمسة فيها تكتب في مكانها
          SliverFillRemaining(
            hasScrollBody: false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _tapBelow(d.localPosition, box.maxWidth),
              child: SizedBox(height: math.max(pad, 48)),
            ),
          ),
        ],
      ),
    );
  }
}
