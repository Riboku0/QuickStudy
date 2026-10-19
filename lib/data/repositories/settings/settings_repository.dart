import 'package:flutter/foundation.dart';

import '../../services/settings_service.dart';

enum AppThemeChoice { system, light, dark }

enum AppLanguageChoice { system, english, arabic }

// لون التطبيق (الثيم): يطبّق على المكتبة والمذاكرة والرئيسية والشريط السفلي
enum AppAccent { violet, ocean, emerald, rose, sunset, graphite }

// مصدر واحد لإعدادات المظهر واللغة.
// التطبيق كله يستمع إليه ويعيد البناء عند أي تغيير.
class SettingsRepository extends ChangeNotifier {
  SettingsRepository({required SettingsService service}) : _service = service;

  final SettingsService _service;

  AppThemeChoice _theme = AppThemeChoice.system;
  AppLanguageChoice _language = AppLanguageChoice.system;
  String _userName = '';
  AppAccent _accent = AppAccent.violet;
  bool _loaded = false;

  AppThemeChoice get theme => _theme;
  AppLanguageChoice get language => _language;

  // اسم المستخدم (يكتبه من قائمة الحساب، ولاحقًا من حساب قوقل)
  String get userName => _userName;

  AppAccent get accent => _accent;
  bool get isLoaded => _loaded;

  // تصنيفات الكتب التي أضافها المستخدم (بعد التصنيفات الأربعة الثابتة)
  List<String> _bookCategories = const [];
  List<String> get bookCategories => _bookCategories;

  // يضيف تصنيفًا ويُرجع اسمه بعد التنظيف، أو null إن كان فارغًا
  Future<String?> addBookCategory(String name, {List<String> taken = const []}) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    final exists = [...taken, ..._bookCategories]
        .any((c) => c.toLowerCase() == clean.toLowerCase());
    if (exists) return clean;
    _bookCategories = List.unmodifiable([..._bookCategories, clean]);
    notifyListeners();
    await _save();
    return clean;
  }

  Future<void> load() async {
    final data = await _service.read();
    _theme = _byName(AppThemeChoice.values, data['theme'], AppThemeChoice.system);
    _language = _byName(
      AppLanguageChoice.values,
      data['language'],
      AppLanguageChoice.system,
    );
    final name = data['userName'];
    _userName = name is String ? name : '';
    _accent = _byName(AppAccent.values, data['accent'], AppAccent.violet);
    final cats = data['bookCategories'];
    _bookCategories = cats is List
        ? List.unmodifiable(cats.whereType<String>())
        : const [];
    _loaded = true;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeChoice value) async {
    if (value == _theme) return;
    _theme = value;
    notifyListeners(); // التغيير يظهر فورًا، والحفظ بعده
    await _save();
  }

  Future<void> setLanguage(AppLanguageChoice value) async {
    if (value == _language) return;
    _language = value;
    notifyListeners();
    await _save();
  }

  Future<void> setAccent(AppAccent value) async {
    if (value == _accent) return;
    _accent = value;
    notifyListeners();
    await _save();
  }

  Future<void> setUserName(String value) async {
    final clean = value.trim();
    if (clean == _userName) return;
    _userName = clean;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _service.write({
        'theme': _theme.name,
        'language': _language.name,
        'userName': _userName,
        'accent': _accent.name,
        'bookCategories': _bookCategories,
      });
    } catch (_) {
      // فشل الحفظ لا يمنع استخدام الإعداد في هذه الجلسة
    }
  }

  static T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
