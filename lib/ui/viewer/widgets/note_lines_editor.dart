import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/core_ui.dart';

// محرر المذكرة سطرًا سطرًا: كل سطر حقل مستقل يأخذ اتجاهه من أول حرف فيه
// (عربي من اليمين، إنجليزي من اليسار، وأي لغة بقاعدتها)، والسطر الفارغ يأخذ
// اتجاه السطر قبله. Enter يقسم السطر، والحذف في أول السطر يدمجه مع السابق،
// ولمسة في الفراغ تحت النص تضيف أسطرًا حتى مكانها وتكتب فيه.
//
// لوحات مفاتيح أندرويد لا ترسل زر الحذف في حقل فارغ، فكل حقل يبدأ بحرف خفي
// (_mark): حذفه يعني "احذف قبل السطر" فيُدمج مع السابق.
const _mark = '​';

class NoteLinesEditor extends StatefulWidget {
  const NoteLinesEditor({
    super.key,
    required this.text,
    required this.style,
    required this.cursorColor,
    required this.onChanged,
    this.readOnly = false,
    this.autofocus = false,
    this.padding = 10,
  });

  final String text; // النص الأول فقط (التحديثات بعدها من المحرر نفسه)
  final TextStyle style;
  final Color cursorColor;
  final ValueChanged<String> onChanged;
  final bool readOnly;
  final bool autofocus;
  final double padding;

  @override
  State<NoteLinesEditor> createState() => _NoteLinesEditorState();
}

class _Line {
  _Line(String text)
    : controller = TextEditingController(text: '$_mark$text'),
      focus = FocusNode();

  final TextEditingController controller;
  final FocusNode focus;

  String get text => controller.text.replaceAll(_mark, '');

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _NoteLinesEditorState extends State<NoteLinesEditor> {
  final List<_Line> _lines = [];
  bool _syncing = false; // تعديل من الكود نفسه: لا نعالجه كأنه كتابة

  @override
  void initState() {
    super.initState();
    for (final t in widget.text.split('\n')) {
      _add(_lines.length, t);
    }
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusEnd(_lines.last),
      );
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  _Line _add(int at, String text) {
    final line = _Line(text);
    line.controller.addListener(() => _onEdit(line));
    _lines.insert(at, line);
    return line;
  }

  void _remove(_Line line) {
    _lines.remove(line);
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

  void _set(_Line line, String text, {int? cursor}) {
    _syncing = true;
    line.controller.value = TextEditingValue(
      text: '$_mark$text',
      selection: TextSelection.collapsed(offset: 1 + (cursor ?? text.length)),
    );
    _syncing = false;
  }

  void _notify() => widget.onChanged(_lines.map((l) => l.text).join('\n'));

  void _onEdit(_Line line) {
    if (_syncing || !_lines.contains(line)) return;
    final value = line.controller.value;
    final raw = value.text;
    final index = _lines.indexOf(line);

    // حُذف الحرف الخفي: حذف قبل السطر = دمجه مع السابق
    if (!raw.startsWith(_mark)) {
      final rest = raw.replaceAll(_mark, '');
      if (index == 0) {
        _set(line, rest, cursor: 0);
      } else {
        final prev = _lines[index - 1];
        final join = prev.text.length;
        _set(prev, prev.text + rest, cursor: join);
        _remove(line);
        setState(() {});
        _focusAt(prev, join + 1);
      }
      _notify();
      return;
    }

    // سطر جديد (Enter أو لصق نص بعدة أسطر): يُقسم على حقول
    if (raw.contains('\n')) {
      final cursor = value.selection.baseOffset;
      final parts = raw.substring(1).split('\n');
      _set(line, parts.first);
      var last = line;
      for (var i = 1; i < parts.length; i++) {
        last = _add(index + i, parts[i]);
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
      line.controller.selection = const TextSelection.collapsed(offset: 1);
    }
    setState(() {}); // الاتجاه قد يتبدل مع أول حرف
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

    var target = last;
    if (count == 0) {
      _set(last, indent);
    } else {
      for (var i = 0; i < count; i++) {
        target = _add(_lines.length, i == count - 1 ? indent : '');
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
