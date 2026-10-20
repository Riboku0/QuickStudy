// إعدادات العارض (واحدة لكل الكتب)
enum ReaderMargin { none, standard, wide }

// ألوان الورق (مقتبسة من مرجع المستخدم)، بترتيب ظهورها في اللوحة
enum ReaderBackground { classic, green, blue, light, warm, dark }

class ReaderSettings {
  const ReaderSettings({
    this.brightness = 1.0,
    this.margin = ReaderMargin.standard,
    this.background = ReaderBackground.classic,
    this.nightMode = false,
    this.vertical = true,
  });

  static const ReaderSettings defaults = ReaderSettings();

  static const double minBrightness = 0.3;

  final double brightness; // 0.3..1.0 (1 = بدون تعتيم)
  final ReaderMargin margin;
  final ReaderBackground background;
  final bool nightMode; // عكس ألوان الصفحات
  final bool vertical; // false = تقليب أفقي صفحة صفحة

  ReaderSettings copyWith({
    double? brightness,
    ReaderMargin? margin,
    ReaderBackground? background,
    bool? nightMode,
    bool? vertical,
  }) {
    return ReaderSettings(
      brightness: brightness ?? this.brightness,
      margin: margin ?? this.margin,
      background: background ?? this.background,
      nightMode: nightMode ?? this.nightMode,
      vertical: vertical ?? this.vertical,
    );
  }

  Map<String, Object?> toMap() => {
    'brightness': brightness,
    'margin': margin.name,
    'background': background.name,
    'nightMode': nightMode,
    'vertical': vertical,
  };

  // أسماء الألوان القديمة المحفوظة ← أقرب لون جديد (حتى لا يضيع اختيار المستخدم)
  static const Map<String, String> _oldBackgrounds = {
    'cream': 'classic',
    'mint': 'green',
    'beige': 'warm',
    'black': 'dark',
    'charcoal': 'dark',
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
      vertical: map['vertical'] != false,
    );
  }
}
