import 'package:flutter/material.dart';

import '../../../data/repositories/reader/reader_settings_repository.dart';
import '../../../domain/models/reader_settings.dart';
import '../../core/l10n/app_strings.dart';
import 'reader_chrome.dart';

// ألوان ورق العارض
extension ReaderBackgroundColor on ReaderBackground {
  Color get color => switch (this) {
    // درجات هادئة مأخوذة من صفحات مرجع المستخدم (لا من دوائر الاختيار)
    ReaderBackground.classic => const Color(0xFFF8F1E4),
    ReaderBackground.green => const Color(0xFFE9F2E5),
    ReaderBackground.blue => const Color(0xFFE8F0F7),
    ReaderBackground.light => const Color(0xFFFBF7F4),
    ReaderBackground.warm => const Color(0xFFF9ECE2),
    ReaderBackground.dark => const Color(0xFF262B29),
  };

  bool get isDark => this == ReaderBackground.dark;
}

// لوحة إعدادات القراءة (تفتح من زر الإعدادات في العارض)
// كل تغيير يُطبَّق فورًا ويُحفظ لكل الكتب. ألوانها تتبع الليلي والنهاري.
class ReaderSettingsSheet extends StatelessWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.repository,
    this.showLayout = true,
  });

  final ReaderSettingsRepository repository;
  // مفتاح القراءة العامودية/الأفقية (العارض الجديد عامودي فقط حاليًا)
  final bool showLayout;

  static Future<void> show(
    BuildContext context,
    ReaderSettingsRepository repository, {
    bool showLayout = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // فوق شريط أزرار أندرويد (التطبيق يخفي شريط الحالة فقط)
      useSafeArea: true,
      // اللون من داخل اللوحة (يتغير فورًا مع الوضع الليلي)
      backgroundColor: Colors.transparent,
      // بدون تعتيم حتى ترى أثر التغيير على الصفحة
      barrierColor: Colors.transparent,
      builder: (_) =>
          ReaderSettingsSheet(repository: repository, showLayout: showLayout),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final r = repository.settings;
        void set(ReaderSettings value) => repository.update(value);
        final c = ReaderChrome(
          dark: r.nightMode || r.background.isDark,
          // الليلي له ورق كحلي موحّد (الافتراضي في ReaderChrome)
          paper: r.nightMode ? null : r.background.color,
        );
        final labelStyle = TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: c.ink,
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                22,
                12,
                22,
                20 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.readerSettings,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // السطوع
                  Row(
                    children: [
                      Icon(Icons.wb_sunny_outlined, size: 18, color: c.muted),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: c.strong,
                            inactiveTrackColor: c.chip,
                            thumbColor: c.strong,
                            overlayColor: c.accent,
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: r.brightness,
                            min: ReaderSettings.minBrightness,
                            max: 1,
                            semanticFormatterCallback: (v) =>
                                '${s.brightness} ${(v * 100).round()}%',
                            onChanged: (v) => set(r.copyWith(brightness: v)),
                          ),
                        ),
                      ),
                      Icon(Icons.wb_sunny, size: 24, color: c.strong),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // الهوامش
                  Row(
                    children: [
                      Expanded(child: Text(s.margins, style: labelStyle)),
                      Container(
                        height: 40,
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          end: 6,
                        ),
                        decoration: BoxDecoration(
                          color: c.chip,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ReaderMargin>(
                            value: r.margin,
                            borderRadius: BorderRadius.circular(14),
                            dropdownColor: c.surface,
                            icon: Icon(Icons.arrow_drop_down, color: c.ink),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                            items: [
                              for (final m in ReaderMargin.values)
                                DropdownMenuItem(
                                  value: m,
                                  child: Text(switch (m) {
                                    ReaderMargin.none => s.marginNone,
                                    ReaderMargin.standard => s.marginStandard,
                                    ReaderMargin.wide => s.marginWide,
                                  }),
                                ),
                            ],
                            onChanged: (m) {
                              if (m != null) set(r.copyWith(margin: m));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // لون الخلفية
                  Text(s.backgroundColor, style: labelStyle),
                  if (r.nightMode) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.colorsDayOnly,
                      style: TextStyle(fontSize: 12.5, color: c.muted),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // الوضع الليلي له لون موحّد، فالألوان تعمل نهارًا فقط
                  IgnorePointer(
                    ignoring: r.nightMode,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: r.nightMode ? 0.35 : 1,
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          for (final (i, b) in ReaderBackground.values.indexed)
                            _Swatch(
                              color: b.color,
                              label: s.readerBackgrounds[i],
                              selected: r.background == b,
                              chrome: c,
                              onTap: () => set(r.copyWith(background: b)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: c.line, height: 1),
                  const SizedBox(height: 6),

                  // المفاتيح
                  if (showLayout)
                    _SwitchRow(
                      label: s.verticalReading,
                      value: r.vertical,
                      style: labelStyle,
                      chrome: c,
                      onChanged: (v) => set(r.copyWith(vertical: v)),
                    ),
                  _SwitchRow(
                    label: s.nightMode,
                    value: r.nightMode,
                    style: labelStyle,
                    chrome: c,
                    onChanged: (v) => set(r.copyWith(nightMode: v)),
                  ),
                  const SizedBox(height: 18),

                  // إعادة الضبط
                  Center(
                    child: OutlinedButton(
                      onPressed: repository.reset,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.ink,
                        minimumSize: const Size(200, 48),
                        side: BorderSide(color: c.ink, width: 1.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        s.resetSettings,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.style,
    required this.chrome,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final TextStyle style;
  final ReaderChrome chrome;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: enabled ? 1 : 0.45,
                child: Text(label, style: style),
              ),
            ),
            // أصفر خفيف موحد مثل باقي التطبيق
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: chrome.onAccent,
              activeTrackColor: chrome.accent,
              inactiveThumbColor: chrome.muted,
              inactiveTrackColor: chrome.chip,
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.chrome,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final ReaderChrome chrome;
  final VoidCallback onTap;

  // نفس اللون أغمق (للورق الفاتح) أو أفتح (للورق الداكن)
  Color get _deep => color.computeLuminance() > 0.4
      ? Color.lerp(color, Colors.black, 0.45)!
      : Color.lerp(color, Colors.white, 0.55)!;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            // المختار بإطار من درجة أعمق من لونه نفسه (لا لون الثيم)
            border: Border.all(
              color: selected ? _deep : chrome.line,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected ? Icon(Icons.check, size: 20, color: _deep) : null,
        ),
      ),
    );
  }
}
