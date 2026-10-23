import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/repositories/reader/reader_settings_repository.dart';
import '../../../domain/models/reader_settings.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/themes/app_icons.dart';
import '../../core/ui/app_icon.dart';
import 'reader_chrome.dart';

// ألوان القراءة في مكان واحد: كل خلفية ولون نصها (مواصفات المستخدم 22 أكتوبر:
// هادئة للقراءة الطويلة، بلا أبيض حاد ولا أسود صرف). العارضان يرسمان الصفحة
// بتحويل خطي: أبيض الصفحة ← الخلفية، وأسودها ← النص.
extension ReaderBackgroundColor on ReaderBackground {
  Color get color => switch (this) {
    ReaderBackground.classic => const Color(0xFFF3E8D5), // Warm Ivory
    ReaderBackground.green => const Color(0xFFDFEBDD), // Sage Mist
    ReaderBackground.blue => const Color(0xFFDFEAF2), // Powder Blue
    ReaderBackground.light => const Color(0xFFF2F0E9), // Soft Paper
    ReaderBackground.warm => const Color(0xFFF2E2D8), // Peach Cream
    ReaderBackground.dark => const Color(0xFF292E32), // Midnight Slate
  };

  // لون النص المناسب لكل خلفية
  Color get ink => switch (this) {
    ReaderBackground.classic => const Color(0xFF393025),
    ReaderBackground.green => const Color(0xFF2D3B32),
    ReaderBackground.blue => const Color(0xFF2C3946),
    ReaderBackground.light => const Color(0xFF33322F),
    ReaderBackground.warm => const Color(0xFF43332E),
    ReaderBackground.dark => const Color(0xFFE5E8E7),
  };

  bool get isDark => this == ReaderBackground.dark;
}

// ثيمات الوضع الليلي الأربعة: ألوانها كلها في NightTheme (reader_chrome.dart)
extension NightBackgroundColor on NightBackground {
  NightTheme get theme => switch (this) {
    NightBackground.obsidian => NightTheme.obsidian,
    NightBackground.ink => NightTheme.ink,
    NightBackground.oliveSmoke => NightTheme.oliveSmoke,
    NightBackground.mocha => NightTheme.mocha,
  };

  Color get color => theme.page;
  Color get ink => theme.text;
}

// ورق القراءة الحالي ونصه حسب الإعدادات (للعارض)
extension ReaderPaper on ReaderSettings {
  Color get paperColor => nightMode ? nightBackground.color : background.color;
  Color get inkColor => nightMode ? nightBackground.ink : background.ink;
  bool get darkPaper => nightMode || background.isDark;

  // مصدر واحد لكل ألوان القارئ واللوحات (الصفحة تُلوَّن من paperColor/inkColor)
  ReaderChrome get chrome => ReaderChrome(
    dark: darkPaper,
    paper: paperColor,
    night: nightMode ? nightBackground.theme : null,
  );
}

// لوحة إعدادات القراءة (تفتح من زر الإعدادات في العارض)
// كل تغيير يُطبَّق فورًا ويُحفظ لكل الكتب. شكلها من مرجع المستخدم (23 أكتوبر):
// رأس بالعنوان والوصف وصورة البومة الليلية، ثم بطاقات (السطوع، الهوامش، لون
// الخلفية، القراءة الأفقية، الليلي) وزر إعادة الضبط. نهارًا ألوانها من الورق،
// وليلًا ألوان الثيم الليلي المختار (ReaderSettings.chrome، نفس مصدر العارض)،
// فتتغير اللوحة مع الصفحة في نفس اللحظة وهي مفتوحة.
// السحب للأسفل من المقبض، أو من المحتوى وهو في أعلاه، يحرك اللوحة مع الإصبع؛
// بعد مسافة أو سرعة كافية تُغلق، وإلا ترجع لمكانها.
class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.repository,
    required this.textMode,
  });

  final ReaderSettingsRepository repository;
  // القراءة النصية في العارض المفتوح (ليست إعدادًا محفوظًا)
  final ValueNotifier<bool> textMode;

  // صورة البومة (زخرفة فقط، لا تلتقط اللمس)
  static const String owlImage = 'assets/owl/owl_night.webp';

  static Future<void> show(
    BuildContext context,
    ReaderSettingsRepository repository,
    ValueNotifier<bool> textMode,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // فوق شريط أزرار أندرويد (التطبيق يخفي شريط الحالة فقط)
      useSafeArea: true,
      // السحب من عندنا (سحب BottomSheet لا يصل إليه المحتوى القابل للتمرير)
      enableDrag: false,
      // اللون من داخل اللوحة (يتغير فورًا مع الوضع الليلي)
      backgroundColor: Colors.transparent,
      // بدون تعتيم حتى ترى أثر التغيير على الصفحة
      barrierColor: Colors.transparent,
      builder: (_) =>
          ReaderSettingsSheet(repository: repository, textMode: textMode),
    );
  }

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet>
    with SingleTickerProviderStateMixin {
  // إزاحة اللوحة للأسفل بالبكسل (0 = في مكانها)
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  final _sheetKey = GlobalKey();
  bool _closing = false;

  ReaderSettingsRepository get repository => widget.repository;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  // يحرك اللوحة بمقدار delta (موجب = للأسفل)، ويرجع ما لم يُستهلك
  double _absorb(double delta, ScrollMetrics? scroll) {
    if (_closing) return 0;
    final atTop = scroll == null || scroll.pixels <= scroll.minScrollExtent;
    if (_offset.value <= 0 && !(delta > 0 && atTop)) return delta;
    final next = _offset.value + delta;
    if (next >= 0) {
      _offset.value = next;
      return 0;
    }
    _offset.value = 0;
    return next; // باقي الحركة للأعلى يعود لتمرير المحتوى
  }

  // الإفلات: سرعة للأسفل أو مسافة كافية تغلق، وإلا ترجع
  void _release(double velocity) {
    if (_closing || _offset.value <= 0) return;
    final height = _sheetKey.currentContext?.size?.height ?? 400;
    final far = _offset.value > math.min(140.0, height * 0.28);
    if (velocity > 700 || (far && velocity > -300)) {
      _closing = true;
      _offset
          .animateTo(
            height,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeIn,
          )
          .whenComplete(() {
            if (mounted) Navigator.of(context).pop();
          });
    } else {
      _offset.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ListenableBuilder(
      listenable: Listenable.merge([repository, widget.textMode]),
      builder: (context, _) {
        final r = repository.settings;
        void set(ReaderSettings value) => repository.update(value);
        final night = r.nightMode;
        final c = r.chrome;
        final title = TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: c.ink,
        );
        final hint = TextStyle(fontSize: 12.5, color: c.muted, height: 1.35);

        final sheet = AnimatedContainer(
          key: _sheetKey,
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // المقبض: منطقة سحب بارتفاع لمس كافٍ
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => _offset.stop(),
                  onVerticalDragUpdate: (d) => _absorb(d.delta.dy, null),
                  onVerticalDragEnd: (d) => _release(d.primaryVelocity ?? 0),
                  onVerticalDragCancel: () => _release(0),
                  child: SizedBox(
                    height: 28,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.icon.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (n) {
                      _release(n.dragDetails?.primaryVelocity ?? 0);
                      return false;
                    },
                    child: SingleChildScrollView(
                      physics: _SheetScrollPhysics(
                        absorb: _absorb,
                        held: () => _offset.value > 0,
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        18 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            title: s.readerSettings,
                            subtitle: s.readerSettingsHint,
                            chrome: c,
                            // السطوع: بطاقته فوق الجزء السفلي من البومة
                            below: _Card(
                              chrome: c,
                              child: Row(
                                children: [
                                  AppIcon(
                                    AppIcons.sun,
                                    size: 22,
                                    color: c.icon,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.brightness, style: title),
                                        SliderTheme(
                                          data: SliderTheme.of(context)
                                              .copyWith(
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
                                            onChanged: (v) =>
                                                set(r.copyWith(brightness: v)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.wb_sunny_rounded,
                                    size: 24,
                                    color: c.strong,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // الهوامش
                          _Card(
                            chrome: c,
                            child: Row(
                              children: [
                                AppIcon(
                                  AppIcons.margins,
                                  size: 22,
                                  color: c.icon,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Texts(
                                    title: s.margins,
                                    hint: s.marginsHint,
                                    titleStyle: title,
                                    hintStyle: hint,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _MarginPicker(
                                  value: r.margin,
                                  chrome: c,
                                  labels: [
                                    s.marginNone,
                                    s.marginStandard,
                                    s.marginWide,
                                  ],
                                  onChanged: (m) => set(r.copyWith(margin: m)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // لون الخلفية: ألوان الليلي في الوضع الليلي، وألوان النهار نهارًا
                          _Card(
                            chrome: c,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    AppIcon(
                                      AppIcons.palette,
                                      size: 22,
                                      color: c.icon,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _Texts(
                                        title: s.backgroundColor,
                                        hint: s.backgroundHint,
                                        titleStyle: title,
                                        hintStyle: hint,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                GridView.count(
                                  crossAxisCount: night ? 2 : 3,
                                  shrinkWrap: true,
                                  // بلا حشوة المساحة الآمنة التي تضيفها القوائم تلقائيًا
                                  // (كانت فراغًا بارتفاع أزرار أندرويد تحت الألوان)
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: night ? 2.5 : 1.45,
                                  children: night
                                      ? [
                                          for (final (i, b)
                                              in NightBackground.values.indexed)
                                            _Swatch(
                                              color: b.color,
                                              label: s.nightBackgrounds[i],
                                              selected: r.nightBackground == b,
                                              chrome: c,
                                              outline: c.strong,
                                              onTap: () => set(
                                                r.copyWith(nightBackground: b),
                                              ),
                                            ),
                                        ]
                                      : [
                                          for (final (i, b)
                                              in ReaderBackground
                                                  .values
                                                  .indexed)
                                            _Swatch(
                                              color: b.color,
                                              label: s.readerBackgrounds[i],
                                              selected: r.background == b,
                                              chrome: c,
                                              onTap: () => set(
                                                r.copyWith(background: b),
                                              ),
                                            ),
                                        ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // القراءة النصية وحجم خطها (النص المستخرج بعرض الشاشة)
                          _Card(
                            chrome: c,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SwitchRow(
                                  leading: AppIcon(
                                    AppIcons.textReading,
                                    size: 22,
                                    color: c.icon,
                                  ),
                                  title: s.textReading,
                                  hint: s.textReadingHint,
                                  titleStyle: title,
                                  hintStyle: hint,
                                  value: widget.textMode.value,
                                  chrome: c,
                                  onChanged: (v) => widget.textMode.value = v,
                                ),
                                Divider(height: 22, color: c.line),
                                _FontSizeRow(
                                  size: r.textFontSize,
                                  chrome: c,
                                  title: title,
                                  hint: hint,
                                  onChanged: (v) =>
                                      set(r.copyWith(textFontSize: v)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // القراءة الأفقية
                          _Card(
                            chrome: c,
                            child: _SwitchRow(
                              leading: AppIcon(
                                AppIcons.book,
                                size: 22,
                                color: c.icon,
                              ),
                              title: s.horizontalReading,
                              hint: s.horizontalReadingHint,
                              titleStyle: title,
                              hintStyle: hint,
                              value: !r.vertical,
                              chrome: c,
                              onChanged: (v) => set(r.copyWith(vertical: !v)),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // الوضع الليلي
                          _Card(
                            chrome: c,
                            child: _SwitchRow(
                              leading: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: AppIcon(
                                  AppIcons.moon,
                                  size: 21,
                                  color: c.strong,
                                ),
                              ),
                              title: s.nightMode,
                              hint: s.nightModeHint,
                              titleStyle: title,
                              hintStyle: hint,
                              value: night,
                              chrome: c,
                              onChanged: (v) => set(r.copyWith(nightMode: v)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // إعادة الضبط
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: repository.reset,
                              icon: AppIcon(
                                AppIcons.refresh,
                                size: 19,
                                color: c.ink,
                              ),
                              label: Text(
                                s.resetSettings,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.ink,
                                minimumSize: const Size(220, 50),
                                side: BorderSide(color: c.muted, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return AnimatedBuilder(
          animation: _offset,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, math.max(0, _offset.value)),
            child: child,
          ),
          child: sheet,
        );
      },
    );
  }
}

// تمرير محتوى اللوحة: وهو في أعلاه، السحب للأسفل يحرك اللوحة نفسها، وما دامت
// اللوحة منزاحة يحركها السحب للأعلى أولًا ثم يعود الباقي للمحتوى. ولا انزلاق
// للمحتوى عند الإفلات واللوحة منزاحة (الإفلات يقرر الإغلاق أو الرجوع).
class _SheetScrollPhysics extends ClampingScrollPhysics {
  const _SheetScrollPhysics({
    required this.absorb,
    required this.held,
    super.parent,
  });

  // offset في التمرير: موجب = الإصبع يتحرك للأسفل
  final double Function(double delta, ScrollMetrics scroll) absorb;
  final bool Function() held;

  @override
  _SheetScrollPhysics applyTo(ScrollPhysics? ancestor) => _SheetScrollPhysics(
    absorb: absorb,
    held: held,
    parent: buildParent(ancestor),
  );

  // حتى لو كان المحتوى كله ظاهرًا: السحب يصل إلينا فيحرك اللوحة
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, absorb(offset, position));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => held() ? null : super.createBallisticSimulation(position, velocity);
}

// حجم خط القراءة النصية: تصغير، الحجم الحالي، تكبير، الافتراضي
class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({
    required this.size,
    required this.chrome,
    required this.title,
    required this.hint,
    required this.onChanged,
  });

  final double size;
  final ReaderChrome chrome;
  final TextStyle title;
  final TextStyle hint;
  final ValueChanged<double> onChanged;

  static const double _step = 2;

  double _clamp(double v) => v
      .clamp(ReaderSettings.minTextFontSize, ReaderSettings.maxTextFontSize)
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = chrome;
    final canDown = size > ReaderSettings.minTextFontSize;
    final canUp = size < ReaderSettings.maxTextFontSize;
    final isDefault = size == ReaderSettings.defaultTextFontSize;

    Widget button(double letter, String tooltip, double? to) => Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: to != null,
        label: tooltip,
        child: Material(
          color: c.chip,
          shape: CircleBorder(side: BorderSide(color: c.line)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: to == null ? null : () => onChanged(to),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: ExcludeSemantics(
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontSize: letter,
                      fontWeight: FontWeight.w800,
                      color: to == null
                          ? c.muted.withValues(alpha: 0.4)
                          : c.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIcon(AppIcons.fontSize, size: 22, color: c.icon),
            const SizedBox(width: 12),
            Expanded(
              child: _Texts(
                title: s.fontSize,
                hint: s.fontSizeHint,
                titleStyle: title,
                hintStyle: hint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            button(14, s.smallerText, canDown ? _clamp(size - _step) : null),
            Expanded(
              child: Text(
                '${size.round()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
            ),
            button(21, s.largerText, canUp ? _clamp(size + _step) : null),
            const SizedBox(width: 8),
            TextButton(
              onPressed: isDefault
                  ? null
                  : () => onChanged(ReaderSettings.defaultTextFontSize),
              style: TextButton.styleFrom(
                foregroundColor: c.strong,
                disabledForegroundColor: c.muted.withValues(alpha: 0.5),
                minimumSize: const Size(48, 46),
              ),
              child: Text(s.resetFontSize),
            ),
          ],
        ),
      ],
    );
  }
}

// العنوان والوصف، والبومة في الزاوية العليا (يمينًا بالإنجليزية ويسارًا
// بالعربية) يختفي أسفلها خلف أول بطاقة كأنها تطل من ورائها (مرجع المستخدم).
// حجمها نسبة من عرض اللوحة (بين 104 و140) فلا تغطي النص في الشاشات الصغيرة،
// وتُفك بحجم عرضها فقط، ولا تلتقط اللمس.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.chrome,
    required this.below,
  });

  final String title;
  final String subtitle;
  final ReaderChrome chrome;
  final Widget below; // أول بطاقة، تُرسم فوق أسفل البومة

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final owl = (box.maxWidth * 0.36).clamp(104.0, 140.0);
        // ما يظهر من البومة فوق البطاقة (الباقي خلفها)
        final visible = owl * 0.7;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              top: 0,
              end: 0,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Image.asset(
                    ReaderSettingsSheet.owlImage,
                    width: owl,
                    height: owl,
                    fit: BoxFit.contain,
                    cacheWidth: (owl * dpr).round(),
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: visible,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: 6,
                      end: owl * 0.82,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: chrome.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          style: TextStyle(fontSize: 13.5, color: chrome.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                below,
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.chrome, required this.child});

  final ReaderChrome chrome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: chrome.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: chrome.line),
      ),
      child: child,
    );
  }
}

class _Texts extends StatelessWidget {
  const _Texts({
    required this.title,
    required this.hint,
    required this.titleStyle,
    required this.hintStyle,
  });

  final String title;
  final String hint;
  final TextStyle titleStyle;
  final TextStyle hintStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 2),
        Text(hint, style: hintStyle),
      ],
    );
  }
}

class _MarginPicker extends StatelessWidget {
  const _MarginPicker({
    required this.value,
    required this.chrome,
    required this.labels,
    required this.onChanged,
  });

  final ReaderMargin value;
  final ReaderChrome chrome;
  final List<String> labels; // بترتيب ReaderMargin
  final ValueChanged<ReaderMargin> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = chrome;
    return Container(
      height: 42,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
      decoration: BoxDecoration(
        color: c.chip,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ReaderMargin>(
          value: value,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: c.card,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.ink),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
          items: [
            for (final m in ReaderMargin.values)
              DropdownMenuItem(value: m, child: Text(labels[m.index])),
          ],
          onChanged: (m) {
            if (m != null) onChanged(m);
          },
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.leading,
    required this.title,
    required this.hint,
    required this.titleStyle,
    required this.hintStyle,
    required this.value,
    required this.chrome,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final String hint;
  final TextStyle titleStyle;
  final TextStyle hintStyle;
  final bool value;
  final ReaderChrome chrome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: _Texts(
              title: title,
              hint: hint,
              titleStyle: titleStyle,
              hintStyle: hintStyle,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: chrome.strong,
            inactiveThumbColor: chrome.muted,
            inactiveTrackColor: chrome.chip,
            trackOutlineColor: WidgetStatePropertyAll(
              value ? Colors.transparent : chrome.line,
            ),
          ),
        ],
      ),
    );
  }
}

// عينة لون: معاينة مستديرة واسمها تحتها. المختار بإطار وعلامة صح:
// outline = لون الثيم (الليلي)، وبدونه درجة أعمق من اللون نفسه (النهار، طلب
// المستخدم 19 أكتوبر)
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.chrome,
    required this.onTap,
    this.outline,
  });

  final Color color;
  final String label;
  final bool selected;
  final ReaderChrome chrome;
  final VoidCallback onTap;
  final Color? outline;

  // نفس اللون أغمق (للورق الفاتح) أو أفتح (للورق الداكن)
  Color get _deep => color.computeLuminance() > 0.4
      ? Color.lerp(color, Colors.black, 0.45)!
      : Color.lerp(color, Colors.white, 0.55)!;

  @override
  Widget build(BuildContext context) {
    final mark = outline ?? _deep;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? mark : chrome.line,
                    width: selected ? 2.2 : 1,
                  ),
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  scale: selected ? 1 : 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mark,
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon(
                      AppIcons.check,
                      size: 15,
                      color: mark.computeLuminance() > 0.5
                          ? const Color(0xFF202020)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? chrome.ink : chrome.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
