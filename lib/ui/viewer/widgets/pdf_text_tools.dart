import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/ui/core_ui.dart';
import 'pdf_notes.dart';
import 'reader_chrome.dart';

// خطوط النص (نفس قائمة العارض القديم)
typedef NoteFont = ({String id, String label, String? google});

const List<NoteFont> noteFonts = [
  (id: 'default', label: 'Default', google: null),
  (id: 'cairo', label: 'القاهرة', google: 'Cairo'),
  (id: 'tajawal', label: 'تجوّل', google: 'Tajawal'),
  (id: 'amiri', label: 'أميري', google: 'Amiri'),
  (id: 'naskh', label: 'نسخ', google: 'Noto Naskh Arabic'),
  (id: 'kufi', label: 'كوفي', google: 'Noto Kufi Arabic'),
  (id: 'reem', label: 'ريم كوفي', google: 'Reem Kufi'),
  (id: 'almarai', label: 'المرعي', google: 'Almarai'),
  (id: 'messiri', label: 'المسيري', google: 'El Messiri'),
  (id: 'lalezar', label: 'لالزار', google: 'Lalezar'),
  (id: 'ruqaa', label: 'رقعة', google: 'Aref Ruqaa'),
  (id: 'lateef', label: 'لطيف', google: 'Lateef'),
  (id: 'mada', label: 'مدى', google: 'Mada'),
  (id: 'changa', label: 'شانغا', google: 'Changa'),
  (id: 'markazi', label: 'مركزي', google: 'Markazi Text'),
  (id: 'scheherazade', label: 'شهرزاد', google: 'Scheherazade New'),
  (id: 'rakkas', label: 'رقّاص', google: 'Rakkas'),
  (id: 'katibeh', label: 'كاتبة', google: 'Katibeh'),
  (id: 'lemonada', label: 'ليمونادا', google: 'Lemonada'),
  (id: 'harmattan', label: 'هرمتان', google: 'Harmattan'),
  (id: 'serif', label: 'Serif', google: null),
  (id: 'mono', label: 'Mono', google: null),
  (id: 'playfair', label: 'Playfair', google: 'Playfair Display'),
  (id: 'robotoslab', label: 'Roboto Slab', google: 'Roboto Slab'),
  (id: 'bebas', label: 'BEBAS', google: 'Bebas Neue'),
  (id: 'pacifico', label: 'Pacifico', google: 'Pacifico'),
];

const List<int> _textColors = [
  0xFF202020,
  0xFFFFFFFF,
  0xFFE53935,
  0xFFFB8C00,
  0xFFFDD835,
  0xFF43A047,
  0xFF1E88E5,
  0xFF8E24AA,
];

const List<int> _bgColors = [
  0xFFFFFFFF,
  0xFFFFF59D,
  0xFFC8E6C9,
  0xFFBBDEFB,
  0xFFF8BBD0,
  0xFFFFE0B2,
  0xFF202020,
];

enum _Tab { font, size, color, background, style, align, opacity, rotate }

// شريط تنسيق النص (مثل العارض القديم): صف تبويبات بالأيقونات وتحته أدوات التبويب.
// يظهر أسفل الشاشة فوق لوحة المفاتيح أثناء كتابة النص.
class NoteToolbar extends StatefulWidget {
  const NoteToolbar({
    super.key,
    required this.note,
    required this.chrome,
    required this.onChanged,
    required this.onDelete,
    required this.onDone,
  });

  final PageNote note;
  final ReaderChrome chrome;
  final VoidCallback onChanged; // بعد كل تغيير (إعادة رسم + حفظ)
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  State<NoteToolbar> createState() => _NoteToolbarState();
}

class _NoteToolbarState extends State<NoteToolbar> {
  _Tab _tab = _Tab.font;

  PageNote get n => widget.note;

  void _set(void Function() change) {
    setState(change);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = widget.chrome;

    Widget tab(_Tab t, Widget icon, String tooltip) {
      final selected = _tab == t;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => setState(() => _tab = t),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 42,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? c.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  color: selected ? c.strong : c.ink,
                  size: 20,
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: selected ? c.strong : c.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: c.surface,
      elevation: 10,
      shadowColor: Colors.black38,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 50, child: _tools(c, s)),
              Divider(height: 8, color: c.line),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          tab(_Tab.font, const Text('Aa'), s.noteFont),
                          tab(
                            _Tab.size,
                            const Icon(Icons.format_size),
                            s.textSize,
                          ),
                          tab(
                            _Tab.color,
                            const Icon(Icons.format_color_text),
                            s.noteColor,
                          ),
                          tab(
                            _Tab.background,
                            const Icon(Icons.format_color_fill),
                            s.noteBackground,
                          ),
                          tab(
                            _Tab.style,
                            const Icon(Icons.format_bold),
                            s.noteStyle,
                          ),
                          tab(
                            _Tab.align,
                            const Icon(Icons.format_align_center),
                            s.noteAlign,
                          ),
                          tab(
                            _Tab.opacity,
                            const Icon(Icons.opacity),
                            s.noteOpacity,
                          ),
                          tab(
                            _Tab.rotate,
                            const Icon(Icons.rotate_right),
                            s.noteRotate,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: s.delete,
                    onPressed: widget.onDelete,
                    icon: AppIcon(AppIcons.trash, size: 21, color: c.ink),
                  ),
                  IconButton(
                    tooltip: s.done,
                    onPressed: widget.onDone,
                    icon: AppIcon(AppIcons.check, size: 22, color: c.strong),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // أدوات التبويب المختار
  Widget _tools(ReaderChrome c, AppStrings s) {
    Widget chip(
      String label,
      bool selected,
      VoidCallback onTap, {
      TextStyle? style,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent : c.chip,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? c.strong : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: (style ?? const TextStyle()).copyWith(
              color: selected ? c.strong : c.ink,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );

    Widget swatch(int? color, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color == null ? c.chip : Color(color),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? c.strong : c.line,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: color == null
              ? Icon(Icons.block, size: 18, color: c.muted)
              : null,
        ),
      ),
    );

    Widget slider(
      double value,
      double min,
      double max,
      ValueChanged<double> on,
    ) => SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: c.strong,
        inactiveTrackColor: c.chip,
        thumbColor: c.strong,
        overlayColor: c.accent,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: on,
      ),
    );

    Widget toggle(IconData icon, bool on, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46,
          height: 40,
          decoration: BoxDecoration(
            color: on ? c.accent : c.chip,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? c.strong : Colors.transparent),
          ),
          child: Icon(icon, color: on ? c.strong : c.ink),
        ),
      ),
    );

    switch (_tab) {
      case _Tab.font:
        return ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final f in noteFonts)
              chip(
                f.label,
                n.font == f.id,
                () => _set(() => n.font = f.id),
                style: f.google == null
                    ? TextStyle(
                        fontFamily: f.id == 'serif'
                            ? 'serif'
                            : (f.id == 'mono' ? 'monospace' : null),
                      )
                    : GoogleFonts.getFont(f.google!),
              ),
          ],
        );
      case _Tab.size:
        // حجم الخط نسبة من عرض الصفحة (0.015 – 0.12)
        return slider(n.size, 0.015, 0.12, (v) => _set(() => n.size = v));
      case _Tab.color:
        return ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final col in _textColors)
              swatch(col, n.color == col, () => _set(() => n.color = col)),
          ],
        );
      case _Tab.background:
        return ListView(
          scrollDirection: Axis.horizontal,
          children: [
            swatch(null, n.bg == null, () => _set(() => n.bg = null)),
            for (final col in _bgColors)
              swatch(col, n.bg == col, () => _set(() => n.bg = col)),
          ],
        );
      case _Tab.style:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            toggle(
              Icons.format_bold,
              n.bold,
              () => _set(() => n.bold = !n.bold),
            ),
            toggle(
              Icons.format_italic,
              n.italic,
              () => _set(() => n.italic = !n.italic),
            ),
            toggle(
              Icons.format_underline,
              n.underline,
              () => _set(() => n.underline = !n.underline),
            ),
          ],
        );
      case _Tab.align:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            toggle(
              Icons.auto_awesome,
              n.align == 0,
              () => _set(() => n.align = 0),
            ),
            toggle(
              Icons.format_align_left,
              n.align == 1,
              () => _set(() => n.align = 1),
            ),
            toggle(
              Icons.format_align_center,
              n.align == 2,
              () => _set(() => n.align = 2),
            ),
            toggle(
              Icons.format_align_right,
              n.align == 3,
              () => _set(() => n.align = 3),
            ),
          ],
        );
      case _Tab.opacity:
        return slider(n.opacity, 0.15, 1, (v) => _set(() => n.opacity = v));
      case _Tab.rotate:
        // من -180 إلى 180 درجة
        return slider(n.rot, -3.1416, 3.1416, (v) => _set(() => n.rot = v));
    }
  }
}
