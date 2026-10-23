// إعدادات العارض (واحدة لكل الكتب)
enum ReaderMargin { none, standard, wide }

// ألوان الورق (مقتبسة من مرجع المستخدم)، بترتيب ظهورها في اللوحة
enum ReaderBackground { classic, green, blue, light, warm, dark }

// ثيمات الوضع الليلي (مواصفات المستخدم 23 أكتوبر، الثانية): كل ثيم يلوّن
// القارئ كله (الخلفية، الصفحة، اللوحات، التمييز). حبر هو الافتراضي
enum NightBackground { obsidian, ink, oliveSmoke, mocha }

class ReaderSettings {
  const ReaderSettings({
    this.brightness = 1.0,
    this.margin = ReaderMargin.standard,
    this.background = ReaderBackground.classic,
    this.nightMode = false,
    this.nightBackground = NightBackground.ink,
    this.vertical = true,
    this.textFontSize = defaultTextFontSize,
    this.customInkColor,
    this.noteBookmarkHintSeen = false,
  });

  static const ReaderSettings defaults = ReaderSettings();

  static const double minBrightness = 0.3;

  // حجم خط وضع القراءة النصي
  static const double defaultTextFontSize = 18;
  static const double minTextFontSize = 12;
  static const double maxTextFontSize = 34;

  final double brightness; // 0.3..1.0 (1 = بدون تعتيم)
  final ReaderMargin margin;
  final ReaderBackground background;
  final bool nightMode; // عكس ألوان الصفحات
  final NightBackground nightBackground; // خلفية الليلي المختارة
  // false = قراءة أفقية صفحة بصفحة (لكل الكتب)، واتجاهها من لغة الكتاب
  final bool vertical;
  final double textFontSize; // وضع القراءة النصي (النص المستخرج بحجم خط)
  final int? customInkColor; // اللون السادس في لوحة القلم (من عجلة الألوان)
  // تلميح زر علامة المذكرة يظهر مرة واحدة فقط
  final bool noteBookmarkHintSeen;

  ReaderSettings copyWith({
    double? brightness,
    ReaderMargin? margin,
    ReaderBackground? background,
    bool? nightMode,
    NightBackground? nightBackground,
    bool? vertical,
    double? textFontSize,
    int? customInkColor,
    bool? noteBookmarkHintSeen,
  }) {
    return ReaderSettings(
      brightness: brightness ?? this.brightness,
      margin: margin ?? this.margin,
      background: background ?? this.background,
      nightMode: nightMode ?? this.nightMode,
      nightBackground: nightBackground ?? this.nightBackground,
      vertical: vertical ?? this.vertical,
      textFontSize: textFontSize ?? this.textFontSize,
      customInkColor: customInkColor ?? this.customInkColor,
      noteBookmarkHintSeen: noteBookmarkHintSeen ?? this.noteBookmarkHintSeen,
    );
  }

  Map<String, Object?> toMap() => {
    'brightness': brightness,
    'margin': margin.name,
    'background': background.name,
    'nightMode': nightMode,
    'nightBackground': nightBackground.name,
    'vertical': vertical,
    'textFontSize': textFontSize,
    'customInkColor': ?customInkColor,
    'noteBookmarkHintSeen': noteBookmarkHintSeen,
  };

  // أسماء الألوان القديمة المحفوظة ← أقرب لون جديد (حتى لا يضيع اختيار المستخدم)
  static const Map<String, String> _oldBackgrounds = {
    'cream': 'classic',
    'mint': 'green',
    'beige': 'warm',
    'black': 'dark',
    'charcoal': 'dark',
  };

  // ثيمات الليلي القديمة ← أقرب ثيم جديد
  static const Map<String, String> _oldNights = {
    'night': 'ink',
    'slate': 'ink',
    'plum': 'ink',
    'charcoal': 'obsidian',
    'olive': 'oliveSmoke',
  };

  factory ReaderSettings.fromMap(Map<String, Object?> map) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    final b = (map['brightness'] as num?)?.toDouble() ?? 1.0;

    return ReaderSettings(
      brightness: b.clamp(minBrightness, 1.0).toDouble(),
      margin: byName(ReaderMargin.values, map['margin'], ReaderMargin.standard),
      background: byName(
        ReaderBackground.values,
        _oldBackgrounds[map['background']] ?? map['background'],
        ReaderBackground.classic,
      ),
      nightMode: map['nightMode'] == true,
      nightBackground: byName(
        NightBackground.values,
        _oldNights[map['nightBackground']] ?? map['nightBackground'],
        NightBackground.ink,
      ),
      vertical: map['vertical'] != false,
      textFontSize: ((map['textFontSize'] as num?)?.toDouble() ??
              defaultTextFontSize)
          .clamp(minTextFontSize, maxTextFontSize)
          .toDouble(),
      customInkColor: (map['customInkColor'] as num?)?.toInt(),
      noteBookmarkHintSeen: map['noteBookmarkHintSeen'] == true,
    );
  }
}
